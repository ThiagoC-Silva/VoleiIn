-- Exclusão da própria conta (RF36, RN27, RNF04).
--
-- Recusas (supabase/CLAUDE.md, Funções): P0001 com o código na mensagem; 42501 com
-- 'sem_permissao'.

-- RF36, RN27. O titular exclui a própria conta. Enquanto houver pendência, recusa, nesta
-- ordem e com o código que a H4 usa para dizer o que falta resolver: cobrança em aberto,
-- como devedor ou credor; admin único de grupo com outros membros (RN30); recebedor de jogo
-- aberto, que ainda vai gerar cobranças a ele.
--
-- Sem pendência, na mesma transação: anonimiza o perfil, apaga a chave Pix copiada nos jogos
-- em que ele é o recebedor (RNF04), tira-o das filas de jogo aberto, de todos os grupos e de
-- todos os aparelhos de push, e apaga o usuário do serviço de autenticação — a credencial
-- deixa de existir, e as sessões caem com ele (RNF07). Participações e cobranças ficam,
-- apontando ao perfil anonimizado, porque são histórico financeiro de terceiros: é para
-- isso que pessoa não tem chave estrangeira para auth.users (docs/stack.md, Autenticação).
create function public.excluir_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_eu uuid := (select auth.uid());
  v_jogo uuid;
  v_posicao integer;
begin
  if v_eu is null then
    raise exception using errcode = '42501', message = 'sem_permissao';
  end if;

  -- RNF10: a conta já foi excluída, e o token de acesso ainda não venceu. Nada a fazer.
  if not exists (select 1 from auth.users where id = v_eu) then
    return;
  end if;

  -- Trava os grupos dele, como promover, remover e sair: um admin que sai ao mesmo tempo
  -- não deixa o grupo sem admin (RN30). A ordem por id evita impasse entre duas exclusões.
  perform 1 from public.grupo
  where id in (select grupo_id from public.membro_grupo where pessoa_id = v_eu)
  order by id
  for update;

  if exists (select 1 from public.cobranca
             where (devedor_id = v_eu or credor_id = v_eu)
               and status in ('pendente', 'comprovante_enviado')) then
    raise exception using errcode = 'P0001', message = 'cobranca_em_aberto';
  end if;

  if exists (select 1 from public.membro_grupo eu
             where eu.pessoa_id = v_eu and eu.papel = 'admin'
               and not exists (select 1 from public.membro_grupo outro
                               where outro.grupo_id = eu.grupo_id and outro.pessoa_id <> v_eu
                                 and outro.papel = 'admin')
               and exists (select 1 from public.membro_grupo outro
                           where outro.grupo_id = eu.grupo_id and outro.pessoa_id <> v_eu)) then
    raise exception using errcode = 'P0001', message = 'promova_outro_admin';
  end if;

  if exists (select 1 from public.jogo where recebedor_id = v_eu and status = 'aberto') then
    raise exception using errcode = 'P0001', message = 'recebedor_de_jogo_aberto';
  end if;

  update public.pessoa
  set nome = 'Jogador removido', avatar_url = null, telefone = null, chave_pix = null
  where id = v_eu;

  -- Com a exclusão permitida, nenhuma cobrança ativa aponta mais para ele, e a chave
  -- congelada seria dado bancário órfão (RN27, RNF04).
  update public.jogo set chave_pix_recebedor = null where recebedor_id = v_eu;

  -- Só a fila de jogo aberto: no encerrado e no cancelado a espera já terminou e a presença
  -- está congelada (RN17; decidido em 2026-11-02). Sair da fila é no prazo, sem cobrança, e
  -- as posições seguintes sobem (RN08). A posição é lida depois da trava do jogo, a mesma
  -- de cancelar_presenca, para outra saída da fila não a mudar no meio.
  for v_jogo in
    select p.jogo_id
    from public.participacao p
    join public.jogo j on j.id = p.jogo_id
    where p.pessoa_id = v_eu and p.status = 'lista_espera' and j.status = 'aberto'
    order by p.jogo_id
  loop
    perform 1 from public.jogo where id = v_jogo for update;

    select posicao_espera into v_posicao from public.participacao
    where jogo_id = v_jogo and pessoa_id = v_eu and status = 'lista_espera';

    update public.participacao
    set status = 'cancelou_no_prazo', cancelado_em = now(), posicao_espera = null
    where jogo_id = v_jogo and pessoa_id = v_eu;

    update public.participacao
    set posicao_espera = posicao_espera - 1
    where jogo_id = v_jogo and status = 'lista_espera' and posicao_espera > v_posicao;
  end loop;

  delete from public.membro_grupo where pessoa_id = v_eu;
  delete from public.dispositivo_push where pessoa_id = v_eu;
  delete from auth.users where id = v_eu;
end;
$$;

revoke execute on function public.excluir_conta() from public, anon;
grant execute on function public.excluir_conta() to authenticated;
