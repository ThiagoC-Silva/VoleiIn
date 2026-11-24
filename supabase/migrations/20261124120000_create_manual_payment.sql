-- Fatia 6 - Pagamentos, etapa A. Marcar como pago e reverter.
-- Documentos: docs/contratos-api.md (seção 6), research R1 a R5 de
-- specs/009-pagamentos-etapa-a, cenários PG01 a PG07 e C09 de
-- docs/testes-referencia.md.

-- lock_charge ----------------------------------------------------------------
-- Bloqueia o jogo e depois o valor, e confere quem chama: NOT_FOUND se não pode
-- ver o valor e NOT_CHARGE_RECEIVER se não é o recebedor dele (RN32). Tudo é
-- lido depois do bloqueio: uma transição simultânea já terminou (R2, C09).
create or replace function private.lock_charge(p_charge_id uuid, p_uid uuid)
returns public.charges
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game_id uuid;
  v_charge public.charges;
begin
  select game_id into v_game_id from public.charges where id = p_charge_id;
  if v_game_id is null then
    perform private.raise_error('NOT_FOUND');
  end if;
  perform private.lock_game(v_game_id, p_uid);

  select * into v_charge from public.charges where id = p_charge_id for update;
  if not private.can_view_charge(p_charge_id, p_uid) then
    perform private.raise_error('NOT_FOUND');
  end if;
  if v_charge.receiver_id <> p_uid then
    perform private.raise_error('NOT_CHARGE_RECEIVER');
  end if;
  return v_charge;
end;
$$;

revoke all on function private.lock_charge(uuid, uuid) from public, anon, authenticated;

-- payment_notification_data --------------------------------------------------
-- O que todo evento de pagamento leva (contratos-api.md, seção 6).
create or replace function private.payment_notification_data(p_charge public.charges)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.game_notification_data(p_charge.game_id)
    || jsonb_build_object('charge_id', p_charge.id, 'amount_cents', p_charge.amount_cents);
$$;

revoke all on function private.payment_notification_data(public.charges)
  from public, anon, authenticated;

-- mark_charge_paid -----------------------------------------------------------
-- RF84, RF97, RN84.
create or replace function public.mark_charge_paid(p_charge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_charge public.charges := private.lock_charge(p_charge_id, v_uid);
begin
  if v_charge.status <> 'pending' then
    perform private.raise_error('CHARGE_NOT_PENDING');
  end if;

  update public.charges
  set status = 'paid', paid_at = now(), paid_via = 'manual'
  where id = p_charge_id;

  insert into public.charge_events (charge_id, from_status, to_status, actor_id)
  values (p_charge_id, 'pending', 'paid', v_uid);

  perform private.emit_notification(
    'charge_paid', v_charge.payer_id,
    private.payment_notification_data(v_charge)
      || jsonb_build_object('paid_via', 'manual', 'receipt_id', null)
  );

  return jsonb_build_object('charge_id', p_charge_id, 'status', 'paid');
end;
$$;

revoke execute on function public.mark_charge_paid(uuid) from public, anon;
grant execute on function public.mark_charge_paid(uuid) to authenticated;

-- revert_charge --------------------------------------------------------------
-- RF85, RF97, RN85. Só o recebedor do valor marca, e a troca de recebedor não
-- mexe em Pago: a marcação manual é sempre dele (R3). Não volta a dever quem
-- excluiu a conta (RN104) nem o recebedor atual do jogo (R4).
create or replace function public.revert_charge(p_charge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_charge public.charges := private.lock_charge(p_charge_id, v_uid);
begin
  if v_charge.status <> 'paid' or v_charge.paid_via <> 'manual'
    or private.is_game_receiver(v_charge.game_id, v_charge.payer_id)
    or exists (
      select 1 from public.profiles
      where id = v_charge.payer_id and deleted_at is not null
    )
  then
    perform private.raise_error('CHARGE_NOT_REVERTIBLE');
  end if;

  update public.charges
  set status = 'pending', paid_at = null, paid_via = null
  where id = p_charge_id;

  insert into public.charge_events (charge_id, from_status, to_status, actor_id)
  values (p_charge_id, 'paid', 'pending', v_uid);

  perform private.emit_notification(
    'charge_back_to_pending', v_charge.payer_id,
    private.payment_notification_data(v_charge)
      || jsonb_build_object('reason', 'reverted', 'receipt_id', null)
  );

  return jsonb_build_object('charge_id', p_charge_id, 'status', 'pending');
end;
$$;

revoke execute on function public.revert_charge(uuid) from public, anon;
grant execute on function public.revert_charge(uuid) to authenticated;
