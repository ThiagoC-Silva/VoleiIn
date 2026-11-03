-- Funções de presença: confirmar (RF14, RF16, RF17, RF19), cancelar (RF15) e marcar falta
-- (RF18).
--
-- Recusas (supabase/CLAUDE.md, Funções): P0001 com o código na mensagem; 42501 com
-- 'sem_permissao'.

-- Confirma a pessoa no jogo, ou a põe na lista de espera. Não confere papel: quem chama
-- confere — confirmar_presenca pelo vínculo com o jogo (RN13), e a aplicar_convite do
-- passo 9 pelo convite (RN22). Devolve o status em que a pessoa ficou.
create function privado.confirmar(p_jogo uuid, p_pessoa uuid)
returns public.participacao_status
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_jogo public.jogo;
  v_participacao public.participacao;
  v_cancelante_tardio boolean;
  v_confirmados integer;
  v_multa record;
begin
  -- RNF09: a trava da linha do jogo enfileira as confirmações, e a contagem abaixo já
  -- enxerga a de quem chegou antes.
  select * into v_jogo from public.jogo where id = p_jogo for update;

  if not found or v_jogo.status <> 'aberto' then
    raise exception using errcode = 'P0001', message = 'jogo_fechado';
  end if;
  if now() >= v_jogo.inicio then
    raise exception using errcode = 'P0001', message = 'jogo_ja_comecou';
  end if;

  select * into v_participacao from public.participacao
  where jogo_id = p_jogo and pessoa_id = p_pessoa;

  -- RNF10: o toque repetido não muda nada.
  if v_participacao.status = 'confirmado' then
    return 'confirmado';
  end if;

  -- Cancelante tardio que volta: a multa dele, pendente ou já isenta, ainda tem a origem
  -- cancelamento_tardio. A volta dele não isenta a multa de outro (RN05).
  v_cancelante_tardio := exists (
    select 1 from public.cobranca
    where participacao_id = v_participacao.id
      and origem = 'cancelamento_tardio'
      and status in ('pendente', 'isenta')
  );

  select count(*) into v_confirmados from public.participacao
  where jogo_id = p_jogo and status = 'confirmado';

  if v_confirmados >= v_jogo.vagas_total then
    -- Sem vaga (RN08): última posição da lista. Quem já está nela fica onde está.
    if v_participacao.status = 'lista_espera' then
      return 'lista_espera';
    end if;

    if v_participacao.id is null then
      insert into public.participacao (jogo_id, pessoa_id, status, posicao_espera)
      values (p_jogo, p_pessoa, 'lista_espera',
              (select coalesce(max(posicao_espera), 0) + 1 from public.participacao
               where jogo_id = p_jogo and status = 'lista_espera'));
    else
      update public.participacao
      set status = 'lista_espera',
          posicao_espera = (select coalesce(max(posicao_espera), 0) + 1 from public.participacao
                            where jogo_id = p_jogo and status = 'lista_espera')
      where id = v_participacao.id;
    end if;
    return 'lista_espera';
  end if;

  -- Com vaga, ela é de quem confirmar primeiro, esteja na lista ou não (RN08).
  if v_participacao.id is null then
    insert into public.participacao (jogo_id, pessoa_id, status, confirmado_em)
    values (p_jogo, p_pessoa, 'confirmado', now())
    returning * into v_participacao;
  else
    update public.participacao
    set status = 'confirmado', confirmado_em = now(), posicao_espera = null
    where id = v_participacao.id;

    -- Quem sai da lista abre o buraco; as posições seguintes sobem (RN08).
    if v_participacao.status = 'lista_espera' then
      update public.participacao
      set posicao_espera = posicao_espera - 1
      where jogo_id = p_jogo and status = 'lista_espera' and posicao_espera > v_participacao.posicao_espera;
    end if;
  end if;

  -- RN07, RN25: a parte nasce, ou a cobrança que já existe é reaberta como parte, com o
  -- valor atual. O recebedor não deve a si mesmo.
  if p_pessoa <> v_jogo.recebedor_id then
    perform privado.nascer_cobranca(v_participacao.id);
  end if;

  -- RN05: quem ocupa a vaga isenta a multa pendente do cancelante tardio mais antigo,
  -- uma por confirmação, sem autor (RN07). O isento é avisado (RN29).
  if not v_cancelante_tardio then
    select c.id, c.devedor_id, c.valor into v_multa
    from public.cobranca c
    join public.participacao p on p.id = c.participacao_id
    where p.jogo_id = p_jogo
      and c.origem = 'cancelamento_tardio'
      and c.status = 'pendente'
    order by p.cancelado_em, c.criado_em, c.id
    limit 1
    for update of c;

    if v_multa.id is not null then
      update public.cobranca set status = 'isenta' where id = v_multa.id;

      perform privado.avisar(
        v_multa.devedor_id,
        'cobranca_isenta',
        'Multa isenta',
        format('Outra pessoa confirmou presença em %s, %s. Os %s da sua multa não são mais devidos.',
               privado.nome_jogo(p_jogo), privado.data_curta(v_jogo.inicio), privado.reais(v_multa.valor)),
        null,
        v_multa.id);
    end if;
  end if;

  return 'confirmado';
end;
$$;

revoke execute on function privado.confirmar(uuid, uuid) from public, anon, authenticated;

-- RF14. Confirma quem vê o jogo: membro do grupo, criador, recebedor ou quem já tem
-- participação (RN13). Quem é de fora entra pelo convite de jogo (RN22, passo 9).
create function public.confirmar_presenca(p_jogo uuid)
returns public.participacao_status
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not privado.pode_ver_jogo(p_jogo) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  return privado.confirmar(p_jogo, (select auth.uid()));
end;
$$;

-- RF15. Cancela a própria presença, ou sai da lista de espera, até o início do jogo
-- (RN02); depois dele, a ausência é falta (RN04). Devolve o status em que a pessoa ficou;
-- sem participação, vazio.
create function public.cancelar_presenca(p_jogo uuid)
returns public.participacao_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_jogo public.jogo;
  v_participacao public.participacao;
  v_no_prazo boolean;
begin
  if v_eu is null or not privado.pode_ver_jogo(p_jogo) then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  -- RNF09: a mesma trava de privado.confirmar; a vaga liberada aqui é disputada por lá.
  select * into v_jogo from public.jogo where id = p_jogo for update;

  if v_jogo.status <> 'aberto' then
    raise exception using errcode = 'P0001', message = 'jogo_fechado';
  end if;
  if now() >= v_jogo.inicio then
    raise exception using errcode = 'P0001', message = 'jogo_ja_comecou';
  end if;

  select * into v_participacao from public.participacao
  where jogo_id = p_jogo and pessoa_id = v_eu;

  -- RNF10: quem já cancelou, ou nunca participou, não muda nada.
  if v_participacao.id is null or v_participacao.status not in ('confirmado', 'lista_espera') then
    return v_participacao.status;
  end if;

  -- Sair da lista é no prazo em qualquer momento, sem cobrança: não ocupava vaga (RN02,
  -- RN08). As posições seguintes sobem.
  if v_participacao.status = 'lista_espera' then
    update public.participacao
    set status = 'cancelou_no_prazo', cancelado_em = now(), posicao_espera = null
    where id = v_participacao.id;

    update public.participacao
    set posicao_espera = posicao_espera - 1
    where jogo_id = p_jogo and status = 'lista_espera' and posicao_espera > v_participacao.posicao_espera;

    return 'cancelou_no_prazo';
  end if;

  -- Prazo sem multa: o mais tardio entre início − prazo e cancelamento_livre_ate (RN02, RN20).
  v_no_prazo := now() <= privado.prazo_sem_multa(p_jogo);

  update public.participacao
  set status = case when v_no_prazo then 'cancelou_no_prazo' else 'cancelou_fora_do_prazo' end::public.participacao_status,
      cancelado_em = now()
  where id = v_participacao.id;

  -- No prazo, a cobrança vai a cancelada (RN02). Fora dele, segue pendente pelo valor
  -- integral, agora como multa (RN03). O recebedor não tem cobrança e sai sem multa (RN07).
  update public.cobranca
  set status = case when v_no_prazo then 'cancelada' else 'pendente' end::public.cobranca_status,
      origem = case when v_no_prazo then origem else 'cancelamento_tardio' end::public.cobranca_origem
  where participacao_id = v_participacao.id;

  -- A vaga que abriu é anunciada a toda a lista (RN08).
  perform privado.anunciar_vaga(p_jogo);

  return case when v_no_prazo then 'cancelou_no_prazo' else 'cancelou_fora_do_prazo' end::public.participacao_status;
end;
$$;

-- RF18, RN04. O recebedor e os admins do grupo marcam quem confirmou e não foi; no avulso,
-- que não tem admin, só o recebedor (RN13). Só com o jogo encerrado (RN17) e até 24 h depois
-- do encerramento previsto, contadas como o vencimento (RN07). O faltoso não contesta.
create function public.marcar_falta(p_jogo uuid, p_pessoa uuid)
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
  if now() > privado.encerramento_previsto(v_jogo.inicio, v_jogo.duracao_minutos) + interval '24 hours' then
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

revoke execute on function
  public.confirmar_presenca(uuid),
  public.cancelar_presenca(uuid),
  public.marcar_falta(uuid, uuid)
from public, anon;

grant execute on function
  public.confirmar_presenca(uuid),
  public.cancelar_presenca(uuid),
  public.marcar_falta(uuid, uuid)
to authenticated;
