-- Marcar como pago e reverter (fatia 6, etapa A). Cenários PG01 a PG07 de
-- docs/testes-referencia.md, seção 14.1 (RN84, RN85). Contratos:
-- docs/contratos-api.md, seção 6.
--
-- Base da seção 14, inserida aqui sem depender do seed (research R7 de
-- specs/009-pagamentos-etapa-a). Cada cenário roda entre um savepoint e o
-- rollback para ele.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(34);

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
-- specs/003-jogo-etapa-a). Os jogos saem antes das chaves Pix, que a RN105
-- prende enquanto a pessoa é recebedora.
delete from public.charge_events;
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

-- Seção 14: Ana Souza Lima, com a chave CPF, e o Bruno com chave, porque vira
-- recebedor no PG06 e no PG07.
update public.profiles set name = 'Ana Souza Lima'
where id = '00000000-0000-0000-0000-00000000000a';
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

-- Valor guardado por um cenário (nulo se a chamada falhou).
create function pg_temp.saved(p_name text)
returns jsonb
language sql
as $fn$
  select nullif(current_setting('t.' || p_name, true), '')::jsonb;
$fn$;

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

-- Chama a função como a pessoa e devolve o retorno, ou o código do erro.
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

-- Tudo que uma recusa não pode mudar.
create function pg_temp.state()
returns jsonb
language sql
as $fn$
  select jsonb_build_object(
    'charges', (select jsonb_agg(to_jsonb(c) order by c.id) from public.charges c),
    'events', (select jsonb_agg(to_jsonb(e) order by e.id) from public.charge_events e),
    'notifications', (select count(*) from public.notifications)
  );
$fn$;

-- Os dados da notificação de pagamento (contratos-api.md, seção 6).
create function pg_temp.payment_data(p_charge uuid, p_extra jsonb)
returns jsonb
language sql
as $fn$
  select private.game_notification_data('00000000-0000-0000-0000-000000000a01')
    || jsonb_build_object('charge_id', p_charge, 'amount_cents', 2084, 'receipt_id', null)
    || p_extra;
$fn$;

-- PG01. Ana marca o valor do Fábio como pago.
savepoint pg01;
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01')::jsonb,
  '{"charge_id": "00000000-0000-0000-0000-000000000c01", "status": "paid"}'::jsonb,
  'PG01a: devolve charge_id e status paid'
);
select results_eq(
  $$ select status::text, paid_at = now(), paid_via::text, receiver_id
     from public.charges where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('paid', true, 'manual', '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'PG01b: paid, paid_at = now(), paid_via manual, devido à Ana'
);
select results_eq(
  $$ select to_status::text, actor_id, receipt_id, note from public.charge_events
     where charge_id = '00000000-0000-0000-0000-000000000c01' and from_status = 'pending' $$,
  $$ values ('paid', '00000000-0000-0000-0000-00000000000a'::uuid, null::uuid, null::text) $$,
  'PG01c: um charge_events de pending para paid, com actor_id = Ana'
);
select results_eq(
  $$ select type::text, user_id, data from public.notifications $$,
  $$ select 'charge_paid', '00000000-0000-0000-0000-00000000000f'::uuid,
            pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', '{"paid_via": "manual"}') $$,
  'PG01d: notifica só charge_paid ao Fábio, com paid_via manual e receipt_id nulo'
);
select is_empty(
  $$ select 1 from public.charges
     where id in ('00000000-0000-0000-0000-000000000c02', '00000000-0000-0000-0000-000000000c03')
       and status <> 'pending' $$,
  'PG01e: os outros valores do jogo continuam Pendentes'
);

-- PG04. Depois do PG01, Ana reverte.
update public.charges set auto_reads_used = 2 where id = '00000000-0000-0000-0000-000000000c01';
delete from public.notifications;
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c01')::jsonb,
  '{"charge_id": "00000000-0000-0000-0000-000000000c01", "status": "pending"}'::jsonb,
  'PG04a: devolve charge_id e status pending'
);
select results_eq(
  $$ select status::text, paid_at, paid_via::text, auto_reads_used::integer, receiver_id
     from public.charges where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('pending', null::timestamptz, null::text, 2, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'PG04b: pending, sem paid_at e paid_via; auto_reads_used não muda'
);
select results_eq(
  $$ select to_status::text, actor_id, receipt_id, note from public.charge_events
     where charge_id = '00000000-0000-0000-0000-000000000c01' and from_status = 'paid' $$,
  $$ values ('pending', '00000000-0000-0000-0000-00000000000a'::uuid, null::uuid, null::text) $$,
  'PG04c: um charge_events de paid para pending, com actor_id = Ana'
);
select results_eq(
  $$ select type::text, user_id, data from public.notifications $$,
  $$ select 'charge_back_to_pending', '00000000-0000-0000-0000-00000000000f'::uuid,
            pg_temp.payment_data('00000000-0000-0000-0000-000000000c01', '{"reason": "reverted"}') $$,
  'PG04d: notifica só charge_back_to_pending ao Fábio, com reason reverted'
);
rollback to savepoint pg01;

-- PG02. Quem não pode marcar.
savepoint pg02;
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000e', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01'),
  'NOT_CHARGE_RECEIVER', 'PG02a: Edu, admin e não recebedor: NOT_CHARGE_RECEIVER'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000f', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01'),
  'NOT_CHARGE_RECEIVER', 'PG02b: Fábio, o pagador: NOT_CHARGE_RECEIVER'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000b', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01'),
  'NOT_FOUND', 'PG02c: Bruno, outro pagador: NOT_FOUND'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000d', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01'),
  'NOT_FOUND', 'PG02d: Diego, fora do jogo: NOT_FOUND'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000cff'),
  'NOT_FOUND', 'PG02e: Ana com um uuid qualquer: NOT_FOUND'
);
select is(pg_temp.state(), current_setting('t.before')::jsonb, 'PG02f: nada muda');
rollback to savepoint pg02;

-- PG03. Valor que não está Pendente.
savepoint pg03;
update public.charges set status = 'under_review' where id = '00000000-0000-0000-0000-000000000c01';
update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual' where id = '00000000-0000-0000-0000-000000000c02';
update public.charges
set status = 'waived', waived_at = now(), waive_reason = 'manual_waiver', waived_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000c03';
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01'),
  'CHARGE_NOT_PENDING', 'PG03a: valor Em análise: CHARGE_NOT_PENDING'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c02'),
  'CHARGE_NOT_PENDING', 'PG03b: valor Pago: CHARGE_NOT_PENDING'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c03'),
  'CHARGE_NOT_PENDING', 'PG03c: valor Isento: CHARGE_NOT_PENDING'
);
select is(pg_temp.state(), current_setting('t.before')::jsonb, 'PG03d: nada muda');
rollback to savepoint pg03;

-- PG05. O que não é revertido e quem não reverte.
savepoint pg05;
select pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01');
update public.charges set status = 'paid', paid_at = now(), paid_via = 'receipt' where id = '00000000-0000-0000-0000-000000000c02';
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c03'),
  'CHARGE_NOT_REVERTIBLE', 'PG05a: valor Pendente: CHARGE_NOT_REVERTIBLE'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c02'),
  'CHARGE_NOT_REVERTIBLE', 'PG05b: valor pago por comprovante: CHARGE_NOT_REVERTIBLE'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000e', 'revert_charge', '00000000-0000-0000-0000-000000000c01'),
  'NOT_CHARGE_RECEIVER', 'PG05c: Edu, admin e não recebedor: NOT_CHARGE_RECEIVER'
);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000f', 'revert_charge', '00000000-0000-0000-0000-000000000c01'),
  'NOT_CHARGE_RECEIVER', 'PG05d: Fábio, o pagador: NOT_CHARGE_RECEIVER'
);
select is(pg_temp.state(), current_setting('t.before')::jsonb, 'PG05e: nada muda');
rollback to savepoint pg05;

-- PG06. Depois da troca de recebedor, só o antigo reverte (RN32).
savepoint pg06;
select pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01');
select pg_temp.ana_passes_to('00000000-0000-0000-0000-00000000000b');
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000b', 'revert_charge', '00000000-0000-0000-0000-000000000c01'),
  'NOT_CHARGE_RECEIVER', 'PG06a: Bruno, o novo recebedor: NOT_CHARGE_RECEIVER'
);
select is(pg_temp.state(), current_setting('t.before')::jsonb, 'PG06b: nada muda');
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c01')::jsonb,
  '{"charge_id": "00000000-0000-0000-0000-000000000c01", "status": "pending"}'::jsonb,
  'PG06c: Ana, a antiga recebedora: aceito'
);
select results_eq(
  $$ select status::text, receiver_id from public.charges where id = '00000000-0000-0000-0000-000000000c01' $$,
  $$ values ('pending', '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'PG06d: o valor volta a Pendente, devido à Ana'
);
rollback to savepoint pg06;

-- PG06, o outro caso: o Fábio excluiu a conta (RN104).
savepoint pg06_deleted;
select pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c01');
update public.profiles set name = 'Usuário removido', deleted_at = now()
where id = '00000000-0000-0000-0000-00000000000f';
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c01'),
  'CHARGE_NOT_REVERTIBLE', 'PG06e: o pagador excluiu a conta: CHARGE_NOT_REVERTIBLE'
);
select is(pg_temp.state(), current_setting('t.before')::jsonb, 'PG06f: nada muda');
rollback to savepoint pg06_deleted;

-- PG07. O pagador virou o recebedor do jogo (RN85). É o último e fica fora de
-- savepoint: o finish() precisa de um teste que não volte atrás.
select pg_temp.call('00000000-0000-0000-0000-00000000000a', 'mark_charge_paid', '00000000-0000-0000-0000-000000000c02');
select pg_temp.ana_passes_to('00000000-0000-0000-0000-00000000000b');
select set_config('t.before', pg_temp.state()::text, true);
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c02'),
  'CHARGE_NOT_REVERTIBLE', 'PG07a: o pagador é o recebedor do jogo: CHARGE_NOT_REVERTIBLE'
);
select is(pg_temp.state(), current_setting('t.before')::jsonb, 'PG07b: nada muda');
select pg_temp.ana_passes_to('00000000-0000-0000-0000-00000000000a');
select is(
  pg_temp.call('00000000-0000-0000-0000-00000000000a', 'revert_charge', '00000000-0000-0000-0000-000000000c02')::jsonb,
  '{"charge_id": "00000000-0000-0000-0000-000000000c02", "status": "pending"}'::jsonb,
  'PG07c: com a Ana de volta como recebedora: aceito'
);
select results_eq(
  $$ select status::text, receiver_id from public.charges where id = '00000000-0000-0000-0000-000000000c02' $$,
  $$ values ('pending', '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'PG07d: o valor fica Pendente, devido à Ana'
);

select * from finish();
rollback;
