-- Funções de cobrança: dar baixa (RF22) e isentar (RF23), só pelo credor e só depois do
-- encerramento (RN07, RN13). As duas preenchem o par confirmado_por/confirmado_em, que diz
-- quem resolveu a cobrança e quando (RN07).
--
-- Âncora da retenção (docs/modelo-de-dados.md): a cobrança que deixa de estar ativa não é
-- mais tocada, salvo pela marcação de falta. Por isso as duas só agem sobre cobrança
-- pendente ou com comprovante enviado.
--
-- Recusas (supabase/CLAUDE.md, Funções): P0001 com o código na mensagem; 42501 com
-- 'sem_permissao'.

-- Primeiro nome, para os títulos dos avisos: a primeira palavra de pessoa.nome
-- (docs/design/telas/08-avisos/implementacao.md, Convenções dos textos).
create function privado.primeiro_nome(p_pessoa uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select split_part(btrim(nome), ' ', 1) from public.pessoa where id = p_pessoa;
$$;

-- Resumo da cobrança nos avisos: 'R$ 20,00 · Areia de Sábado, sáb 17 out', com a data do
-- início do jogo sem a vírgula do dia da semana, como no G1.
create function privado.resumo_cobranca(p_cobranca uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select format('%s · %s, %s', privado.reais(c.valor), privado.nome_jogo(j.id),
                replace(privado.data_curta(j.inicio), ',', ''))
  from public.cobranca c
  join public.participacao p on p.id = c.participacao_id
  join public.jogo j on j.id = p.jogo_id
  where c.id = p_cobranca;
$$;

-- O que dar_baixa e isentar_cobranca têm em comum: trava a cobrança, confere o credor e o
-- encerramento e leva a cobrança ativa ao status pedido, com o par de autor e momento.
-- Devolve a cobrança como ficou, ou vazio quando ela já estava nesse status (RNF10).
create function privado.resolver_cobranca(p_cobranca uuid, p_status public.cobranca_status)
returns public.cobranca
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_cobranca public.cobranca;
begin
  select * into v_cobranca from public.cobranca where id = p_cobranca for update;

  -- Só o credor, que é quem recebe o Pix (RN13).
  if not found or v_eu is null or v_cobranca.credor_id <> v_eu then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  -- Congelamento (RN07): antes do encerramento, ninguém resolve cobrança à mão.
  if (select j.status from public.participacao p join public.jogo j on j.id = p.jogo_id
      where p.id = v_cobranca.participacao_id) <> 'encerrado' then
    raise exception using errcode = 'P0001', message = 'pagamento_nao_liberado';
  end if;

  if v_cobranca.status = p_status then
    return null;
  end if;
  if v_cobranca.status not in ('pendente', 'comprovante_enviado') then
    raise exception using errcode = 'P0001', message = 'cobranca_resolvida';
  end if;

  update public.cobranca
  set status = p_status, confirmado_por = v_eu, confirmado_em = now()
  where id = p_cobranca
  returning * into v_cobranca;

  return v_cobranca;
end;
$$;

revoke execute on function
  privado.primeiro_nome(uuid),
  privado.resumo_cobranca(uuid),
  privado.resolver_cobranca(uuid, public.cobranca_status)
from public, anon, authenticated;

-- RF22. O credor confirma que recebeu, com ou sem comprovante. Já confirmada, nada muda;
-- isenta ou cancelada, recusa.
create function public.dar_baixa(p_cobranca uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cobranca public.cobranca;
begin
  v_cobranca := privado.resolver_cobranca(p_cobranca, 'confirmado');
  if v_cobranca.id is null then
    return;
  end if;

  perform privado.avisar(
    v_cobranca.devedor_id,
    'cobranca_confirmada',
    format('%s confirmou seu pagamento', privado.primeiro_nome(v_cobranca.credor_id)),
    privado.resumo_cobranca(v_cobranca.id),
    null,
    v_cobranca.id);
end;
$$;

-- RF23. O credor isenta quando entender que é o caso, como no cancelamento tardio por
-- motivo justo (RN03). Já isenta, nada muda; confirmada ou cancelada, recusa.
create function public.isentar_cobranca(p_cobranca uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cobranca public.cobranca;
begin
  v_cobranca := privado.resolver_cobranca(p_cobranca, 'isenta');
  if v_cobranca.id is null then
    return;
  end if;

  perform privado.avisar(
    v_cobranca.devedor_id,
    'cobranca_isenta',
    format('%s isentou sua cobrança', privado.primeiro_nome(v_cobranca.credor_id)),
    privado.resumo_cobranca(v_cobranca.id) || '. Nada a pagar.',
    null,
    v_cobranca.id);
end;
$$;

revoke execute on function public.dar_baixa(uuid), public.isentar_cobranca(uuid) from public, anon;
grant execute on function public.dar_baixa(uuid), public.isentar_cobranca(uuid) to authenticated;
