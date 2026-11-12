-- Estrutura da base (fatia 1).
-- Cenários B11 a B14 e B24 de docs/testes-referencia.md, seção 9.2, mais os
-- valores de cada enum (docs/modelo-dados.md, seção 3).

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

-- B11. RN04: dinheiro nunca em ponto flutuante nem em tipo decimal.
select is_empty(
  $$ select c.relname || '.' || a.attname
     from pg_attribute a
     join pg_class c on c.oid = a.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and a.attnum > 0
       and not a.attisdropped
       and format_type(a.atttypid, null) in ('real', 'double precision', 'numeric', 'money') $$,
  'B11: nenhuma coluna real, double precision, numeric ou money (RN04)'
);

-- B12. RN04: toda coluna de dinheiro é integer em centavos.
select is_empty(
  $$ select c.relname || '.' || a.attname || ': ' || format_type(a.atttypid, null)
     from pg_attribute a
     join pg_class c on c.oid = a.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and a.attnum > 0
       and not a.attisdropped
       and a.attname like '%\_cents'
       and format_type(a.atttypid, null) <> 'integer' $$,
  'B12: toda coluna _cents é integer (RN04)'
);

-- B13. RN01: todo instante é timestamptz.
select is_empty(
  $$ select c.relname || '.' || a.attname || ': ' || format_type(a.atttypid, null)
     from pg_attribute a
     join pg_class c on c.oid = a.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and a.attnum > 0
       and not a.attisdropped
       and format_type(a.atttypid, null) in (
         'timestamp without time zone', 'time without time zone', 'time with time zone'
       ) $$,
  'B13: nenhuma coluna timestamp sem fuso, time ou timetz (RN01)'
);

-- B14. RN02: created_at vem do relógio do servidor.
select is_empty(
  $$ select c.relname
     from pg_attribute a
     join pg_class c on c.oid = a.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and a.attname = 'created_at'
       and not a.attisdropped
       and (not a.attnotnull or coalesce(pg_get_expr(d.adbin, d.adrelid), '') <> 'now()') $$,
  'B14: toda coluna created_at é not null com padrão now() (RN02)'
);

-- B24. Toda tabela com updated_at tem a trigger que o mantém.
select is_empty(
  $$ select c.relname
     from pg_attribute a
     join pg_class c on c.oid = a.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and a.attname = 'updated_at'
       and not a.attisdropped
       and not exists (
         select 1
         from pg_trigger t
         join pg_proc p on p.oid = t.tgfoid
         join pg_namespace pn on pn.oid = p.pronamespace
         where t.tgrelid = c.oid
           and not t.tgisinternal
           and pn.nspname = 'private'
           and p.proname = 'set_updated_at'
       ) $$,
  'B24: toda tabela com updated_at tem a trigger private.set_updated_at'
);

-- Enums (docs/modelo-dados.md, seção 3) --------------------------------------
select enum_has_labels('public', 'pix_key_type', array['cpf', 'cnpj', 'email', 'phone', 'random'],
  'pix_key_type tem os valores do RF11');
select enum_has_labels('public', 'legal_document', array['terms_of_use', 'privacy_policy'],
  'legal_document tem os valores do RF105');
select enum_has_labels('public', 'group_role', array['admin', 'member'],
  'group_role tem os valores da RN10');
select enum_has_labels('public', 'join_request_status',
  array['pending', 'approved', 'rejected', 'cancelled'],
  'join_request_status tem os valores da RN12');
select enum_has_labels('public', 'game_status', array['open', 'confirmed', 'cancelled', 'completed'],
  'game_status tem os valores do RF37');
select enum_has_labels('public', 'game_completion_mode', array['manual', 'automatic'],
  'game_completion_mode tem os valores das RN44 e RN45');
select enum_has_labels('public', 'participant_status',
  array['active', 'left_after_start', 'cancelled', 'removed'],
  'participant_status tem os valores das RN57 e RN58');
select enum_has_labels('public', 'removal_reason', array['by_admin', 'left_group', 'account_deleted'],
  'removal_reason tem os valores das RN14 e RN58');
select enum_has_labels('public', 'absence_source', array['left_after_start', 'marked_by_admin'],
  'absence_source tem os valores da RN63');
select enum_has_labels('public', 'charge_kind',
  array['share', 'absence_penalty', 'late_cancellation_penalty'],
  'charge_kind tem os valores da RN72');
select enum_has_labels('public', 'charge_status', array['pending', 'under_review', 'paid', 'waived'],
  'charge_status tem os valores do RF72');
select enum_has_labels('public', 'charge_waive_reason', array['manual_waiver', 'receiver_change'],
  'charge_waive_reason tem os valores das RN93 e RN94');
select enum_has_labels('public', 'payment_method', array['receipt', 'manual'],
  'payment_method tem os valores das RN80 e RN84');
select enum_has_labels('public', 'receipt_status', array['under_review', 'approved', 'rejected'],
  'receipt_status tem os valores da RN90');
select enum_has_labels('public', 'receipt_rejection_reason',
  array['duplicate_transaction', 'receiver_rejected'],
  'receipt_rejection_reason tem os valores das RN83 e RN89');
select enum_has_labels('public', 'device_platform', array['android', 'ios'],
  'device_platform tem as plataformas do stacks.md (seção 5)');
select enum_has_labels('public', 'notification_type',
  array[
    'group_join_requested', 'group_join_decided', 'removed_from_group', 'waitlist_slot_opened',
    'game_confirmed', 'game_cancelled', 'game_completed', 'game_updated', 'removed_from_game',
    'reminder_cancellation_deadline', 'reminder_game_start', 'reminder_complete_game',
    'charge_created', 'penalty_waived', 'charge_reminder', 'receipt_needs_review',
    'payment_received', 'charge_paid', 'charge_back_to_pending', 'receiver_changed'
  ],
  'notification_type tem os 20 tipos dos RF89 a RF97 e RF104');

select * from finish();
rollback;
