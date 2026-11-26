-- Fatia 6 - Pagamentos, etapa B. Gravação e análise do comprovante.
-- Documentos: docs/contratos-api.md (seções 6 e 7), docs/comprovantes-ia.md
-- (seções 4 e 5), ADR 0019, research R1 a R5 de specs/010-pagamentos-etapa-b,
-- cenários CP01 a CP24, RV01 a RV06, C10 a C12 e C18 de
-- docs/testes-referencia.md.

-- Auxiliares da conferência (RN88b) -------------------------------------------

-- A chave lida, normalizada pelo tipo da chave atual do recebedor, com as regras
-- de profile_private (docs/modelo-dados.md, 4.1).
create or replace function private.normalize_pix_key(p_type public.pix_key_type, p_key text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_type
    when 'cpf' then upper(regexp_replace(p_key, '[^0-9A-Za-z]', '', 'g'))
    when 'cnpj' then upper(regexp_replace(p_key, '[^0-9A-Za-z]', '', 'g'))
    when 'email' then lower(btrim(p_key))
    when 'random' then lower(btrim(p_key))
    when 'phone' then (
      select case when char_length(d) in (10, 11) then '+55' || d else '+' || d end
      from (select regexp_replace(p_key, '[^0-9]', '', 'g') as d) digits
    )
  end;
$$;

-- As palavras de um nome: maiúsculas, sem acentos, só letras.
create or replace function private.name_words(p_name text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(word), '{}')
  from regexp_split_to_table(
    btrim(regexp_replace(
      regexp_replace(upper(normalize(coalesce(p_name, ''), NFD)), '[' || U&'\0300' || '-' || U&'\036F' || ']', '', 'g'),
      '[^A-Z]+', ' ', 'g'
    )),
    ' '
  ) as word
  where word <> '';
$$;

-- RN88b: a chave ou o nome conferem com o recebedor. Nulo se nenhum dos dois foi
-- lido. Com uma palavra só no perfil, o nome não confere.
create or replace function private.recipient_matches(
  p_receiver_id uuid, p_name text, p_key text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile_words text[];
  v_read_words text[] := private.name_words(p_name);
  v_type public.pix_key_type;
  v_key text;
  v_count integer;
begin
  if p_name is null and p_key is null then
    return null;
  end if;
  select private.name_words(p.name), pp.pix_key_type, pp.pix_key
  into v_profile_words, v_type, v_key
  from public.profiles p
  left join public.profile_private pp on pp.user_id = p.id
  where p.id = p_receiver_id;

  if p_key is not null and v_key is not null
    and private.normalize_pix_key(v_type, p_key) = v_key then
    return true;
  end if;
  v_count := coalesce(array_length(v_profile_words, 1), 0);
  return v_count >= 2
    and v_profile_words[1] = any(v_read_words)
    and v_profile_words[v_count] = any(v_read_words);
end;
$$;

revoke all on function private.normalize_pix_key(public.pix_key_type, text) from public, anon, authenticated;
revoke all on function private.name_words(text) from public, anon, authenticated;
revoke all on function private.recipient_matches(uuid, text, text) from public, anon, authenticated;

-- record_receipt -------------------------------------------------------------
-- Só para a process-receipt (ADR 0019). RF79 a RF83, RN32, RN80, RN81, RN86 a
-- RN89. Validações na ordem da research R1: existência, pagador, estado e
-- entrada. Tudo é relido depois do bloqueio do jogo e do valor (R2, C12).
create or replace function public.record_receipt(
  p_charge_id uuid,
  p_payer_id uuid,
  p_storage_path text,
  p_mime_type text,
  p_size_bytes integer,
  p_reading jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game_id uuid;
  v_game public.games;
  v_charge public.charges;
  v_outcome text := p_reading ->> 'outcome';
  v_read boolean;
  v_amount integer;
  v_paid_at timestamptz;
  v_name text;
  v_key text;
  v_transaction text;
  v_duplicate boolean := false;
  v_validation jsonb;
  v_status public.receipt_status;
  v_reads smallint;
  v_receipt_id uuid;
  v_charge_status public.charge_status;
  v_constraint text;
  v_data jsonb;
begin
  select game_id into v_game_id from public.charges where id = p_charge_id;
  if v_game_id is null then
    perform private.raise_error('NOT_FOUND');
  end if;
  select * into v_game from public.games where id = v_game_id for update;
  select * into v_charge from public.charges where id = p_charge_id for update;

  if v_charge.payer_id is distinct from p_payer_id then
    perform private.raise_error('NOT_CHARGE_PAYER');
  end if;
  if v_charge.status <> 'pending' then
    perform private.raise_error('CHARGE_NOT_PENDING');
  end if;

  -- Entrada (R2): o caminho do próprio valor, ainda sem comprovante, o tipo e o
  -- tamanho da RN87 e o resultado da leitura.
  if p_storage_path is null
    or p_storage_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|heic|pdf)$'
    or split_part(p_storage_path, '/', 1) <> p_charge_id::text
    or exists (select 1 from public.receipts where storage_path = p_storage_path)
    or p_mime_type is null
    or p_mime_type not in ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf')
    or p_size_bytes is null or p_size_bytes not between 1 and 10485760
    or v_outcome is null or v_outcome not in ('read', 'failed', 'skipped_limit', 'skipped_file')
  then
    perform private.raise_error('INVALID_INPUT');
  end if;

  v_read := v_outcome = 'read';
  if v_read then
    -- Os campos já vêm normalizados (comprovantes-ia.md, seção 4). Fora disso é
    -- erro de programa, e não leitura nula.
    begin
      if jsonb_typeof(p_reading -> 'amount_cents') not in ('null', 'number')
        or jsonb_typeof(p_reading -> 'paid_at') not in ('null', 'string')
        or jsonb_typeof(p_reading -> 'recipient_name') not in ('null', 'string')
        or jsonb_typeof(p_reading -> 'recipient_key') not in ('null', 'string')
        or jsonb_typeof(p_reading -> 'transaction_id') not in ('null', 'string')
      then
        raise exception using errcode = '22023';
      end if;
      v_amount := (p_reading ->> 'amount_cents')::integer;
      if v_amount is not null and v_amount <= 0 then
        raise exception using errcode = '22023';
      end if;
      if p_reading ->> 'paid_at' is not null then
        if p_reading ->> 'paid_at' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$' then
          raise exception using errcode = '22023';
        end if;
        -- O minuto lido, no horário de Brasília (RN88c).
        v_paid_at := ((p_reading ->> 'paid_at')::timestamp) at time zone 'America/Sao_Paulo';
      end if;
      v_name := p_reading ->> 'recipient_name';
      v_key := p_reading ->> 'recipient_key';
      v_transaction := p_reading ->> 'transaction_id';
      if v_transaction is not null and v_transaction !~ '^E[0-9]{20}[A-Z0-9]{11}$' then
        raise exception using errcode = '22023';
      end if;
    exception when others then
      perform private.raise_error('INVALID_INPUT');
    end;

    -- RN89: o ID num comprovante Aprovado ou Em análise de outro valor.
    v_duplicate := v_transaction is not null and exists (
      select 1 from public.receipts
      where transaction_id = v_transaction
        and status in ('approved', 'under_review')
        and charge_id <> p_charge_id
    );
    v_validation := jsonb_build_object(
      'amount', case when v_amount is null then null else v_amount = v_charge.amount_cents end,
      'recipient', private.recipient_matches(v_charge.receiver_id, v_name, v_key),
      'paid_at', case when v_paid_at is null then null
        else v_paid_at >= date_trunc('minute', v_game.starts_at)
          and v_paid_at <= now() + interval '5 minutes' end,
      'transaction_id', case when v_transaction is null then null else not v_duplicate end
    );
    v_status := (case
      when v_duplicate then 'rejected'
      when v_validation = '{"amount": true, "recipient": true, "paid_at": true, "transaction_id": true}'::jsonb
        then 'approved'
      else 'under_review'
    end)::public.receipt_status;
  else
    v_validation := jsonb_build_object(
      'amount', null, 'recipient', null, 'paid_at', null, 'transaction_id', null,
      'skipped', case v_outcome
        when 'failed' then 'api_failed'
        when 'skipped_limit' then 'read_limit'
        else 'file_not_supported'
      end
    );
    v_status := 'under_review';
  end if;

  -- RN86: a leitura que a API respondeu conta, até 3, mesmo com ID repetido.
  v_reads := case when v_read then least(v_charge.auto_reads_used + 1, 3)
    else v_charge.auto_reads_used end;
  v_data := private.payment_notification_data(v_charge);

  begin
    insert into public.receipts (
      charge_id, payer_id, receiver_id, storage_path, mime_type, size_bytes, status, auto_read,
      extracted_amount_cents, extracted_paid_at, extracted_recipient_name,
      extracted_recipient_key, transaction_id, extraction, validation, rejection_reason,
      decided_at
    ) values (
      p_charge_id, p_payer_id, v_charge.receiver_id, p_storage_path, p_mime_type, p_size_bytes,
      v_status, v_read, v_amount, v_paid_at, v_name, v_key, v_transaction, p_reading -> 'raw',
      v_validation,
      case when v_status = 'rejected' then 'duplicate_transaction'::public.receipt_rejection_reason end,
      case when v_status <> 'under_review' then now() end
    )
    returning id into v_receipt_id;

    if v_status = 'approved' then
      v_charge_status := 'paid';
      update public.charges
      set status = 'paid', paid_at = now(), paid_via = 'receipt', auto_reads_used = v_reads
      where id = p_charge_id;
      insert into public.charge_events (charge_id, from_status, to_status, actor_id, receipt_id)
      values (p_charge_id, 'pending', 'paid', p_payer_id, v_receipt_id);
      perform private.emit_notification(
        'payment_received', v_charge.receiver_id,
        v_data || jsonb_build_object('receipt_id', v_receipt_id, 'payer_id', p_payer_id)
      );
      perform private.emit_notification(
        'charge_paid', p_payer_id,
        v_data || jsonb_build_object('paid_via', 'receipt', 'receipt_id', v_receipt_id)
      );
    elsif v_status = 'under_review' then
      v_charge_status := 'under_review';
      update public.charges set status = 'under_review', auto_reads_used = v_reads
      where id = p_charge_id;
      insert into public.charge_events (charge_id, from_status, to_status, actor_id, receipt_id)
      values (p_charge_id, 'pending', 'under_review', p_payer_id, v_receipt_id);
      perform private.emit_notification(
        'receipt_needs_review', v_charge.receiver_id,
        v_data || jsonb_build_object('receipt_id', v_receipt_id, 'payer_id', p_payer_id)
      );
    else
      v_charge_status := 'pending';
      update public.charges set auto_reads_used = v_reads where id = p_charge_id;
    end if;
  exception when unique_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint is distinct from 'receipts_transaction_id_idx' then
      perform private.raise_error('INVALID_INPUT');
    end if;
    -- Corrida do ID (C10): o outro envio gravou antes. A mesma recusa (R4).
    v_status := 'rejected';
    v_charge_status := 'pending';
    v_validation := v_validation || '{"transaction_id": false}'::jsonb;
    insert into public.receipts (
      charge_id, payer_id, receiver_id, storage_path, mime_type, size_bytes, status, auto_read,
      extracted_amount_cents, extracted_paid_at, extracted_recipient_name,
      extracted_recipient_key, transaction_id, extraction, validation, rejection_reason,
      decided_at
    ) values (
      p_charge_id, p_payer_id, v_charge.receiver_id, p_storage_path, p_mime_type, p_size_bytes,
      'rejected', v_read, v_amount, v_paid_at, v_name, v_key, v_transaction, p_reading -> 'raw',
      v_validation, 'duplicate_transaction', now()
    )
    returning id into v_receipt_id;
    update public.charges set auto_reads_used = v_reads where id = p_charge_id;
  end;

  return jsonb_build_object(
    'receipt_id', v_receipt_id,
    'result', v_status,
    'error_code', case when v_status = 'rejected' then 'DUPLICATE_TRANSACTION' end,
    'charge_status', v_charge_status,
    'auto_reads_used', v_reads
  );
end;
$$;

revoke execute on function public.record_receipt(uuid, uuid, text, text, integer, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_receipt(uuid, uuid, text, text, integer, jsonb)
  to service_role;

-- review_receipt -------------------------------------------------------------
-- RF83, RN82, RN83, RN90. Ordem e bloqueios da research R5.
create or replace function public.review_receipt(
  p_receipt_id uuid, p_approve boolean, p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_uid();
  v_charge_id uuid;
  v_game_id uuid;
  v_charge public.charges;
  v_receipt public.receipts;
  v_note text := nullif(btrim(p_note), '');
  v_data jsonb;
begin
  select r.charge_id, c.game_id into v_charge_id, v_game_id
  from public.receipts r join public.charges c on c.id = r.charge_id
  where r.id = p_receipt_id;
  if v_charge_id is null then
    perform private.raise_error('NOT_FOUND');
  end if;
  perform 1 from public.games where id = v_game_id for update;
  select * into v_charge from public.charges where id = v_charge_id for update;
  select * into v_receipt from public.receipts where id = p_receipt_id for update;

  -- Os admins do jogo não veem o comprovante (RF87).
  if v_uid is distinct from v_receipt.payer_id and v_uid is distinct from v_receipt.receiver_id then
    perform private.raise_error('NOT_FOUND');
  end if;
  if v_uid is distinct from v_receipt.receiver_id then
    perform private.raise_error('NOT_CHARGE_RECEIVER');
  end if;
  if v_receipt.status <> 'under_review' then
    perform private.raise_error('RECEIPT_NOT_UNDER_REVIEW');
  end if;
  if p_approve is null then
    perform private.raise_error('INVALID_INPUT');
  end if;
  if not p_approve and v_note is null then
    perform private.raise_error('RECEIPT_NOTE_REQUIRED');
  end if;
  if char_length(v_note) > 200 then
    perform private.raise_error('INVALID_INPUT');
  end if;

  v_data := private.payment_notification_data(v_charge)
    || jsonb_build_object('receipt_id', p_receipt_id);

  if p_approve then
    update public.receipts
    set status = 'approved', decided_by = v_uid, decided_at = now(), receiver_note = v_note
    where id = p_receipt_id;
    update public.charges set status = 'paid', paid_at = now(), paid_via = 'receipt'
    where id = v_charge_id;
    insert into public.charge_events (charge_id, from_status, to_status, actor_id, receipt_id)
    values (v_charge_id, 'under_review', 'paid', v_uid, p_receipt_id);
    perform private.emit_notification(
      'charge_paid', v_charge.payer_id, v_data || jsonb_build_object('paid_via', 'receipt')
    );
  else
    update public.receipts
    set status = 'rejected', rejection_reason = 'receiver_rejected', decided_by = v_uid,
        decided_at = now(), receiver_note = v_note
    where id = p_receipt_id;
    update public.charges set status = 'pending' where id = v_charge_id;
    insert into public.charge_events (charge_id, from_status, to_status, actor_id, receipt_id)
    values (v_charge_id, 'under_review', 'pending', v_uid, p_receipt_id);
    perform private.emit_notification(
      'charge_back_to_pending', v_charge.payer_id,
      v_data || jsonb_build_object('reason', 'receipt_rejected')
    );
  end if;

  return jsonb_build_object(
    'receipt_id', p_receipt_id,
    'status', case when p_approve then 'approved' else 'rejected' end,
    'charge_status', case when p_approve then 'paid' else 'pending' end
  );
end;
$$;

revoke execute on function public.review_receipt(uuid, boolean, text) from public, anon;
grant execute on function public.review_receipt(uuid, boolean, text) to authenticated;
