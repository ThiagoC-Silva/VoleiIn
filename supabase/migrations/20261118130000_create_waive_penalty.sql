-- Fatia 5 - Conclusão, multas e rateio, etapa B. Isenção manual de multa.
-- Documentos: docs/contratos-api.md (seção 5, waive_penalty), research R1 a R3
-- de specs/007-conclusao-etapa-b, cenários F09 a F11, R08, Z08 e C09 de
-- docs/testes-referencia.md.

-- waive_penalty --------------------------------------------------------------
-- RF64, RF104, RN66, RN93. Validações na ordem da research R1: existência,
-- papel, tipo e status. O jogo é bloqueado antes de ler o status (R2).
create or replace function public.waive_penalty(p_charge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_game_id uuid;
  v_charge public.charges;
begin
  select game_id into v_game_id from public.charges where id = p_charge_id;
  if v_game_id is null then
    perform private.raise_error('NOT_FOUND');
  end if;
  perform private.lock_game(v_game_id, v_uid);
  perform private.require_game_admin(v_game_id, v_uid);

  -- Relido depois do lock: uma isenção simultânea já terminou (C09).
  select * into v_charge from public.charges where id = p_charge_id for update;
  if v_charge.kind = 'share' then
    perform private.raise_error('NOT_A_PENALTY');
  end if;
  if v_charge.status <> 'pending' then
    perform private.raise_error('CHARGE_NOT_PENDING');
  end if;

  update public.charges
  set status = 'waived',
      waived_at = now(),
      waive_reason = 'manual_waiver',
      waived_by = v_uid,
      updated_at = now()
  where id = p_charge_id;

  insert into public.charge_events (charge_id, from_status, to_status, actor_id)
  values (p_charge_id, 'pending', 'waived', v_uid);

  perform private.emit_notification(
    'penalty_waived', v_charge.payer_id,
    private.game_notification_data(v_game_id)
      || jsonb_build_object('charge_id', p_charge_id, 'reason', 'manual_waiver')
  );

  return jsonb_build_object('charge_id', p_charge_id, 'status', 'waived');
end;
$$;

revoke execute on function public.waive_penalty(uuid) from public, anon;
grant execute on function public.waive_penalty(uuid) to authenticated;
