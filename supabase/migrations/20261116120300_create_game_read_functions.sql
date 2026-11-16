-- Fatia 4 - Jogo e lista de presença, etapa A. Funções de leitura.
-- Documentos: docs/contratos-api.md (seção 4, get_profile_contact e
-- get_game_groups), docs/rls-matriz.md (fatia 4). Cenários W08 a W11, W13 e W14
-- de docs/testes-referencia.md.
--
-- As duas são `security definer` porque leem profile_private e groups, que o RLS
-- fecha para terceiros. Cada uma confere a permissão no próprio corpo e devolve
-- só as colunas do contrato. Nenhuma devolve erro: sem permissão, nada volta.

-- get_profile_contact --------------------------------------------------------
-- RF11, RF45, RF77, RF101, RN101, RN102, RN107.
create or replace function public.get_profile_contact(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_private public.profile_private;
  v_phone text;
  v_key_visible boolean;
begin
  if v_uid is not null then
    select * into v_private from public.profile_private where user_id = p_user_id;
  end if;
  if v_uid is null or v_private.user_id is null then
    return jsonb_build_object('phone', null, 'pix_key_type', null, 'pix_key', null);
  end if;

  -- O próprio dono: o telefone e a chave, como estão.
  if v_uid = p_user_id then
    return jsonb_build_object(
      'phone', v_private.phone,
      'pix_key_type', v_private.pix_key_type,
      'pix_key', v_private.pix_key
    );
  end if;

  -- RN101, RN107: telefone visível e contexto compartilhado.
  if v_private.phone_visible and private.shares_context(v_uid, p_user_id) then
    v_phone := v_private.phone;
  end if;

  -- RN102: recebedor de um jogo não cancelado em que quem chama ocupa vaga, ou
  -- credor de um valor Pendente ou Em análise de quem chama.
  v_key_visible := exists (
      select 1
      from public.games g
      join public.game_participants p on p.game_id = g.id
      where g.receiver_id = p_user_id
        and g.status <> 'cancelled'
        and p.user_id = v_uid
        and p.status in ('active', 'left_after_start')
    )
    or exists (
      select 1 from public.charges c
      where c.receiver_id = p_user_id
        and c.payer_id = v_uid
        and c.status in ('pending', 'under_review')
    );

  return jsonb_build_object(
    'phone', v_phone,
    'pix_key_type', case when v_key_visible then v_private.pix_key_type end,
    'pix_key', case when v_key_visible then v_private.pix_key end
  );
end;
$$;

revoke execute on function public.get_profile_contact(uuid) from public, anon;
grant execute on function public.get_profile_contact(uuid) to authenticated;

-- get_game_groups ------------------------------------------------------------
-- RF44, RF45. O nome do grupo do jogo para quem vê o jogo, mesmo sem ser membro
-- (o ex-membro com o jogo no histórico) e com o grupo arquivado (RN17). Não
-- devolve o código de convite nem os membros.
create or replace function public.get_game_groups(p_game_ids uuid[])
returns table (game_id uuid, group_id uuid, group_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select g.id, g.group_id, gr.name
  from public.games g
  join public.groups gr on gr.id = g.group_id
  where g.id = any (p_game_ids)
    and private.can_view_game(g.id, (select auth.uid()));
$$;

revoke execute on function public.get_game_groups(uuid[]) from public, anon;
grant execute on function public.get_game_groups(uuid[]) to authenticated;
