-- Fatia 5 - Conclusão, multas e rateio, etapa A. Conclusão manual e
-- automática, rateio e isenção automática.
-- Documentos: docs/contratos-api.md (seções 5 e 7), docs/modelo-dados.md
-- (seção 6, passo a passo de complete_game), research R1 a R7 de
-- specs/006-conclusao-etapa-a, cenários T11 a T15, R01 a R10, F03, F04, Z01 a
-- Z07, Y07 e C08 de docs/testes-referencia.md.

create extension if not exists pg_cron with schema pg_catalog;

-- Núcleo -----------------------------------------------------------------------

-- Calcula a conclusão e, sem p_dry_run, grava (research R2). Recebe o jogo já
-- bloqueado e validado. Na manual, p_absent_user_ids é a lista completa de
-- faltosos (RN47); na automática, as faltas gravadas não mudam (RN49).
create or replace function private.complete_game_core(
  p_game public.games,
  p_actor uuid,
  p_total_cents integer,
  p_absent_user_ids uuid[],
  p_mode public.game_completion_mode,
  p_dry_run boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total integer := coalesce(p_total_cents, p_game.total_cents);
  v_absent uuid[] := coalesce(p_absent_user_ids, '{}');
  v_occupied integer;
  v_payers integer;
  v_at_deadline integer;
  v_between integer;
  v_l integer;
  v_late uuid[];
  v_kept uuid[];
  v_kept_count integer;
  v_share bigint;
  v_charges integer;
  v_to_receive bigint;
  v_data jsonb;
  v_row record;
begin
  -- P: passagens com vaga ocupada (modelo-dados.md, seção 5).
  select count(*), count(*) filter (where user_id <> p_game.receiver_id)
  into v_occupied, v_payers
  from public.game_participants
  where game_id = p_game.id and status in ('active', 'left_after_start');

  -- L da RN62 (research R3).
  select h.slot_limit into v_at_deadline
  from public.game_limit_history h
  where h.game_id = p_game.id and h.effective_from <= p_game.cancellation_deadline
  order by h.effective_from desc, h.id desc
  limit 1;
  if v_at_deadline is null then
    select h.slot_limit into v_at_deadline
    from public.game_limit_history h
    where h.game_id = p_game.id
    order by h.effective_from, h.id
    limit 1;
  end if;
  select min(h.slot_limit) into v_between
  from public.game_limit_history h
  where h.game_id = p_game.id
    and h.effective_from > p_game.cancellation_deadline
    and h.effective_from < p_game.starts_at;
  v_l := coalesce(least(v_at_deadline, v_between), v_at_deadline, v_between, p_game.slot_limit);

  -- Isenção automática: mantém as multas dos últimos a cancelar (research R4).
  select coalesce(array_agg(p.id order by p.left_at desc, p.id desc), '{}') into v_late
  from public.game_participants p
  where p.game_id = p_game.id and p.status = 'cancelled' and p.late_cancellation
    and p.cancellation_voided_at is null and p.user_id <> p_game.receiver_id;
  v_kept_count := least(cardinality(v_late), greatest(0, v_l - v_occupied));
  v_kept := v_late[1:v_kept_count];

  -- Parte por vaga com o limite final, em bigint (RN71, R09).
  v_share := (v_total::bigint + p_game.slot_limit - 1) / p_game.slot_limit;
  v_charges := v_payers + v_kept_count;
  v_to_receive := v_share * v_charges;

  if not p_dry_run then
    if p_mode = 'manual' then
      update public.game_participants p
      set absent = p.user_id = any(v_absent),
          absence_source = case
            when not p.user_id = any(v_absent) then null
            when p.status = 'left_after_start' then 'left_after_start'::public.absence_source
            else 'marked_by_admin'::public.absence_source
          end
      where p.game_id = p_game.id and p.status in ('active', 'left_after_start');
    end if;

    update public.game_participants
    set late_cancellation_exempt = not (id = any(v_kept))
    where id = any(v_late);

    update public.games
    set status = 'completed',
        total_cents = v_total,
        share_cents = v_share,
        completed_at = now(),
        completion_mode = p_mode,
        completed_by = p_actor
    where id = p_game.id;

    with created as (
      insert into public.charges (game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
      select p_game.id, p.id, p.user_id, p_game.receiver_id,
             case when p.absent then 'absence_penalty' else 'share' end::public.charge_kind,
             v_share
      from public.game_participants p
      where p.game_id = p_game.id and p.status in ('active', 'left_after_start')
        and p.user_id <> p_game.receiver_id
      union all
      select p_game.id, p.id, p.user_id, p_game.receiver_id, 'late_cancellation_penalty', v_share
      from public.game_participants p
      where p.id = any(v_kept)
      returning id
    )
    insert into public.charge_events (charge_id, from_status, to_status, actor_id)
    select id, null, 'pending', p_actor from created;

    -- Notificações (contratos-api.md, seção 5, "Dados das notificações de conclusão").
    v_data := private.game_notification_data(p_game.id);
    for v_row in
      select p.user_id from public.game_participants p
      where p.game_id = p_game.id and p.status in ('active', 'left_after_start')
      union
      select p_game.receiver_id
    loop
      if p_actor is null or v_row.user_id <> p_actor then
        perform private.emit_notification(
          'game_completed', v_row.user_id, v_data || jsonb_build_object('completion_mode', p_mode)
        );
      end if;
    end loop;

    for v_row in
      select c.id, c.payer_id, c.kind, c.amount_cents from public.charges c
      where c.game_id = p_game.id
    loop
      perform private.emit_notification(
        'charge_created', v_row.payer_id,
        v_data || jsonb_build_object(
          'charge_id', v_row.id, 'kind', v_row.kind, 'amount_cents', v_row.amount_cents
        )
      );
    end loop;

    for v_row in
      select p.user_id from public.game_participants p
      where p.id = any(v_late) and not p.id = any(v_kept)
    loop
      perform private.emit_notification(
        'penalty_waived', v_row.user_id,
        v_data || jsonb_build_object('charge_id', null, 'reason', 'automatic')
      );
    end loop;

    insert into public.audit_log (event, actor_id, entity_type, entity_id, data)
    values (
      'game_completed', p_actor, 'game', p_game.id,
      jsonb_build_object('completion_mode', p_mode, 'share_cents', v_share, 'charges_created', v_charges)
    );
  end if;

  return jsonb_build_object(
    'game_id', p_game.id,
    'share_cents', v_share,
    'total_to_receive_cents', v_to_receive,
    'receiver_covered_cents', v_total - v_to_receive,
    'uncovered_slots', greatest(0, p_game.slot_limit - (v_occupied + v_kept_count)),
    'penalties_exempted', cardinality(v_late) - v_kept_count,
    'charges_created', v_charges
  );
end;
$$;

-- Validações da manual, na ordem do contrato (seção 1): existência, papel,
-- estado e tempo e, por último, os dados de entrada.
create or replace function private.manual_completion(
  p_game_id uuid,
  p_total_cents integer,
  p_absent_user_ids uuid[],
  p_dry_run boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_absent uuid[] := coalesce(p_absent_user_ids, '{}');
begin
  perform private.require_game_admin(p_game_id, v_uid);
  if v_game.status not in ('open', 'confirmed') then
    perform private.raise_error('GAME_NOT_OPEN');
  end if;
  if now() < v_game.ends_at then
    perform private.raise_error('GAME_NOT_ENDED');
  end if;

  if (p_total_cents is not null and p_total_cents <= 0) or array_position(v_absent, null) is not null then
    perform private.raise_error('INVALID_INPUT');
  end if;
  if v_game.receiver_id = any(v_absent) then
    perform private.raise_error('RECEIVER_CANNOT_BE_ABSENT');
  end if;
  if exists (
    select 1 from unnest(v_absent) a (user_id)
    where not exists (
      select 1 from public.game_participants p
      where p.game_id = p_game_id and p.user_id = a.user_id
        and p.status in ('active', 'left_after_start')
    )
  ) then
    perform private.raise_error('ABSENT_NOT_PARTICIPANT');
  end if;

  return private.complete_game_core(
    v_game, v_uid, p_total_cents, v_absent, 'manual', p_dry_run
  );
end;
$$;

revoke all on function private.complete_game_core(
  public.games, uuid, integer, uuid[], public.game_completion_mode, boolean
) from public, anon, authenticated;
revoke all on function private.manual_completion(uuid, integer, uuid[], boolean)
  from public, anon, authenticated;

-- preview_complete_game ------------------------------------------------------
-- RF41, RN48, RN74. Os mesmos números de complete_game, sem gravar.
create or replace function public.preview_complete_game(
  p_game_id uuid,
  p_total_cents integer default null,
  p_absent_user_ids uuid[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.manual_completion(p_game_id, p_total_cents, p_absent_user_ids, true);
end;
$$;

revoke execute on function public.preview_complete_game(uuid, integer, uuid[]) from public, anon;
grant execute on function public.preview_complete_game(uuid, integer, uuid[]) to authenticated;

-- complete_game --------------------------------------------------------------
-- RF40 a RF42, RF56 a RF63, RF67 a RF71, RN36, RN44 a RN49, RN60 a RN65, RN70 a RN75.
create or replace function public.complete_game(
  p_game_id uuid,
  p_total_cents integer default null,
  p_absent_user_ids uuid[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.manual_completion(p_game_id, p_total_cents, p_absent_user_ids, false);
end;
$$;

revoke execute on function public.complete_game(uuid, integer, uuid[]) from public, anon;
grant execute on function public.complete_game(uuid, integer, uuid[]) to authenticated;

-- auto_complete_due_games ----------------------------------------------------
-- RF42, RN45, RN46, RN49. Interna, chamada pelo pg_cron (contratos-api.md,
-- seção 7). Pula o jogo que uma conclusão manual já bloqueou (research R6).
create or replace function public.auto_complete_due_games()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.games;
  v_count integer := 0;
begin
  for v_game in
    select * from public.games
    where status in ('open', 'confirmed') and ends_at + interval '1 hour' <= now()
    order by id
    for update skip locked
  loop
    perform private.complete_game_core(v_game, null, null, null, 'automatic', false);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke execute on function public.auto_complete_due_games() from public, anon, authenticated;

-- Agendamento (research R7). cron.schedule substitui a tarefa de mesmo nome.
select cron.schedule(
  'auto-complete-due-games', '*/5 * * * *', 'select public.auto_complete_due_games()'
);
