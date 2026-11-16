-- RLS e visibilidade dos jogos (fatia 4, etapa A).
-- Cenários W01 a W11 e W13 a W15 de docs/testes-referencia.md, seção 12.4. O W12
-- (telefone oculto) entra na etapa C.
-- Documentos: docs/rls-matriz.md (fatia 4) e docs/contratos-api.md (seção 4,
-- get_profile_contact e get_game_groups).
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

-- Quantas linhas a pessoa logada lê numa consulta (o RLS filtra).
create function pg_temp.count_as(p_user uuid, p_sql text)
returns bigint
language plpgsql
as $fn$
declare
  v_count bigint;
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  execute 'select count(*) from (' || p_sql || ') q' into v_count;
  reset role;
  return v_count;
exception when others then
  -- Sem privilégio ou sem a função: -1, para a asserção falhar sem abortar o arquivo.
  return -1;
end;
$fn$;

-- IDs que a pessoa logada lê numa consulta, em ordem (nulo se a leitura falha).
create function pg_temp.ids_as(p_user uuid, p_sql text)
returns uuid[]
language plpgsql
as $fn$
declare
  v_ids uuid[];
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  execute 'select array_agg(id order by id) from (' || p_sql || ') q' into v_ids;
  reset role;
  return v_ids;
exception when others then
  return null;
end;
$fn$;

-- Linhas de get_game_groups para quem chama, em jsonb (o erro, se falhar).
create function pg_temp.game_groups_as(p_user uuid, p_ids uuid[])
returns jsonb
language plpgsql
as $fn$
declare
  v_rows jsonb;
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  select coalesce(jsonb_agg(to_jsonb(r) order by r.game_id), '[]'::jsonb) into v_rows
  from public.get_game_groups(p_ids) r;
  reset role;
  return v_rows;
exception when others then
  return jsonb_build_object('error', sqlerrm);
end;
$fn$;

-- Contato devolvido por get_profile_contact a quem chama.
create function pg_temp.contact_as(p_caller uuid, p_owner uuid)
returns jsonb
language plpgsql
as $fn$
declare
  v_result jsonb;
begin
  perform pg_temp.login_as(p_caller);
  set local role authenticated;
  v_result := public.get_profile_contact(p_owner);
  reset role;
  return v_result;
exception when others then
  return jsonb_build_object('error', sqlerrm);
end;
$fn$;

-- Contato da Ana como o teste espera: telefone e chave, ou nulos. Nos W09 a
-- W11, quem chama também é do Quinta, então recebe o telefone visível da Ana
-- (RN101, RN107) junto da chave ou da chave nula.
create function pg_temp.ana_contact(p_phone boolean, p_key boolean)
returns jsonb
language sql
as $fn$
  select jsonb_build_object(
    'phone', case when p_phone then '+5586999998888' end,
    'pix_key_type', case when p_key then 'cpf' end,
    'pix_key', case when p_key then '12345678909' end
  );
$fn$;

-- =========================================================================
-- Leitura das tabelas de jogo (can_view_game, is_game_admin)
-- =========================================================================

-- W01. Ana e Bruno na lista; Carla membro fora; Diego sem grupo.
savepoint w01;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000a',
    $$ select 1 from public.games where id = '00000000-0000-0000-0000-000000000401' and invite_code is not null $$),
  1::bigint, 'W01a: Ana vê o jogo, com o invite_code'
);
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000b',
    $$ select 1 from public.games where id = '00000000-0000-0000-0000-000000000401' and invite_code is not null $$),
  1::bigint, 'W01b: Bruno vê o jogo, com o invite_code'
);
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000c',
    $$ select 1 from public.games where id = '00000000-0000-0000-0000-000000000401' and invite_code is not null $$),
  1::bigint, 'W01c: Carla, membro fora da lista, vê o jogo'
);
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000d', $$ select 1 from public.games $$),
  0::bigint, 'W01d: Diego não vê nenhuma linha'
);
rollback to savepoint w01;

-- W02. Bruno na lista e Edu na espera: admins, lista e espera.
savepoint w02;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
insert into public.game_waitlist (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e');
select results_eq(
  $$ select pg_temp.count_as(u, 'select 1 from public.game_admins'),
            pg_temp.count_as(u, 'select 1 from public.game_participants'),
            pg_temp.count_as(u, 'select 1 from public.game_waitlist')
     from unnest(array[
       '00000000-0000-0000-0000-00000000000a'::uuid, '00000000-0000-0000-0000-00000000000b'::uuid,
       '00000000-0000-0000-0000-00000000000c'::uuid, '00000000-0000-0000-0000-00000000000d'::uuid
     ]) with ordinality as t (u, n) order by n $$,
  $$ values (1::bigint, 2::bigint, 1::bigint), (1, 2, 1), (1, 2, 1), (0, 0, 0) $$,
  'W02: Ana, Bruno e Carla veem todas as linhas de game_admins, game_participants e game_waitlist; Diego, nenhuma'
);
rollback to savepoint w02;

-- W03. Avulso do Bruno, com uma linha antiga do Diego na espera.
savepoint w03;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours',
  4, null, '00000000-0000-0000-0000-00000000000b'
);
insert into public.game_waitlist (game_id, user_id, joined_at, left_at)
values (
  '00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-00000000000d',
  now() - interval '2 hours', now() - interval '1 hour'
);
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000a',
    $$ select 1 from public.games where id = '00000000-0000-0000-0000-000000000402' $$),
  0::bigint, 'W03a: Ana não vê o avulso do Bruno'
);
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000d',
    $$ select 1 from public.games where id = '00000000-0000-0000-0000-000000000402' $$),
  1::bigint, 'W03b: Diego vê: passar pela espera conta'
);
rollback to savepoint w03;

-- Dados do W04: Edu saiu do Quinta com uma passagem removed no jogo base; outro
-- jogo do Quinta sem passagem dele.
create function pg_temp.w04_data()
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.base_game();
  perform pg_temp.make_game(
    '00000000-0000-0000-0000-000000000402',
    now() + interval '2 days', now() + interval '50 hours', now() + interval '52 hours'
  );
  insert into public.game_participants (game_id, user_id, joined_at, status, left_at, removal_reason)
  values (
    '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e',
    now() - interval '1 day', 'removed', now() - interval '1 hour', 'left_group'
  );
  delete from public.group_members
  where group_id = '00000000-0000-0000-0000-000000000301'
    and user_id = '00000000-0000-0000-0000-00000000000e';
end;
$fn$;

-- W04. O ex-membro vê só o jogo em que teve passagem.
savepoint w04;
select pg_temp.w04_data();
select is(
  pg_temp.ids_as('00000000-0000-0000-0000-00000000000e', $$ select id from public.games $$),
  array['00000000-0000-0000-0000-000000000401'::uuid],
  'W04: Edu vê só o jogo base'
);
rollback to savepoint w04;

-- W05. Histórico de limite: só os admins do jogo.
savepoint w05;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000a', $$ select 1 from public.game_limit_history $$),
  1::bigint, 'W05a: Ana, admin, vê a linha do histórico'
);
select is(
  pg_temp.count_as('00000000-0000-0000-0000-00000000000b', $$ select 1 from public.game_limit_history $$),
  0::bigint, 'W05b: Bruno, na lista e não admin, não vê nenhuma'
);
rollback to savepoint w05;

-- W06. Ninguém escreve direto nas cinco tabelas.
savepoint w06;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok($$ insert into public.games (location_name) values ('x') $$, '42501', null, 'W06a: insert em games');
select throws_ok($$ update public.games set location_name = 'x' $$, '42501', null, 'W06b: update em games');
select throws_ok($$ delete from public.games $$, '42501', null, 'W06c: delete em games');
select throws_ok(
  $$ insert into public.game_admins (game_id, user_id)
     values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  '42501', null, 'W06d: insert em game_admins'
);
select throws_ok($$ update public.game_admins set added_by = null $$, '42501', null, 'W06e: update em game_admins');
select throws_ok($$ delete from public.game_admins $$, '42501', null, 'W06f: delete em game_admins');
select throws_ok(
  $$ insert into public.game_participants (game_id, user_id)
     values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  '42501', null, 'W06g: insert em game_participants'
);
select throws_ok($$ update public.game_participants set absent = false $$, '42501', null, 'W06h: update em game_participants');
select throws_ok($$ delete from public.game_participants $$, '42501', null, 'W06i: delete em game_participants');
select throws_ok(
  $$ insert into public.game_waitlist (game_id, user_id)
     values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  '42501', null, 'W06j: insert em game_waitlist'
);
select throws_ok($$ update public.game_waitlist set left_at = now() $$, '42501', null, 'W06k: update em game_waitlist');
select throws_ok($$ delete from public.game_waitlist $$, '42501', null, 'W06l: delete em game_waitlist');
select throws_ok(
  $$ insert into public.game_limit_history (game_id, slot_limit)
     values ('00000000-0000-0000-0000-000000000401', 9) $$,
  '42501', null, 'W06m: insert em game_limit_history'
);
select throws_ok($$ update public.game_limit_history set slot_limit = 9 $$, '42501', null, 'W06n: update em game_limit_history');
select throws_ok($$ delete from public.game_limit_history $$, '42501', null, 'W06o: delete em game_limit_history');
reset role;
rollback to savepoint w06;

-- W07. anon não lê nada.
savepoint w07;
set local role anon;
select throws_ok($$ select 1 from public.games $$, '42501', null, 'W07a: anon em games');
select throws_ok($$ select 1 from public.game_admins $$, '42501', null, 'W07b: anon em game_admins');
select throws_ok($$ select 1 from public.game_participants $$, '42501', null, 'W07c: anon em game_participants');
select throws_ok($$ select 1 from public.game_waitlist $$, '42501', null, 'W07d: anon em game_waitlist');
select throws_ok($$ select 1 from public.game_limit_history $$, '42501', null, 'W07e: anon em game_limit_history');
reset role;
rollback to savepoint w07;

-- =========================================================================
-- Chave Pix e telefone (get_profile_contact; RN101, RN102, RN107)
-- =========================================================================

-- W08. Ana recebedora; Bruno na lista, Carla na espera, Edu cancelou, Diego fora.
savepoint w08;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
insert into public.game_waitlist (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000c');
insert into public.game_participants (game_id, user_id, joined_at, status, left_at, late_cancellation)
values (
  '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e',
  now() - interval '2 hours', 'cancelled', now() - interval '1 hour', false
);
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, true), 'W08a: Bruno, na lista, recebe o telefone e a chave'
);
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, false), 'W08b: Carla, na espera, recebe o telefone e a chave nula (RN102)'
);
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, false), 'W08c: Edu, que cancelou, recebe o telefone e a chave nula'
);
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(false, false), 'W08d: Diego recebe tudo nulo'
);
rollback to savepoint w08;

-- W09. Jogo iniciado, com Bruno left_after_start.
savepoint w09;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now() - interval '30 minutes', now() + interval '90 minutes'
);
insert into public.game_participants (
  game_id, user_id, joined_at, status, left_at, absent, absence_source
)
values (
  '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b',
  now() - interval '1 day', 'left_after_start', now() - interval '10 minutes', true, 'left_after_start'
);
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, true), 'W09: Bruno, que saiu depois do início, recebe a chave'
);
rollback to savepoint w09;

-- W10. Jogo cancelado, com Bruno ainda active.
savepoint w10;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
update public.games
set status = 'cancelled', cancelled_at = now(), cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000401';
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, false), 'W10: jogo cancelado, chave nula (RN102)'
);
rollback to savepoint w10;

-- W11. Jogo concluído; Edu cancelou e tem um valor pending devido à Ana; depois paid.
savepoint w11;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '2 days', now() - interval '2 days', now() - interval '2 days' + interval '2 hours'
);
update public.games
set status = 'completed', completed_at = now() - interval '1 day', share_cents = 3000,
    completion_mode = 'manual', completed_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000401';
insert into public.game_participants (
  id, game_id, user_id, joined_at, status, left_at, late_cancellation
)
values (
  '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-00000000000e', now() - interval '3 days', 'cancelled',
  now() - interval '2 days' - interval '1 hour', true
);
insert into public.charges (id, game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
values (
  '00000000-0000-0000-0000-000000000421', '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000411', '00000000-0000-0000-0000-00000000000e',
  '00000000-0000-0000-0000-00000000000a', 'late_cancellation_penalty', 3000
);
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, true), 'W11a: Edu, com o valor pending, recebe a chave'
);
update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
where id = '00000000-0000-0000-0000-000000000421';
select is(
  pg_temp.contact_as('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a'),
  pg_temp.ana_contact(true, false), 'W11b: depois de pago, chave nula'
);
rollback to savepoint w11;

-- =========================================================================
-- Nome do grupo nos jogos (get_game_groups) e Realtime
-- =========================================================================

-- W13. Dados do W04, mais o avulso do Bruno.
savepoint w13;
select pg_temp.w04_data();
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000403',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours',
  4, null, '00000000-0000-0000-0000-00000000000b'
);
select is(
  pg_temp.game_groups_as('00000000-0000-0000-0000-00000000000e', array[
    '00000000-0000-0000-0000-000000000401'::uuid, '00000000-0000-0000-0000-000000000402'::uuid,
    '00000000-0000-0000-0000-000000000403'::uuid, '4c1d7e9a-0000-4000-8000-000000000000'::uuid
  ]),
  jsonb_build_array(jsonb_build_object(
    'game_id', '00000000-0000-0000-0000-000000000401',
    'group_id', '00000000-0000-0000-0000-000000000301',
    'group_name', 'Vôlei de Quinta'
  )),
  'W13: Edu recebe uma linha só, a do jogo base, com o grupo e o nome do Quinta'
);

-- W14. Depois do W13: jogo base cancelado e Quinta arquivado.
update public.games
set status = 'cancelled', cancelled_at = now(), cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id in ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000402');
update public.groups
set archived_at = now(), archived_by = '00000000-0000-0000-0000-00000000000a', invite_code = null
where id = '00000000-0000-0000-0000-000000000301';
delete from public.group_members where group_id = '00000000-0000-0000-0000-000000000301';
select is(
  pg_temp.game_groups_as(
    '00000000-0000-0000-0000-00000000000e', array['00000000-0000-0000-0000-000000000401'::uuid]
  ) -> 0 ->> 'group_name',
  'Vôlei de Quinta',
  'W14: com o grupo arquivado, Edu continua recebendo o nome do Quinta (RN17)'
);
rollback to savepoint w13;

-- W15. Publicação do Realtime.
select set_eq(
  $$ select tablename::text from pg_publication_tables
     where pubname = 'supabase_realtime' $$,
  array['games', 'game_participants', 'game_waitlist'],
  'W15: a publicação supabase_realtime tem exatamente games, game_participants e game_waitlist'
);

-- Sem finish(): o rollback para cada savepoint apaga a tabela de resultados do
-- pgTAP (a numeração segue certa, porque vem de uma sequência). O pg_prove
-- confere o plano pelas linhas ok e not ok.
rollback;
