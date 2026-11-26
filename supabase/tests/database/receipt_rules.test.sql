-- Conferência e análise do comprovante (fatia 6, etapa B). Cenários CP01 a
-- CP24 e RV01 a RV06 de docs/testes-referencia.md, seção 14.2 (RN80 a RN83,
-- RN86, RN88 a RN90). Contratos: record_receipt (docs/contratos-api.md, seção
-- 7) e review_receipt (seção 6). Conferência: docs/comprovantes-ia.md, seção 5.
--
-- Base da seção 14, inserida aqui sem depender do seed (research R7 de
-- specs/009-pagamentos-etapa-a). Cada cenário roda entre um savepoint e o
-- rollback para ele, salvo o último.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(77);

-- Personagens (docs/setup.md, seção 8), mais o Edu e o Fábio, que só existem
-- nos testes.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  'nao-usado-no-teste', now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb, jsonb_build_object('name', u.name),
  now(), now(), '', '', '', ''
from (
  values
    ('00000000-0000-0000-0000-00000000000a'::uuid, 'ana@voleiin.test', 'Ana'),
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'bruno@voleiin.test', 'Bruno'),
    ('00000000-0000-0000-0000-00000000000c'::uuid, 'carla@voleiin.test', 'Carla'),
    ('00000000-0000-0000-0000-00000000000d'::uuid, 'diego@voleiin.test', 'Diego'),
    ('00000000-0000-0000-0000-00000000000e'::uuid, 'edu@voleiin.test', 'Edu'),
    ('00000000-0000-0000-0000-00000000000f'::uuid, 'fabio@voleiin.test', 'Fábio')
) as u (id, email, name)
on conflict do nothing;

-- Limpeza dos jogos e das linhas de grupo do seed (research R6 de
-- specs/003-jogo-etapa-a e R12 de specs/010-pagamentos-etapa-b). Os jogos saem
-- antes das chaves Pix, que a RN105 prende enquanto a pessoa é recebedora.
delete from public.charge_events;
delete from public.receipts;
delete from public.charges;
delete from public.receiver_changes;
delete from public.game_waitlist;
delete from public.game_participants;
delete from public.game_admins;
delete from public.game_limit_history;
delete from public.games;
delete from public.group_join_requests;
delete from public.group_members;
update public.groups set invite_code = null where invite_code is not null;
delete from public.notifications;
delete from public.audit_log;

-- Seção 14: Ana Souza Lima, com a chave CPF, e o Bruno Costa (CP07, CP23) com
-- chave, porque vira recebedor no CP23.
update public.profiles set name = 'Ana Souza Lima'
where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set name = 'Bruno Costa'
where id = '00000000-0000-0000-0000-00000000000b';
update public.profile_private set pix_key_type = 'cpf', pix_key = '52998224725'
where user_id = '00000000-0000-0000-0000-00000000000a';
update public.profile_private set pix_key_type = 'email', pix_key = 'bruno@voleiin.test'
where user_id = '00000000-0000-0000-0000-00000000000b';

-- Base: o Quinta, com Ana admin e os outros membros. Diego sem grupo.
insert into public.groups (id, name, invite_code, created_by)
values (
  '00000000-0000-0000-0000-000000000301', 'Vôlei de Quinta', 'VoleiQuinta1',
  '00000000-0000-0000-0000-00000000000a'
);
insert into public.group_members (group_id, user_id, role)
select '00000000-0000-0000-0000-000000000301', u, 'member'
from unnest(array[
  '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c',
  '00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000f'
]::uuid[]) u;
insert into public.group_members (group_id, user_id, role)
values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'admin');

-- Jogo concluído do R01, inserido direto: 19/11/2026 às 20h (Fortaleza), total
-- 25.000, limite 12, parte 2.084. Ana recebedora e admin; Edu também admin;
-- Fábio e Bruno com share Pendente; Carla com absence_penalty Pendente.
insert into public.games (
  id, group_id, created_by, location_name, cancellation_deadline, starts_at, ends_at,
  total_cents, slot_limit, receiver_id, invite_code, status, share_cents, completed_at,
  completion_mode, completed_by
)
values (
  '00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-00000000000a', 'Quadra do Sesc',
  '2026-11-19 18:00-03', '2026-11-19 20:00-03', '2026-11-19 22:00-03',
  25000, 12, '00000000-0000-0000-0000-00000000000a', 'JogoPagto001', 'completed', 2084,
  '2026-11-19 22:10-03', 'manual', '00000000-0000-0000-0000-00000000000a'
);
insert into public.game_admins (game_id, user_id, added_by)
values
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-00000000000a', null),
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a');
insert into public.game_participants (game_id, user_id, joined_at)
select '00000000-0000-0000-0000-000000000a01', u, '2026-11-18 12:00-03'
from unnest(array[
  '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
  '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000f'
]::uuid[]) u;
update public.game_participants set absent = true, absence_source = 'marked_by_admin'
where game_id = '00000000-0000-0000-0000-000000000a01' and user_id = '00000000-0000-0000-0000-00000000000c';
insert into public.charges (id, game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
select v.id, p.game_id, p.id, p.user_id, '00000000-0000-0000-0000-00000000000a', v.kind, 2084
from (
  values
    ('00000000-0000-0000-0000-000000000c01'::uuid, '00000000-0000-0000-0000-00000000000f'::uuid, 'share'::public.charge_kind),
    ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-00000000000b', 'share'),
    ('00000000-0000-0000-0000-000000000c03', '00000000-0000-0000-0000-00000000000c', 'absence_penalty')
) v (id, payer, kind)
join public.game_participants p on p.game_id = '00000000-0000-0000-0000-000000000a01' and p.user_id = v.payer;
insert into public.charge_events (charge_id, from_status, to_status, actor_id)
select id, null, 'pending', '00000000-0000-0000-0000-00000000000a' from public.charges;

-- Auxiliares --------------------------------------------------------------

-- Entra como a pessoa, do jeito que a API faz.
create function pg_temp.login_as(p_user uuid)
returns void
language plpgsql
as $fn$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
end;
$fn$;

-- A leitura boa da seção 14, com as mudanças do cenário.
create function pg_temp.reading(p_changes jsonb default '{}')
returns jsonb
language sql
as $fn$
  select jsonb_build_object(
    'outcome', 'read',
    'amount_cents', 2084,
    'paid_at', '2026-11-19T22:15',
    'recipient_name', 'ANA SOUZA LIMA',
    'recipient_key', null,
    'transaction_id', 'E18236120202611200115S0123456789',
    'raw', jsonb_build_object(
      'response', jsonb_build_object('payment_status', 'completed'),
      'model', 'teste', 'prompt_version', 1, 'usage', '{}'::jsonb
    )
  ) || p_changes;
$fn$;

-- record_receipt como a Edge Function a chama (service_role). Devolve o
-- retorno, ou o código do erro.
create function pg_temp.record(
  p_charge uuid, p_payer uuid, p_reading jsonb, p_path text default null
)
returns text
language plpgsql
as $fn$
declare
  v_result text;
begin
  begin
    set local role service_role;
    select public.record_receipt(
      p_charge, p_payer,
      coalesce(p_path, p_charge::text || '/' || gen_random_uuid()::text || '.jpg'),
      'image/jpeg', 200000, p_reading
    )::text into v_result;
  exception when sqlstate 'P0001' then
    v_result := sqlerrm;
  end;
  reset role;
  return v_result;
end;
$fn$;

-- O Fábio envia, e devolve o status, a conferência e o recebedor do
-- comprovante gravado, ou o código do erro.
create function pg_temp.fabio_sends(p_changes jsonb default '{}')
returns jsonb
language plpgsql
as $fn$
declare
  v_text text := pg_temp.record(
    '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
    pg_temp.reading(p_changes)
  );
begin
  if left(v_text, 1) <> '{' then
    return to_jsonb(v_text);
  end if;
  return (
    select jsonb_build_object('status', r.status, 'validation', r.validation)
    from public.receipts r where r.id = (v_text::jsonb ->> 'receipt_id')::uuid
  );
end;
$fn$;

-- review_receipt como a pessoa. Devolve o retorno, ou o código do erro.
create function pg_temp.review(p_user uuid, p_receipt uuid, p_approve boolean, p_note text)
returns text
language plpgsql
as $fn$
declare
  v_result text;
begin
  perform pg_temp.login_as(p_user);
  begin
    set local role authenticated;
    select public.review_receipt(p_receipt, p_approve, p_note)::text into v_result;
  exception when sqlstate 'P0001' then
    v_result := sqlerrm;
  end;
  reset role;
  return v_result;
end;
$fn$;

-- Função de valor (mark_charge_paid, waive_penalty) como a pessoa.
create function pg_temp.call(p_user uuid, p_fn text, p_charge uuid)
returns text
language plpgsql
as $fn$
declare
  v_result text;
begin
  perform pg_temp.login_as(p_user);
  begin
    set local role authenticated;
    execute format('select public.%I(%L)::text', p_fn, p_charge) into v_result;
  exception when sqlstate 'P0001' then
    v_result := sqlerrm;
  end;
  reset role;
  return v_result;
end;
$fn$;

-- Passa o recebimento, como a Ana.
create function pg_temp.ana_passes_to(p_user uuid)
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
  set local role authenticated;
  perform public.change_receiver('00000000-0000-0000-0000-000000000a01', p_user);
  reset role;
end;
$fn$;

-- Valor guardado por um cenário.
create function pg_temp.saved(p_name text)
returns jsonb
language sql
as $fn$
  select nullif(current_setting('t.' || p_name, true), '')::jsonb;
$fn$;

-- O comprovante do retorno guardado.
create function pg_temp.saved_receipt(p_name text)
returns uuid
language sql
as $fn$
  select (pg_temp.saved(p_name) ->> 'receipt_id')::uuid;
$fn$;

-- Os dados da notificação de pagamento (contratos-api.md, seção 6).
create function pg_temp.payment_data(p_charge uuid, p_extra jsonb)
returns jsonb
language sql
as $fn$
  select private.game_notification_data('00000000-0000-0000-0000-000000000a01')
    || jsonb_build_object('charge_id', p_charge, 'amount_cents', 2084)
    || p_extra;
$fn$;

-- Tudo que uma recusa não pode mudar.
create function pg_temp.state()
returns jsonb
language sql
as $fn$
  select jsonb_build_object(
    'charges', (select jsonb_agg(to_jsonb(c) order by c.id) from public.charges c),
    'events', (select jsonb_agg(to_jsonb(e) order by e.id) from public.charge_events e),
    'receipts', (select count(*) from public.receipts),
    'notifications', (select count(*) from public.notifications)
  );
$fn$;

create function pg_temp.all_true()
returns jsonb
language sql
as $fn$
  select '{"amount": true, "recipient": true, "paid_at": true, "transaction_id": true}'::jsonb;
$fn$;

-- CP01 a CP24: conferência ---------------------------------------------------

-- CP01. Leitura boa.
savepoint cp01;
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  pg_temp.reading(), '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f1.jpg'
), true);
select is(
  pg_temp.saved('r') - 'receipt_id',
  '{"result": "approved", "error_code": null, "charge_status": "paid", "auto_reads_used": 1}'::jsonb,
  'CP01a: devolve approved, sem erro, valor paid e uma leitura usada'
);
select results_eq(
  $$ select status::text, decided_at = now(), decided_by, auto_read, payer_id, receiver_id,
            storage_path, mime_type, size_bytes
     from public.receipts where id = pg_temp.saved_receipt('r') $$,
  $$ values ('approved', true, null::uuid, true, '00000000-0000-0000-0000-00000000000f'::uuid,
             '00000000-0000-0000-0000-00000000000a'::uuid,
             '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f1.jpg',
             'image/jpeg', 200000) $$,
  'CP01b: approved, decidido agora, sem decided_by, auto_read, devido à Ana, com o arquivo'
);
select results_eq(
  $$ select extracted_amount_cents, extracted_paid_at, extracted_recipient_name,
            extracted_recipient_key, transaction_id, extraction
     from public.receipts where id = pg_temp.saved_receipt('r') $$,
  $$ values (2084, '2026-11-20 01:15+00'::timestamptz, 'ANA SOUZA LIMA', null::text,
             'E18236120202611200115S0123456789', pg_temp.reading() -> 'raw') $$,
  'CP01c: o que foi lido, com extracted_paid_at = 20/11/2026 01:15 UTC e a resposta em extraction'
);
select is(
  (select validation from public.receipts where id = pg_temp.saved_receipt('r')),
  pg_temp.all_true(),
  'CP01d: validation com as quatro chaves verdadeiras'
);
select results_eq(
  $$ select status::text, paid_via::text, paid_at = now(), auto_reads_used::int
     from public.charges where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('paid', 'receipt', true, 1) $$,
  'CP01e: valor paid, paid_via receipt, auto_reads_used 1'
);
select results_eq(
  $$ select from_status::text, to_status::text, actor_id, receipt_id from public.charge_events
     where charge_id = '00000000-0000-0000-0000-000000000c01' and from_status is not null $$,
  $$ values ('pending', 'paid', '00000000-0000-0000-0000-00000000000f'::uuid, pg_temp.saved_receipt('r')) $$,
  'CP01f: um charge_events de pending para paid, com o Fábio e o receipt_id'
);
select set_eq(
  $$ select type::text, user_id, data from public.notifications $$,
  $$ values
       ('payment_received', '00000000-0000-0000-0000-00000000000a'::uuid,
        pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', jsonb_build_object(
          'receipt_id', pg_temp.saved_receipt('r'), 'payer_id', '00000000-0000-0000-0000-00000000000f'))),
       ('charge_paid', '00000000-0000-0000-0000-00000000000f'::uuid,
        pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', jsonb_build_object(
          'paid_via', 'receipt', 'receipt_id', pg_temp.saved_receipt('r')))) $$,
  'CP01g: notifica payment_received à Ana e charge_paid ao Fábio'
);
rollback to savepoint cp01;

-- CP02 a CP09: destinatário (RN88b).
savepoint cp02;
select is(
  pg_temp.fabio_sends('{"recipient_name": null, "recipient_key": "529.982.247-25"}'),
  jsonb_build_object('status', 'approved', 'validation', pg_temp.all_true()),
  'CP02: nome nulo e chave 529.982.247-25: approved'
);
rollback to savepoint cp02;

savepoint cp03;
select is(
  pg_temp.fabio_sends('{"recipient_name": "ANA S LIMA"}') ->> 'status', 'approved',
  'CP03: nome ANA S LIMA: approved'
);
rollback to savepoint cp03;

savepoint cp04;
select is(
  pg_temp.fabio_sends('{"recipient_name": "Ana Sóuza Líma"}') ->> 'status', 'approved',
  'CP04: nome com acentos: approved'
);
rollback to savepoint cp04;

savepoint cp05;
select is(
  pg_temp.fabio_sends('{"recipient_name": "MARIANA LIMA"}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"recipient": false}'),
  'CP05: MARIANA LIMA, chave nula: under_review, recipient falso (palavra inteira)'
);
rollback to savepoint cp05;

savepoint cp06;
update public.profiles set name = 'Ana' where id = '00000000-0000-0000-0000-00000000000a';
select is(
  pg_temp.fabio_sends('{"recipient_name": "ANA PAULA LIMA"}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"recipient": false}'),
  'CP06a: perfil só com Ana, nome ANA PAULA LIMA: under_review, recipient falso'
);
rollback to savepoint cp06;
savepoint cp06;
update public.profiles set name = 'Ana' where id = '00000000-0000-0000-0000-00000000000a';
select is(
  pg_temp.fabio_sends('{"recipient_name": "ANA PAULA LIMA", "recipient_key": "529.982.247-25"}') ->> 'status',
  'approved',
  'CP06b: o mesmo com a chave dela: approved'
);
rollback to savepoint cp06;

savepoint cp07;
select is(
  pg_temp.fabio_sends('{"recipient_name": "BRUNO COSTA", "recipient_key": "bruno@voleiin.test"}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"recipient": false}'),
  'CP07: nome e chave do Bruno: under_review, recipient falso'
);
rollback to savepoint cp07;

savepoint cp08;
select is(
  pg_temp.fabio_sends('{"recipient_name": null, "recipient_key": null}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"recipient": null}'),
  'CP08: nome e chave nulos: under_review, recipient nulo'
);
rollback to savepoint cp08;

savepoint cp09;
update public.profile_private set pix_key_type = 'phone', pix_key = '+5586999998888'
where user_id = '00000000-0000-0000-0000-00000000000a';
select is(
  pg_temp.fabio_sends('{"recipient_name": null, "recipient_key": "(86) 99999-8888"}') ->> 'status',
  'approved',
  'CP09a: chave atual de telefone, lida (86) 99999-8888: approved'
);
rollback to savepoint cp09;
savepoint cp09;
update public.profile_private set pix_key_type = 'phone', pix_key = '+5586999998888'
where user_id = '00000000-0000-0000-0000-00000000000a';
select is(
  pg_temp.fabio_sends('{"recipient_name": null, "recipient_key": "529.982.247-25"}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"recipient": false}'),
  'CP09b: a chave antiga: under_review, recipient falso (vale a chave atual)'
);
rollback to savepoint cp09;

-- CP10. Valor (RN88a).
savepoint cp10;
select is(
  pg_temp.fabio_sends('{"amount_cents": 2083}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"amount": false}'),
  'CP10a: 2.083: under_review, amount falso'
);
rollback to savepoint cp10;
savepoint cp10;
select is(
  pg_temp.fabio_sends('{"amount_cents": 2085}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"amount": false}'),
  'CP10b: 2.085: under_review, amount falso'
);
rollback to savepoint cp10;
savepoint cp10;
select is(
  pg_temp.fabio_sends('{"amount_cents": null}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"amount": null}'),
  'CP10c: valor nulo: under_review, amount nulo'
);
rollback to savepoint cp10;

-- CP11 a CP13. Data e hora (RN88c).
savepoint cp11;
select is(
  pg_temp.fabio_sends('{"paid_at": "2026-11-19T20:00"}') ->> 'status', 'approved',
  'CP11a: pago às 20:00, com início às 20:00: approved'
);
rollback to savepoint cp11;
savepoint cp11;
select is(
  pg_temp.fabio_sends('{"paid_at": "2026-11-19T19:59"}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"paid_at": false}'),
  'CP11b: pago às 19:59: under_review, paid_at falso'
);
rollback to savepoint cp11;

savepoint cp12;
update public.games set starts_at = '2026-11-19 20:00:40-03'
where id = '00000000-0000-0000-0000-000000000a01';
select is(
  pg_temp.fabio_sends('{"paid_at": "2026-11-19T20:00"}') ->> 'status', 'approved',
  'CP12: início às 20:00:40 e pago às 20:00: approved (minuto truncado)'
);
rollback to savepoint cp12;

savepoint cp13;
select is(
  pg_temp.fabio_sends(jsonb_build_object('paid_at', to_char(
    (now() + interval '1 day') at time zone 'America/Sao_Paulo', 'YYYY-MM-DD"T"HH24:MI'))),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"paid_at": false}'),
  'CP13a: paid_at 1 dia depois de now(): under_review, paid_at falso'
);
rollback to savepoint cp13;
savepoint cp13;
select is(
  pg_temp.fabio_sends(jsonb_build_object('paid_at', to_char(
    (now() + interval '3 minutes') at time zone 'America/Sao_Paulo', 'YYYY-MM-DD"T"HH24:MI'))) ->> 'status',
  'approved',
  'CP13b: paid_at 3 min depois de now(): approved'
);
rollback to savepoint cp13;

-- CP14. Data e ID nulos.
savepoint cp14;
select is(
  pg_temp.fabio_sends('{"paid_at": null}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"paid_at": null}'),
  'CP14a: paid_at nulo: under_review, paid_at nulo'
);
rollback to savepoint cp14;
savepoint cp14;
select is(
  pg_temp.fabio_sends('{"transaction_id": null}'),
  jsonb_build_object('status', 'under_review', 'validation', pg_temp.all_true() || '{"transaction_id": null}'),
  'CP14b: ID nulo: under_review, transaction_id nulo'
);
rollback to savepoint cp14;

-- CP15 e CP16. ID repetido (RN89).
savepoint cp15;
select pg_temp.record(
  '00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-00000000000b', pg_temp.reading()
);
select set_config('t.before', pg_temp.state()::text, true);
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', pg_temp.reading()
), true);
select is(
  pg_temp.saved('r') - 'receipt_id',
  '{"result": "rejected", "error_code": "DUPLICATE_TRANSACTION", "charge_status": "pending", "auto_reads_used": 1}'::jsonb,
  'CP15a: ID de um comprovante approved do Bruno: rejected, DUPLICATE_TRANSACTION'
);
select results_eq(
  $$ select status::text, rejection_reason::text, decided_at = now(), decided_by
     from public.receipts where id = pg_temp.saved_receipt('r') $$,
  $$ values ('rejected', 'duplicate_transaction', true, null::uuid) $$,
  'CP15b: rejected, duplicate_transaction, decided_at = now()'
);
select results_eq(
  $$ select status::text, auto_reads_used::int from public.charges
     where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('pending', 1) $$,
  'CP15c: o valor do Fábio continua pending, com auto_reads_used 1'
);
select is(
  (pg_temp.state() - 'charges' - 'receipts'),
  (pg_temp.saved('before') - 'charges' - 'receipts'),
  'CP15d: sem notificação e sem charge_events'
);
rollback to savepoint cp15;

savepoint cp15;
select pg_temp.record(
  '00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-00000000000b',
  pg_temp.reading('{"amount_cents": null}')
);
select set_config('t.bruno', (select to_jsonb(r.id) from public.receipts r
  where r.charge_id = '00000000-0000-0000-0000-000000000c02')::text, true);
select set_config('t.before', pg_temp.state()::text, true);
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', pg_temp.reading()
), true);
select is(
  pg_temp.saved('r') - 'receipt_id',
  '{"result": "rejected", "error_code": "DUPLICATE_TRANSACTION", "charge_status": "pending", "auto_reads_used": 1}'::jsonb,
  'CP15e: ID de um comprovante under_review do Bruno: rejected, DUPLICATE_TRANSACTION'
);
select results_eq(
  $$ select status::text, rejection_reason::text, decided_at = now()
     from public.receipts where id = pg_temp.saved_receipt('r') $$,
  $$ values ('rejected', 'duplicate_transaction', true) $$,
  'CP15f: rejected, duplicate_transaction, decided_at = now()'
);
select is(
  (pg_temp.state() - 'charges' - 'receipts'),
  (pg_temp.saved('before') - 'charges' - 'receipts'),
  'CP15g: sem notificação e sem charge_events'
);

-- CP16. A Ana recusa o do Bruno, e o ID volta a ficar livre.
select pg_temp.review(
  '00000000-0000-0000-0000-00000000000a', (pg_temp.saved('bruno') #>> '{}')::uuid, false, 'Outro pagamento.'
);
select is(
  pg_temp.fabio_sends() ->> 'status', 'approved',
  'CP16: depois da recusa do comprovante do Bruno, o mesmo ID: approved (RN89)'
);
rollback to savepoint cp15;

-- CP17 a CP19. Sem leitura.
savepoint cp17;
update public.charges set auto_reads_used = 3 where id = '00000000-0000-0000-0000-000000000c01';
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  '{"outcome": "skipped_limit"}'
), true);
select is(
  pg_temp.saved('r') - 'receipt_id',
  '{"result": "under_review", "error_code": null, "charge_status": "under_review", "auto_reads_used": 3}'::jsonb,
  'CP17a: auto_reads_used 3, skipped_limit: under_review, sem passar de 3'
);
select results_eq(
  $$ select status::text, auto_read, decided_at, validation from public.receipts
     where id = pg_temp.saved_receipt('r') $$,
  $$ values ('under_review', false, null::timestamptz,
             '{"amount": null, "recipient": null, "paid_at": null, "transaction_id": null, "skipped": "read_limit"}'::jsonb) $$,
  'CP17b: under_review, auto_read falso, validation.skipped read_limit'
);
select results_eq(
  $$ select status::text, auto_reads_used::int from public.charges
     where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('under_review', 3) $$,
  'CP17c: o valor vai para under_review, e auto_reads_used continua 3'
);
select results_eq(
  $$ select from_status::text, to_status::text, actor_id, receipt_id from public.charge_events
     where charge_id = '00000000-0000-0000-0000-000000000c01' and from_status is not null $$,
  $$ values ('pending', 'under_review', '00000000-0000-0000-0000-00000000000f'::uuid, pg_temp.saved_receipt('r')) $$,
  'CP17d: um charge_events de pending para under_review, com o Fábio e o receipt_id'
);
select results_eq(
  $$ select type::text, user_id, data from public.notifications $$,
  $$ values ('receipt_needs_review', '00000000-0000-0000-0000-00000000000a'::uuid,
             pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', jsonb_build_object(
               'receipt_id', pg_temp.saved_receipt('r'), 'payer_id', '00000000-0000-0000-0000-00000000000f'))) $$,
  'CP17e: notifica receipt_needs_review à Ana'
);
rollback to savepoint cp17;

savepoint cp18;
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', '{"outcome": "failed"}'
), true);
select results_eq(
  $$ select r.status::text, r.auto_read, c.auto_reads_used::int, r.validation
     from public.receipts r join public.charges c on c.id = r.charge_id
     where r.id = pg_temp.saved_receipt('r') $$,
  $$ values ('under_review', false, 0,
             '{"amount": null, "recipient": null, "paid_at": null, "transaction_id": null, "skipped": "api_failed"}'::jsonb) $$,
  'CP18: failed: under_review, auto_read falso, auto_reads_used 0, skipped api_failed'
);
rollback to savepoint cp18;

savepoint cp19;
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', '{"outcome": "skipped_file"}'
), true);
select results_eq(
  $$ select r.status::text, r.auto_read, c.auto_reads_used::int, r.validation
     from public.receipts r join public.charges c on c.id = r.charge_id
     where r.id = pg_temp.saved_receipt('r') $$,
  $$ values ('under_review', false, 0,
             '{"amount": null, "recipient": null, "paid_at": null, "transaction_id": null, "skipped": "file_not_supported"}'::jsonb) $$,
  'CP19: skipped_file: under_review, auto_read falso, auto_reads_used 0, skipped file_not_supported'
);
rollback to savepoint cp19;

-- CP20. Três leituras ilegíveis, cada uma recusada pela Ana.
savepoint cp20;
create function pg_temp.illegible_then_rejected()
returns int
language plpgsql
as $fn$
declare
  v_result jsonb := pg_temp.record(
    '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
    pg_temp.reading('{"amount_cents": null, "paid_at": null, "recipient_name": null, "transaction_id": null}')
  )::jsonb;
begin
  perform pg_temp.review(
    '00000000-0000-0000-0000-00000000000a', (v_result ->> 'receipt_id')::uuid, false, 'Ilegível.'
  );
  return (v_result ->> 'auto_reads_used')::int;
end;
$fn$;
select is(
  array[pg_temp.illegible_then_rejected(), pg_temp.illegible_then_rejected(), pg_temp.illegible_then_rejected()],
  array[1, 2, 3],
  'CP20: três leituras ilegíveis recusadas: auto_reads_used 1, 2 e 3'
);
rollback to savepoint cp20;

-- CP21. Valor fora de Pendente.
savepoint cp21;
update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
where id = '00000000-0000-0000-0000-000000000c01';
select set_config('t.before', pg_temp.state()::text, true);
select is(pg_temp.fabio_sends(), to_jsonb('CHARGE_NOT_PENDING'::text), 'CP21a: valor paid: CHARGE_NOT_PENDING');
select is(pg_temp.state(), pg_temp.saved('before'), 'CP21b: nada é gravado, e auto_reads_used não muda');
rollback to savepoint cp21;
savepoint cp21;
update public.charges set status = 'under_review' where id = '00000000-0000-0000-0000-000000000c01';
select is(pg_temp.fabio_sends(), to_jsonb('CHARGE_NOT_PENDING'::text), 'CP21c: valor under_review: CHARGE_NOT_PENDING');
rollback to savepoint cp21;
savepoint cp21;
update public.charges set status = 'waived', waived_at = now(), waive_reason = 'receiver_change'
where id = '00000000-0000-0000-0000-000000000c01';
select is(pg_temp.fabio_sends(), to_jsonb('CHARGE_NOT_PENDING'::text), 'CP21d: valor waived: CHARGE_NOT_PENDING');
rollback to savepoint cp21;

-- CP22. Entrada e pagador.
savepoint cp22;
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.record(
    '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', pg_temp.reading(),
    '00000000-0000-0000-0000-000000000c02/00000000-0000-0000-0000-0000000000f2.jpg'
  ),
  'INVALID_INPUT', 'CP22a: caminho de outro valor: INVALID_INPUT'
);
select is(
  pg_temp.record(
    '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000b', pg_temp.reading()
  ),
  'NOT_CHARGE_PAYER', 'CP22b: pagador Bruno no valor do Fábio: NOT_CHARGE_PAYER'
);
select is(pg_temp.state(), pg_temp.saved('before'), 'CP22c: nada é gravado');
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  pg_temp.reading('{"amount_cents": null}'),
  '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f3.jpg'
), true);
select pg_temp.review('00000000-0000-0000-0000-00000000000a', pg_temp.saved_receipt('r'), false, 'Ilegível.');
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.record(
    '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', pg_temp.reading(),
    '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f3.jpg'
  ),
  'INVALID_INPUT', 'CP22d: caminho já usado por um comprovante: INVALID_INPUT'
);
select is(pg_temp.state(), pg_temp.saved('before'), 'CP22e: nada é gravado');
rollback to savepoint cp22;

-- CP23. A Ana passou o recebimento para o Bruno antes do envio (RN32).
savepoint cp23;
select pg_temp.ana_passes_to('00000000-0000-0000-0000-00000000000b');
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f', pg_temp.reading()
), true);
select results_eq(
  $$ select status::text, validation -> 'recipient', receiver_id from public.receipts
     where id = pg_temp.saved_receipt('r') $$,
  $$ values ('under_review', 'false'::jsonb, '00000000-0000-0000-0000-00000000000b'::uuid) $$,
  'CP23a: nome ANA SOUZA LIMA: under_review, recipient falso, receiver_id = Bruno'
);
rollback to savepoint cp23;
savepoint cp23;
select pg_temp.ana_passes_to('00000000-0000-0000-0000-00000000000b');
select set_config('t.r', pg_temp.record(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  pg_temp.reading('{"recipient_name": "Bruno Costa"}')
), true);
select results_eq(
  $$ select status::text, receiver_id from public.receipts where id = pg_temp.saved_receipt('r') $$,
  $$ values ('approved', '00000000-0000-0000-0000-00000000000b'::uuid) $$,
  'CP23b: nome Bruno Costa: approved, receiver_id = Bruno'
);
rollback to savepoint cp23;

-- CP24. O app não chama record_receipt.
savepoint cp24;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.record_receipt(
       '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
       '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f4.jpg',
       'image/jpeg', 200000, '{"outcome": "failed"}'::jsonb) $$,
  '42501', null,
  'CP24: Ana logada (authenticated) chama record_receipt: 42501'
);
reset role;
rollback to savepoint cp24;

-- RV01 a RV06: análise do recebedor --------------------------------------------

-- O comprovante do Fábio Em análise, com o valor nulo.
create function pg_temp.fabio_under_review()
returns uuid
language sql
as $fn$
  select (pg_temp.record(
    '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
    pg_temp.reading('{"amount_cents": null}')
  )::jsonb ->> 'receipt_id')::uuid;
$fn$;

-- RV01. Ana aprova, sem observação.
savepoint rv01;
select set_config('t.id', to_jsonb(pg_temp.fabio_under_review())::text, true);
delete from public.notifications;
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, true, null)::jsonb,
  jsonb_build_object('receipt_id', pg_temp.saved('id') #>> '{}', 'status', 'approved', 'charge_status', 'paid'),
  'RV01a: devolve receipt_id, approved e o valor paid'
);
select results_eq(
  $$ select status::text, decided_by, decided_at = now(), receiver_note from public.receipts
     where id = (pg_temp.saved('id') #>> '{}')::uuid $$,
  $$ values ('approved', '00000000-0000-0000-0000-00000000000a'::uuid, true, null::text) $$,
  'RV01b: approved, decided_by = Ana, decided_at = now(), receiver_note nulo'
);
select results_eq(
  $$ select status::text, paid_via::text, paid_at = now() from public.charges
     where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('paid', 'receipt', true) $$,
  'RV01c: valor paid, paid_via receipt'
);
select results_eq(
  $$ select from_status::text, to_status::text, actor_id, receipt_id, note from public.charge_events
     where charge_id = '00000000-0000-0000-0000-000000000c01' and from_status = 'under_review' $$,
  $$ values ('under_review', 'paid', '00000000-0000-0000-0000-00000000000a'::uuid,
             (pg_temp.saved('id') #>> '{}')::uuid, null::text) $$,
  'RV01d: um charge_events com o receipt_id e note nulo'
);
select results_eq(
  $$ select type::text, user_id, data from public.notifications $$,
  $$ values ('charge_paid', '00000000-0000-0000-0000-00000000000f'::uuid,
             pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', jsonb_build_object(
               'paid_via', 'receipt', 'receipt_id', pg_temp.saved('id') #>> '{}'))) $$,
  'RV01e: notifica charge_paid ao Fábio, com paid_via receipt'
);

-- RV05, depois do RV01.
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, true, null),
  'RECEIPT_NOT_UNDER_REVIEW', 'RV05a: depois do RV01, aprovar de novo: RECEIPT_NOT_UNDER_REVIEW'
);
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, 'Não.'),
  'RECEIPT_NOT_UNDER_REVIEW', 'RV05b: depois do RV01, recusar: RECEIPT_NOT_UNDER_REVIEW'
);
rollback to savepoint rv01;

-- RV02. Ana recusa com observação.
savepoint rv02;
select set_config('t.id', to_jsonb(pg_temp.fabio_under_review())::text, true);
delete from public.notifications;
select is(
  pg_temp.review(
    '00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, '  O valor está errado.  '
  )::jsonb,
  jsonb_build_object('receipt_id', pg_temp.saved('id') #>> '{}', 'status', 'rejected', 'charge_status', 'pending'),
  'RV02a: devolve receipt_id, rejected e o valor pending'
);
select results_eq(
  $$ select status::text, rejection_reason::text, receiver_note, decided_by, decided_at = now()
     from public.receipts where id = (pg_temp.saved('id') #>> '{}')::uuid $$,
  $$ values ('rejected', 'receiver_rejected', 'O valor está errado.',
             '00000000-0000-0000-0000-00000000000a'::uuid, true) $$,
  'RV02b: rejected, receiver_rejected, observação sem os espaços'
);
select results_eq(
  $$ select c.status::text, e.to_status::text, e.receipt_id, e.note
     from public.charges c
     join public.charge_events e on e.charge_id = c.id and e.from_status = 'under_review'
     where c.id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('pending', 'pending', (pg_temp.saved('id') #>> '{}')::uuid, null::text) $$,
  'RV02c: valor pending; charge_events com o receipt_id e note nulo'
);
select results_eq(
  $$ select type::text, user_id, data from public.notifications $$,
  $$ values ('charge_back_to_pending', '00000000-0000-0000-0000-00000000000f'::uuid,
             pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', jsonb_build_object(
               'reason', 'receipt_rejected', 'receipt_id', pg_temp.saved('id') #>> '{}'))) $$,
  'RV02d: notifica charge_back_to_pending, com reason receipt_rejected e sem a observação'
);

-- RV05, depois do RV02.
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, true, null),
  'RECEIPT_NOT_UNDER_REVIEW', 'RV05c: depois do RV02, aprovar: RECEIPT_NOT_UNDER_REVIEW'
);
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, 'De novo.'),
  'RECEIPT_NOT_UNDER_REVIEW', 'RV05d: depois do RV02, recusar de novo: RECEIPT_NOT_UNDER_REVIEW'
);
rollback to savepoint rv02;

-- RV03. Observação da recusa.
savepoint rv03;
select set_config('t.id', to_jsonb(pg_temp.fabio_under_review())::text, true);
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, null),
  'RECEIPT_NOTE_REQUIRED', 'RV03a: recusa sem observação: RECEIPT_NOTE_REQUIRED'
);
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, '   '),
  'RECEIPT_NOTE_REQUIRED', 'RV03b: recusa só com espaços: RECEIPT_NOTE_REQUIRED'
);
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, repeat('a', 201)),
  'INVALID_INPUT', 'RV03c: observação com 201 caracteres: INVALID_INPUT'
);
select is(pg_temp.state(), pg_temp.saved('before'), 'RV03d: nada muda nas recusadas');
select is(
  pg_temp.review('00000000-0000-0000-0000-00000000000a', (pg_temp.saved('id') #>> '{}')::uuid, false, repeat('a', 200))::jsonb ->> 'status',
  'rejected', 'RV03e: com 200 caracteres: aceito'
);
rollback to savepoint rv03;

-- RV04. Quem não é o recebedor do comprovante.
savepoint rv04;
select set_config('t.id', to_jsonb(pg_temp.fabio_under_review())::text, true);
select is(
  array[
    pg_temp.review('00000000-0000-0000-0000-00000000000f', (pg_temp.saved('id') #>> '{}')::uuid, true, null),
    pg_temp.review('00000000-0000-0000-0000-00000000000e', (pg_temp.saved('id') #>> '{}')::uuid, true, null),
    pg_temp.review('00000000-0000-0000-0000-00000000000b', (pg_temp.saved('id') #>> '{}')::uuid, true, null),
    pg_temp.review('00000000-0000-0000-0000-00000000000d', (pg_temp.saved('id') #>> '{}')::uuid, true, null),
    pg_temp.review('00000000-0000-0000-0000-00000000000a', gen_random_uuid(), true, null)
  ],
  array['NOT_CHARGE_RECEIVER', 'NOT_FOUND', 'NOT_FOUND', 'NOT_FOUND', 'NOT_FOUND'],
  'RV04: Fábio NOT_CHARGE_RECEIVER; Edu (admin), Bruno, Diego e um uuid qualquer NOT_FOUND'
);
rollback to savepoint rv04;

-- RV06. Valor Em análise trava a troca, a marcação e a isenção. É o último e
-- fica fora de savepoint: o finish() precisa de um teste que não volte atrás.
select pg_temp.fabio_under_review();
select pg_temp.record(
  '00000000-0000-0000-0000-000000000c03', '00000000-0000-0000-0000-00000000000c',
  pg_temp.reading('{"amount_cents": null, "transaction_id": "E18236120202611200115S0123456780"}')
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'RECEIVER_CHANGE_BLOCKED',
  'RV06a: Ana troca o recebedor com valor Em análise: RECEIVER_CHANGE_BLOCKED'
);
reset role;
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01'),
  'CHARGE_NOT_PENDING', 'RV06b: Ana marca como pago o valor Em análise: CHARGE_NOT_PENDING'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000e', 'waive_penalty', '00000000-0000-0000-0000-000000000c03'),
  'CHARGE_NOT_PENDING', 'RV06c: Edu isenta a multa da Carla, Em análise: CHARGE_NOT_PENDING'
);

select * from finish();
rollback;
