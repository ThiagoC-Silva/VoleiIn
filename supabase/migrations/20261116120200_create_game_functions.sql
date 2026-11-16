-- Fatia 4 - Jogo e lista de presença, etapa A. Funções do app.
-- Documentos: docs/contratos-api.md (seção 4), docs/arquitetura-app.md (14.3),
-- research R1 a R5 de specs/003-jogo-etapa-a, cenários J01 a J13, O01 a O07,
-- O20 a O23, T03 a T05, C01, C02, C04 e C05 de docs/testes-referencia.md.
--
-- Ordem das validações (contratos-api.md, seção 1, e research R4): autenticação,
-- existência, papel, estado e tempo e, por último, os dados de entrada. "Sem
-- acesso, sem pista": quem não pode ver o jogo recebe NOT_FOUND.
--
-- Toda função que muda um jogo bloqueia primeiro a linha de games (research
-- R1): entradas e mudanças de limite simultâneas ficam em fila, e cada uma conta
-- as vagas depois que a anterior gravou (RN53). Quando a função precisa também
-- do grupo, a ordem é grupo e depois jogo. As etapas B e C acrescentam as
-- saídas, a remoção, a espera, o cancelamento e os admins.

-- Auxiliares internas --------------------------------------------------------

-- Bloqueia o jogo e confere que quem chama pode vê-lo (NOT_FOUND se não puder).
create or replace function private.lock_game(p_game_id uuid, p_uid uuid)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.games;
begin
  select * into v_game from public.games where id = p_game_id for update;
  if not found or not private.can_view_game(p_game_id, p_uid) then
    perform private.raise_error('NOT_FOUND');
  end if;
  return v_game;
end;
$$;

-- NOT_GAME_ADMIN se quem chama não é admin do jogo.
create or replace function private.require_game_admin(p_game_id uuid, p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_game_admin(p_game_id, p_uid) then
    perform private.raise_error('NOT_GAME_ADMIN');
  end if;
end;
$$;

-- Jogo Aberto ou Confirmado e ainda não iniciado, pelo relógio do servidor
-- (RN02, RN03): GAME_NOT_OPEN, depois GAME_STARTED.
create or replace function private.require_game_before_start(p_game public.games)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_game.status not in ('open', 'confirmed') then
    perform private.raise_error('GAME_NOT_OPEN');
  end if;
  if p_game.starts_at <= now() then
    perform private.raise_error('GAME_STARTED');
  end if;
end;
$$;

-- RN50: membro do grupo do jogo. O código de convite só vale a partir da fatia 8
-- (research R3); até lá, quem não é membro recebe NO_GAME_ACCESS.
create or replace function private.require_game_access(
  p_game public.games,
  p_uid uuid,
  p_invite_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Fatia 8: um código válido também dá acesso. Até lá, ele é ignorado.
  if p_invite_code is not null then
    null;
  end if;
  if p_game.group_id is null or not private.is_group_member(p_game.group_id, p_uid) then
    perform private.raise_error('NO_GAME_ACCESS');
  end if;
end;
$$;

-- Dados do jogo, na criação e na edição (RN05, RN23): START_IN_PAST,
-- INVALID_GAME_DATES e INVALID_INPUT. Devolve o local sem os espaços das pontas.
create or replace function private.valid_game_data(
  p_location_name text,
  p_maps_url text,
  p_cancellation_deadline timestamptz,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_total_cents integer
)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_location text := btrim(p_location_name);
begin
  if p_cancellation_deadline is null or p_starts_at is null or p_ends_at is null then
    perform private.raise_error('INVALID_INPUT');
  end if;
  if p_starts_at <= now() then
    perform private.raise_error('START_IN_PAST');
  end if;
  if p_cancellation_deadline > p_starts_at or p_starts_at >= p_ends_at then
    perform private.raise_error('INVALID_GAME_DATES');
  end if;
  if v_location is null or char_length(v_location) < 1 or char_length(v_location) > 120
    or (p_maps_url is not null and p_maps_url not like 'https://%')
    or p_total_cents is null or p_total_cents < 1
  then
    perform private.raise_error('INVALID_INPUT');
  end if;
  return v_location;
end;
$$;

-- Vagas ocupadas: passagens active e left_after_start (RN57).
create or replace function private.occupied_slots(p_game_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.game_participants
  where game_id = p_game_id and status in ('active', 'left_after_start');
$$;

-- Recalcula o status pelas vagas (RN40 a RN42), só em jogo Aberto ou Confirmado,
-- e devolve o status gravado (research R2).
create or replace function private.refresh_game_status(p_game_id uuid)
returns public.game_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.game_status;
begin
  update public.games g
  set status = case
    when private.occupied_slots(g.id) >= g.slot_limit then 'confirmed'::public.game_status
    else 'open'::public.game_status
  end
  where g.id = p_game_id and g.status in ('open', 'confirmed')
  returning g.status into v_status;
  return v_status;
end;
$$;

-- p_data das notificações de jogo (contratos-api.md, seção 4; research R5). O
-- nome vem também de grupo arquivado, e é nulo no jogo avulso.
create or replace function private.game_notification_data(p_game_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'game_id', g.id,
    'group_name', gr.name,
    'location_name', g.location_name,
    'starts_at', g.starts_at
  )
  from public.games g
  left join public.groups gr on gr.id = g.group_id
  where g.id = p_game_id;
$$;

-- Notifica cada participante com passagem active, exceto quem fez a mudança.
create or replace function private.notify_active_participants(
  p_game_id uuid,
  p_type public.notification_type,
  p_except uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_data jsonb := private.game_notification_data(p_game_id);
  v_user uuid;
begin
  for v_user in
    select distinct p.user_id from public.game_participants p
    where p.game_id = p_game_id and p.status = 'active' and p.user_id <> p_except
  loop
    perform private.emit_notification(p_type, v_user, v_data);
  end loop;
end;
$$;

-- Avisa cada pessoa da espera com left_at nulo de que há vaga (RN53).
create or replace function private.notify_waitlist(p_game_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_data jsonb := private.game_notification_data(p_game_id) || jsonb_build_object('reason', p_reason);
  v_user uuid;
begin
  for v_user in
    select w.user_id from public.game_waitlist w
    where w.game_id = p_game_id and w.left_at is null
  loop
    perform private.emit_notification('waitlist_slot_opened', v_user, v_data);
  end loop;
end;
$$;

-- Grava o jogo novo com um código de convite, com nova tentativa em caso de
-- colisão (research R1 de specs/002-grupos).
create or replace function private.insert_game_with_code(p_game public.games)
returns public.games
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.games := p_game;
begin
  for v_attempt in 1 .. 5 loop
    v_game.invite_code := private.generate_invite_code();
    begin
      insert into public.games (
        group_id, created_by, location_name, maps_url, cancellation_deadline, starts_at,
        ends_at, total_cents, slot_limit, status, receiver_id, invite_code
      )
      values (
        v_game.group_id, v_game.created_by, v_game.location_name, v_game.maps_url,
        v_game.cancellation_deadline, v_game.starts_at, v_game.ends_at, v_game.total_cents,
        v_game.slot_limit, v_game.status, v_game.receiver_id, v_game.invite_code
      )
      returning * into v_game;
      return v_game;
    exception when unique_violation then
      null;
    end;
  end loop;
  perform private.raise_error('INTERNAL_ERROR');
  return null;
end;
$$;

revoke all on function private.lock_game(uuid, uuid) from public, anon, authenticated;
revoke all on function private.require_game_admin(uuid, uuid) from public, anon, authenticated;
revoke all on function private.require_game_before_start(public.games) from public, anon, authenticated;
revoke all on function private.require_game_access(public.games, uuid, text)
  from public, anon, authenticated;
revoke all on function private.valid_game_data(text, text, timestamptz, timestamptz, timestamptz, integer)
  from public, anon, authenticated;
revoke all on function private.occupied_slots(uuid) from public, anon, authenticated;
revoke all on function private.refresh_game_status(uuid) from public, anon, authenticated;
revoke all on function private.game_notification_data(uuid) from public, anon, authenticated;
revoke all on function private.notify_active_participants(uuid, public.notification_type, uuid)
  from public, anon, authenticated;
revoke all on function private.notify_waitlist(uuid, text) from public, anon, authenticated;
revoke all on function private.insert_game_with_code(public.games) from public, anon, authenticated;

-- create_game ----------------------------------------------------------------
-- RF26 a RF32, RN05, RN06, RN20 a RN23, RN40.
create or replace function public.create_game(
  p_group_id uuid,
  p_location_name text,
  p_maps_url text,
  p_cancellation_deadline timestamptz,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_total_cents integer,
  p_slot_limit integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_location text;
  v_game public.games;
begin
  -- Membro do grupo, com o grupo bloqueado (NOT_FOUND inclui o arquivado).
  if p_group_id is not null then
    perform private.lock_member_group(p_group_id, v_uid);
  end if;

  -- RN22: quem cria é o recebedor e precisa de chave Pix.
  if not exists (
    select 1 from public.profile_private pp where pp.user_id = v_uid and pp.pix_key is not null
  ) then
    perform private.raise_error('RECEIVER_NEEDS_PIX_KEY');
  end if;

  v_location := private.valid_game_data(
    p_location_name, p_maps_url, p_cancellation_deadline, p_starts_at, p_ends_at, p_total_cents
  );
  if p_slot_limit is null or p_slot_limit < 1 then
    perform private.raise_error('INVALID_INPUT');
  end if;

  v_game.group_id := p_group_id;
  v_game.created_by := v_uid;
  v_game.receiver_id := v_uid;
  v_game.location_name := v_location;
  v_game.maps_url := p_maps_url;
  v_game.cancellation_deadline := p_cancellation_deadline;
  v_game.starts_at := p_starts_at;
  v_game.ends_at := p_ends_at;
  v_game.total_cents := p_total_cents;
  v_game.slot_limit := p_slot_limit;
  -- RN40: o criador já ocupa uma vaga.
  v_game.status := case when p_slot_limit = 1 then 'confirmed' else 'open' end::public.game_status;
  v_game := private.insert_game_with_code(v_game);

  -- RN21: admin, recebedor e primeiro da lista. O histórico de limite vem da trigger.
  insert into public.game_admins (game_id, user_id) values (v_game.id, v_uid);
  insert into public.game_participants (game_id, user_id) values (v_game.id, v_uid);

  return jsonb_build_object(
    'game_id', v_game.id, 'status', v_game.status, 'invite_code', v_game.invite_code
  );
end;
$$;

revoke execute on function public.create_game(
  uuid, text, text, timestamptz, timestamptz, timestamptz, integer, integer
) from public, anon;
grant execute on function public.create_game(
  uuid, text, text, timestamptz, timestamptz, timestamptz, integer, integer
) to authenticated;

-- update_game ----------------------------------------------------------------
-- RF36, RN23, RN33 a RN35. O limite muda por set_slot_limit, e o grupo não muda.
-- As passagens não são tocadas: um cancelamento mantém a classificação (RN35).
create or replace function public.update_game(
  p_game_id uuid,
  p_location_name text,
  p_maps_url text,
  p_cancellation_deadline timestamptz,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_total_cents integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_location text;
begin
  perform private.require_game_admin(p_game_id, v_uid);
  perform private.require_game_before_start(v_game);
  v_location := private.valid_game_data(
    p_location_name, p_maps_url, p_cancellation_deadline, p_starts_at, p_ends_at, p_total_cents
  );

  update public.games
  set location_name = v_location,
      maps_url = p_maps_url,
      cancellation_deadline = p_cancellation_deadline,
      starts_at = p_starts_at,
      ends_at = p_ends_at,
      total_cents = p_total_cents
  where id = p_game_id;

  perform private.notify_active_participants(p_game_id, 'game_updated', v_uid);

  return jsonb_build_object('game_id', p_game_id);
end;
$$;

revoke execute on function public.update_game(
  uuid, text, text, timestamptz, timestamptz, timestamptz, integer
) from public, anon;
grant execute on function public.update_game(
  uuid, text, text, timestamptz, timestamptz, timestamptz, integer
) to authenticated;

-- join_game ------------------------------------------------------------------
-- RF47, RF51, RF55, RN03, RN50 a RN54, RN56. p_invite_code vale a partir da
-- fatia 8 (research R3).
create or replace function public.join_game(p_game_id uuid, p_invite_code text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_participant_id uuid;
  v_status public.game_status;
begin
  perform private.require_game_access(v_game, v_uid, p_invite_code);
  perform private.require_game_before_start(v_game);

  if exists (
    select 1 from public.game_participants p
    where p.game_id = p_game_id and p.user_id = v_uid and p.status in ('active', 'left_after_start')
  ) then
    perform private.raise_error('ALREADY_PARTICIPANT');
  end if;
  if private.occupied_slots(p_game_id) >= v_game.slot_limit then
    perform private.raise_error('GAME_FULL');
  end if;

  -- RN56: quem volta anula o cancelamento anterior e vai para o fim da ordem.
  update public.game_participants
  set cancellation_voided_at = now()
  where game_id = p_game_id and user_id = v_uid
    and status = 'cancelled' and cancellation_voided_at is null;

  begin
    insert into public.game_participants (game_id, user_id)
    values (p_game_id, v_uid)
    returning id into v_participant_id;
  exception when unique_violation then
    perform private.raise_error('ALREADY_PARTICIPANT');
  end;

  -- RN54: quem entra na lista sai da espera.
  update public.game_waitlist
  set left_at = now()
  where game_id = p_game_id and user_id = v_uid and left_at is null;

  v_status := private.refresh_game_status(p_game_id);
  if v_game.status = 'open' and v_status = 'confirmed' then
    perform private.notify_active_participants(p_game_id, 'game_confirmed', v_uid);
  end if;

  return jsonb_build_object('participant_id', v_participant_id, 'status', v_status);
end;
$$;

revoke execute on function public.join_game(uuid, text) from public, anon;
grant execute on function public.join_game(uuid, text) to authenticated;

-- join_waitlist --------------------------------------------------------------
-- RF49, RN51, RN54. Quem volta à espera fica no fim da ordem (decisão de
-- 16/11/2026). A ordem é só de exibição: a espera não dá prioridade (RN53).
create or replace function public.join_waitlist(p_game_id uuid, p_invite_code text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
begin
  perform private.require_game_access(v_game, v_uid, p_invite_code);
  perform private.require_game_before_start(v_game);

  if exists (
    select 1 from public.game_participants p
    where p.game_id = p_game_id and p.user_id = v_uid and p.status in ('active', 'left_after_start')
  ) then
    perform private.raise_error('ALREADY_PARTICIPANT');
  end if;
  -- RN51: a espera exige o jogo Confirmado.
  if v_game.status <> 'confirmed' then
    perform private.raise_error('GAME_NOT_FULL');
  end if;
  if exists (
    select 1 from public.game_waitlist w
    where w.game_id = p_game_id and w.user_id = v_uid and w.left_at is null
  ) then
    perform private.raise_error('ALREADY_ON_WAITLIST');
  end if;

  insert into public.game_waitlist (game_id, user_id)
  values (p_game_id, v_uid)
  on conflict (game_id, user_id) do update
  set left_at = null, joined_at = now();

  return jsonb_build_object('game_id', p_game_id);
end;
$$;

revoke execute on function public.join_waitlist(uuid, text) from public, anon;
grant execute on function public.join_waitlist(uuid, text) to authenticated;

-- set_slot_limit -------------------------------------------------------------
-- RF52, RF53, RN41, RN42, RN53, RN59. A trigger registra o histórico.
create or replace function public.set_slot_limit(p_game_id uuid, p_slot_limit integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_status public.game_status;
begin
  perform private.require_game_admin(p_game_id, v_uid);
  perform private.require_game_before_start(v_game);

  if p_slot_limit is null or p_slot_limit < 1 then
    perform private.raise_error('INVALID_INPUT');
  end if;
  if p_slot_limit < private.occupied_slots(p_game_id) then
    perform private.raise_error('SLOT_LIMIT_BELOW_PARTICIPANTS');
  end if;

  -- O mesmo limite: aceito, sem histórico e sem notificação.
  if p_slot_limit = v_game.slot_limit then
    return jsonb_build_object('slot_limit', v_game.slot_limit, 'status', v_game.status);
  end if;

  update public.games set slot_limit = p_slot_limit where id = p_game_id;
  v_status := private.refresh_game_status(p_game_id);

  perform private.notify_active_participants(p_game_id, 'game_updated', v_uid);
  if v_game.status = 'open' and v_status = 'confirmed' then
    perform private.notify_active_participants(p_game_id, 'game_confirmed', v_uid);
  end if;
  if p_slot_limit > v_game.slot_limit then
    perform private.notify_waitlist(p_game_id, 'limit_increased');
  end if;

  return jsonb_build_object('slot_limit', p_slot_limit, 'status', v_status);
end;
$$;

revoke execute on function public.set_slot_limit(uuid, integer) from public, anon;
grant execute on function public.set_slot_limit(uuid, integer) to authenticated;
