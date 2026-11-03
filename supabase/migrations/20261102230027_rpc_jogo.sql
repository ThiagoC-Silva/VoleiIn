-- Funções de jogo: criar (RF07, RF08) e duplicar (RF34), e as auxiliares que presença e
-- edição reaproveitam: o prazo sem multa (RN02, RN20), as checagens de quadra e de
-- funcionamento (RN15) e o nascimento da cobrança (RN07, RN25).
-- Cresce nas próximas tasks com editar_jogo, cancelar_jogo e encerrar_jogo.
--
-- Recusas (supabase/CLAUDE.md, Funções): P0001 com o código na mensagem; 42501 com
-- 'sem_permissao'.

-- Dinheiro nos textos dos avisos (DESIGN.md, Escrita e formatos): 'R$ 1.234,56', sempre
-- com centavos. Montado à mão, sem to_char, para não depender do locale do servidor.
create function privado.reais(p_centavos integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select 'R$ '
         || regexp_replace((p_centavos / 100)::text, '(\d)(?=(\d{3})+$)', '\1.', 'g')
         || ',' || lpad((p_centavos % 100)::text, 2, '0');
$$;

-- Como o jogo aparece nos avisos: o nome do grupo, ou o do local no avulso
-- (docs/design/telas/08-avisos/implementacao.md, Convenções dos textos).
create function privado.nome_jogo(p_jogo uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(g.nome, l.nome)
  from public.jogo j
  join public.local l on l.id = j.local_id
  left join public.grupo g on g.id = j.grupo_id
  where j.id = p_jogo;
$$;

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

-- RN08: a vaga liberada é anunciada a todos da lista ao mesmo tempo, e fica com quem
-- confirmar primeiro. Chamada por cancelar_presenca e, quando as vagas aumentam, por
-- editar_jogo (T07). Lista vazia: ninguém é avisado.
create function privado.anunciar_vaga(p_jogo uuid)
returns void
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_jogo public.jogo;
  v_pessoa uuid;
begin
  select * into v_jogo from public.jogo where id = p_jogo;

  for v_pessoa in
    select pessoa_id from public.participacao
    where jogo_id = p_jogo and status = 'lista_espera'
    order by posicao_espera
  loop
    perform privado.avisar(
      v_pessoa,
      'vaga_liberada',
      format('Abriu uma vaga em %s', privado.nome_jogo(p_jogo)),
      format('%s · %s. Fica com quem confirmar primeiro.',
             privado.data_curta(v_jogo.inicio), privado.hora(v_jogo.inicio)),
      p_jogo);
  end loop;
end;
$$;

revoke execute on function
  privado.anunciar_vaga(uuid),
  privado.reais(integer),
  privado.nome_jogo(uuid),
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

-- RF10, RN20. Os parâmetros vazios ficam como estão. Quem trocar o local informa a quadra
-- do local novo junto, inclusive vazia, porque a do local antigo não serve lá.
--   Até o início: vagas, data e horário, local e quadra. Até o encerramento: custo e
--   recebedor. Duração e prazo não são editáveis (RN20).
--   Custo ou vagas recalculam o preço e as cobranças ativas (RN01). A remarcação grava
--   cancelamento_livre_ate e cancela as multas (RN02, RN20). A troca de recebedor migra o
--   credor (RN20, RN24).
-- Avisos (docs/design/telas/08-avisos/implementacao.md): o jogo é identificado pelo nome e
-- pela data de antes da edição; quem edita não recebe aviso do próprio ato.
create function public.editar_jogo(
  p_jogo uuid,
  p_inicio timestamptz default null,
  p_local uuid default null,
  p_quadra uuid default null,
  p_vagas_total integer default null,
  p_custo_total integer default null,
  p_recebedor uuid default null,
  p_chave_pix_recebedor text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_antes public.jogo;
  v_inicio timestamptz;
  v_local uuid;
  v_quadra uuid;
  v_vagas integer;
  v_custo integer;
  v_recebedor uuid;
  v_chave text;
  v_preco integer;
  v_remarca boolean;
  v_muda_vagas boolean;
  v_muda_custo boolean;
  v_muda_recebedor boolean;
  v_nome_antes text;
  v_onde text;
  v_titulo text;
  v_inicio_corpo text;
  v_aviso record;
  v_participacao public.participacao;
begin
  -- RNF09: a mesma trava de confirmar e cancelar presença.
  select * into v_antes from public.jogo where id = p_jogo for update;

  if not found or v_eu is null
     or not (v_antes.criador_id = v_eu or privado.eh_admin(v_antes.grupo_id)) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;
  if v_antes.status <> 'aberto' then
    raise exception using errcode = 'P0001', message = 'jogo_fechado';
  end if;

  v_inicio := coalesce(p_inicio, v_antes.inicio);
  v_local := coalesce(p_local, v_antes.local_id);
  v_quadra := case when v_local <> v_antes.local_id then p_quadra
                   else coalesce(p_quadra, v_antes.quadra_id) end;
  v_vagas := coalesce(p_vagas_total, v_antes.vagas_total);
  v_custo := coalesce(p_custo_total, v_antes.custo_total);
  v_recebedor := coalesce(p_recebedor, v_antes.recebedor_id);

  v_remarca := v_inicio <> v_antes.inicio or v_local <> v_antes.local_id
               or v_quadra is distinct from v_antes.quadra_id;
  v_muda_vagas := v_vagas <> v_antes.vagas_total;
  v_muda_custo := v_custo <> v_antes.custo_total;
  v_muda_recebedor := v_recebedor <> v_antes.recebedor_id;

  -- RNF10: o pedido igual ao estado atual não muda nada nem avisa.
  if not (v_remarca or v_muda_vagas or v_muda_custo or v_muda_recebedor) then
    return;
  end if;

  -- Trocar o recebedor é só do criador (RN13).
  if v_muda_recebedor and v_antes.criador_id <> v_eu then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;
  -- Janela até o início (RN06, RN20).
  if (v_remarca or v_muda_vagas) and now() >= v_antes.inicio then
    raise exception using errcode = 'P0001', message = 'jogo_ja_comecou';
  end if;
  if v_remarca and v_inicio <= now() then
    raise exception using errcode = 'P0001', message = 'inicio_no_passado';
  end if;
  if v_vagas <= 0 then
    raise exception using errcode = 'P0001', message = 'vagas_invalidas';
  end if;
  if v_custo < 0 then
    raise exception using errcode = 'P0001', message = 'custo_invalido';
  end if;
  if v_muda_vagas and v_vagas < (select count(*) from public.participacao
                                 where jogo_id = p_jogo and status = 'confirmado') then
    raise exception using errcode = 'P0001', message = 'vagas_abaixo_dos_confirmados';
  end if;
  if v_muda_recebedor then
    if not privado.conhece(v_recebedor) or not exists (select 1 from public.pessoa where id = v_recebedor) then
      raise exception using errcode = 'P0001', message = 'recebedor_desconhecido';
    end if;
    v_chave := privado.chave_do_recebedor(v_recebedor, p_chave_pix_recebedor);
  end if;

  -- Remarcação: fila do local novo e RN15 sem contar o próprio jogo.
  if v_remarca then
    perform pg_advisory_xact_lock(hashtextextended(v_local::text, 0));
    perform privado.checar_rn15(v_local, v_quadra, v_inicio, v_antes.duracao_minutos, p_jogo);
  end if;

  v_nome_antes := privado.nome_jogo(p_jogo);
  v_preco := (v_custo + v_vagas - 1) / v_vagas;

  update public.jogo
  set inicio = v_inicio,
      local_id = v_local,
      quadra_id = v_quadra,
      vagas_total = v_vagas,
      custo_total = v_custo,
      preco_por_vaga = v_preco,
      recebedor_id = v_recebedor,
      chave_pix_recebedor = case when v_muda_recebedor then v_chave else chave_pix_recebedor end,
      cancelamento_livre_ate = case when v_remarca then v_inicio else cancelamento_livre_ate end
  where id = p_jogo;

  -- Remarcação (RN20): as multas pendentes eram da vaga no horário antigo e vão a
  -- cancelada, sem autor (RN07). Quem as tinha é avisado junto com os confirmados.
  if v_remarca then
    select l.nome || coalesce(' · ' || q.nome, '') into v_onde
    from public.local l left join public.quadra q on q.id = v_quadra
    where l.id = v_local;
    v_inicio_corpo := format('%s de %s passou para %s · %s, em %s.',
                             v_nome_antes, privado.data_curta(v_antes.inicio),
                             privado.data_curta(v_inicio), privado.hora(v_inicio), v_onde);

    for v_aviso in
      update public.cobranca c
      set status = 'cancelada'
      from public.participacao p
      where p.id = c.participacao_id and p.jogo_id = p_jogo
        and c.origem = 'cancelamento_tardio' and c.status = 'pendente'
      returning c.devedor_id, c.valor
    loop
      if v_aviso.devedor_id <> v_eu then
        perform privado.avisar(
          v_aviso.devedor_id, 'jogo_editado', 'Jogo remarcado',
          format('%s Sua multa de %s foi cancelada.', v_inicio_corpo, privado.reais(v_aviso.valor)),
          p_jogo);
      end if;
    end loop;

    for v_aviso in
      select pessoa_id from public.participacao
      where jogo_id = p_jogo and status = 'confirmado' and pessoa_id <> v_eu
    loop
      perform privado.avisar(
        v_aviso.pessoa_id, 'jogo_editado', 'Jogo remarcado',
        format('%s Cancelar fica sem multa até o início.', v_inicio_corpo),
        p_jogo);
    end loop;
  end if;

  -- RN01: o valor por vaga mudou; toda cobrança ativa acompanha, parte, multa ou falta.
  -- Avisa quem a tem, menos quem edita e quem passa a ser o recebedor, cuja cobrança a
  -- troca abaixo cancela.
  if v_preco <> v_antes.preco_por_vaga then
    v_titulo := v_nome_antes || case
      when v_muda_custo and v_muda_vagas then ' mudou o custo e as vagas'
      when v_muda_custo then ' mudou o custo'
      else ' mudou as vagas' end;

    for v_aviso in
      update public.cobranca c
      set valor = v_preco
      from public.participacao p
      where p.id = c.participacao_id and p.jogo_id = p_jogo
        and c.status in ('pendente', 'comprovante_enviado')
      returning c.id, c.devedor_id, c.origem
    loop
      if v_aviso.devedor_id <> v_eu and v_aviso.devedor_id <> v_recebedor then
        perform privado.avisar(
          v_aviso.devedor_id, 'valor_recalculado', v_titulo,
          format('%s %s passou para %s.',
                 case
                   when v_muda_custo and v_muda_vagas then
                     format('Total %s em %s %s.', privado.reais(v_custo), v_vagas,
                            case when v_vagas = 1 then 'vaga' else 'vagas' end)
                   when v_muda_custo then format('Total %s.', privado.reais(v_custo))
                   else format('Agora %s %s %s.', case when v_vagas = 1 then 'é' else 'são' end, v_vagas,
                               case when v_vagas = 1 then 'vaga' else 'vagas' end)
                 end,
                 case when v_aviso.origem = 'parte' then 'Sua parte' else 'Sua multa' end,
                 privado.reais(v_preco)),
          null,
          v_aviso.id);
      end if;
    end loop;
  end if;

  -- Troca de recebedor (RN20, RN24), sem aviso: as cobranças estão congeladas, e o
  -- pagamento liberado já chega com o credor novo. Todas migram, inclusive isentas e
  -- canceladas, menos a do próprio recebedor novo, que não deve a si mesmo
  -- (cobranca_devedor_nao_e_credor): ela vai a cancelada e fica com o credor anterior.
  if v_muda_recebedor then
    update public.cobranca c
    set status = 'cancelada'
    from public.participacao p
    where p.id = c.participacao_id and p.jogo_id = p_jogo and c.devedor_id = v_recebedor;

    update public.cobranca c
    set credor_id = v_recebedor
    from public.participacao p
    where p.id = c.participacao_id and p.jogo_id = p_jogo and c.devedor_id <> v_recebedor;

    -- O recebedor anterior que joga passa a dever a parte dele.
    select * into v_participacao from public.participacao
    where jogo_id = p_jogo and pessoa_id = v_antes.recebedor_id and status = 'confirmado';
    if found then
      perform privado.nascer_cobranca(v_participacao.id);
    end if;
  end if;

  -- RN08: vagas a mais com fila são anunciadas à fila.
  if v_vagas > v_antes.vagas_total then
    perform privado.anunciar_vaga(p_jogo);
  end if;
end;
$$;

revoke execute on function
  public.criar_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text),
  public.duplicar_jogo(uuid, timestamptz, text),
  public.editar_jogo(uuid, timestamptz, uuid, uuid, integer, integer, uuid, text)
from public, anon;

grant execute on function
  public.criar_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text),
  public.duplicar_jogo(uuid, timestamptz, text),
  public.editar_jogo(uuid, timestamptz, uuid, uuid, integer, integer, uuid, text)
to authenticated;
