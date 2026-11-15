-- Fatia 3 - Grupos. Funções do app.
-- Documentos: docs/contratos-api.md (seção 3), docs/arquitetura-app.md (14.3),
-- research R1 e R2 de specs/002-grupos, cenários G01 a G33, C13 e C15 de
-- docs/testes-referencia.md.
--
-- Ordem das validações (contratos-api.md, seção 1): autenticação, existência,
-- papel, estado e, por último, os dados de entrada. "Sem acesso, sem pista":
-- quem não é membro do grupo recebe NOT_FOUND.
--
-- Toda função que muda o grupo bloqueia primeiro a linha de groups (research R2):
-- chamadas simultâneas no mesmo grupo ficam em fila, e a segunda é validada com
-- o que a primeira gravou. A ordem dos bloqueios é sempre grupo e depois
-- solicitação. A RN16 e os efeitos sobre jogos entram na fatia 4: até lá,
-- leave_group e remove_group_member devolvem games_left vazio.

-- Auxiliares internas --------------------------------------------------------

-- Erro de negócio no formato do contrato.
create or replace function private.raise_error(p_code text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = p_code;
end;
$$;

-- Quem chama, ou NOT_AUTHENTICATED.
create or replace function private.require_uid()
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    perform private.raise_error('NOT_AUTHENTICATED');
  end if;
  return v_uid;
end;
$$;

-- Bloqueia o grupo e confere que quem chama é membro (NOT_FOUND se não for, o
-- que inclui o grupo arquivado, que não tem membros).
create or replace function private.lock_member_group(p_group_id uuid, p_uid uuid)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group public.groups;
begin
  select * into v_group from public.groups where id = p_group_id for update;
  if not found or not private.is_group_member(p_group_id, p_uid) then
    perform private.raise_error('NOT_FOUND');
  end if;
  return v_group;
end;
$$;

-- NOT_GROUP_ADMIN se quem chama não é admin do grupo.
create or replace function private.require_group_admin(p_group_id uuid, p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_group_admin(p_group_id, p_uid) then
    perform private.raise_error('NOT_GROUP_ADMIN');
  end if;
end;
$$;

-- Nome do grupo sem os espaços das pontas, com 1 a 60 caracteres, ou INVALID_INPUT.
create or replace function private.valid_group_name(p_name text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_name text := btrim(p_name);
begin
  if v_name is null or char_length(v_name) < 1 or char_length(v_name) > 60 then
    perform private.raise_error('INVALID_INPUT');
  end if;
  return v_name;
end;
$$;

-- Grava um código novo no grupo, com nova tentativa em caso de colisão (R1).
create or replace function private.set_new_invite_code(p_group_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  for v_attempt in 1 .. 5 loop
    v_code := private.generate_invite_code();
    begin
      update public.groups
      set invite_code = v_code, invite_code_updated_at = now()
      where id = p_group_id;
      return v_code;
    exception when unique_violation then
      null;
    end;
  end loop;
  perform private.raise_error('INTERNAL_ERROR');
  return null;
end;
$$;

revoke all on function private.raise_error(text) from public, anon, authenticated;
revoke all on function private.require_uid() from public, anon, authenticated;
revoke all on function private.lock_member_group(uuid, uuid) from public, anon, authenticated;
revoke all on function private.require_group_admin(uuid, uuid) from public, anon, authenticated;
revoke all on function private.valid_group_name(text) from public, anon, authenticated;
revoke all on function private.set_new_invite_code(uuid) from public, anon, authenticated;

-- create_group ---------------------------------------------------------------
-- RF14, RN10, RN11. A foto vem depois, por update_group.
create or replace function public.create_group(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_name text := private.valid_group_name(p_name);
  v_group_id uuid;
  v_code text;
begin
  insert into public.groups (name, created_by)
  values (v_name, v_uid)
  returning id into v_group_id;

  insert into public.group_members (group_id, user_id, role)
  values (v_group_id, v_uid, 'admin');

  v_code := private.set_new_invite_code(v_group_id);

  return jsonb_build_object('group_id', v_group_id, 'invite_code', v_code);
end;
$$;

revoke execute on function public.create_group(text) from public, anon;
grant execute on function public.create_group(text) to authenticated;

-- update_group ---------------------------------------------------------------
-- RF18, RN106. p_photo_path nulo retira a foto; o arquivo antigo é apagado pelo app.
create or replace function public.update_group(p_group_id uuid, p_name text, p_photo_path text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_name text;
begin
  perform private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  v_name := private.valid_group_name(p_name);
  if p_photo_path is not null
     and p_photo_path !~ ('^groups/' || p_group_id::text || '/[^/]+$') then
    perform private.raise_error('INVALID_INPUT');
  end if;

  update public.groups
  set name = v_name, photo_path = p_photo_path
  where id = p_group_id;

  return jsonb_build_object('group_id', p_group_id);
end;
$$;

revoke execute on function public.update_group(uuid, text, text) from public, anon;
grant execute on function public.update_group(uuid, text, text) to authenticated;

-- regenerate_group_invite ----------------------------------------------------
-- RF15, RN11. As solicitações já criadas não mudam.
create or replace function public.regenerate_group_invite(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
begin
  perform private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  return jsonb_build_object('invite_code', private.set_new_invite_code(p_group_id));
end;
$$;

revoke execute on function public.regenerate_group_invite(uuid) from public, anon;
grant execute on function public.regenerate_group_invite(uuid) to authenticated;

-- invalidate_group_invite ----------------------------------------------------
-- RN11. Um novo código só existe depois de regenerate_group_invite.
create or replace function public.invalidate_group_invite(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
begin
  perform private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  update public.groups set invite_code = null where id = p_group_id;

  return jsonb_build_object('group_id', p_group_id);
end;
$$;

revoke execute on function public.invalidate_group_invite(uuid) from public, anon;
grant execute on function public.invalidate_group_invite(uuid) to authenticated;

-- request_group_join ---------------------------------------------------------
-- RF16, RN12, RF89. O código é comparado exatamente, com maiúsculas e
-- minúsculas; quem tira os espaços é o app. O bloqueio do grupo põe pedidos
-- simultâneos em fila e relê o grupo se ele for arquivado no meio (R2); o
-- índice único da RN12 continua como rede de segurança.
create or replace function public.request_group_join(p_invite_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_group public.groups;
  v_request_id uuid;
  v_admin uuid;
begin
  select * into v_group
  from public.groups
  where invite_code = p_invite_code and archived_at is null
  for update;
  if not found then
    perform private.raise_error('INVITE_INVALID');
  end if;

  if private.is_group_member(v_group.id, v_uid) then
    perform private.raise_error('ALREADY_MEMBER');
  end if;

  if exists (
    select 1 from public.group_join_requests
    where group_id = v_group.id and user_id = v_uid and status = 'pending'
  ) then
    perform private.raise_error('JOIN_REQUEST_PENDING');
  end if;

  begin
    insert into public.group_join_requests (group_id, user_id)
    values (v_group.id, v_uid)
    returning id into v_request_id;
  exception when unique_violation then
    perform private.raise_error('JOIN_REQUEST_PENDING');
  end;

  for v_admin in
    select user_id from public.group_members where group_id = v_group.id and role = 'admin'
  loop
    perform private.emit_notification(
      'group_join_requested',
      v_admin,
      jsonb_build_object('group_id', v_group.id, 'group_name', v_group.name,
                         'request_id', v_request_id)
    );
  end loop;

  return jsonb_build_object('request_id', v_request_id, 'group_id', v_group.id);
end;
$$;

revoke execute on function public.request_group_join(text) from public, anon;
grant execute on function public.request_group_join(text) to authenticated;

-- decide_join_request --------------------------------------------------------
-- RF17, RF89. Quem vê a solicitação é o solicitante e os admins do grupo: um
-- membro que não é admin recebe NOT_FOUND, e o próprio solicitante,
-- NOT_GROUP_ADMIN. Bloqueia o grupo e depois a solicitação (R2).
create or replace function public.decide_join_request(p_request_id uuid, p_approve boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_group_id uuid;
  v_group public.groups;
  v_request public.group_join_requests;
  v_status public.join_request_status;
begin
  select group_id into v_group_id from public.group_join_requests where id = p_request_id;
  if not found then
    perform private.raise_error('NOT_FOUND');
  end if;

  select * into v_group from public.groups where id = v_group_id for update;
  select * into v_request from public.group_join_requests where id = p_request_id for update;

  if v_request.user_id <> v_uid and not private.is_group_admin(v_group_id, v_uid) then
    perform private.raise_error('NOT_FOUND');
  end if;
  perform private.require_group_admin(v_group_id, v_uid);

  if v_request.status <> 'pending' then
    perform private.raise_error('REQUEST_NOT_PENDING');
  end if;

  if p_approve is null then
    perform private.raise_error('INVALID_INPUT');
  end if;

  v_status := case
    when p_approve then 'approved'::public.join_request_status
    else 'rejected'::public.join_request_status
  end;

  update public.group_join_requests
  set status = v_status, decided_at = now(), decided_by = v_uid
  where id = p_request_id;

  if p_approve then
    insert into public.group_members (group_id, user_id, role)
    values (v_group_id, v_request.user_id, 'member')
    on conflict do nothing;
  end if;

  perform private.emit_notification(
    'group_join_decided',
    v_request.user_id,
    jsonb_build_object('group_id', v_group_id, 'group_name', v_group.name,
                       'request_id', p_request_id, 'approved', p_approve)
  );

  return jsonb_build_object('request_id', p_request_id, 'status', v_status);
end;
$$;

revoke execute on function public.decide_join_request(uuid, boolean) from public, anon;
grant execute on function public.decide_join_request(uuid, boolean) to authenticated;

-- set_group_role -------------------------------------------------------------
-- RF23, RF24, RN10, RN13. Promove ou rebaixa, inclusive a si mesmo. Gravar o
-- papel que a pessoa já tem é aceito e não muda nada.
create or replace function public.set_group_role(
  p_group_id uuid,
  p_user_id uuid,
  p_role public.group_role
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_current public.group_role;
begin
  perform private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  select role into v_current
  from public.group_members
  where group_id = p_group_id and user_id = p_user_id;
  if not found then
    perform private.raise_error('TARGET_NOT_MEMBER');
  end if;

  if p_role is null then
    perform private.raise_error('INVALID_INPUT');
  end if;

  if v_current = 'admin' and p_role = 'member' and not exists (
    select 1 from public.group_members
    where group_id = p_group_id and role = 'admin' and user_id <> p_user_id
  ) then
    perform private.raise_error('LAST_ADMIN');
  end if;

  if v_current <> p_role then
    update public.group_members
    set role = p_role
    where group_id = p_group_id and user_id = p_user_id;
  end if;

  return jsonb_build_object('user_id', p_user_id, 'role', p_role);
end;
$$;

revoke execute on function public.set_group_role(uuid, uuid, public.group_role) from public, anon;
grant execute on function public.set_group_role(uuid, uuid, public.group_role) to authenticated;

-- leave_group ----------------------------------------------------------------
-- RF21, RN13. O último admin recebe LAST_ADMIN, também quando é o único membro:
-- nesse caso, ele exclui o grupo. Sem notificação.
create or replace function public.leave_group(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
begin
  perform private.lock_member_group(p_group_id, v_uid);

  if private.is_group_admin(p_group_id, v_uid) and not exists (
    select 1 from public.group_members
    where group_id = p_group_id and role = 'admin' and user_id <> v_uid
  ) then
    perform private.raise_error('LAST_ADMIN');
  end if;

  delete from public.group_members where group_id = p_group_id and user_id = v_uid;

  return jsonb_build_object('games_left', '[]'::jsonb);
end;
$$;

revoke execute on function public.leave_group(uuid) from public, anon;
grant execute on function public.leave_group(uuid) to authenticated;

-- remove_group_member --------------------------------------------------------
-- RF20, RF104. Quem remove é admin e continua no grupo, então o grupo nunca
-- fica sem admin por uma remoção.
create or replace function public.remove_group_member(p_group_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_group public.groups;
begin
  v_group := private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  if p_user_id = v_uid then
    perform private.raise_error('CANNOT_REMOVE_SELF');
  end if;

  if p_user_id is null or not private.is_group_member(p_group_id, p_user_id) then
    perform private.raise_error('TARGET_NOT_MEMBER');
  end if;

  delete from public.group_members where group_id = p_group_id and user_id = p_user_id;

  perform private.emit_notification(
    'removed_from_group',
    p_user_id,
    jsonb_build_object('group_id', p_group_id, 'group_name', v_group.name, 'reason', 'removed')
  );

  return jsonb_build_object('games_left', '[]'::jsonb);
end;
$$;

revoke execute on function public.remove_group_member(uuid, uuid) from public, anon;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;

-- archive_group --------------------------------------------------------------
-- RF103, RN17, RF104. A foto continua em photo_path e é apagada pelo
-- storage-cleanup (fatia 6).
create or replace function public.archive_group(p_group_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_group public.groups;
  v_member uuid;
begin
  v_group := private.lock_member_group(p_group_id, v_uid);
  perform private.require_group_admin(p_group_id, v_uid);

  if exists (
    select 1 from public.games
    where group_id = p_group_id and status in ('open', 'confirmed')
  ) then
    perform private.raise_error('GROUP_HAS_ACTIVE_GAMES');
  end if;

  for v_member in
    select user_id from public.group_members where group_id = p_group_id and user_id <> v_uid
  loop
    perform private.emit_notification(
      'removed_from_group',
      v_member,
      jsonb_build_object('group_id', p_group_id, 'group_name', v_group.name, 'reason', 'archived')
    );
  end loop;

  delete from public.group_members where group_id = p_group_id;

  -- Cancelamento automático: decided_by nulo.
  update public.group_join_requests
  set status = 'cancelled', decided_at = now(), decided_by = null
  where group_id = p_group_id and status = 'pending';

  update public.groups
  set archived_at = now(), archived_by = v_uid, invite_code = null
  where id = p_group_id;

  insert into public.audit_log (event, actor_id, entity_type, entity_id)
  values ('group_archived', v_uid, 'group', p_group_id);

  return jsonb_build_object('group_id', p_group_id);
end;
$$;

revoke execute on function public.archive_group(uuid) from public, anon;
grant execute on function public.archive_group(uuid) to authenticated;
