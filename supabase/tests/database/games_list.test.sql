-- Lista de presença, espera e limite de vagas (fatia 4, etapa A).
-- Cenários O01 a O07 e O20 a O23 de docs/testes-referencia.md, seção 12.2, e
-- T03 a T05 da seção 3. Os O08 a O19 (saídas, espera e remoção) e T01, T02 e
-- T06 a T10 entram na etapa B.
-- Contratos: docs/contratos-api.md, seção 4.
--
-- Base e jogo base: os mesmos de games_functions.test.sql (seção 12; research
-- R6 de specs/003-jogo-etapa-a). Cada cenário roda entre um savepoint e o
-- rollback para ele.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(41);

-- Personagens (docs/setup.md, seção 8), mais o Edu, que só existe nos testes.
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
    ('00000000-0000-0000-0000-00000000000e'::uuid, 'edu@voleiin.test', 'Edu')
) as u (id, email, name)
on conflict do nothing;

-- Limpeza dos jogos e das linhas de grupo do seed (research R6). Os jogos saem
-- antes da chave Pix da Carla, que a RN105 prende enquanto ela é recebedora.
delete from public.game_waitlist;
delete from public.game_participants;
delete from public.game_admins;
delete from public.game_limit_history;
delete from public.games;
delete from public.group_join_requests;
delete from public.group_members;
update public.groups set invite_code = null where invite_code is not null;
delete from public.notifications;

update public.profile_private
set phone = '+5586999998888', phone_visible = true, pix_key_type = 'cpf', pix_key = '12345678909'
where user_id = '00000000-0000-0000-0000-00000000000a';
update public.profile_private
set phone = '+5586988887777', phone_visible = false, pix_key_type = 'email', pix_key = 'bruno@voleiin.test'
where user_id = '00000000-0000-0000-0000-00000000000b';
update public.profile_private
set phone = null, phone_visible = false, pix_key_type = null, pix_key = null
where user_id in (
  '00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000d',
  '00000000-0000-0000-0000-00000000000e'
);

-- Base: o Quinta. Os IDs de teste (...0301 e ...0401 em diante) não colidem com os do seed.
insert into public.groups (id, name, invite_code, created_by)
values (
  '00000000-0000-0000-0000-000000000301', 'Vôlei de Quinta', 'VoleiQuinta1',
  '00000000-0000-0000-0000-00000000000a'
);
insert into public.group_members (group_id, user_id, role)
values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'admin'),
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b', 'member'),
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000c', 'member'),
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000e', 'member');

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

-- Jogo inserido direto, com quem cria como admin, recebedor e primeiro da lista
-- (entrou 1 h antes, para ficar no começo da ordem).
create function pg_temp.make_game(
  p_id uuid,
  p_deadline timestamptz,
  p_starts timestamptz,
  p_ends timestamptz,
  p_limit integer default 3,
  p_group uuid default '00000000-0000-0000-0000-000000000301',
  p_creator uuid default '00000000-0000-0000-0000-00000000000a'
)
returns void
language plpgsql
as $fn$
begin
  insert into public.games (
    id, group_id, created_by, location_name, cancellation_deadline, starts_at, ends_at,
    total_cents, slot_limit, receiver_id, invite_code
  )
  values (
    p_id, p_group, p_creator, 'Quadra do Sesc', p_deadline, p_starts, p_ends,
    9000, p_limit, p_creator, 'Jogo' || right(replace(p_id::text, '-', ''), 8)
  );
  insert into public.game_admins (game_id, user_id) values (p_id, p_creator);
  insert into public.game_participants (game_id, user_id, joined_at)
  values (p_id, p_creator, now() - interval '1 hour');
end;
$fn$;

-- Jogo base.
create function pg_temp.base_game()
returns void
language sql
as $fn$
  select pg_temp.make_game(
    '00000000-0000-0000-0000-000000000401',
    now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours'
  );
$fn$;

-- Passagem ativa, com o status do jogo acompanhando as vagas.
create function pg_temp.add_participant(p_game uuid, p_user uuid)
returns void
language plpgsql
as $fn$
begin
  insert into public.game_participants (game_id, user_id) values (p_game, p_user);
  update public.games g
  set status = case
    when (select count(*) from public.game_participants p
          where p.game_id = g.id and p.status in ('active', 'left_after_start')) >= g.slot_limit
    then 'confirmed'::public.game_status else 'open'::public.game_status end
  where g.id = p_game;
end;
$fn$;

-- Vagas ocupadas do jogo: passagens active e left_after_start (RN57).
create function pg_temp.occupied(p_game uuid)
returns bigint
language sql
as $fn$
  select count(*) from public.game_participants
  where game_id = p_game and status in ('active', 'left_after_start');
$fn$;

-- Lista cheia: Ana, Bruno e Carla no jogo base (Confirmado).
create function pg_temp.full_base_game()
returns void
language sql
as $fn$
  select pg_temp.base_game();
  select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
  select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000c');
$fn$;

-- =========================================================================
-- Entrar e encher (RF47, RF51, RF55, RN03, RN41, RN50 a RN52)
-- =========================================================================

-- O01. Bruno entra no jogo base, só com a Ana.
savepoint o01;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.o01', public.join_game('00000000-0000-0000-0000-000000000401')::text, true) $$,
  'O01a: Bruno entra'
);
reset role;
select is(pg_temp.saved('o01') ->> 'status', 'open', 'O01b: devolve status = open');
select results_eq(
  format(
    $$ select user_id, status::text, joined_at = now() from public.game_participants where id = %L $$,
    pg_temp.saved('o01') ->> 'participant_id'
  ),
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, 'active'::text, true) $$,
  'O01c: participant_id é a passagem active do Bruno, com joined_at = now()'
);
select is(pg_temp.occupied('00000000-0000-0000-0000-000000000401'), 2::bigint, 'O01d: 2 vagas ocupadas');
select is_empty($$ select 1 from public.notifications $$, 'O01e: nenhuma notificação');
rollback to savepoint o01;

-- O02. Carla enche a lista.
savepoint o02;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.o02', public.join_game('00000000-0000-0000-0000-000000000401')::text, true) $$,
  'O02a: Carla entra'
);
reset role;
select is(pg_temp.saved('o02') ->> 'status', 'confirmed', 'O02b: devolve status = confirmed (RN41)');
select is(
  (select status::text from public.games where id = '00000000-0000-0000-0000-000000000401'),
  'confirmed', 'O02c: o jogo está confirmed'
);
select set_eq(
  $$ select user_id, type::text, data ->> 'game_id' as game_id, data ->> 'group_name' as group_name,
            data ->> 'location_name' as location_name,
            (data ->> 'starts_at')::timestamptz = now() + interval '26 hours' as starts_at_ok
     from public.notifications $$,
  $$ values
       ('00000000-0000-0000-0000-00000000000a'::uuid, 'game_confirmed'::text,
        '00000000-0000-0000-0000-000000000401'::text, 'Vôlei de Quinta'::text, 'Quadra do Sesc'::text, true),
       ('00000000-0000-0000-0000-00000000000b'::uuid, 'game_confirmed'::text,
        '00000000-0000-0000-0000-000000000401'::text, 'Vôlei de Quinta'::text, 'Quadra do Sesc'::text, true) $$,
  'O02d: notifica Ana e Bruno (game_confirmed), e não Carla'
);
rollback to savepoint o02;

-- O03. Lista cheia: Edu tenta entrar, entra na espera, tenta de novo; Bruno tenta a espera.
savepoint o03;
select pg_temp.full_base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_FULL', 'O03a: Edu recebe GAME_FULL'
);
select lives_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'O03b: Edu entra na espera'
);
reset role;
select results_eq(
  $$ select joined_at = now(), left_at from public.game_waitlist
     where game_id = '00000000-0000-0000-0000-000000000401'
       and user_id = '00000000-0000-0000-0000-00000000000e' $$,
  $$ values (true, null::timestamptz) $$,
  'O03c: linha na espera com joined_at = now() e left_at nulo'
);
set local role authenticated;
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'ALREADY_ON_WAITLIST', 'O03d: de novo, ALREADY_ON_WAITLIST'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'ALREADY_PARTICIPANT', 'O03e: Bruno, na lista, recebe ALREADY_PARTICIPANT'
);
reset role;
rollback to savepoint o03;

-- O04. Jogo Aberto: a espera recusa.
savepoint o04;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_NOT_FULL', 'O04: Edu recebe GAME_NOT_FULL (RN51)'
);
reset role;
rollback to savepoint o04;

-- O05. Bruno já na lista.
savepoint o05;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'ALREADY_PARTICIPANT', 'O05: Bruno recebe ALREADY_PARTICIPANT'
);
reset role;
rollback to savepoint o05;

-- O06. Quem não vê o jogo: Diego no jogo base; Carla no avulso do Bruno.
savepoint o06;
select pg_temp.base_game();
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours',
  4, null, '00000000-0000-0000-0000-00000000000b'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'NOT_FOUND', 'O06a: Diego, join_game no jogo base'
);
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'NOT_FOUND', 'O06b: Diego, join_waitlist no jogo base'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
set local role authenticated;
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000402') $$,
  'P0001', 'NOT_FOUND', 'O06c: Carla, join_game no avulso do Bruno'
);
reset role;
rollback to savepoint o06;

-- O07. Jogo iniciado com vaga; jogo cheio iniciado; jogo cancelado.
savepoint o07;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now(), now() + interval '2 hours'
);
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() - interval '3 hours', now(), now() + interval '2 hours', 1
);
update public.games set status = 'confirmed' where id = '00000000-0000-0000-0000-000000000402';
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000403',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours'
);
update public.games
set status = 'cancelled', cancelled_at = now(), cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000403';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_STARTED', 'O07a: jogo iniciado, com vaga (T04)'
);
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000402') $$,
  'P0001', 'GAME_STARTED', 'O07b: jogo cheio iniciado, na espera (T05)'
);
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000403') $$,
  'P0001', 'GAME_NOT_OPEN', 'O07c: jogo cancelado'
);
reset role;
rollback to savepoint o07;

-- =========================================================================
-- Limites de tempo na entrada (seção 3: T03 a T05)
-- =========================================================================

-- T03. Início 1 µs depois de now(), com vaga.
savepoint t03;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now() + interval '1 microsecond', now() + interval '2 hours'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select lives_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'T03: início 1 µs depois de now(), Edu entra'
);
reset role;
rollback to savepoint t03;

-- T04. Início em now(), com vaga.
savepoint t04;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now(), now() + interval '2 hours'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_STARTED', 'T04: início em now(), GAME_STARTED'
);
reset role;
rollback to savepoint t04;

-- T05. Início em now(), jogo cheio.
savepoint t05;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now(), now() + interval '2 hours', 1
);
update public.games set status = 'confirmed' where id = '00000000-0000-0000-0000-000000000401';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_STARTED', 'T05: início em now(), jogo cheio, espera recebe GAME_STARTED'
);
reset role;
rollback to savepoint t05;

-- =========================================================================
-- Limite de vagas (RF52, RF53, RN41, RN42, RN59)
-- =========================================================================

-- O20. Lista cheia (3), Edu na espera; Ana aumenta para 4.
savepoint o20;
select pg_temp.full_base_game();
insert into public.game_waitlist (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.o20', public.set_slot_limit('00000000-0000-0000-0000-000000000401', 4)::text, true) $$,
  'O20a: Ana aumenta o limite para 4'
);
reset role;
select results_eq(
  $$ select (pg_temp.saved('o20') ->> 'slot_limit')::integer, pg_temp.saved('o20') ->> 'status' $$,
  $$ values (4, 'open'::text) $$,
  'O20b: devolve slot_limit = 4 e status = open'
);
select results_eq(
  $$ select slot_limit, effective_from = now() from public.game_limit_history
     where game_id = '00000000-0000-0000-0000-000000000401' and slot_limit = 4 $$,
  $$ values (4, true) $$,
  'O20c: linha nova em game_limit_history, com effective_from = now()'
);
select set_eq(
  $$ select user_id, type::text, data ->> 'reason' as reason from public.notifications $$,
  $$ values
       ('00000000-0000-0000-0000-00000000000e'::uuid, 'waitlist_slot_opened'::text, 'limit_increased'::text),
       ('00000000-0000-0000-0000-00000000000b'::uuid, 'game_updated'::text, null::text),
       ('00000000-0000-0000-0000-00000000000c'::uuid, 'game_updated'::text, null::text) $$,
  'O20d: notifica Edu (waitlist_slot_opened, limit_increased) e Bruno e Carla (game_updated), e não Ana'
);
select is(
  (select count(*) from public.notifications
   where type = 'waitlist_slot_opened'
     and data ->> 'game_id' = '00000000-0000-0000-0000-000000000401'
     and data ->> 'location_name' = 'Quadra do Sesc'
     and data ->> 'group_name' = 'Vôlei de Quinta'
     and (data ->> 'starts_at')::timestamptz = now() + interval '26 hours'),
  1::bigint,
  'O20e: o aviso da espera leva os dados do jogo'
);
rollback to savepoint o20;

-- O21. 3 na lista, limite 4: reduz para 3, depois 2, depois 0.
savepoint o21;
select pg_temp.base_game();
update public.games set slot_limit = 4 where id = '00000000-0000-0000-0000-000000000401';
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000c');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.o21', public.set_slot_limit('00000000-0000-0000-0000-000000000401', 3)::text, true) $$,
  'O21a: Ana reduz para 3'
);
reset role;
select is(pg_temp.saved('o21') ->> 'status', 'confirmed', 'O21b: status = confirmed');
select set_eq(
  $$ select user_id, type::text from public.notifications $$,
  $$ values
       ('00000000-0000-0000-0000-00000000000b'::uuid, 'game_updated'::text),
       ('00000000-0000-0000-0000-00000000000b'::uuid, 'game_confirmed'::text),
       ('00000000-0000-0000-0000-00000000000c'::uuid, 'game_updated'::text),
       ('00000000-0000-0000-0000-00000000000c'::uuid, 'game_confirmed'::text) $$,
  'O21c: notifica Bruno e Carla (game_updated e game_confirmed)'
);
set local role authenticated;
select throws_ok(
  $$ select public.set_slot_limit('00000000-0000-0000-0000-000000000401', 2) $$,
  'P0001', 'SLOT_LIMIT_BELOW_PARTICIPANTS', 'O21d: limite 2, abaixo da lista'
);
select throws_ok(
  $$ select public.set_slot_limit('00000000-0000-0000-0000-000000000401', 0) $$,
  'P0001', 'INVALID_INPUT', 'O21e: limite 0'
);
reset role;
rollback to savepoint o21;

-- O22. O mesmo limite: aceito, sem histórico novo e sem notificação.
savepoint o22;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.set_slot_limit('00000000-0000-0000-0000-000000000401', 3) $$,
  'O22a: Ana grava o limite 3, que o jogo já tem'
);
reset role;
select is(
  (select count(*) from public.game_limit_history where game_id = '00000000-0000-0000-0000-000000000401'),
  1::bigint, 'O22b: sem linha nova no histórico'
);
select is_empty($$ select 1 from public.notifications $$, 'O22c: sem notificação');
rollback to savepoint o22;

-- O23. Jogo iniciado; jogo cancelado; Bruno, não admin.
savepoint o23;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now(), now() + interval '2 hours'
);
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours'
);
update public.games
set status = 'cancelled', cancelled_at = now(), cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000402';
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000403',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.set_slot_limit('00000000-0000-0000-0000-000000000401', 5) $$,
  'P0001', 'GAME_STARTED', 'O23a: jogo iniciado (RN34)'
);
select throws_ok(
  $$ select public.set_slot_limit('00000000-0000-0000-0000-000000000402', 5) $$,
  'P0001', 'GAME_NOT_OPEN', 'O23b: jogo cancelado'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.set_slot_limit('00000000-0000-0000-0000-000000000403', 5) $$,
  'P0001', 'NOT_GAME_ADMIN', 'O23c: Bruno, membro e não admin'
);
reset role;
rollback to savepoint o23;

-- Sem finish(): o rollback para cada savepoint apaga a tabela de resultados do
-- pgTAP (a numeração segue certa, porque vem de uma sequência). O pg_prove
-- confere o plano pelas linhas ok e not ok.
rollback;
