-- Leitura e escrita de receipts (fatia 6, etapa B). Cenários RS01 a RS05 e
-- RS09 de docs/testes-referencia.md, seção 14.5 (RF87). Políticas e
-- privilégios: docs/rls-matriz.md, fatia 6. RS06 a RS08 (Storage) ficam em
-- supabase/functions/_tests/receipts_test.ts. Em RS09, list_storage_cleanup e
-- mark_receipts_file_deleted entram na etapa C.
--
-- A mesma base de receipt_rules.test.sql. Cada cenário roda entre um savepoint
-- e o rollback para ele, salvo o último.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(13);

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

-- Grava um comprovante como a Edge Function (service_role), com o valor nulo
-- (Em análise), e devolve o id.
create function pg_temp.send(p_charge uuid, p_payer uuid, p_transaction text)
returns uuid
language plpgsql
as $fn$
declare
  v_result jsonb;
begin
  set local role service_role;
  v_result := public.record_receipt(
    p_charge, p_payer, p_charge::text || '/' || gen_random_uuid()::text || '.jpg',
    'image/jpeg', 200000,
    jsonb_build_object(
      'outcome', 'read', 'amount_cents', null, 'paid_at', '2026-11-19T22:15',
      'recipient_name', 'ANA SOUZA LIMA', 'recipient_key', null, 'transaction_id', p_transaction,
      'raw', '{}'::jsonb
    )
  );
  reset role;
  return (v_result ->> 'receipt_id')::uuid;
end;
$fn$;

-- A Ana recusa, com observação.
create function pg_temp.ana_rejects(p_receipt uuid)
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
  set local role authenticated;
  perform public.review_receipt(p_receipt, false, 'Não é deste jogo.');
  reset role;
end;
$fn$;

-- Os comprovantes que a pessoa lê.
create function pg_temp.visible(p_user uuid)
returns uuid[]
language plpgsql
as $fn$
declare
  v_ids uuid[];
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  select coalesce(array_agg(id order by id), '{}') into v_ids from public.receipts;
  reset role;
  return v_ids;
end;
$fn$;

-- RS01. Só o pagador e o recebedor do comprovante.
savepoint rs01;
select set_config('t.id', pg_temp.send(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  'E18236120202611200115S0123456789')::text, true);
select is(
  array[
    pg_temp.visible('00000000-0000-0000-0000-00000000000f'),
    pg_temp.visible('00000000-0000-0000-0000-00000000000a')
  ],
  array[array[current_setting('t.id')::uuid], array[current_setting('t.id')::uuid]],
  'RS01a: o Fábio e a Ana veem o comprovante'
);
select is(
  array[
    pg_temp.visible('00000000-0000-0000-0000-00000000000e'),
    pg_temp.visible('00000000-0000-0000-0000-00000000000b'),
    pg_temp.visible('00000000-0000-0000-0000-00000000000d')
  ]::text,
  '{{},{},{}}',
  'RS01b: o Edu (admin), o Bruno e o Diego não veem nenhum'
);
rollback to savepoint rs01;

-- RS02 e RS03. O recebedor do comprovante é o do envio (RN32).
savepoint rs02;
select set_config('t.old', pg_temp.send(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  'E18236120202611200115S0123456789')::text, true);
select pg_temp.ana_rejects(current_setting('t.old')::uuid);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select public.change_receiver('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-00000000000b');
reset role;
select is(
  array[
    pg_temp.visible('00000000-0000-0000-0000-00000000000a'),
    pg_temp.visible('00000000-0000-0000-0000-00000000000b')
  ]::text,
  array[array[current_setting('t.old')::uuid], '{}'::uuid[]]::text,
  'RS02: depois da troca para o Bruno, a Ana vê o recusado; o Bruno, não'
);
select set_config('t.new', pg_temp.send(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  'E18236120202611200115S0123456781')::text, true);
select is(
  array[
    pg_temp.visible('00000000-0000-0000-0000-00000000000a'),
    pg_temp.visible('00000000-0000-0000-0000-00000000000b')
  ],
  array[array[current_setting('t.old')::uuid], array[current_setting('t.new')::uuid]],
  'RS03: depois de um novo envio, a Ana vê só o antigo; o Bruno, só o novo'
);
rollback to savepoint rs02;

-- RS04. A observação não chega aos admins pelos eventos.
savepoint rs04;
select set_config('t.id', pg_temp.send(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  'E18236120202611200115S0123456789')::text, true);
select pg_temp.ana_rejects(current_setting('t.id')::uuid);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select results_eq(
  $$ select from_status::text, to_status::text, receipt_id, note from public.charge_events
     where charge_id = '00000000-0000-0000-0000-000000000c01' and from_status = 'under_review' $$,
  $$ values ('under_review', 'pending', current_setting('t.id')::uuid, null::text) $$,
  'RS04: o Edu vê a transição da recusa, com note nulo'
);
reset role;
rollback to savepoint rs04;

-- RS05. Ninguém escreve direto em receipts, e anon não lê.
savepoint rs05;
select set_config('t.id', pg_temp.send(
  '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
  'E18236120202611200115S0123456789')::text, true);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000f');
set local role authenticated;
select throws_ok(
  $$ insert into public.receipts (charge_id, payer_id, receiver_id, mime_type, size_bytes, status, auto_read)
     values ('00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
             '00000000-0000-0000-0000-00000000000a', 'image/jpeg', 1, 'approved', false) $$,
  '42501', null, 'RS05a: o Fábio insere em receipts: 42501'
);
select throws_ok(
  $$ update public.receipts set status = 'approved' $$,
  '42501', null, 'RS05b: o Fábio altera receipts: 42501'
);
select throws_ok(
  $$ delete from public.receipts $$,
  '42501', null, 'RS05c: o Fábio apaga em receipts: 42501'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ update public.receipts set receiver_note = 'x' $$,
  '42501', null, 'RS05d: a Ana altera receipts: 42501'
);
select throws_ok(
  $$ delete from public.receipts $$,
  '42501', null, 'RS05e: a Ana apaga em receipts: 42501'
);
reset role;
set local role anon;
select throws_ok(
  $$ select * from public.receipts $$,
  '42501', null, 'RS05f: anon lê receipts: 42501'
);
reset role;
rollback to savepoint rs05;

-- RS09. O app não executa as funções de service_role (as da etapa C entram
-- nela). É o último e fica fora de savepoint.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000f');
set local role authenticated;
select throws_ok(
  $$ select public.record_receipt(
       '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
       '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f1.jpg',
       'image/jpeg', 200000, '{"outcome": "failed"}'::jsonb) $$,
  '42501', null, 'RS09a: o Fábio chama record_receipt: 42501'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.record_receipt(
       '00000000-0000-0000-0000-000000000c01', '00000000-0000-0000-0000-00000000000f',
       '00000000-0000-0000-0000-000000000c01/00000000-0000-0000-0000-0000000000f1.jpg',
       'image/jpeg', 200000, '{"outcome": "failed"}'::jsonb) $$,
  '42501', null, 'RS09b: a Ana chama record_receipt: 42501'
);
reset role;

select * from finish();
rollback;
