-- RLS de grupo e contexto (fatia 3, RN107).
-- Cenários K01 a K15 de docs/testes-referencia.md, seção 11.2.
-- Políticas e privilégios: docs/rls-matriz.md, fatia 3.
--
-- Mesma base do groups_functions.test.sql: o Quinta, com o código VoleiQuinta1,
-- Ana admin e Bruno membro; Carla e Diego fora de qualquer grupo. As linhas de
-- grupo do seed são apagadas dentro desta transação (research R3 de
-- specs/002-grupos). Os jogos usados para contexto são inseridos direto, com o
-- admin na mesma transação (docs/modelo-dados.md, 4.3).

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(34);

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
    ('00000000-0000-0000-0000-00000000000d'::uuid, 'diego@voleiin.test', 'Diego')
) as u (id, email, name)
on conflict do nothing;

-- Desde a fatia 4, o seed também põe Ana, Bruno e Carla nos mesmos jogos, que
-- também são contexto: os jogos saem antes (research R6 de specs/003-jogo-etapa-a).
-- Valores do jogo concluído do seed (fatia 5) saem antes das passagens.
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

insert into public.groups (id, name, invite_code, created_by)
values (
  '00000000-0000-0000-0000-000000000301', 'Vôlei de Quinta', 'VoleiQuinta1',
  '00000000-0000-0000-0000-00000000000a'
);
insert into public.group_members (group_id, user_id, role)
values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'admin'),
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b', 'member');

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

-- Se quem está logado vê o perfil de p_user.
create function pg_temp.sees_profile(p_user uuid)
returns boolean
language sql
as $fn$
  select exists (select 1 from public.profiles where id = p_user);
$fn$;

-- K01. Grupos.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select results_eq(
  $$ select id, invite_code from public.groups $$,
  $$ values ('00000000-0000-0000-0000-000000000301'::uuid, 'VoleiQuinta1'::text) $$,
  'K01a: Bruno vê o Quinta, com o invite_code'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select is_empty($$ select id from public.groups $$, 'K01b: Diego não vê nenhum grupo');

-- K02. Integrantes.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select set_eq(
  $$ select user_id from public.group_members $$,
  array['00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b']::uuid[],
  'K02a: Bruno vê Ana e Bruno'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select is_empty($$ select user_id from public.group_members $$, 'K02b: Diego não vê nenhum integrante');
reset role;

-- K03. O ex-membro deixa de ler o grupo.
savepoint k03;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select lives_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$,
  'K03a: Bruno sai do Quinta'
);
select is_empty($$ select id from public.groups $$, 'K03b: o ex-membro não vê o grupo');
select is_empty($$ select user_id from public.group_members $$, 'K03c: nem os integrantes');
reset role;
rollback to savepoint k03;

-- K04. Grupo arquivado.
savepoint k04;
delete from public.group_members where group_id = '00000000-0000-0000-0000-000000000301';
update public.groups
set archived_at = now(), archived_by = '00000000-0000-0000-0000-00000000000a', invite_code = null
where id = '00000000-0000-0000-0000-000000000301';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is_empty($$ select id from public.groups $$, 'K04: ninguém lê o grupo arquivado');
reset role;
rollback to savepoint k04;

-- K05. Solicitações: o solicitante e os admins.
savepoint k05;
insert into public.group_join_requests (group_id, user_id, status, decided_at, decided_by)
values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d',
   'rejected', now() - interval '1 day', '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d',
   'pending', null, null);
set local role authenticated;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select is(
  (select count(*) from public.group_join_requests), 2::bigint,
  'K05a: Diego vê as duas solicitações dele'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
select is(
  (select count(*) from public.group_join_requests), 2::bigint,
  'K05b: Ana, admin, vê as duas'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select is_empty($$ select id from public.group_join_requests $$, 'K05c: Bruno, membro comum, não vê');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
select is_empty($$ select id from public.group_join_requests $$, 'K05d: Carla não vê');
reset role;
rollback to savepoint k05;

-- K06. Nenhuma escrita direta nas três tabelas.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ insert into public.groups (name, created_by) values ('X', '00000000-0000-0000-0000-00000000000a') $$,
  '42501', null, 'K06a: insert em groups'
);
select throws_ok(
  $$ update public.groups set name = 'X' where id = '00000000-0000-0000-0000-000000000301' $$,
  '42501', null, 'K06b: update em groups'
);
select throws_ok(
  $$ delete from public.groups where id = '00000000-0000-0000-0000-000000000301' $$,
  '42501', null, 'K06c: delete em groups'
);
select throws_ok(
  $$ insert into public.group_members (group_id, user_id)
     values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000c') $$,
  '42501', null, 'K06d: insert em group_members'
);
select throws_ok(
  $$ update public.group_members set role = 'admin'
     where user_id = '00000000-0000-0000-0000-00000000000b' $$,
  '42501', null, 'K06e: update em group_members'
);
select throws_ok(
  $$ delete from public.group_members where user_id = '00000000-0000-0000-0000-00000000000b' $$,
  '42501', null, 'K06f: delete em group_members'
);
select throws_ok(
  $$ insert into public.group_join_requests (group_id, user_id)
     values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a') $$,
  '42501', null, 'K06g: insert em group_join_requests'
);
select throws_ok(
  $$ update public.group_join_requests set status = 'approved' $$,
  '42501', null, 'K06h: update em group_join_requests'
);
select throws_ok(
  $$ delete from public.group_join_requests $$,
  '42501', null, 'K06i: delete em group_join_requests'
);
reset role;

-- K07. Perfis por contexto de grupo (RN107).
set local role authenticated;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select set_eq(
  $$ select id from public.profiles
     where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
                  '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000d') $$,
  array['00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b']::uuid[],
  'K07a: Bruno vê a própria linha e a da Ana'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select results_eq(
  $$ select id from public.profiles
     where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b',
                  '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000d') $$,
  $$ values ('00000000-0000-0000-0000-00000000000d'::uuid) $$,
  'K07b: Diego, sem contexto, vê só a própria (RN107, negativo)'
);
reset role;

-- K08. Jogo passado e espera contam como contexto.
savepoint k08;
insert into public.games (
  id, group_id, created_by, location_name, cancellation_deadline, starts_at, ends_at,
  total_cents, slot_limit, receiver_id, invite_code
)
values (
  '00000000-0000-0000-0000-000000000411', null, '00000000-0000-0000-0000-00000000000c',
  'Praia', now() + interval '1 day', now() + interval '1 day 2 hours',
  now() + interval '1 day 4 hours', 6000, 6, '00000000-0000-0000-0000-00000000000c', 'JogoAvulso01'
);
insert into public.game_admins (game_id, user_id)
values ('00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-00000000000c');
insert into public.game_participants (game_id, user_id, status, left_at, late_cancellation)
values ('00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-00000000000c',
        'cancelled', now(), false);
insert into public.game_waitlist (game_id, user_id, left_at)
values ('00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-00000000000d', now());
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select ok(
  pg_temp.sees_profile('00000000-0000-0000-0000-00000000000c'),
  'K08: Diego vê a Carla (jogo passado e espera contam como contexto)'
);
reset role;
rollback to savepoint k08;

-- K09 e K10. Admin vê quem tem solicitação pendente; depois da recusa, não.
savepoint k09;
insert into public.group_join_requests (group_id, user_id)
values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
select ok(
  pg_temp.sees_profile('00000000-0000-0000-0000-00000000000d'),
  'K09a: Ana, admin, vê o perfil do Diego (RN107, exceção 2)'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select ok(
  not pg_temp.sees_profile('00000000-0000-0000-0000-00000000000d'),
  'K09b: Bruno, membro comum, não vê'
);
reset role;
update public.group_join_requests
set status = 'rejected', decided_at = now(), decided_by = '00000000-0000-0000-0000-00000000000a'
where user_id = '00000000-0000-0000-0000-00000000000d';
set local role authenticated;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
select ok(
  not pg_temp.sees_profile('00000000-0000-0000-0000-00000000000d'),
  'K10: depois da recusa, Ana não vê o Diego'
);
reset role;
rollback to savepoint k09;

-- K11. Depois da aprovação, vale o contexto do grupo.
savepoint k11;
insert into public.group_join_requests (group_id, user_id, status, decided_at, decided_by)
values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d',
        'approved', now(), '00000000-0000-0000-0000-00000000000a');
insert into public.group_members (group_id, user_id)
values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select ok(
  pg_temp.sees_profile('00000000-0000-0000-0000-00000000000d'),
  'K11: Bruno vê o Diego pelo contexto do grupo'
);
reset role;
rollback to savepoint k11;

-- K12. O contexto acaba com a saída.
savepoint k12;
delete from public.group_members where user_id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select ok(
  not pg_temp.sees_profile('00000000-0000-0000-0000-00000000000b'),
  'K12: depois que Bruno sai, Ana não o vê'
);
reset role;
rollback to savepoint k12;

-- K13. O contexto acaba com o arquivamento.
savepoint k13;
delete from public.group_members where group_id = '00000000-0000-0000-0000-000000000301';
update public.groups
set archived_at = now(), archived_by = '00000000-0000-0000-0000-00000000000a', invite_code = null
where id = '00000000-0000-0000-0000-000000000301';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select ok(
  not pg_temp.sees_profile('00000000-0000-0000-0000-00000000000b'),
  'K13: com o Quinta arquivado, Ana não vê o Bruno'
);
reset role;
rollback to savepoint k13;

-- K14. Dados privados continuam só do dono.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select results_eq(
  $$ select user_id from public.profile_private $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid) $$,
  'K14: Bruno vê só a própria linha de profile_private, mesmo com contexto'
);
reset role;

-- K15. anon não lê nada.
set local role anon;
select throws_ok($$ select id from public.groups $$, '42501', null, 'K15a: anon em groups');
select throws_ok(
  $$ select user_id from public.group_members $$, '42501', null, 'K15b: anon em group_members'
);
select throws_ok(
  $$ select id from public.group_join_requests $$, '42501', null,
  'K15c: anon em group_join_requests'
);
reset role;

-- Sem finish(): o rollback para cada savepoint apaga a tabela de resultados do
-- pgTAP (a numeração segue certa, porque vem de uma sequência). O pg_prove
-- confere o plano pelas linhas ok e not ok.
rollback;
