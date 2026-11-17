-- Fatia 4 - Jogo e lista de presença, etapa C. Cancelamento, admins do jogo e
-- saída do grupo com jogos.
-- Documentos: docs/contratos-api.md (seções 3 e 4), research R1 a R4 de
-- specs/005-jogo-etapa-c, cenários J14 a J21, H01 a H10, C07 e C16 de
-- docs/testes-referencia.md.

-- Auxiliares internas --------------------------------------------------------

-- Erro de negócio com detail em JSON (contratos-api.md, seção 1).
create or replace function private.raise_error_detail(p_code text, p_detail jsonb)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = p_code, detail = p_detail::text;
end;
$$;

-- RN16 e RN14 na saída e na remoção do grupo (research R1, R3 e R4). Bloqueia
-- os jogos open/confirmed do grupo em ordem de id, confere o bloqueio e retira
-- a pessoa das listas dos jogos não iniciados e do papel de admin. Devolve os
-- jogos de que ela saiu da lista ou da espera.
create or replace function private.leave_group_games(p_group_id uuid, p_user_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_blocked uuid[];
  v_freed uuid[];
  v_waitlist uuid[];
  v_game uuid;
begin
  perform 1 from public.games
  where group_id = p_group_id and status in ('open', 'confirmed')
  order by id
  for update;

  -- Ser recebedor vem antes.
  select array_agg(g.id order by g.id) into v_blocked
  from public.games g
  where g.group_id = p_group_id and g.status in ('open', 'confirmed') and g.receiver_id = p_user_id;
  if v_blocked is not null then
    perform private.raise_error_detail('MEMBER_IS_RECEIVER', jsonb_build_object('game_ids', v_blocked));
  end if;

  select array_agg(g.id order by g.id) into v_blocked
  from public.games g
  join public.game_admins a on a.game_id = g.id and a.user_id = p_user_id
  where g.group_id = p_group_id and g.status in ('open', 'confirmed')
    and not exists (
      select 1 from public.game_admins o where o.game_id = g.id and o.user_id <> p_user_id
    );
  if v_blocked is not null then
    perform private.raise_error_detail(
      'MEMBER_IS_ONLY_GAME_ADMIN', jsonb_build_object('game_ids', v_blocked)
    );
  end if;

  -- RN14, item 1: listas dos jogos não iniciados, sem multa.
  with removed as (
    update public.game_participants p
    set status = 'removed', left_at = now(), removal_reason = 'left_group'
    from public.games g
    where g.id = p.game_id and g.group_id = p_group_id and g.status in ('open', 'confirmed')
      and g.starts_at > now() and p.user_id = p_user_id and p.status = 'active'
    returning p.game_id
  )
  select array_agg(distinct game_id) into v_freed from removed;

  with left_waitlist as (
    update public.game_waitlist w
    set left_at = now()
    from public.games g
    where g.id = w.game_id and g.group_id = p_group_id and g.status in ('open', 'confirmed')
      and g.starts_at > now() and w.user_id = p_user_id and w.left_at is null
    returning w.game_id
  )
  select array_agg(distinct game_id) into v_waitlist from left_waitlist;

  -- RN14, item 2: o papel de admin dos jogos open/confirmed.
  delete from public.game_admins a
  using public.games g
  where g.id = a.game_id and g.group_id = p_group_id and g.status in ('open', 'confirmed')
    and a.user_id = p_user_id;

  foreach v_game in array coalesce(v_freed, '{}') loop
    perform private.refresh_game_status(v_game);
    perform private.notify_waitlist(v_game, 'slot_freed');
  end loop;

  return coalesce(
    (select array_agg(distinct x order by x)
     from unnest(coalesce(v_freed, '{}') || coalesce(v_waitlist, '{}')) x),
    '{}'
  );
end;
$$;

revoke all on function private.raise_error_detail(text, jsonb) from public, anon, authenticated;
revoke all on function private.leave_group_games(uuid, uuid) from public, anon, authenticated;

-- leave_group ----------------------------------------------------------------
-- RF21, RF22, RF102, RN13, RN14, RN16. A RN16 vem depois de LAST_ADMIN.
create or replace function public.leave_group(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_games_left uuid[];
begin
  perform private.lock_member_group(p_group_id, v_uid);

  if private.is_group_admin(p_group_id, v_uid) and not exists (
    select 1 from public.group_members
    where group_id = p_group_id and role = 'admin' and user_id <> v_uid
  ) then
    perform private.raise_error('LAST_ADMIN');
  end if;

  v_games_left := private.leave_group_games(p_group_id, v_uid);
  delete from public.group_members where group_id = p_group_id and user_id = v_uid;

  return jsonb_build_object('games_left', to_jsonb(v_games_left));
end;
$$;

-- remove_group_member --------------------------------------------------------
-- RF20, RF22, RF104, RN14, RN16. A RN16 vem depois de TARGET_NOT_MEMBER.
create or replace function public.remove_group_member(p_group_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_group public.groups;
  v_games_left uuid[];
begin
  v_group := private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  if p_user_id = v_uid then
    perform private.raise_error('CANNOT_REMOVE_SELF');
  end if;

  if p_user_id is null or not private.is_group_member(p_group_id, p_user_id) then
    perform private.raise_error('TARGET_NOT_MEMBER');
  end if;

  v_games_left := private.leave_group_games(p_group_id, p_user_id);
  delete from public.group_members where group_id = p_group_id and user_id = p_user_id;

  perform private.emit_notification(
    'removed_from_group',
    p_user_id,
    jsonb_build_object('group_id', p_group_id, 'group_name', v_group.name, 'reason', 'removed')
  );

  return jsonb_build_object('games_left', to_jsonb(v_games_left));
end;
$$;

-- cancel_game ----------------------------------------------------------------
-- RF39, RF66, RN43, RN67, RN114. Até a conclusão, inclusive em andamento.
create or replace function public.cancel_game(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_data jsonb;
  v_user uuid;
begin
  perform private.require_game_admin(p_game_id, v_uid);
  if v_game.status not in ('open', 'confirmed') then
    perform private.raise_error('GAME_NOT_OPEN');
  end if;

  update public.games
  set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid
  where id = p_game_id;

  v_data := private.game_notification_data(p_game_id);
  for v_user in
    select p.user_id from public.game_participants p
    where p.game_id = p_game_id and p.status in ('active', 'left_after_start')
    union
    select w.user_id from public.game_waitlist w
    where w.game_id = p_game_id and w.left_at is null
  loop
    if v_user <> v_uid then
      perform private.emit_notification('game_cancelled', v_user, v_data);
    end if;
  end loop;

  return jsonb_build_object('game_id', p_game_id);
end;
$$;

revoke execute on function public.cancel_game(uuid) from public, anon;
grant execute on function public.cancel_game(uuid) to authenticated;

-- add_game_admin e remove_game_admin -----------------------------------------
-- RF34, RF35, RN25 a RN27. Valem em qualquer status do jogo. Sem notificação.
create or replace function public.add_game_admin(p_game_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
begin
  perform private.require_game_admin(v_game.id, v_uid);

  if not exists (
    select 1 from public.game_participants p
    where p.game_id = p_game_id and p.user_id = p_user_id and p.status = 'active'
  ) then
    perform private.raise_error('ADMIN_MUST_BE_PARTICIPANT');
  end if;
  if private.is_game_admin(p_game_id, p_user_id) then
    perform private.raise_error('ALREADY_GAME_ADMIN');
  end if;

  insert into public.game_admins (game_id, user_id, added_by) values (p_game_id, p_user_id, v_uid);

  return jsonb_build_object('game_id', p_game_id, 'user_id', p_user_id);
end;
$$;

revoke execute on function public.add_game_admin(uuid, uuid) from public, anon;
grant execute on function public.add_game_admin(uuid, uuid) to authenticated;

create or replace function public.remove_game_admin(p_game_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
begin
  perform private.require_game_admin(v_game.id, v_uid);

  if not private.is_game_admin(p_game_id, p_user_id) then
    perform private.raise_error('NOT_GAME_ADMIN_TARGET');
  end if;
  if not exists (
    select 1 from public.game_admins a where a.game_id = p_game_id and a.user_id <> p_user_id
  ) then
    perform private.raise_error('LAST_GAME_ADMIN');
  end if;

  delete from public.game_admins where game_id = p_game_id and user_id = p_user_id;

  return jsonb_build_object('game_id', p_game_id, 'user_id', p_user_id);
end;
$$;

revoke execute on function public.remove_game_admin(uuid, uuid) from public, anon;
grant execute on function public.remove_game_admin(uuid, uuid) to authenticated;
