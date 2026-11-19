-- Fatia 5 - Conclusão, multas e rateio, etapa C. Troca de recebedor.
-- Documentos: docs/contratos-api.md (seção 5, change_receiver), research R1 a
-- R5 de specs/008-conclusao-etapa-c, cenários V01 a V11, Z10 a Z15 e Y04 de
-- docs/testes-referencia.md.

-- change_receiver ------------------------------------------------------------
-- RF33, RF97, RN28 a RN32, RN94, RN115. Validações na ordem da research R1:
-- existência, papel, estado do jogo e, por último, a pessoa escolhida. No jogo
-- concluído, os valores são bloqueados antes da busca por Em análise (R4).
create or replace function public.change_receiver(p_game_id uuid, p_new_receiver_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game public.games := private.lock_game(p_game_id, v_uid);
  v_old uuid := v_game.receiver_id;
  v_after boolean := v_game.status = 'completed';
  v_waived uuid;
  v_transferred integer := 0;
  v_new_charge uuid;
  v_data jsonb;
  v_row record;
begin
  perform private.require_game_admin(p_game_id, v_uid);
  if v_game.status = 'cancelled' then
    perform private.raise_error('GAME_CANCELLED');
  end if;
  if v_after then
    perform 1 from public.charges where game_id = p_game_id order by id for update;
    if exists (
      select 1 from public.charges where game_id = p_game_id and status = 'under_review'
    ) then
      perform private.raise_error('RECEIVER_CHANGE_BLOCKED');
    end if;
  end if;

  if p_new_receiver_id = v_old then
    perform private.raise_error('RECEIVER_UNCHANGED');
  end if;
  -- Na lista: passagem active (R2). Quem saiu após o início não está mais.
  if p_new_receiver_id is null or not exists (
    select 1 from public.game_participants
    where game_id = p_game_id and user_id = p_new_receiver_id and status = 'active'
  ) then
    perform private.raise_error('RECEIVER_MUST_BE_PARTICIPANT');
  end if;
  if not exists (
    select 1 from public.profile_private
    where user_id = p_new_receiver_id and pix_key is not null
  ) then
    perform private.raise_error('RECEIVER_NEEDS_PIX_KEY');
  end if;

  update public.games set receiver_id = p_new_receiver_id where id = p_game_id;

  -- Depois da conclusão (RN31), na ordem do contrato (R3).
  if v_after then
    -- O valor Pendente do novo recebedor fica Isento (RN94).
    update public.charges
    set status = 'waived',
        waived_at = now(),
        waive_reason = 'receiver_change',
        waived_by = v_uid
    where game_id = p_game_id and payer_id = p_new_receiver_id and status = 'pending'
    returning id into v_waived;
    if v_waived is not null then
      insert into public.charge_events (charge_id, from_status, to_status, actor_id, note)
      values (v_waived, 'pending', 'waived', v_uid, 'receiver_change');
    end if;

    -- Os Pendentes passam ao novo recebedor; os Pagos ficam com o antigo.
    update public.charges set receiver_id = p_new_receiver_id
    where game_id = p_game_id and status = 'pending';
    get diagnostics v_transferred = row_count;

    -- O antigo recebedor sem valor ativo no jogo paga a parte dele.
    if not exists (
      select 1 from public.charges
      where game_id = p_game_id and payer_id = v_old and status <> 'waived'
    ) then
      insert into public.charges (game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
      select p_game_id, p.id, v_old, p_new_receiver_id, 'share', v_game.share_cents
      from public.game_participants p
      where p.game_id = p_game_id and p.user_id = v_old and p.status in ('active', 'left_after_start')
      order by p.joined_at desc, p.id desc
      limit 1
      returning id into v_new_charge;
      insert into public.charge_events (charge_id, from_status, to_status, actor_id, note)
      values (v_new_charge, null, 'pending', v_uid, 'receiver_change');
    end if;
  end if;

  insert into public.receiver_changes (
    game_id, old_receiver_id, new_receiver_id, changed_by, after_completion
  )
  values (p_game_id, v_old, p_new_receiver_id, v_uid, v_after);

  -- Notificações (R5; contratos-api.md, seção 5).
  v_data := private.game_notification_data(p_game_id);
  for v_row in
    select v_old as user_id
    union
    select p_new_receiver_id
    union
    select c.payer_id from public.charges c where c.game_id = p_game_id and c.status = 'pending'
  loop
    if v_row.user_id <> v_uid then
      perform private.emit_notification(
        'receiver_changed', v_row.user_id,
        v_data || jsonb_build_object('old_receiver_id', v_old, 'new_receiver_id', p_new_receiver_id)
      );
    end if;
  end loop;
  if v_new_charge is not null then
    perform private.emit_notification(
      'charge_created', v_old,
      v_data || jsonb_build_object(
        'charge_id', v_new_charge, 'kind', 'share', 'amount_cents', v_game.share_cents
      )
    );
  end if;

  insert into public.audit_log (event, actor_id, entity_type, entity_id, data)
  values (
    'receiver_changed', v_uid, 'game', p_game_id,
    jsonb_build_object(
      'after_completion', v_after,
      'charges_transferred', v_transferred,
      'charge_created', v_new_charge is not null
    )
  );

  return jsonb_build_object(
    'game_id', p_game_id,
    'receiver_id', p_new_receiver_id,
    'charges_transferred', v_transferred,
    'charge_created', v_new_charge is not null
  );
end;
$$;

revoke execute on function public.change_receiver(uuid, uuid) from public, anon;
grant execute on function public.change_receiver(uuid, uuid) to authenticated;
