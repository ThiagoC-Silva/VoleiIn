-- Visões de leitura do app (passo 5) e um só lugar para o prazo de vencimento.
--
-- Antes desta migração, "24 horas depois do encerramento previsto" estava escrito à mão em
-- três funções, e a visão abaixo seria a quarta cópia. A regra é uma: a cobrança vence e a
-- janela de falta fecha 24 horas depois do encerramento previsto, inicio + duracao + 1 h,
-- mesmo quando o jogo é encerrado antes à mão (RN04, RN07, RN17; docs/modelo-de-dados.md).

-- A única expressão do prazo. stable, e não immutable, pelo mesmo motivo da
-- encerramento_previsto (ver 20261102161311_ajustes_funcoes.sql): soma de timestamptz com
-- intervalo depende do fuso da sessão. É também por isso que vence_em não pode ser coluna
-- gerada em jogo — generated always as exige expressão immutable.
create function privado.vencimento(p_inicio timestamptz, p_duracao_minutos integer)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select privado.encerramento_previsto(p_inicio, p_duracao_minutos) + interval '24 hours';
$$;

-- As duas são puras: calculam sobre os próprios argumentos e não leem tabela. A visão
-- abaixo é security_invoker, então quem a consulta precisa executá-las, e as duas chamadas
-- são conferidas contra authenticated. O grant não as torna chamáveis pela API: o PostgREST
-- só expõe os schemas configurados, e privado não é um deles. Por isso elas não são
-- security definer — não há privilégio a elevar, e não há o que vazar.
grant execute on function privado.encerramento_previsto(timestamptz, integer) to authenticated;
grant execute on function privado.vencimento(timestamptz, integer) to authenticated;

-- A cobrança com o prazo e a marca de vencida, calculados com a hora do servidor (RNF08):
-- é o único lugar onde o predicado "está vencida" existe. O app lê daqui, nunca da tabela,
-- e nunca compara prazo no aparelho.
--
-- security_invoker = on: a política de linha de cobranca, participacao e jogo vale para
-- quem consulta, então o painel mostra só o que é do devedor ou do credor (RN19, RNF02).
-- Dentro de uma função security definer de postgres, que é dono das três tabelas e tem
-- rolbypassrls, a visão não filtra nada — é o que a listar_participantes usa para ver o
-- débito de terceiros, e é deliberado. Função security definer nova não é protegida por
-- esta visão.
--
-- Vencida é cobrança ainda pendente de jogo encerrado, passado o prazo. O
-- comprovante_enviado fica de fora: quem mandou comprovante fez a parte dele e não é
-- marcado (RN26).
--
-- As colunas derivadas ficam no fim, para um create or replace view futuro poder só
-- acrescentar.
create view public.cobranca_vencimento with (security_invoker = on) as
  select
    c.id,
    c.participacao_id,
    c.devedor_id,
    c.credor_id,
    c.valor,
    c.origem,
    c.status,
    c.confirmado_por,
    c.confirmado_em,
    c.criado_em,
    c.atualizado_em,
    p.jogo_id,
    j.grupo_id,
    privado.vencimento(j.inicio, j.duracao_minutos) as vence_em,
    c.status = 'pendente'
      and j.status = 'encerrado'
      and privado.vencimento(j.inicio, j.duracao_minutos) <= now() as vencida
  from public.cobranca c
  join public.participacao p on p.id = c.participacao_id
  join public.jogo j on j.id = p.jogo_id;

comment on view public.cobranca_vencimento is
  'Cobrança com vence_em e vencida (RN07, RN26). Único lugar onde o predicado existe; '
  'security_invoker, então a política de linha de cobranca, participacao e jogo vale para quem lê.';

-- O privilégio padrão de tabelas e visões novas está revogado (20261019183743_rls.sql).
grant select on public.cobranca_vencimento to authenticated;


-- Os três que repetiam o prazo passam a chamar privado.vencimento. Mesmo comportamento: as
-- suítes do passo 4 rodam sem edição. O corpo vigente destas funções é o daqui, e não o das
-- migrações do passo 4 (supabase/CLAUDE.md, Migrações).

-- RN26: igual à de 20261019183743_rls.sql, menos o débito vencido, que agora sai da visão.
-- O recorte de turma fica aqui, porque é regra de visibilidade, não de prazo: no jogo de
-- grupo valem as cobranças daquele grupo; no avulso, as devidas ao mesmo recebedor.
create or replace function public.listar_participantes(p_jogo_id uuid)
returns table (
  participacao_id uuid,
  pessoa_id uuid,
  nome text,
  avatar_url text,
  status public.participacao_status,
  confirmado_em timestamptz,
  cancelado_em timestamptz,
  posicao_espera integer,
  debito_vencido boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.pessoa_id,
    pe.nome,
    pe.avatar_url,
    p.status,
    p.confirmado_em,
    p.cancelado_em,
    p.posicao_espera,
    case
      when j.criador_id = (select auth.uid())
        or j.recebedor_id = (select auth.uid())
        or privado.eh_admin(j.grupo_id)
      then exists (
        select 1 from public.cobranca_vencimento cv
        where cv.devedor_id = p.pessoa_id
          and cv.vencida
          and case
            when j.grupo_id is not null then cv.grupo_id = j.grupo_id
            else cv.credor_id = j.recebedor_id
          end
      )
    end
  from public.jogo j
  join public.participacao p on p.jogo_id = j.id
  join public.pessoa pe on pe.id = p.pessoa_id
  where j.id = p_jogo_id
    and privado.pode_ver_jogo(j.id)
  order by
    case p.status when 'confirmado' then 0 when 'lista_espera' then 1 else 2 end,
    p.confirmado_em,
    p.posicao_espera,
    p.cancelado_em;
$$;

-- RN17, RN07: igual à de 20261102230027_rpc_jogo.sql, com o prazo vindo da função.
create or replace function privado.encerrar(p_jogo uuid)
returns void
language plpgsql
volatile
set search_path = ''
as $$
declare
  -- Quem encerra à mão; vazio na rotina de minuto, que não tem autor.
  v_eu uuid := (select auth.uid());
  v_jogo public.jogo;
  v_vence timestamptz;
  v_aviso record;
begin
  select * into v_jogo from public.jogo where id = p_jogo for update;

  if v_jogo.status = 'encerrado' then
    return;
  end if;
  if v_jogo.status is distinct from 'aberto' then
    raise exception using errcode = 'P0001', message = 'jogo_fechado';
  end if;

  update public.jogo set status = 'encerrado' where id = p_jogo;

  -- A cobrança vence 24 h depois do encerramento previsto, mesmo quando o jogo é encerrado
  -- antes, à mão (RN07).
  v_vence := privado.vencimento(v_jogo.inicio, v_jogo.duracao_minutos);

  -- pagamento_liberado a cada cobrança pendente, parte ou multa: isenta e cancelada não
  -- devem nada, e o recebedor e a lista de espera não têm cobrança (RN07, RN17). Quem
  -- encerra à mão não recebe o aviso do próprio ato.
  for v_aviso in
    select c.id, c.devedor_id, c.valor, credor.nome as credor
    from public.cobranca c
    join public.participacao p on p.id = c.participacao_id
    join public.pessoa credor on credor.id = c.credor_id
    where p.jogo_id = p_jogo
      and c.status = 'pendente'
      and c.devedor_id is distinct from v_eu
  loop
    perform privado.avisar(
      v_aviso.devedor_id,
      'pagamento_liberado',
      'Pagamento liberado',
      format('%s para %s. Vence %s · %s.', privado.reais(v_aviso.valor), v_aviso.credor,
             privado.data_curta(v_vence), privado.hora(v_vence)),
      null,
      v_aviso.id);
  end loop;
end;
$$;

-- RF18, RN04: igual à de 20261102231636_rpc_presenca.sql, com a janela vindo da função.
-- A janela de falta fecha no mesmo instante do vencimento (RN07).
create or replace function public.marcar_falta(p_jogo uuid, p_pessoa uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_jogo public.jogo;
  v_participacao public.participacao;
  v_cobranca uuid;
begin
  -- RNF09: a mesma trava das outras mutações de presença.
  select * into v_jogo from public.jogo where id = p_jogo for update;

  if not found or v_eu is null
     or not (v_jogo.recebedor_id = v_eu or privado.eh_admin(v_jogo.grupo_id)) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;
  if v_jogo.status <> 'encerrado' then
    raise exception using errcode = 'P0001', message = 'jogo_nao_encerrado';
  end if;
  if now() > privado.vencimento(v_jogo.inicio, v_jogo.duracao_minutos) then
    raise exception using errcode = 'P0001', message = 'janela_de_falta_encerrada';
  end if;

  select * into v_participacao from public.participacao
  where jogo_id = p_jogo and pessoa_id = p_pessoa;

  -- RNF10: já marcado, nada muda nem avisa.
  if v_participacao.status = 'faltou' then
    return;
  end if;
  if v_participacao.status is distinct from 'confirmado' then
    raise exception using errcode = 'P0001', message = 'nao_confirmado';
  end if;

  update public.participacao set status = 'faltou' where id = v_participacao.id;

  -- A parte vira falta com o mesmo valor, qualquer que seja o status, inclusive já paga ou
  -- isenta: a origem é só o registro do desfecho (RN04). É a exceção da âncora da retenção
  -- (docs/modelo-de-dados.md). O recebedor não tem cobrança (RN07) e só muda de
  -- participação; a cobrança cancelada que ele guarde de antes de virar recebedor (RN20)
  -- fica como está.
  if p_pessoa <> v_jogo.recebedor_id then
    update public.cobranca
    set origem = 'falta'
    where participacao_id = v_participacao.id and origem = 'parte'
    returning id into v_cobranca;
  end if;

  -- falta_marcada (docs/design/telas/08-avisos/implementacao.md): com cobrança, leva a ela;
  -- sem cobrança, o do recebedor, perde a frase do valor e leva ao jogo. A data perde a
  -- vírgula depois do nome do jogo, como no G1.
  if p_pessoa <> v_eu then
    perform privado.avisar(
      p_pessoa,
      'falta_marcada',
      'Falta marcada',
      format('%s marcou sua falta em %s, %s.%s',
             (select nome from public.pessoa where id = v_eu),
             privado.nome_jogo(p_jogo),
             replace(privado.data_curta(v_jogo.inicio), ',', ''),
             case when v_cobranca is not null then ' O valor da cobrança não muda.' else '' end),
      case when v_cobranca is null then p_jogo end,
      v_cobranca);
  end if;
end;
$$;
