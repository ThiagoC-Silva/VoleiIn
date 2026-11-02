-- Funções de grupo (RF03, RF06, RF29, RF30, RF31) e as peças que todas as funções do
-- passo 4 reaproveitam: o gravador de avisos e a formatação de data dos textos.
--
-- Convenção de recusa (supabase/CLAUDE.md, Funções): regra violada é P0001 com um código
-- estável na mensagem; falta de papel é 42501 com 'sem_permissao'.
-- Textos dos avisos: docs/design/telas/08-avisos/implementacao.md.

-- Grava um aviso na mesma transação de quem muda o estado. O sino é a fonte de verdade
-- e o push é entrega oportunista (RN29); o envio à FCM entra no passo 7.
create function privado.avisar(
  p_pessoa uuid,
  p_tipo public.notificacao_tipo,
  p_titulo text,
  p_corpo text,
  p_jogo uuid default null,
  p_cobranca uuid default null
)
returns void
language sql
volatile
set search_path = ''
as $$
  insert into public.notificacao (pessoa_id, tipo, titulo, corpo, jogo_id, cobranca_id)
  values (p_pessoa, p_tipo, p_titulo, p_corpo, p_jogo, p_cobranca);
$$;

-- Data curta do DESIGN.md em horário de Brasília: 'sáb, 24 out'. Montada à mão, sem
-- to_char, para não depender do locale do servidor.
create function privado.data_curta(p_momento timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select (array['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'])[extract(dow from l)::int + 1]
         || ', ' || extract(day from l)::int || ' '
         || (array['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'])[extract(month from l)::int]
  from (select p_momento at time zone 'America/Sao_Paulo' as l) b;
$$;

-- Hora do DESIGN.md em horário de Brasília: '20:00'.
create function privado.hora(p_momento timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select to_char(p_momento at time zone 'America/Sao_Paulo', 'HH24:MI');
$$;

-- Corpo do aviso regra_grupo_alterada (RN11): o prazo novo do grupo, em horas, e o prazo
-- sem multa que ele dá ao jogo. Com 1 h o verbo vai ao singular; com zero o prazo sem
-- multa é o próprio início, e o corpo é uma frase só.
create function privado.corpo_regra_grupo(p_horas integer, p_inicio timestamptz, p_prazo_sem_multa timestamptz)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_horas = 0 then
      format('Agora dá para cancelar sem multa até o início do jogo, %s · %s.',
             privado.data_curta(p_inicio), privado.hora(p_inicio))
    else
      format('Agora %s %s h antes do início. No jogo de %s · %s, cancelar sem multa vai até %s · %s.',
             case when p_horas = 1 then 'é' else 'são' end, p_horas,
             privado.data_curta(p_inicio), privado.hora(p_inicio),
             privado.data_curta(p_prazo_sem_multa), privado.hora(p_prazo_sem_multa))
  end;
$$;

-- Valida os campos que criar_grupo e editar_grupo recebem (RN12). O nome chega aparado.
create function privado.validar_grupo(p_nome text, p_cor text, p_prazo_cancelamento_horas integer)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_nome is null or p_nome = '' then
    raise exception using errcode = 'P0001', message = 'nome_vazio';
  end if;
  -- As seis cores do DESIGN.md (Cor do grupo).
  if p_cor is null or p_cor not in ('#3B6FE0', '#0FA3A0', '#7B5CE6', '#E0559B', '#7FB22A', '#5A6B8C') then
    raise exception using errcode = 'P0001', message = 'cor_invalida';
  end if;
  if p_prazo_cancelamento_horas is null or p_prazo_cancelamento_horas < 0 then
    raise exception using errcode = 'P0001', message = 'prazo_invalido';
  end if;
end;
$$;

revoke execute on function
  privado.avisar(uuid, public.notificacao_tipo, text, text, uuid, uuid),
  privado.data_curta(timestamptz),
  privado.hora(timestamptz),
  privado.corpo_regra_grupo(integer, timestamptz, timestamptz),
  privado.validar_grupo(text, text, integer)
from public, anon, authenticated;

-- RF03: quem cria entra como admin (RN13, RN30). Os padrões são sugestão do formulário (RN12).
create function public.criar_grupo(
  p_nome text,
  p_cor text,
  p_prazo_cancelamento_horas integer,
  p_local_padrao_id uuid default null,
  p_vagas_padrao integer default null,
  p_custo_total_padrao integer default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_nome text := btrim(p_nome);
  v_cor text := upper(p_cor);
  v_grupo uuid;
begin
  if v_eu is null then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  perform privado.validar_grupo(v_nome, v_cor, p_prazo_cancelamento_horas);

  insert into public.grupo (nome, cor, criado_por, local_padrao_id, vagas_padrao,
                            custo_total_padrao, prazo_cancelamento_horas)
  values (v_nome, v_cor, v_eu, p_local_padrao_id, p_vagas_padrao,
          p_custo_total_padrao, p_prazo_cancelamento_horas)
  returning id into v_grupo;

  insert into public.membro_grupo (grupo_id, pessoa_id, papel)
  values (v_grupo, v_eu, 'admin');

  return v_grupo;
end;
$$;

-- RF06: só admins (RN13). Recebe todos os campos, e o que não muda vai com o valor atual.
-- A mudança vale de imediato nos jogos abertos que seguem o grupo (RN11). Só a do prazo
-- avisa: aos confirmados de cada jogo do grupo aberto, ainda não começado, sem prazo
-- próprio, cujo prazo sem multa de fato mudou — o de um jogo remarcado pode não mudar,
-- porque vale o mais tardio entre o prazo e cancelamento_livre_ate (RN02, RN20).
create function public.editar_grupo(
  p_grupo uuid,
  p_nome text,
  p_cor text,
  p_prazo_cancelamento_horas integer,
  p_local_padrao_id uuid default null,
  p_vagas_padrao integer default null,
  p_custo_total_padrao integer default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_nome text := btrim(p_nome);
  v_cor text := upper(p_cor);
  v_grupo public.grupo;
  v_aviso record;
begin
  if not privado.eh_admin(p_grupo) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  perform privado.validar_grupo(v_nome, v_cor, p_prazo_cancelamento_horas);

  select * into v_grupo from public.grupo where id = p_grupo for update;

  -- Repetir o mesmo pedido não toca a linha nem avisa (RNF10).
  if (v_grupo.nome, v_grupo.cor, v_grupo.prazo_cancelamento_horas, v_grupo.local_padrao_id,
      v_grupo.vagas_padrao, v_grupo.custo_total_padrao)
     is not distinct from
     (v_nome, v_cor, p_prazo_cancelamento_horas, p_local_padrao_id,
      p_vagas_padrao, p_custo_total_padrao) then
    return;
  end if;

  update public.grupo
  set nome = v_nome,
      cor = v_cor,
      prazo_cancelamento_horas = p_prazo_cancelamento_horas,
      local_padrao_id = p_local_padrao_id,
      vagas_padrao = p_vagas_padrao,
      custo_total_padrao = p_custo_total_padrao
  where id = p_grupo;

  if p_prazo_cancelamento_horas = v_grupo.prazo_cancelamento_horas then
    return;
  end if;

  -- Quem edita não recebe o aviso do próprio ato.
  for v_aviso in
    select p.pessoa_id, j.id as jogo_id, j.inicio, prazo.novo
    from public.jogo j
    cross join lateral (
      select greatest(j.inicio - make_interval(hours => v_grupo.prazo_cancelamento_horas),
                      j.cancelamento_livre_ate) as antigo,
             greatest(j.inicio - make_interval(hours => p_prazo_cancelamento_horas),
                      j.cancelamento_livre_ate) as novo
    ) prazo
    join public.participacao p on p.jogo_id = j.id and p.status = 'confirmado'
    where j.grupo_id = p_grupo
      and j.status = 'aberto'
      and j.inicio > now()
      and j.prazo_cancelamento_horas is null
      and prazo.novo <> prazo.antigo
      and p.pessoa_id <> v_eu
  loop
    perform privado.avisar(
      v_aviso.pessoa_id,
      'regra_grupo_alterada',
      format('Novo prazo sem multa em %s', v_nome),
      privado.corpo_regra_grupo(p_prazo_cancelamento_horas, v_aviso.inicio, v_aviso.novo),
      v_aviso.jogo_id);
  end loop;
end;
$$;

-- RF31: qualquer admin promove um membro (RN13). Já admin, nada muda e nada avisa (RNF10).
create function public.promover_admin(p_grupo uuid, p_pessoa uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_papel public.membro_grupo_papel;
  v_grupo_nome text;
begin
  if not privado.eh_admin(p_grupo) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  -- Trava o grupo: promoção, remoção e saída do mesmo grupo correm uma de cada vez,
  -- para duas saídas simultâneas não deixarem o grupo sem admin (RN30).
  select nome into v_grupo_nome from public.grupo where id = p_grupo for update;

  select papel into v_papel from public.membro_grupo
  where grupo_id = p_grupo and pessoa_id = p_pessoa;

  if v_papel is null then
    raise exception using errcode = 'P0001', message = 'nao_e_membro';
  end if;
  if v_papel = 'admin' then
    return;
  end if;

  update public.membro_grupo set papel = 'admin'
  where grupo_id = p_grupo and pessoa_id = p_pessoa;

  perform privado.avisar(
    p_pessoa,
    'promovido_a_admin',
    format('Você agora é admin de %s', v_grupo_nome),
    format('%s promoveu você. Agora você edita as regras, convida e remove membros.',
           (select nome from public.pessoa where id = v_eu)));
end;
$$;

-- RF30: só admins removem, qualquer membro, inclusive outro admin (RN13, RN30). Quem
-- remove a si mesmo usa sair_grupo, que confere o admin único. Participações e cobranças
-- ficam (RN30). Alvo que já não é membro: nada muda e nada avisa (RNF10).
create function public.remover_membro(p_grupo uuid, p_pessoa uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_grupo_nome text;
begin
  if not privado.eh_admin(p_grupo) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;
  if p_pessoa = v_eu then
    raise exception using errcode = 'P0001', message = 'saia_do_grupo';
  end if;

  select nome into v_grupo_nome from public.grupo where id = p_grupo for update;

  delete from public.membro_grupo where grupo_id = p_grupo and pessoa_id = p_pessoa;
  if not found then
    return;
  end if;

  perform privado.avisar(
    p_pessoa,
    'removido_do_grupo',
    format('Você não está mais em %s', v_grupo_nome),
    'Um admin removeu você do grupo. Suas presenças e cobranças continuam valendo.');
end;
$$;

-- RF29: o membro sai quando quiser (RN30). O admin único de grupo com outros membros
-- promove outro antes; o último membro sai livre. Quem já saiu: nada muda (RNF10).
-- Participações e cobranças ficam, e o cancelamento de presença segue o caminho normal.
create function public.sair_grupo(p_grupo uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
begin
  perform 1 from public.grupo where id = p_grupo for update;

  if not exists (select 1 from public.membro_grupo where grupo_id = p_grupo and pessoa_id = v_eu) then
    return;
  end if;

  if exists (select 1 from public.membro_grupo
             where grupo_id = p_grupo and pessoa_id = v_eu and papel = 'admin')
     and not exists (select 1 from public.membro_grupo
                     where grupo_id = p_grupo and pessoa_id <> v_eu and papel = 'admin')
     and exists (select 1 from public.membro_grupo
                 where grupo_id = p_grupo and pessoa_id <> v_eu) then
    raise exception using errcode = 'P0001', message = 'promova_outro_admin';
  end if;

  delete from public.membro_grupo where grupo_id = p_grupo and pessoa_id = v_eu;
end;
$$;

revoke execute on function
  public.criar_grupo(text, text, integer, uuid, integer, integer),
  public.editar_grupo(uuid, text, text, integer, uuid, integer, integer),
  public.promover_admin(uuid, uuid),
  public.remover_membro(uuid, uuid),
  public.sair_grupo(uuid)
from public, anon;

grant execute on function
  public.criar_grupo(text, text, integer, uuid, integer, integer),
  public.editar_grupo(uuid, text, text, integer, uuid, integer, integer),
  public.promover_admin(uuid, uuid),
  public.remover_membro(uuid, uuid),
  public.sair_grupo(uuid)
to authenticated;
