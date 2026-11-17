-- Fatia 4 - Jogo e lista de presença, etapa B. Saídas, remoção e espera.
-- Documentos: docs/contratos-api.md (seção 4), research R1 a R5 de
-- specs/004-jogo-etapa-b, cenários O08 a O19, T01, T02, T06 a T10, C03 e C06
-- de docs/testes-referencia.md.
--
-- Reusa as auxiliares da etapa A (20261116120200_create_game_functions.sql):
-- cada função bloqueia primeiro a linha do jogo, e saídas e entradas
-- simultâneas ficam em fila (RN53).

-- leave_game -----------------------------------------------------------------
-- RF50, RN03, RN29, RN35, RN57, RN60, RN61. Ordem dos erros: research R1.
create or replace function public.leave_game(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_participant_id uuid;
  v_outcome text;
begin
  if v_game.status not in ('open', 'confirmed') then
    perform private.raise_error('GAME_NOT_OPEN');
  end if;

  select p.id into v_participant_id
  from public.game_participants p
  where p.game_id = p_game_id and p.user_id = v_uid and p.status = 'active';
  if v_participant_id is null then
    perform private.raise_error('NOT_PARTICIPANT');
  end if;

  if v_game.receiver_id = v_uid then
    perform private.raise_error('RECEIVER_LOCKED');
  end if;
  if v_game.ends_at <= now() then
    perform private.raise_error('LIST_LOCKED');
  end if;

  if v_game.starts_at > now() then
    -- Antes do início: libera a vaga. O prazo vale até o instante dele (RN61, T01).
    update public.game_participants
    set status = 'cancelled',
        left_at = now(),
        late_cancellation = now() > v_game.cancellation_deadline
    where id = v_participant_id;
    v_outcome := case when now() > v_game.cancellation_deadline
      then 'cancelled_late' else 'cancelled_on_time' end;
    perform private.refresh_game_status(p_game_id);
    perform private.notify_waitlist(p_game_id, 'slot_freed');
  else
    -- Entre o início e o fim: falta, e a vaga continua ocupada (RN57).
    update public.game_participants
    set status = 'left_after_start',
        left_at = now(),
        absent = true,
        absence_source = 'left_after_start'
    where id = v_participant_id;
    v_outcome := 'left_after_start';
  end if;

  return jsonb_build_object('outcome', v_outcome);
end;
$$;

revoke execute on function public.leave_game(uuid) from public, anon;
grant execute on function public.leave_game(uuid) to authenticated;

-- remove_participant ---------------------------------------------------------
-- RF54, RF59, RN29, RN58. Sem multa: late_cancellation fica nulo.
create or replace function public.remove_participant(p_game_id uuid, p_user_id uuid)
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
  perform private.require_game_admin(p_game_id, v_uid);
  perform private.require_game_before_start(v_game);

  if p_user_id = v_uid then
    perform private.raise_error('CANNOT_REMOVE_SELF');
  end if;

  select p.id into v_participant_id
  from public.game_participants p
  where p.game_id = p_game_id and p.user_id = p_user_id and p.status = 'active';
  if v_participant_id is null then
    perform private.raise_error('NOT_PARTICIPANT');
  end if;

  if v_game.receiver_id = p_user_id then
    perform private.raise_error('RECEIVER_LOCKED');
  end if;

  update public.game_participants
  set status = 'removed', left_at = now(), removal_reason = 'by_admin'
  where id = v_participant_id;

  v_status := private.refresh_game_status(p_game_id);
  perform private.emit_notification(
    'removed_from_game', p_user_id, private.game_notification_data(p_game_id)
  );
  perform private.notify_waitlist(p_game_id, 'slot_freed');

  return jsonb_build_object('status', v_status);
end;
$$;

revoke execute on function public.remove_participant(uuid, uuid) from public, anon;
grant execute on function public.remove_participant(uuid, uuid) to authenticated;

-- leave_waitlist -------------------------------------------------------------
-- RF49, RN51, RN54. A linha fica, com left_at (contexto compartilhado, RN107).
create or replace function public.leave_waitlist(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
begin
  update public.game_waitlist
  set left_at = now()
  where game_id = v_game.id and user_id = v_uid and left_at is null;
  if not found then
    perform private.raise_error('NOT_ON_WAITLIST');
  end if;

  return jsonb_build_object('game_id', p_game_id);
end;
$$;

revoke execute on function public.leave_waitlist(uuid) from public, anon;
grant execute on function public.leave_waitlist(uuid) to authenticated;
