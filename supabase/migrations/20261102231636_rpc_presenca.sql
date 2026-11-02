-- Funções de presença: confirmar (RF14, RF16, RF17, RF19). Cresce nas próximas tasks com
-- cancelar_presenca (T06) e marcar_falta (T09).
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

revoke execute on function public.confirmar_presenca(uuid) from public, anon;
grant execute on function public.confirmar_presenca(uuid) to authenticated;
