-- Conclusão manual e automática (fatia 5, etapa A).
-- Cenários T11 a T15 (seção 3), F03 e F04 (seção 6) e Z01 a Z07 (seção 13.1) de
-- docs/testes-referencia.md. Contratos: docs/contratos-api.md, seções 5 e 7.
--
-- Base da seção 13, inserida aqui sem depender do seed: o Quinta, com Ana admin
-- e os outros membros; Diego sem grupo. Os jogos e as linhas de grupo do seed
-- são apagados dentro desta transação, e o rollback do fim devolve tudo. Cada
-- cenário roda entre um savepoint e o rollback para ele.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(40);

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

-- Retrato das tabelas que a conclusão grava, para conferir que nada mudou.
create function pg_temp.snapshot()
returns text
language sql
as $fn$
  select md5(concat_ws('|',
    (select string_agg(t::text, ',' order by t.id) from public.games t),
    (select string_agg(t::text, ',' order by t.id) from public.game_participants t),
    (select string_agg(t::text, ',' order by t.id) from public.charges t),
    (select string_agg(t::text, ',' order by t.id) from public.charge_events t),
    (select string_agg(t::text, ',' order by t.id) from public.notifications t),
    (select string_agg(t::text, ',' order by t.id) from public.audit_log t)
  ));
$fn$;

-- =========================================================================
-- Limites de tempo (seção 3)
-- =========================================================================

-- T11. Fim 1 µs depois de now().
savepoint t11;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000601', 10000, 10, now() + interval '1 microsecond');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000601') $$,
  'P0001', 'GAME_NOT_ENDED', 'T11: GAME_NOT_ENDED antes do fim'
);
reset role;
rollback to savepoint t11;

-- T12. Fim = now().
savepoint t12;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000602', 10000, 10, now());
select pg_temp.ana_calls('complete_game', 't12', '00000000-0000-0000-0000-000000000602');
select results_eq(
  $$ select status::text, completion_mode::text from public.games
     where id = '00000000-0000-0000-0000-000000000602' $$,
  $$ values ('completed', 'manual') $$,
  'T12: conclui no fim, completion_mode = manual'
);
rollback to savepoint t12;

-- T13. Fim + 1 h, 1 µs depois de now().
savepoint t13;
select pg_temp.ended_game(
  '00000000-0000-0000-0000-000000000603', 10000, 10, now() - interval '1 hour' + interval '1 microsecond'
);
select public.auto_complete_due_games();
select is(
  (select status::text from public.games where id = '00000000-0000-0000-0000-000000000603'), 'open',
  'T13: a automática não mexe no jogo antes de fim + 1 h'
);
rollback to savepoint t13;

-- T14. Fim + 1 h = now().
savepoint t14;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000604', 10000, 10, now() - interval '1 hour');
select pg_temp.fill('00000000-0000-0000-0000-000000000604', 4);
select public.auto_complete_due_games();
select results_eq(
  $$ select status::text, completion_mode::text, completed_by from public.games
     where id = '00000000-0000-0000-0000-000000000604' $$,
  $$ values ('completed', 'automatic', null::uuid) $$,
  'T14: conclui em fim + 1 h, completion_mode = automatic, sem autor'
);
rollback to savepoint t14;

-- T15. Já concluído manualmente.
savepoint t15;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000605', 10000, 10, now() - interval '2 hours');
select pg_temp.fill('00000000-0000-0000-0000-000000000605', 4);
select pg_temp.ana_calls('complete_game', 't15', '00000000-0000-0000-0000-000000000605');
select public.auto_complete_due_games();
select results_eq(
  $$ select count(*)::integer, min(g.completion_mode::text)
     from public.charges c join public.games g on g.id = c.game_id
     where c.game_id = '00000000-0000-0000-0000-000000000605' $$,
  $$ values (3, 'manual') $$,
  'T15: a automática não cria valor novo nem muda a conclusão manual'
);
rollback to savepoint t15;

-- =========================================================================
-- Faltas na conclusão automática (seção 6)
-- =========================================================================

-- F03. Edu sai às 20h30 (30 min depois do início); conclusão automática.
savepoint f03;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000606', 10000, 10, now() - interval '1 hour');
select pg_temp.fill('00000000-0000-0000-0000-000000000606', 10);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000606', '00000000-0000-0000-0000-00000000000e', 30);
select public.auto_complete_due_games();
select results_eq(
  $$ select kind::text, amount_cents from public.charges
     where game_id = '00000000-0000-0000-0000-000000000606'
       and payer_id = '00000000-0000-0000-0000-00000000000e' $$,
  $$ values ('absence_penalty', 1000) $$,
  'F03: Edu mantém a falta, com absence_penalty de 1.000 (RN49)'
);
rollback to savepoint f03;

-- F04. Ninguém saiu; conclusão automática.
savepoint f04;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000607', 10000, 10, now() - interval '1 hour');
select pg_temp.fill('00000000-0000-0000-0000-000000000607', 10);
select public.auto_complete_due_games();
select results_eq(
  $$ select count(*)::integer, min(kind::text), max(kind::text),
            (select total_cents from public.games where id = '00000000-0000-0000-0000-000000000607'),
            (select count(*)::integer from public.game_participants
             where game_id = '00000000-0000-0000-0000-000000000607' and absent)
     from public.charges where game_id = '00000000-0000-0000-0000-000000000607' $$,
  $$ values (9, 'share', 'share', 10000, 0) $$,
  'F04: 9 valores share, ninguém com falta, total sem mudança'
);
rollback to savepoint f04;

-- =========================================================================
-- Conclusão (seção 13.1)
-- =========================================================================

-- Z01. Jogo base do R01: 10 na lista; Carla e P09 com multa de cancelamento mantida.
savepoint z01;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000611', 25000, 12);
select pg_temp.join('00000000-0000-0000-0000-000000000611', '00000000-0000-0000-0000-00000000000b');
select pg_temp.join('00000000-0000-0000-0000-000000000611', '00000000-0000-0000-0000-00000000000e');
select pg_temp.join('00000000-0000-0000-0000-000000000611', pg_temp.p(i)) from generate_series(1, 7) i;
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000611', '00000000-0000-0000-0000-00000000000c', 20);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000611', pg_temp.p(9), 40);
select pg_temp.ana_calls('complete_game', 'z01', '00000000-0000-0000-0000-000000000611');
select results_eq(
  $$ select status::text, share_cents, completed_at, completion_mode::text, completed_by
     from public.games where id = '00000000-0000-0000-0000-000000000611' $$,
  $$ values ('completed', 2084, now(), 'manual', '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'Z01a: completed, share_cents 2.084, completed_at = now(), manual, por Ana'
);
select results_eq(
  $$ select count(*)::integer, count(*) filter (where status = 'pending')::integer,
            count(*) filter (where receiver_id = '00000000-0000-0000-0000-00000000000a')::integer
     from public.charges where game_id = '00000000-0000-0000-0000-000000000611' $$,
  $$ values (11, 11, 11) $$,
  'Z01b: 11 valores Pendentes, todos devidos a Ana'
);
select results_eq(
  $$ select count(*)::integer, count(distinct e.charge_id)::integer,
            count(*) filter (where e.from_status is null and e.to_status = 'pending'
                             and e.actor_id = '00000000-0000-0000-0000-00000000000a')::integer
     from public.charge_events e join public.charges c on c.id = e.charge_id
     where c.game_id = '00000000-0000-0000-0000-000000000611' $$,
  $$ values (11, 11, 11) $$,
  'Z01c: um charge_events por valor, de nulo para pending, com actor_id = Ana'
);
select results_eq(
  $$ select event, actor_id, entity_type from public.audit_log
     where entity_id = '00000000-0000-0000-0000-000000000611' $$,
  $$ values ('game_completed'::text, '00000000-0000-0000-0000-00000000000a'::uuid, 'game'::text) $$,
  'Z01d: uma linha game_completed em audit_log'
);
select set_eq(
  $$ select user_id from public.notifications where type = 'game_completed' $$,
  array[
    '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000e',
    '00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000502',
    '00000000-0000-0000-0000-000000000503', '00000000-0000-0000-0000-000000000504',
    '00000000-0000-0000-0000-000000000505', '00000000-0000-0000-0000-000000000506',
    '00000000-0000-0000-0000-000000000507'
  ]::uuid[],
  'Z01e: game_completed às passagens que ocupam vaga, exceto Ana'
);
select is(
  (select count(*)::integer from public.notifications where type = 'game_completed'), 9,
  'Z01f: um game_completed por pessoa'
);
select set_eq(
  $$ select n.user_id, n.data from public.notifications n where n.type = 'charge_created' $$,
  $$ select c.payer_id, jsonb_build_object(
       'game_id', c.game_id, 'group_name', 'Vôlei de Quinta', 'location_name', 'Quadra do Sesc',
       'starts_at', g.starts_at, 'charge_id', c.id, 'kind', c.kind, 'amount_cents', c.amount_cents)
     from public.charges c join public.games g on g.id = c.game_id
     where c.game_id = '00000000-0000-0000-0000-000000000611' $$,
  'Z01g: charge_created a cada pagador, com o data da seção 5 do contrato'
);
select is(
  (select data from public.notifications
   where type = 'game_completed' and user_id = '00000000-0000-0000-0000-00000000000b'),
  (select jsonb_build_object(
     'game_id', id, 'group_name', 'Vôlei de Quinta', 'location_name', 'Quadra do Sesc',
     'starts_at', starts_at, 'completion_mode', 'manual')
   from public.games where id = '00000000-0000-0000-0000-000000000611'),
  'Z01h: data de game_completed como na seção 5 do contrato'
);
rollback to savepoint z01;

-- Z02. Jogo base do R06 (6 na lista).
savepoint z02;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000612', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000612', 6);
select pg_temp.ana_calls('complete_game', 'z02', '00000000-0000-0000-0000-000000000612');
select is(
  pg_temp.saved('z02'),
  jsonb_build_object(
    'game_id', '00000000-0000-0000-0000-000000000612', 'share_cents', 2084,
    'total_to_receive_cents', 10420, 'receiver_covered_cents', 14580, 'uncovered_slots', 6,
    'penalties_exempted', 0, 'charges_created', 5
  ),
  'Z02: o retorno de complete_game'
);
rollback to savepoint z02;

-- Z03. Preview igual à conclusão, sem gravar, nos jogos base do R01, R04, R06 e R07.
savepoint z03;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000613', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000613', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000613', pg_temp.p(9), 20);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000613', pg_temp.p(10), 40);
select pg_temp.ended_game('00000000-0000-0000-0000-000000000614', 1, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000614', 10);
select pg_temp.ended_game('00000000-0000-0000-0000-000000000615', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000615', 6);
select pg_temp.ended_game('00000000-0000-0000-0000-000000000616', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000616', 12);
select set_config('t.z03_before', to_jsonb(pg_temp.snapshot())::text, true);
select pg_temp.ana_calls('preview_complete_game', 'z03p1', '00000000-0000-0000-0000-000000000613');
select pg_temp.ana_calls('preview_complete_game', 'z03p4', '00000000-0000-0000-0000-000000000614');
select pg_temp.ana_calls('preview_complete_game', 'z03p6', '00000000-0000-0000-0000-000000000615');
select pg_temp.ana_calls('preview_complete_game', 'z03p7', '00000000-0000-0000-0000-000000000616', 30000);
select is(
  to_jsonb(pg_temp.snapshot()), pg_temp.saved('z03_before'),
  'Z03a: o preview não grava nada em games, game_participants, charges, charge_events, notifications e audit_log'
);
select pg_temp.ana_calls('complete_game', 'z03c1', '00000000-0000-0000-0000-000000000613');
select pg_temp.ana_calls('complete_game', 'z03c4', '00000000-0000-0000-0000-000000000614');
select pg_temp.ana_calls('complete_game', 'z03c6', '00000000-0000-0000-0000-000000000615');
select pg_temp.ana_calls('complete_game', 'z03c7', '00000000-0000-0000-0000-000000000616', 30000);
select is(pg_temp.saved('z03p1'), pg_temp.saved('z03c1'), 'Z03b: preview do R01 igual à conclusão');
select is(pg_temp.saved('z03p4'), pg_temp.saved('z03c4'), 'Z03c: preview do R04 igual à conclusão');
select is(pg_temp.saved('z03p6'), pg_temp.saved('z03c6'), 'Z03d: preview do R06 igual à conclusão');
select is(pg_temp.saved('z03p7'), pg_temp.saved('z03c7'), 'Z03e: preview do R07 igual à conclusão');
rollback to savepoint z03;

-- Z04. Erros, sem gravar nada.
savepoint z04;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000617', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000617', 4);
select pg_temp.ended_game('00000000-0000-0000-0000-000000000618', 10000, 10);
update public.games set status = 'cancelled', cancelled_at = now() - interval '1 day',
  cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000618';
select pg_temp.ended_game('00000000-0000-0000-0000-000000000619', 10000, 10);
select pg_temp.ana_calls('complete_game', 'z04done', '00000000-0000-0000-0000-000000000619');
select set_config('t.z04_before', to_jsonb(pg_temp.snapshot())::text, true);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000617') $$,
  'P0001', 'NOT_GAME_ADMIN', 'Z04a: Bruno conclui: NOT_GAME_ADMIN'
);
select throws_ok(
  $$ select public.preview_complete_game('00000000-0000-0000-0000-000000000617') $$,
  'P0001', 'NOT_GAME_ADMIN', 'Z04b: Bruno pede o preview: NOT_GAME_ADMIN'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000618') $$,
  'P0001', 'GAME_NOT_OPEN', 'Z04c: jogo cancelado: GAME_NOT_OPEN'
);
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000619') $$,
  'P0001', 'GAME_NOT_OPEN', 'Z04d: jogo já concluído: GAME_NOT_OPEN'
);
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-0000000006ff') $$,
  'P0001', 'NOT_FOUND', 'Z04e: uuid qualquer: NOT_FOUND'
);
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000617', 0) $$,
  'P0001', 'INVALID_INPUT', 'Z04f: total 0: INVALID_INPUT'
);
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000617', -1) $$,
  'P0001', 'INVALID_INPUT', 'Z04g: total -1: INVALID_INPUT'
);
select throws_ok(
  $$ select public.preview_complete_game('00000000-0000-0000-0000-000000000617', 0) $$,
  'P0001', 'INVALID_INPUT', 'Z04h: preview com total 0: INVALID_INPUT'
);
reset role;
select is(
  to_jsonb(pg_temp.snapshot()), pg_temp.saved('z04_before'),
  'Z04i: nada é gravado em nenhum dos casos'
);
rollback to savepoint z04;

-- Z05. Automática com Edu left_after_start com falta.
savepoint z05;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000620', 10000, 10, now() - interval '61 minutes');
select pg_temp.fill('00000000-0000-0000-0000-000000000620', 5);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000620', '00000000-0000-0000-0000-00000000000e', 30);
select public.auto_complete_due_games();
select results_eq(
  $$ select completion_mode::text, total_cents from public.games
     where id = '00000000-0000-0000-0000-000000000620' $$,
  $$ values ('automatic', 10000) $$,
  'Z05a: automatic, o total não muda'
);
select is(
  (select kind::text from public.charges
   where game_id = '00000000-0000-0000-0000-000000000620'
     and payer_id = '00000000-0000-0000-0000-00000000000e'),
  'absence_penalty', 'Z05b: Edu tem absence_penalty (F03)'
);
select results_eq(
  $$ select count(*)::integer, count(e.actor_id)::integer
     from public.charge_events e join public.charges c on c.id = e.charge_id
     where c.game_id = '00000000-0000-0000-0000-000000000620' $$,
  $$ values (4, 0) $$,
  'Z05c: os charge_events têm actor_id nulo'
);
select results_eq(
  $$ select event, actor_id from public.audit_log
     where entity_id = '00000000-0000-0000-0000-000000000620' $$,
  $$ values ('game_completed'::text, null::uuid) $$,
  'Z05d: audit_log com actor_id nulo'
);
select set_eq(
  $$ select user_id from public.notifications where type = 'game_completed' $$,
  $$ select user_id from public.game_participants
     where game_id = '00000000-0000-0000-0000-000000000620' $$,
  'Z05e: game_completed a todas as passagens que ocupam vaga, inclusive Ana'
);
select is(
  (select count(*)::integer from public.notifications
   where type = 'game_completed' and data ->> 'completion_mode' = 'automatic'),
  5, 'Z05f: cinco game_completed, com completion_mode automatic'
);
rollback to savepoint z05;

-- Z06. Jogo concluído: cancelar e concluir de novo.
savepoint z06;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000621', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000621', 4);
select pg_temp.ana_calls('complete_game', 'z06', '00000000-0000-0000-0000-000000000621');
select set_config('t.z06_before', to_jsonb(pg_temp.snapshot())::text, true);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000621') $$,
  'P0001', 'GAME_NOT_OPEN', 'Z06a: cancelar o jogo concluído: GAME_NOT_OPEN'
);
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000621', 20000) $$,
  'P0001', 'GAME_NOT_OPEN', 'Z06b: concluir de novo: GAME_NOT_OPEN'
);
reset role;
select is(
  to_jsonb(pg_temp.snapshot()), pg_temp.saved('z06_before'),
  'Z06c: share_cents, total_cents e os valores não mudam (RN36)'
);
rollback to savepoint z06;

-- Z07. O agendamento.
select results_eq(
  $$ select schedule, command from cron.job where command like '%auto_complete_due_games%' $$,
  $$ values ('*/5 * * * *'::text, 'select public.auto_complete_due_games()'::text) $$,
  'Z07: uma tarefa do pg_cron chama auto_complete_due_games() a cada 5 minutos'
);

select * from finish();
rollback;
