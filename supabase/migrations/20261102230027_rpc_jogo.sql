-- Funções de jogo: criar (RF07, RF08) e duplicar (RF34), e as auxiliares que presença e
-- edição reaproveitam: o prazo sem multa (RN02, RN20), as checagens de quadra e de
-- funcionamento (RN15) e o nascimento da cobrança (RN07, RN25).
-- Cresce nas próximas tasks com editar_jogo, cancelar_jogo e encerrar_jogo.
--
-- Recusas (supabase/CLAUDE.md, Funções): P0001 com o código na mensagem; 42501 com
-- 'sem_permissao'.

-- Prazo sem multa do jogo (RN02): início menos o prazo — do jogo, ou do grupo quando o
-- jogo não tem o próprio (RN12) —, ou cancelamento_livre_ate, o que for mais tardio
-- (RN20). greatest ignora o vazio.
create function privado.prazo_sem_multa(p_jogo uuid)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select greatest(
           j.inicio - make_interval(hours => coalesce(j.prazo_cancelamento_horas, g.prazo_cancelamento_horas)),
           j.cancelamento_livre_ate)
  from public.jogo j
  left join public.grupo g on g.id = j.grupo_id
  where j.id = p_jogo;
$$;

-- RN15: quadra do modo do local, funcionamento e ocupação. Quem chama já segura a trava
-- do local (pg_advisory_xact_lock), para dois pedidos simultâneos não passarem juntos.
-- p_jogo_ignorado tira o próprio jogo da conta, na remarcação (T07).
create function privado.checar_rn15(
  p_local uuid,
  p_quadra uuid,
  p_inicio timestamptz,
  p_duracao_minutos integer,
  p_jogo_ignorado uuid default null
)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_local public.local;
  v_fim timestamptz := p_inicio + make_interval(mins => p_duracao_minutos);
  -- Faixas de funcionamento são horas locais de Brasília.
  v_inicio_local timestamp := p_inicio at time zone 'America/Sao_Paulo';
  v_fim_local timestamp := (p_inicio at time zone 'America/Sao_Paulo') + make_interval(mins => p_duracao_minutos);
  v_pico integer;
begin
  select * into v_local from public.local where id = p_local;
  if not found then
    raise exception using errcode = 'P0001', message = 'local_invalido';
  end if;

  -- No modo por_quadra a quadra é obrigatória e do próprio local; no por_horario, vazia.
  if v_local.modo_reserva = 'por_quadra' then
    if p_quadra is null then
      raise exception using errcode = 'P0001', message = 'quadra_obrigatoria';
    end if;
    if not exists (select 1 from public.quadra where id = p_quadra and local_id = p_local) then
      raise exception using errcode = 'P0001', message = 'quadra_invalida';
    end if;
  elsif p_quadra is not null then
    raise exception using errcode = 'P0001', message = 'quadra_invalida';
  end if;

  -- O jogo inteiro cabe numa faixa. A faixa com fecha <= abre termina no dia seguinte,
  -- inclusive a que fecha à meia-noite; por isso a faixa do dia anterior também é candidata.
  if not exists (
    select 1
    from public.horario_funcionamento h
    cross join lateral (values (v_inicio_local::date), (v_inicio_local::date - 1)) d(dia)
    where h.local_id = p_local
      and h.dia_semana = extract(dow from d.dia)
      and d.dia + h.abre <= v_inicio_local
      and v_fim_local <= d.dia + h.fecha
                         + case when h.fecha <= h.abre then interval '1 day' else interval '0' end
  ) then
    raise exception using errcode = 'P0001', message = 'fora_do_funcionamento';
  end if;

  -- Jogo cancelado não ocupa; aberto e encerrado ocupam. Intervalos semiabertos: o jogo
  -- que começa quando o outro termina não sobrepõe.
  if v_local.modo_reserva = 'por_quadra' then
    if exists (
      select 1 from public.jogo j
      where j.quadra_id = p_quadra
        and j.status in ('aberto', 'encerrado')
        and j.id is distinct from p_jogo_ignorado
        and j.inicio < v_fim
        and j.inicio + make_interval(mins => j.duracao_minutos) > p_inicio
    ) then
      raise exception using errcode = 'P0001', message = 'quadra_ocupada';
    end if;
  elsif v_local.capacidade is not null then
    -- Pico de jogos simultâneos dentro do intervalo: a lotação só cresce quando um jogo
    -- começa, então basta contar no início do novo e no de cada jogo que começa durante ele.
    select coalesce(max(n), 0) into v_pico
    from (
      select (
        select count(*) from public.jogo j
        where j.local_id = p_local
          and j.status in ('aberto', 'encerrado')
          and j.id is distinct from p_jogo_ignorado
          and j.inicio <= t.instante
          and j.inicio + make_interval(mins => j.duracao_minutos) > t.instante
      ) as n
      from (
        select p_inicio as instante
        union
        select j.inicio from public.jogo j
        where j.local_id = p_local
          and j.status in ('aberto', 'encerrado')
          and j.id is distinct from p_jogo_ignorado
          and j.inicio > p_inicio
          and j.inicio < v_fim
      ) t
    ) contagem;

    if v_pico + 1 > v_local.capacidade then
      raise exception using errcode = 'P0001', message = 'local_lotado';
    end if;
  end if;
end;
$$;

-- RN07: a vaga ocupada gera a cobrança pendente de origem parte, no valor por vaga atual,
-- devida ao recebedor. Se a participação já tem cobrança, reabre a mesma (RN25): uma
-- cobrança por participação, sem exceção. Nunca para o recebedor: quem chama confere, e o
-- check cobranca_devedor_nao_e_credor recusa se escapar.
create function privado.nascer_cobranca(p_participacao uuid)
returns uuid
language sql
volatile
set search_path = ''
as $$
  insert into public.cobranca (participacao_id, devedor_id, credor_id, valor, origem, status)
  select p.id, p.pessoa_id, j.recebedor_id, j.preco_por_vaga, 'parte', 'pendente'
  from public.participacao p
  join public.jogo j on j.id = p.jogo_id
  where p.id = p_participacao
  on conflict (participacao_id) do update
  set credor_id = excluded.credor_id,
      valor = excluded.valor,
      origem = 'parte',
      status = 'pendente',
      confirmado_por = null,
      confirmado_em = null
  returning id;
$$;

-- Chave do recebedor (RN24, RN28): a digitada vale só para o jogo e não toca o perfil;
-- sem ela, a do perfil do recebedor, lida agora. Nenhuma das duas: recusa.
create function privado.chave_do_recebedor(p_recebedor uuid, p_chave_digitada text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_chave text;
begin
  select coalesce(nullif(btrim(p_chave_digitada), ''), nullif(btrim(chave_pix), ''))
  into v_chave
  from public.pessoa where id = p_recebedor;

  if v_chave is null then
    raise exception using errcode = 'P0001', message = 'recebedor_sem_chave';
  end if;
  return v_chave;
end;
$$;

-- O que criar_jogo e duplicar_jogo têm em comum, depois de conferido o papel: valida os
-- campos, resolve a chave, entra na fila do local, checa a RN15, grava o jogo aberto com
-- o preço por vaga (RN01, RN16) e põe quem chama confirmado, com cobrança só se ele não
-- for o recebedor (RN07, RN24).
create function privado.nascer_jogo(
  p_grupo uuid,
  p_local uuid,
  p_quadra uuid,
  p_inicio timestamptz,
  p_duracao_minutos integer,
  p_vagas_total integer,
  p_custo_total integer,
  p_prazo_cancelamento_horas integer,
  p_recebedor uuid,
  p_chave_pix_recebedor text
)
returns uuid
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_chave text;
  v_jogo uuid;
  v_participacao uuid;
begin
  if p_inicio is null or p_inicio <= now() then
    raise exception using errcode = 'P0001', message = 'inicio_no_passado';
  end if;
  if p_duracao_minutos is null or p_duracao_minutos <= 0 then
    raise exception using errcode = 'P0001', message = 'duracao_invalida';
  end if;
  if p_vagas_total is null or p_vagas_total <= 0 then
    raise exception using errcode = 'P0001', message = 'vagas_invalidas';
  end if;
  if p_custo_total is null or p_custo_total < 0 then
    raise exception using errcode = 'P0001', message = 'custo_invalido';
  end if;
  -- No grupo, vazio segue o grupo; no avulso é obrigatório (RN12).
  if (p_grupo is null and p_prazo_cancelamento_horas is null) or p_prazo_cancelamento_horas < 0 then
    raise exception using errcode = 'P0001', message = 'prazo_invalido';
  end if;

  v_chave := privado.chave_do_recebedor(p_recebedor, p_chave_pix_recebedor);

  -- Fila por local (docs/stack.md): a trava da linha do jogo não alcança dois jogos que
  -- ainda não existem. Quem chega junto espera e checa depois que o primeiro gravou.
  perform pg_advisory_xact_lock(hashtextextended(p_local::text, 0));
  perform privado.checar_rn15(p_local, p_quadra, p_inicio, p_duracao_minutos);

  insert into public.jogo (grupo_id, criador_id, recebedor_id, chave_pix_recebedor, local_id, quadra_id,
                           inicio, duracao_minutos, vagas_total, custo_total, preco_por_vaga,
                           prazo_cancelamento_horas, status)
  values (p_grupo, v_eu, p_recebedor, v_chave, p_local, p_quadra,
          p_inicio, p_duracao_minutos, p_vagas_total, p_custo_total,
          (p_custo_total + p_vagas_total - 1) / p_vagas_total,
          p_prazo_cancelamento_horas, 'aberto')
  returning id into v_jogo;

  insert into public.participacao (jogo_id, pessoa_id, status, confirmado_em)
  values (v_jogo, v_eu, 'confirmado', now())
  returning id into v_participacao;

  if v_eu <> p_recebedor then
    perform privado.nascer_cobranca(v_participacao);
  end if;

  return v_jogo;
end;
$$;

revoke execute on function
  privado.prazo_sem_multa(uuid),
  privado.checar_rn15(uuid, uuid, timestamptz, integer, uuid),
  privado.nascer_cobranca(uuid),
  privado.chave_do_recebedor(uuid, text),
  privado.nascer_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text)
from public, anon, authenticated;

-- RF07, RF08. No grupo, qualquer membro cria; o avulso, qualquer pessoa (RN13, RN24).
-- O recebedor é quem cria, por padrão, ou alguém que ele conhece — a lista de quem ele
-- vê (RN24). Sem grupo, p_grupo vem vazio.
create function public.criar_jogo(
  p_grupo uuid,
  p_local uuid,
  p_quadra uuid,
  p_inicio timestamptz,
  p_duracao_minutos integer,
  p_vagas_total integer,
  p_custo_total integer,
  p_prazo_cancelamento_horas integer,
  p_recebedor uuid default null,
  p_chave_pix_recebedor text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_recebedor uuid := coalesce(p_recebedor, (select auth.uid()));
begin
  if v_eu is null or (p_grupo is not null and not privado.eh_membro(p_grupo)) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;
  if not privado.conhece(v_recebedor) or not exists (select 1 from public.pessoa where id = v_recebedor) then
    raise exception using errcode = 'P0001', message = 'recebedor_desconhecido';
  end if;

  return privado.nascer_jogo(p_grupo, p_local, p_quadra, p_inicio, p_duracao_minutos, p_vagas_total,
                             p_custo_total, p_prazo_cancelamento_horas, v_recebedor, p_chave_pix_recebedor);
end;
$$;

-- RF34, RN28. Jogo do grupo: qualquer membro; avulso: só o criador da origem. Copia grupo,
-- local, quadra, duração, vagas, custo, recebedor e prazo; a chave é relida do perfil do
-- recebedor, ou digitada. Nenhuma participação é copiada: só nasce a de quem duplica,
-- que é o criador do jogo novo.
create function public.duplicar_jogo(
  p_origem uuid,
  p_inicio timestamptz,
  p_chave_pix_recebedor text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_origem public.jogo;
begin
  select * into v_origem from public.jogo where id = p_origem;

  if not found
     or v_eu is null
     or (v_origem.grupo_id is not null and not privado.eh_membro(v_origem.grupo_id))
     or (v_origem.grupo_id is null and v_origem.criador_id <> v_eu) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  return privado.nascer_jogo(v_origem.grupo_id, v_origem.local_id, v_origem.quadra_id, p_inicio,
                             v_origem.duracao_minutos, v_origem.vagas_total, v_origem.custo_total,
                             v_origem.prazo_cancelamento_horas, v_origem.recebedor_id, p_chave_pix_recebedor);
end;
$$;

revoke execute on function
  public.criar_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text),
  public.duplicar_jogo(uuid, timestamptz, text)
from public, anon;

grant execute on function
  public.criar_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text),
  public.duplicar_jogo(uuid, timestamptz, text)
to authenticated;
