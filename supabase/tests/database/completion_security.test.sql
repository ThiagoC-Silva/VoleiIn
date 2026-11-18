-- RLS da conclusão (fatia 5, etapa A). Cenários Y01 a Y03 e Y05 a Y07 de
-- docs/testes-referencia.md, seção 13.4 (RN76, RN32). Y04 (troca de recebedor)
-- é da etapa C. Políticas: docs/rls-matriz.md, fatia 5.
--
-- Base da seção 13.4, inserida direto, como postgres.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(29);

-- Personagens (docs/setup.md, seção 8), mais o Edu e o Fábio, que só existem
-- nos testes, e dez pessoas para completar as listas (P01 a P10).
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
  union all
  select ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid,
         'p' || lpad(i::text, 2, '0') || '@voleiin.test', 'P' || lpad(i::text, 2, '0')
  from generate_series(1, 10) i
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

update public.profile_private
set pix_key_type = 'cpf', pix_key = '12345678909'
where user_id = '00000000-0000-0000-0000-00000000000a';

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
]::uuid[] || array(
  select ('00000000-0000-0000-0000-0000000005' || lpad(i::text, 2, '0'))::uuid
  from generate_series(1, 10) i
)) u;
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

-- P01 a P10.
create function pg_temp.p(p_n integer)
returns uuid
language sql
as $fn$
  select ('00000000-0000-0000-0000-0000000005' || lpad(p_n::text, 2, '0'))::uuid;
$fn$;

-- Jogo depois do fim (seção 13): prazo 4 h antes do fim, início 2 h antes, e o
-- fim em p_ends. Ana admin, recebedora e primeira da lista. O histórico de
-- limite nasce pela trigger, depois do prazo (research R3 de
-- specs/006-conclusao-etapa-a).
create function pg_temp.ended_game(
  p_id uuid,
  p_total integer,
  p_limit integer,
  p_ends timestamptz default now() - interval '10 minutes'
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
    p_id, '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a',
    'Quadra do Sesc', p_ends - interval '4 hours', p_ends - interval '2 hours', p_ends,
    p_total, p_limit, '00000000-0000-0000-0000-00000000000a',
    'Jogo' || right(replace(p_id::text, '-', ''), 8)
  );
  insert into public.game_admins (game_id, user_id)
  values (p_id, '00000000-0000-0000-0000-00000000000a');
  insert into public.game_participants (game_id, user_id, joined_at)
  values (p_id, '00000000-0000-0000-0000-00000000000a', p_ends - interval '1 day');
end;
$fn$;

-- Passagem ativa, com o status do jogo acompanhando as vagas.
create function pg_temp.join(p_game uuid, p_user uuid)
returns void
language plpgsql
as $fn$
begin
  insert into public.game_participants (game_id, user_id, joined_at)
  values (p_game, p_user, now() - interval '20 hours');
  update public.games g
  set status = case
    when (select count(*) from public.game_participants p
          where p.game_id = g.id and p.status in ('active', 'left_after_start')) >= g.slot_limit
    then 'confirmed'::public.game_status else 'open'::public.game_status end
  where g.id = p_game;
end;
$fn$;

-- Completa a lista até p_count passagens, na ordem Bruno, Carla, Edu, P01 a P10.
create function pg_temp.fill(p_game uuid, p_count integer)
returns void
language plpgsql
as $fn$
declare
  v_people uuid[] := array[
    '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c',
    '00000000-0000-0000-0000-00000000000e'
  ]::uuid[] || array(select pg_temp.p(i) from generate_series(1, 10) i);
  v_have integer;
  v_user uuid;
begin
  select count(*) into v_have from public.game_participants
  where game_id = p_game and status in ('active', 'left_after_start');
  foreach v_user in array v_people loop
    exit when v_have >= p_count;
    if not exists (select 1 from public.game_participants where game_id = p_game and user_id = v_user) then
      perform pg_temp.join(p_game, v_user);
      v_have := v_have + 1;
    end if;
  end loop;
end;
$fn$;

-- Cancelamento fora do prazo, p_minutes depois do prazo.
create function pg_temp.late_cancel(p_game uuid, p_user uuid, p_minutes integer)
returns void
language sql
as $fn$
  insert into public.game_participants (game_id, user_id, joined_at, status, left_at, late_cancellation)
  select p_game, p_user, g.cancellation_deadline - interval '1 day', 'cancelled',
         g.cancellation_deadline + make_interval(mins => p_minutes), true
  from public.games g where g.id = p_game;
$fn$;

-- Saída após o início, p_minutes depois do início, com a falta (RN57).
create function pg_temp.left_after_start(p_game uuid, p_user uuid, p_minutes integer)
returns void
language sql
as $fn$
  update public.game_participants p
  set status = 'left_after_start', left_at = g.starts_at + make_interval(mins => p_minutes),
      absent = true, absence_source = 'left_after_start'
  from public.games g
  where g.id = p.game_id and p.game_id = p_game and p.user_id = p_user and p.status = 'active';
$fn$;

-- Ana conclui (ou pede o preview) e guarda o retorno em t.<p_name>.
create function pg_temp.ana_calls(
  p_fn text, p_name text, p_game uuid, p_total integer default null, p_absent uuid[] default '{}'
)
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
  set local role authenticated;
  execute format(
    'select set_config(%L, public.%I(%L, %L, %L)::text, true)',
    't.' || p_name, p_fn, p_game, p_total, p_absent
  );
  reset role;
end;
$fn$;

-- Base (seção 13.4): jogo concluído, inserido direto. Ana recebedora e admin;
-- Edu admin, na lista, com share Pendente; Bruno com share Pendente; Carla com
-- absence_penalty Pendente; Fábio com passagem cancelled no prazo, sem valor;
-- Diego fora do jogo. Um charge_events por valor e uma troca de recebedor.
select pg_temp.ended_game('00000000-0000-0000-0000-000000000801', 9000, 10);
select pg_temp.join('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-00000000000e');
select pg_temp.join('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-00000000000b');
select pg_temp.join('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-00000000000c');
insert into public.game_participants (game_id, user_id, joined_at, status, left_at, late_cancellation)
select id, '00000000-0000-0000-0000-00000000000f', now() - interval '1 day', 'cancelled',
       cancellation_deadline - interval '1 hour', false
from public.games where id = '00000000-0000-0000-0000-000000000801';
update public.game_participants set absent = true, absence_source = 'marked_by_admin'
where game_id = '00000000-0000-0000-0000-000000000801'
  and user_id = '00000000-0000-0000-0000-00000000000c';
insert into public.game_admins (game_id, user_id, added_by)
values (
  '00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-00000000000e',
  '00000000-0000-0000-0000-00000000000a'
);
update public.games
set status = 'completed', share_cents = 900, completed_at = now(), completion_mode = 'manual',
    completed_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000801';
insert into public.charges (id, game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
select v.id, p.game_id, p.id, p.user_id, '00000000-0000-0000-0000-00000000000a', v.kind, 900
from (
  values
    ('00000000-0000-0000-0000-000000000901'::uuid, '00000000-0000-0000-0000-00000000000e'::uuid,
     'share'::public.charge_kind),
    ('00000000-0000-0000-0000-000000000902', '00000000-0000-0000-0000-00000000000b', 'share'),
    ('00000000-0000-0000-0000-000000000903', '00000000-0000-0000-0000-00000000000c', 'absence_penalty')
) v (id, payer, kind)
join public.game_participants p
  on p.game_id = '00000000-0000-0000-0000-000000000801' and p.user_id = v.payer;
insert into public.charge_events (charge_id, from_status, to_status, actor_id)
select id, null, 'pending', '00000000-0000-0000-0000-00000000000a' from public.charges;
insert into public.receiver_changes (game_id, old_receiver_id, new_receiver_id, changed_by, after_completion)
values (
  '00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-00000000000b',
  '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', false
);

-- O que a pessoa lê, como lista ordenada de payer_id.
create function pg_temp.visible(p_user uuid, p_query text)
returns uuid[]
language plpgsql
as $fn$
declare
  v_result uuid[];
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  execute p_query into v_result;
  reset role;
  return coalesce(v_result, '{}');
end;
$fn$;

-- Y01. Leitura de charges.
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000a',
    'select array_agg(payer_id order by payer_id) from public.charges'),
  array['00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c',
        '00000000-0000-0000-0000-00000000000e']::uuid[],
  'Y01a: Ana, recebedora, vê os três valores'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000e',
    'select array_agg(payer_id order by payer_id) from public.charges'),
  array['00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c',
        '00000000-0000-0000-0000-00000000000e']::uuid[],
  'Y01b: Edu, admin do jogo, vê os três valores'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000b',
    'select array_agg(payer_id order by payer_id) from public.charges'),
  array['00000000-0000-0000-0000-00000000000b']::uuid[],
  'Y01c: Bruno vê só o próprio'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000c',
    'select array_agg(payer_id order by payer_id) from public.charges'),
  array['00000000-0000-0000-0000-00000000000c']::uuid[],
  'Y01d: Carla vê só o próprio'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000f',
    'select array_agg(payer_id order by payer_id) from public.charges'),
  '{}'::uuid[],
  'Y01e: Fábio não vê nenhum'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000d',
    'select array_agg(payer_id order by payer_id) from public.charges'),
  '{}'::uuid[],
  'Y01f: Diego não vê nenhum'
);

-- Y02. Leitura de charge_events: o mesmo recorte.
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000a',
    'select array_agg(c.payer_id order by c.payer_id) from public.charge_events e
     join public.charges c on c.id = e.charge_id'),
  array['00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000c',
        '00000000-0000-0000-0000-00000000000e']::uuid[],
  'Y02a: Ana vê os eventos dos três valores'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000e',
    'select array_agg(charge_id order by charge_id) from public.charge_events'),
  array['00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000902',
        '00000000-0000-0000-0000-000000000903']::uuid[],
  'Y02b: Edu vê os eventos dos três valores'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000b',
    'select array_agg(charge_id order by charge_id) from public.charge_events'),
  array['00000000-0000-0000-0000-000000000902']::uuid[],
  'Y02c: Bruno vê só os eventos do próprio valor'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000c',
    'select array_agg(charge_id order by charge_id) from public.charge_events'),
  array['00000000-0000-0000-0000-000000000903']::uuid[],
  'Y02d: Carla vê só os eventos do próprio valor'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000f',
    'select array_agg(charge_id order by charge_id) from public.charge_events'),
  '{}'::uuid[],
  'Y02e: Fábio não vê nenhum evento'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000d',
    'select array_agg(charge_id order by charge_id) from public.charge_events'),
  '{}'::uuid[],
  'Y02f: Diego não vê nenhum evento'
);

-- Y03. Leitura de receiver_changes.
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000a',
    'select array_agg(game_id) from public.receiver_changes'),
  array['00000000-0000-0000-0000-000000000801']::uuid[],
  'Y03a: Ana, admin, vê a troca'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000e',
    'select array_agg(game_id) from public.receiver_changes'),
  array['00000000-0000-0000-0000-000000000801']::uuid[],
  'Y03b: Edu, admin, vê a troca'
);
select is(
  pg_temp.visible('00000000-0000-0000-0000-00000000000b',
    'select array_agg(game_id) from public.receiver_changes'),
  '{}'::uuid[],
  'Y03c: Bruno não vê nenhuma'
);

-- Y05. Escrita direta e audit_log.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ insert into public.charges (game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
     select game_id, participant_id, payer_id, receiver_id, kind, 1 from public.charges limit 1 $$,
  '42501', null, 'Y05a: insert em charges'
);
select throws_ok(
  $$ update public.charges set amount_cents = 1 $$, '42501', null, 'Y05b: update em charges'
);
select throws_ok($$ delete from public.charges $$, '42501', null, 'Y05c: delete em charges');
select throws_ok(
  $$ insert into public.charge_events (charge_id, to_status)
     values ('00000000-0000-0000-0000-000000000902', 'paid') $$,
  '42501', null, 'Y05d: insert em charge_events'
);
select throws_ok(
  $$ update public.charge_events set note = 'x' $$, '42501', null, 'Y05e: update em charge_events'
);
select throws_ok($$ delete from public.charge_events $$, '42501', null, 'Y05f: delete em charge_events');
select throws_ok(
  $$ insert into public.receiver_changes (game_id, old_receiver_id, new_receiver_id, changed_by, after_completion)
     values ('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-00000000000a',
             '00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-00000000000a', true) $$,
  '42501', null, 'Y05g: insert em receiver_changes'
);
select throws_ok(
  $$ update public.receiver_changes set after_completion = true $$,
  '42501', null, 'Y05h: update em receiver_changes'
);
select throws_ok(
  $$ delete from public.receiver_changes $$, '42501', null, 'Y05i: delete em receiver_changes'
);
select throws_ok($$ select 1 from public.audit_log $$, '42501', null, 'Y05j: select em audit_log');

-- Y07. A conclusão automática é interna.
select throws_ok(
  $$ select public.auto_complete_due_games() $$, '42501', null, 'Y07: Ana chama auto_complete_due_games'
);
reset role;

-- Y06. anon não lê nada.
set local role anon;
select throws_ok($$ select 1 from public.charges $$, '42501', null, 'Y06a: anon em charges');
select throws_ok($$ select 1 from public.charge_events $$, '42501', null, 'Y06b: anon em charge_events');
select throws_ok(
  $$ select 1 from public.receiver_changes $$, '42501', null, 'Y06c: anon em receiver_changes'
);
reset role;

select * from finish();
rollback;
