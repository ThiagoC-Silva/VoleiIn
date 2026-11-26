-- Rateio, isenção automática, faltas e multas (fatia 5). Etapa A: R01 a R07,
-- R09 e R10 (seção 4). Etapa B: R08 (seção 4), I01 a I12 (seção 5) e F01, F02
-- e F05 a F14 (seção 6). Etapa C: V01 a V11 (seção 7) de
-- docs/testes-referencia.md, com as notas de "Em todos". F03 e F04 ficam em
-- completion_functions.test.sql (etapa A). Contratos: complete_game,
-- waive_penalty e change_receiver (docs/contratos-api.md, seção 5).
--
-- Base da seção 13, como em completion_functions.test.sql.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(169);

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

update public.profile_private
set pix_key_type = 'cpf', pix_key = '12345678909'
where user_id = '00000000-0000-0000-0000-00000000000a';
-- Bruno e Carla, que viram recebedores na etapa C. Como no seed, para passar
-- também no banco do ensaio, que não tem seed (docs/setup.md, seção 9.2).
update public.profile_private set pix_key_type = 'email', pix_key = 'bruno@voleiin.test'
where user_id = '00000000-0000-0000-0000-00000000000b';
update public.profile_private set pix_key_type = 'email', pix_key = 'carla@voleiin.test'
where user_id = '00000000-0000-0000-0000-00000000000c';

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

-- Confere um cenário da seção 4: parte, valores, soma, por conta, e as notas de
-- "Em todos" (só Pendentes, devidos a Ana, sem valor da Ana). Seis asserções.
create function pg_temp.check_split(
  p_label text, p_game uuid, p_name text,
  p_share integer, p_count integer, p_sum bigint, p_covered bigint
)
returns setof text
language plpgsql
as $fn$
begin
  return next is(
    (select share_cents from public.games where id = p_game), p_share,
    p_label || 'a: parte por vaga ' || p_share
  );
  return next is(
    (select count(*)::integer from public.charges where game_id = p_game), p_count,
    p_label || 'b: ' || p_count || ' valores criados'
  );
  return next is(
    (select coalesce(sum(amount_cents), 0)::bigint from public.charges where game_id = p_game), p_sum,
    p_label || 'c: soma ' || p_sum
  );
  return next is(
    (pg_temp.saved(p_name) ->> 'receiver_covered_cents')::bigint, p_covered,
    p_label || 'd: por conta da recebedora ' || p_covered
  );
  return next is(
    (select count(*)::integer from public.charges
     where game_id = p_game and status = 'pending'
       and receiver_id = '00000000-0000-0000-0000-00000000000a'),
    p_count,
    p_label || 'e: todos Pendentes e devidos a Ana (RN73)'
  );
  return next is(
    (select count(*)::integer from public.charges
     where game_id = p_game and payer_id = '00000000-0000-0000-0000-00000000000a'),
    0,
    p_label || 'f: Ana não tem valor a pagar (RF71)'
  );
end;
$fn$;

-- Etapa B ----------------------------------------------------------------------

-- Histórico de limite do cenário (research R3 de specs/006-conclusao-etapa-a):
-- cada valor de p_limits vale a partir de p_minutes depois do prazo (negativo,
-- antes dele). O último vira o limite final do jogo.
create function pg_temp.limits(p_game uuid, p_limits integer[], p_minutes integer[])
returns void
language plpgsql
as $fn$
declare
  v_deadline timestamptz;
begin
  update public.games set slot_limit = p_limits[cardinality(p_limits)]
  where id = p_game
  returning cancellation_deadline into v_deadline;
  delete from public.game_limit_history where game_id = p_game;
  for i in 1 .. cardinality(p_limits) loop
    insert into public.game_limit_history (game_id, slot_limit, effective_from)
    values (p_game, p_limits[i], v_deadline + make_interval(mins => p_minutes[i]));
  end loop;
end;
$fn$;

-- Cancelamento fora do prazo anulado pela volta à lista, p_back minutos depois
-- do prazo (RN56). A volta em si é uma passagem nova (pg_temp.join).
create function pg_temp.voided_cancel(p_game uuid, p_user uuid, p_minutes integer, p_back integer)
returns void
language sql
as $fn$
  insert into public.game_participants (
    game_id, user_id, joined_at, status, left_at, late_cancellation, cancellation_voided_at
  )
  select p_game, p_user, g.cancellation_deadline - interval '1 day', 'cancelled',
         g.cancellation_deadline + make_interval(mins => p_minutes), true,
         g.cancellation_deadline + make_interval(mins => p_back)
  from public.games g where g.id = p_game;
$fn$;

-- Cancelamento no prazo, p_minutes antes do prazo.
create function pg_temp.on_time_cancel(p_game uuid, p_user uuid, p_minutes integer)
returns void
language sql
as $fn$
  insert into public.game_participants (game_id, user_id, joined_at, status, left_at, late_cancellation)
  select p_game, p_user, g.cancellation_deadline - interval '1 day', 'cancelled',
         g.cancellation_deadline - make_interval(mins => p_minutes), false
  from public.games g where g.id = p_game;
$fn$;

-- Remoção por um admin, p_minutes depois do prazo (RN58).
create function pg_temp.removed(p_game uuid, p_user uuid, p_minutes integer)
returns void
language sql
as $fn$
  insert into public.game_participants (game_id, user_id, joined_at, status, left_at, removal_reason)
  select p_game, p_user, g.cancellation_deadline - interval '1 day', 'removed',
         g.cancellation_deadline + make_interval(mins => p_minutes), 'by_admin'
  from public.games g where g.id = p_game;
$fn$;

-- O valor da pessoa no jogo, ativo ou não (no máximo um por pessoa nestes cenários).
create function pg_temp.charge_of(p_game uuid, p_user uuid)
returns uuid
language sql
as $fn$
  select id from public.charges where game_id = p_game and payer_id = p_user;
$fn$;

-- A pessoa chama waive_penalty e guarda o retorno em t.<p_name>.
create function pg_temp.waive_as(p_user uuid, p_charge uuid, p_name text)
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  perform set_config('t.' || p_name, public.waive_penalty(p_charge)::text, true);
  reset role;
end;
$fn$;

-- Confere um cenário da seção 5: quem paga multa (igual à parte), quem fica
-- isento e o penalties_exempted do retorno. Três asserções.
create function pg_temp.check_exempt(
  p_label text, p_game uuid, p_name text, p_kept uuid[], p_exempt uuid[]
)
returns setof text
language plpgsql
as $fn$
begin
  return next is(
    (select coalesce(array_agg(c.payer_id order by c.payer_id), '{}')
     from public.charges c join public.games g on g.id = c.game_id
     where c.game_id = p_game and c.kind = 'late_cancellation_penalty'
       and c.amount_cents = g.share_cents),
    (select coalesce(array_agg(u order by u), '{}') from unnest(p_kept) u),
    p_label || 'a: pagam multa de cancelamento, igual à parte'
  );
  return next is(
    (select coalesce(array_agg(p.user_id order by p.user_id), '{}')
     from public.game_participants p
     where p.game_id = p_game and p.late_cancellation_exempt),
    (select coalesce(array_agg(u order by u), '{}') from unnest(p_exempt) u),
    p_label || 'b: isentos, com late_cancellation_exempt'
  );
  return next is(
    (pg_temp.saved(p_name) ->> 'penalties_exempted')::integer, cardinality(p_exempt),
    p_label || 'c: penalties_exempted ' || cardinality(p_exempt)
  );
end;
$fn$;

-- R01. Exemplo do regras-negocio.md: 10 na lista, Carla e P09 com multa de
-- cancelamento mantida (2 vagas ociosas).
savepoint r01;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000701', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000701', 10);
update public.game_participants set status = 'cancelled', left_at = now() - interval '230 minutes',
  late_cancellation = true
where game_id = '00000000-0000-0000-0000-000000000701'
  and user_id = '00000000-0000-0000-0000-00000000000c';
select pg_temp.fill('00000000-0000-0000-0000-000000000701', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000701', pg_temp.p(9), 30);
select pg_temp.ana_calls('complete_game', 'r01', '00000000-0000-0000-0000-000000000701');
select pg_temp.check_split('R01', '00000000-0000-0000-0000-000000000701', 'r01', 2084, 11, 22924, 2076);
select is(
  (select count(*)::integer from public.charges
   where game_id = '00000000-0000-0000-0000-000000000701' and kind = 'late_cancellation_penalty'),
  2, 'R01g: duas multas de cancelamento, iguais à parte'
);
select is(
  (pg_temp.saved('r01') ->> 'total_to_receive_cents')::bigint, 22924::bigint,
  'R01h: R$ 229,24 a receber'
);
rollback to savepoint r01;

-- R02. Divide exato.
savepoint r02;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000702', 24000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000702', 12);
select pg_temp.ana_calls('complete_game', 'r02', '00000000-0000-0000-0000-000000000702');
select pg_temp.check_split('R02', '00000000-0000-0000-0000-000000000702', 'r02', 2000, 11, 22000, 2000);
rollback to savepoint r02;

-- R03. Limite 1: nenhum valor, e o jogo nasce Confirmado (RN40).
savepoint r03;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000703', 10000, 1);
update public.games set status = 'confirmed' where id = '00000000-0000-0000-0000-000000000703';
select pg_temp.ana_calls('complete_game', 'r03', '00000000-0000-0000-0000-000000000703');
select pg_temp.check_split('R03', '00000000-0000-0000-0000-000000000703', 'r03', 10000, 0, 0, 10000);
rollback to savepoint r03;

-- R04. Total pequeno: por conta negativo, devolvido com sinal.
savepoint r04;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000704', 1, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000704', 10);
select pg_temp.ana_calls('complete_game', 'r04', '00000000-0000-0000-0000-000000000704');
select pg_temp.check_split('R04', '00000000-0000-0000-0000-000000000704', 'r04', 1, 9, 9, -8);
rollback to savepoint r04;

-- R05. Arredonda para cima.
savepoint r05;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000705', 10000, 3);
select pg_temp.fill('00000000-0000-0000-0000-000000000705', 3);
select pg_temp.ana_calls('complete_game', 'r05', '00000000-0000-0000-0000-000000000705');
select pg_temp.check_split('R05', '00000000-0000-0000-0000-000000000705', 'r05', 3334, 2, 6668, 3332);
rollback to savepoint r05;

-- R06. Seis vagas não cobertas.
savepoint r06;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000706', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000706', 6);
select pg_temp.ana_calls('complete_game', 'r06', '00000000-0000-0000-0000-000000000706');
select pg_temp.check_split('R06', '00000000-0000-0000-0000-000000000706', 'r06', 2084, 5, 10420, 14580);
select is((pg_temp.saved('r06') ->> 'uncovered_slots')::integer, 6, 'R06g: uncovered_slots = 6');
rollback to savepoint r06;

-- R07. Total editado de 25.000 para 30.000 na conclusão; o limite não muda.
savepoint r07;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000707', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000707', 12);
select pg_temp.ana_calls('complete_game', 'r07', '00000000-0000-0000-0000-000000000707', 30000);
select pg_temp.check_split('R07', '00000000-0000-0000-0000-000000000707', 'r07', 2500, 11, 27500, 2500);
select results_eq(
  $$ select total_cents, slot_limit from public.games where id = '00000000-0000-0000-0000-000000000707' $$,
  $$ values (30000, 12) $$,
  'R07g: total gravado 30.000, limite 12 (RN34, RN48)'
);
rollback to savepoint r07;

-- R09. Maior total em integer: total + limite - 1 estoura e roda em bigint.
savepoint r09;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000709', 2147483647, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000709', 12);
select pg_temp.ana_calls('complete_game', 'r09', '00000000-0000-0000-0000-000000000709');
select pg_temp.check_split(
  'R09', '00000000-0000-0000-0000-000000000709', 'r09', 178956971, 11, 1968526681, 178956966
);
rollback to savepoint r09;

-- =========================================================================
-- Etapa B: R08, isenção automática (seção 5) e faltas e multas (seção 6)
-- =========================================================================

-- R08. R01 com a multa do P09 isentada depois da conclusão.
savepoint r08;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000708', 25000, 12);
select pg_temp.fill('00000000-0000-0000-0000-000000000708', 10);
update public.game_participants set status = 'cancelled', left_at = now() - interval '230 minutes',
  late_cancellation = true
where game_id = '00000000-0000-0000-0000-000000000708'
  and user_id = '00000000-0000-0000-0000-00000000000c';
select pg_temp.fill('00000000-0000-0000-0000-000000000708', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000708', pg_temp.p(9), 30);
select pg_temp.ana_calls('complete_game', 'r08', '00000000-0000-0000-0000-000000000708');
select pg_temp.waive_as(
  '00000000-0000-0000-0000-00000000000a',
  pg_temp.charge_of('00000000-0000-0000-0000-000000000708', pg_temp.p(9)), 'r08w'
);
select results_eq(
  $$ select count(*)::integer, (count(*) filter (where status <> 'waived'))::integer,
            sum(amount_cents)::bigint, (sum(amount_cents) filter (where status <> 'waived'))::bigint
     from public.charges where game_id = '00000000-0000-0000-0000-000000000708' $$,
  $$ values (11, 10, 22924::bigint, 20840::bigint) $$,
  'R08a: 11 valores (10 ativos), soma 22.924 (20.840 ativos)'
);
select is(
  (select g.total_cents - sum(c.amount_cents) from public.games g
   join public.charges c on c.game_id = g.id and c.status <> 'waived'
   where g.id = '00000000-0000-0000-0000-000000000708' group by g.total_cents)::bigint,
  4160::bigint, 'R08b: 4.160 por conta da recebedora'
);
rollback to savepoint r08;

-- Seção 5. Limite 10, total R$ 100,00 (parte 1.000). Ana é a recebedora, e os
-- papéis da tabela passam a Carla ("Ana"), Edu ("Bruno"), P01 ("Davi") e P02
-- ("Carla"), research R5 de specs/007-conclusao-etapa-b. Os minutos são contados
-- a partir do prazo (18h): 10 é 18h10, 60 é 19h.

-- I01. Carla (18h10), Edu (18h30) e P01 (19h20) cancelam. 8 no início.
savepoint i01;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000721', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000721', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000721', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000721', pg_temp.p(1), 80);
select pg_temp.fill('00000000-0000-0000-0000-000000000721', 8);
select pg_temp.ana_calls('complete_game', 'i01', '00000000-0000-0000-0000-000000000721');
select pg_temp.check_exempt(
  'I01', '00000000-0000-0000-0000-000000000721', 'i01',
  array['00000000-0000-0000-0000-00000000000e'::uuid, pg_temp.p(1)],
  array['00000000-0000-0000-0000-00000000000c'::uuid]
);
rollback to savepoint i01;

-- I02. Lista cheia no início. Carla, Edu e P01 cancelaram.
savepoint i02;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000722', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000722', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000722', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000722', pg_temp.p(1), 80);
select pg_temp.fill('00000000-0000-0000-0000-000000000722', 10);
select pg_temp.ana_calls('complete_game', 'i02', '00000000-0000-0000-0000-000000000722');
select pg_temp.check_exempt(
  'I02', '00000000-0000-0000-0000-000000000722', 'i02', '{}',
  array['00000000-0000-0000-0000-00000000000c'::uuid, '00000000-0000-0000-0000-00000000000e', pg_temp.p(1)]
);
rollback to savepoint i02;

-- I03. 5 no início. Carla e Edu cancelaram.
savepoint i03;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000723', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000723', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000723', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.fill('00000000-0000-0000-0000-000000000723', 5);
select pg_temp.ana_calls('complete_game', 'i03', '00000000-0000-0000-0000-000000000723');
select pg_temp.check_exempt(
  'I03', '00000000-0000-0000-0000-000000000723', 'i03',
  array['00000000-0000-0000-0000-00000000000c'::uuid, '00000000-0000-0000-0000-00000000000e'], '{}'
);
rollback to savepoint i03;

-- I04. Limite subiu de 10 para 12 às 19h. 10 no início. Carla e Edu cancelaram
-- antes. Total R$ 120,00: a isenção usa L = 10, e a parte, o limite final 12.
savepoint i04;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000724', 12000, 10);
select pg_temp.limits('00000000-0000-0000-0000-000000000724', array[10, 12], array[-1440, 60]);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000724', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000724', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.fill('00000000-0000-0000-0000-000000000724', 10);
select pg_temp.ana_calls('complete_game', 'i04', '00000000-0000-0000-0000-000000000724');
select pg_temp.check_exempt(
  'I04', '00000000-0000-0000-0000-000000000724', 'i04', '{}',
  array['00000000-0000-0000-0000-00000000000c'::uuid, '00000000-0000-0000-0000-00000000000e']
);
select pg_temp.check_split('I04', '00000000-0000-0000-0000-000000000724', 'i04', 1000, 9, 9000, 3000);
rollback to savepoint i04;

-- I05. Limite caiu de 10 para 8 às 19h. 8 no início. Carla e Edu cancelaram antes.
savepoint i05;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000725', 10000, 10);
select pg_temp.limits('00000000-0000-0000-0000-000000000725', array[10, 8], array[-1440, 60]);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000725', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000725', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.fill('00000000-0000-0000-0000-000000000725', 8);
select pg_temp.ana_calls('complete_game', 'i05', '00000000-0000-0000-0000-000000000725');
select pg_temp.check_exempt(
  'I05', '00000000-0000-0000-0000-000000000725', 'i05', '{}',
  array['00000000-0000-0000-0000-00000000000c'::uuid, '00000000-0000-0000-0000-00000000000e']
);
select pg_temp.check_split('I05', '00000000-0000-0000-0000-000000000725', 'i05', 1250, 7, 8750, 1250);
rollback to savepoint i05;

-- I06. Limite caiu de 12 para 10 às 17h, antes do prazo. 9 no início. Carla cancelou.
savepoint i06;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000726', 10000, 12);
select pg_temp.limits('00000000-0000-0000-0000-000000000726', array[12, 10], array[-1440, -60]);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000726', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000726', 9);
select pg_temp.ana_calls('complete_game', 'i06', '00000000-0000-0000-0000-000000000726');
select pg_temp.check_exempt(
  'I06', '00000000-0000-0000-0000-000000000726', 'i06',
  array['00000000-0000-0000-0000-00000000000c'::uuid], '{}'
);
rollback to savepoint i06;

-- I07. Limite foi de 10 para 8 e voltou a 10, tudo depois do prazo. 8 no início.
savepoint i07;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000727', 10000, 10);
select pg_temp.limits('00000000-0000-0000-0000-000000000727', array[10, 8, 10], array[-1440, 30, 90]);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000727', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000727', 8);
select pg_temp.ana_calls('complete_game', 'i07', '00000000-0000-0000-0000-000000000727');
select pg_temp.check_exempt(
  'I07', '00000000-0000-0000-0000-000000000727', 'i07', '{}',
  array['00000000-0000-0000-0000-00000000000c'::uuid]
);
rollback to savepoint i07;

-- I08. Carla cancela às 18h10. Edu cancela às 18h30 e volta às 19h (anulado,
-- RN56). 9 no início.
savepoint i08;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000728', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000728', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.voided_cancel('00000000-0000-0000-0000-000000000728', '00000000-0000-0000-0000-00000000000e', 30, 60);
select pg_temp.join('00000000-0000-0000-0000-000000000728', '00000000-0000-0000-0000-00000000000e');
select pg_temp.fill('00000000-0000-0000-0000-000000000728', 9);
select pg_temp.ana_calls('complete_game', 'i08', '00000000-0000-0000-0000-000000000728');
select pg_temp.check_exempt(
  'I08', '00000000-0000-0000-0000-000000000728', 'i08',
  array['00000000-0000-0000-0000-00000000000c'::uuid], '{}'
);
rollback to savepoint i08;

-- I09. Carla cancela às 19h. Edu cancela às 18h30, volta às 18h50 e cancela de
-- novo às 19h30. 9 no início: só a passagem mais recente do Edu conta.
savepoint i09;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000729', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000729', '00000000-0000-0000-0000-00000000000c', 60);
select pg_temp.voided_cancel('00000000-0000-0000-0000-000000000729', '00000000-0000-0000-0000-00000000000e', 30, 50);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000729', '00000000-0000-0000-0000-00000000000e', 90);
select pg_temp.fill('00000000-0000-0000-0000-000000000729', 9);
select pg_temp.ana_calls('complete_game', 'i09', '00000000-0000-0000-0000-000000000729');
select pg_temp.check_exempt(
  'I09', '00000000-0000-0000-0000-000000000729', 'i09',
  array['00000000-0000-0000-0000-00000000000e'::uuid],
  array['00000000-0000-0000-0000-00000000000c'::uuid]
);
rollback to savepoint i09;

-- I10. 9 ativos e o Bruno, que saiu após o início (não libera a vaga). Carla cancelou.
savepoint i10;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000730', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000730', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000730', 10);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000730', '00000000-0000-0000-0000-00000000000b', 30);
select pg_temp.ana_calls(
  'complete_game', 'i10', '00000000-0000-0000-0000-000000000730', null,
  array['00000000-0000-0000-0000-00000000000b'::uuid]
);
select pg_temp.check_exempt(
  'I10', '00000000-0000-0000-0000-000000000730', 'i10', '{}',
  array['00000000-0000-0000-0000-00000000000c'::uuid]
);
rollback to savepoint i10;

-- I11. P01 é removido por um admin às 19h. 9 no início. Carla cancelou.
savepoint i11;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000731', 10000, 10);
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000731', '00000000-0000-0000-0000-00000000000c', 10);
select pg_temp.removed('00000000-0000-0000-0000-000000000731', pg_temp.p(1), 60);
select pg_temp.fill('00000000-0000-0000-0000-000000000731', 9);
select pg_temp.ana_calls('complete_game', 'i11', '00000000-0000-0000-0000-000000000731');
select pg_temp.check_exempt(
  'I11', '00000000-0000-0000-0000-000000000731', 'i11',
  array['00000000-0000-0000-0000-00000000000c'::uuid], '{}'
);
select is(
  (select count(*)::integer from public.charges
   where game_id = '00000000-0000-0000-0000-000000000731' and payer_id = pg_temp.p(1)),
  0, 'I11d: o removido não tem multa nem valor (RN58)'
);
rollback to savepoint i11;

-- I12. Cancelamento só dentro do prazo. 9 no início.
savepoint i12;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000732', 10000, 10);
select pg_temp.on_time_cancel('00000000-0000-0000-0000-000000000732', '00000000-0000-0000-0000-00000000000c', 30);
select pg_temp.fill('00000000-0000-0000-0000-000000000732', 9);
select pg_temp.ana_calls('complete_game', 'i12', '00000000-0000-0000-0000-000000000732');
select pg_temp.check_exempt('I12', '00000000-0000-0000-0000-000000000732', 'i12', '{}', '{}');
rollback to savepoint i12;

-- Seção 6. Limite 10, total R$ 100,00 (parte 1.000), lista cheia, recebedora Ana.

-- F01. Edu sai às 20h30 e fica na lista de faltosos.
savepoint f01;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000741', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000741', 10);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000741', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.ana_calls(
  'complete_game', 'f01', '00000000-0000-0000-0000-000000000741', null,
  array['00000000-0000-0000-0000-00000000000e'::uuid]
);
select results_eq(
  $$ select c.kind::text, c.amount_cents, p.absent, p.absence_source::text
     from public.charges c join public.game_participants p on p.id = c.participant_id
     where c.game_id = '00000000-0000-0000-0000-000000000741'
       and c.payer_id = '00000000-0000-0000-0000-00000000000e' $$,
  $$ values ('absence_penalty', 1000, true, 'left_after_start') $$,
  'F01a: Edu com absence_penalty de 1.000'
);
select results_eq(
  $$ select count(*)::integer, min(amount_cents), max(amount_cents) from public.charges
     where game_id = '00000000-0000-0000-0000-000000000741' and kind = 'share' $$,
  $$ values (8, 1000, 1000) $$,
  'F01b: os outros 8 com share de 1.000'
);
rollback to savepoint f01;

-- F02. Edu sai às 20h30, e Ana conclui sem ele na lista: a falta é desmarcada (RN47).
savepoint f02;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000742', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000742', 10);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000742', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.ana_calls('complete_game', 'f02', '00000000-0000-0000-0000-000000000742');
select results_eq(
  $$ select c.kind::text, c.amount_cents, p.absent, p.absence_source::text
     from public.charges c join public.game_participants p on p.id = c.participant_id
     where c.game_id = '00000000-0000-0000-0000-000000000742'
       and c.payer_id = '00000000-0000-0000-0000-00000000000e' $$,
  $$ values ('share', 1000, false, null::text) $$,
  'F02: falta desmarcada, Edu com share de 1.000'
);
rollback to savepoint f02;

-- F05. Ana marca a Carla como faltosa.
savepoint f05;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000745', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000745', 10);
select pg_temp.ana_calls(
  'complete_game', 'f05', '00000000-0000-0000-0000-000000000745', null,
  array['00000000-0000-0000-0000-00000000000c'::uuid]
);
select results_eq(
  $$ select c.kind::text, c.amount_cents, p.absent, p.absence_source::text
     from public.charges c join public.game_participants p on p.id = c.participant_id
     where c.game_id = '00000000-0000-0000-0000-000000000745'
       and c.payer_id = '00000000-0000-0000-0000-00000000000c' $$,
  $$ values ('absence_penalty', 1000, true, 'marked_by_admin') $$,
  'F05: Carla com absence_penalty, marked_by_admin'
);
rollback to savepoint f05;

-- F06. Ana se marca como faltosa.
savepoint f06;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000746', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000746', 10);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.complete_game('00000000-0000-0000-0000-000000000746', null,
       array['00000000-0000-0000-0000-00000000000a'::uuid]) $$,
  'P0001', 'RECEIVER_CANNOT_BE_ABSENT', 'F06a: RECEIVER_CANNOT_BE_ABSENT'
);
reset role;
select results_eq(
  $$ select g.status::text, (select count(*)::integer from public.charges c where c.game_id = g.id),
            (select count(*)::integer from public.game_participants p where p.game_id = g.id and p.absent)
     from public.games g where g.id = '00000000-0000-0000-0000-000000000746' $$,
  $$ values ('confirmed', 0, 0) $$,
  'F06b: nada é gravado'
);
rollback to savepoint f06;

-- F07. Ana, recebedora, tenta sair do jogo iniciado (RN29).
savepoint f07;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000747', 10000, 10, now() + interval '1 hour');
select pg_temp.fill('00000000-0000-0000-0000-000000000747', 10);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.leave_game('00000000-0000-0000-0000-000000000747') $$,
  'P0001', 'RECEIVER_LOCKED', 'F07: RECEIVER_LOCKED'
);
reset role;
rollback to savepoint f07;

-- F08. Ana marca o P10, que não está na lista.
savepoint f08;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000748', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000748', 10);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  format(
    'select public.complete_game(%L, null, array[%L::uuid])',
    '00000000-0000-0000-0000-000000000748', pg_temp.p(10)
  ),
  'P0001', 'ABSENT_NOT_PARTICIPANT', 'F08a: ABSENT_NOT_PARTICIPANT'
);
reset role;
select results_eq(
  $$ select g.status::text, (select count(*)::integer from public.charges c where c.game_id = g.id),
            (select count(*)::integer from public.game_participants p where p.game_id = g.id and p.absent)
     from public.games g where g.id = '00000000-0000-0000-0000-000000000748' $$,
  $$ values ('confirmed', 0, 0) $$,
  'F08b: nada é gravado'
);
rollback to savepoint f08;

-- F09. Ana isenta a multa Pendente do Edu.
savepoint f09;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000749', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000749', 10);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000749', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.ana_calls(
  'complete_game', 'f09', '00000000-0000-0000-0000-000000000749', null,
  array['00000000-0000-0000-0000-00000000000e'::uuid]
);
select pg_temp.waive_as(
  '00000000-0000-0000-0000-00000000000a',
  pg_temp.charge_of('00000000-0000-0000-0000-000000000749', '00000000-0000-0000-0000-00000000000e'), 'f09w'
);
select results_eq(
  $$ select status::text, waive_reason::text from public.charges
     where game_id = '00000000-0000-0000-0000-000000000749'
       and payer_id = '00000000-0000-0000-0000-00000000000e' $$,
  $$ values ('waived', 'manual_waiver') $$,
  'F09a: waived, manual_waiver'
);
select is(
  (select sum(amount_cents)::integer from public.charges
   where game_id = '00000000-0000-0000-0000-000000000749' and status <> 'waived'),
  8000, 'F09b: sai dos totais: 8.000 ativos'
);
rollback to savepoint f09;

-- F10. Ana tenta isentar o share Pendente da Carla.
savepoint f10;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000750', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000750', 10);
select pg_temp.ana_calls('complete_game', 'f10', '00000000-0000-0000-0000-000000000750');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  format(
    'select public.waive_penalty(%L)',
    pg_temp.charge_of('00000000-0000-0000-0000-000000000750', '00000000-0000-0000-0000-00000000000c')
  ),
  'P0001', 'NOT_A_PENALTY', 'F10: NOT_A_PENALTY'
);
reset role;
rollback to savepoint f10;

-- F11. Ana tenta isentar a multa Paga do Edu.
savepoint f11;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000751', 10000, 10);
select pg_temp.fill('00000000-0000-0000-0000-000000000751', 10);
select pg_temp.left_after_start('00000000-0000-0000-0000-000000000751', '00000000-0000-0000-0000-00000000000e', 30);
select pg_temp.ana_calls(
  'complete_game', 'f11', '00000000-0000-0000-0000-000000000751', null,
  array['00000000-0000-0000-0000-00000000000e'::uuid]
);
update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
where game_id = '00000000-0000-0000-0000-000000000751'
  and payer_id = '00000000-0000-0000-0000-00000000000e';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  format(
    'select public.waive_penalty(%L)',
    pg_temp.charge_of('00000000-0000-0000-0000-000000000751', '00000000-0000-0000-0000-00000000000e')
  ),
  'P0001', 'CHARGE_NOT_PENDING', 'F11: CHARGE_NOT_PENDING'
);
reset role;
rollback to savepoint f11;

-- F12. Bruno, admin, cancela às 19h e tenta se remover (RN58). Jogo antes do início.
savepoint f12;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000752', 10000, 10, now() + interval '3 hours');
insert into public.game_admins (game_id, user_id)
values ('00000000-0000-0000-0000-000000000752', '00000000-0000-0000-0000-00000000000b');
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000752', '00000000-0000-0000-0000-00000000000b', 60);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.remove_participant('00000000-0000-0000-0000-000000000752',
       '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'CANNOT_REMOVE_SELF', 'F12: CANNOT_REMOVE_SELF'
);
reset role;
rollback to savepoint f12;

-- F13. Bruno, admin, cancela às 19h, com vaga ociosa no início: multa mantida.
savepoint f13;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000753', 10000, 10);
insert into public.game_admins (game_id, user_id)
values ('00000000-0000-0000-0000-000000000753', '00000000-0000-0000-0000-00000000000b');
select pg_temp.late_cancel('00000000-0000-0000-0000-000000000753', '00000000-0000-0000-0000-00000000000b', 60);
select pg_temp.fill('00000000-0000-0000-0000-000000000753', 9);
select pg_temp.ana_calls('complete_game', 'f13', '00000000-0000-0000-0000-000000000753');
select pg_temp.check_exempt(
  'F13', '00000000-0000-0000-0000-000000000753', 'f13',
  array['00000000-0000-0000-0000-00000000000b'::uuid], '{}'
);
rollback to savepoint f13;

-- F14. P01 removido por outro admin às 19h: sem multa nem valor (RF59).
savepoint f14;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000754', 10000, 10);
select pg_temp.removed('00000000-0000-0000-0000-000000000754', pg_temp.p(1), 60);
select pg_temp.fill('00000000-0000-0000-0000-000000000754', 9);
select pg_temp.ana_calls('complete_game', 'f14', '00000000-0000-0000-0000-000000000754');
select is(
  (select count(*)::integer from public.charges
   where game_id = '00000000-0000-0000-0000-000000000754' and payer_id = pg_temp.p(1)),
  0, 'F14: o removido não tem multa nem valor'
);
rollback to savepoint f14;

-- =========================================================================
-- Etapa C: troca de recebedor após a conclusão (seção 7)
-- =========================================================================

-- Pessoas da seção 7: A (Ana), B (Bruno), C (Carla), D (P01, "Davi"), E (Edu)
-- e Z (Fábio, "Zeca").
create function pg_temp.u(p_who text)
returns uuid
language sql
as $fn$
  select case p_who
    when 'A' then '00000000-0000-0000-0000-00000000000a'::uuid
    when 'B' then '00000000-0000-0000-0000-00000000000b'::uuid
    when 'C' then '00000000-0000-0000-0000-00000000000c'::uuid
    when 'D' then '00000000-0000-0000-0000-000000000501'::uuid
    when 'E' then '00000000-0000-0000-0000-00000000000e'::uuid
    when 'Z' then '00000000-0000-0000-0000-00000000000f'::uuid
  end;
$fn$;

-- Base da seção 7 (research R6 de specs/008-conclusao-etapa-c): jogo concluído,
-- R$ 100,00, limite 5 (parte 2.000), recebedora Ana. Bruno Pago, Carla e Davi
-- Pendentes, Edu com multa por falta Pendente (com p_edu_left, ele saiu após o
-- início). Todos têm chave Pix.
create function pg_temp.v_base(p_game uuid, p_edu_left boolean default false)
returns void
language plpgsql
as $fn$
begin
  update public.profile_private set pix_key_type = 'email', pix_key = 'edu@voleiin.test'
  where user_id = pg_temp.u('E');
  update public.profile_private set pix_key_type = 'email', pix_key = 'p01@voleiin.test'
  where user_id = pg_temp.u('D');
  perform pg_temp.ended_game(p_game, 10000, 5);
  perform pg_temp.join(p_game, pg_temp.u('B'));
  perform pg_temp.join(p_game, pg_temp.u('C'));
  perform pg_temp.join(p_game, pg_temp.u('D'));
  perform pg_temp.join(p_game, pg_temp.u('E'));
  if p_edu_left then
    perform pg_temp.left_after_start(p_game, pg_temp.u('E'), 30);
  end if;
  perform pg_temp.ana_calls('complete_game', 'v_base', p_game, null, array[pg_temp.u('E')]);
  update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
  where game_id = p_game and payer_id = pg_temp.u('B');
  delete from public.notifications;
end;
$fn$;

-- A pessoa chama change_receiver e guarda o retorno em t.<p_name>.
create function pg_temp.change_as(p_user uuid, p_game uuid, p_new uuid, p_name text)
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.login_as(p_user);
  set local role authenticated;
  perform set_config('t.' || p_name, public.change_receiver(p_game, p_new)::text, true);
  reset role;
end;
$fn$;

-- Ana troca o recebedor. Antes da última troca de um cenário, apaga as
-- notificações, para conferir só as dela.
create function pg_temp.ana_changes(p_game uuid, p_new text, p_last boolean default true)
returns void
language plpgsql
as $fn$
begin
  if p_last then
    delete from public.notifications;
  end if;
  perform pg_temp.change_as(pg_temp.u('A'), p_game, pg_temp.u(p_new), 'v');
end;
$fn$;

-- Retrato do jogo e dos valores, para conferir que nada mudou.
create function pg_temp.v_snapshot(p_game uuid)
returns text
language sql
as $fn$
  select md5(concat_ws('|',
    (select t::text from public.games t where t.id = p_game),
    (select string_agg(t::text, ',' order by t.id) from public.charges t where t.game_id = p_game),
    (select string_agg(t::text, ',' order by t.id) from public.charge_events t),
    (select string_agg(t::text, ',' order by t.id) from public.receiver_changes t),
    (select string_agg(t::text, ',' order by t.id) from public.notifications t)
  ));
$fn$;

-- Confere um cenário da seção 7: os valores (pagador, tipo, status e a quem é
-- devido), o Pendente a receber do recebedor final, o Pago à Ana e as notas de
-- "Em todos". p_last_old é o recebedor antes da última troca. Sete asserções.
create function pg_temp.check_change(
  p_label text, p_game uuid, p_receiver text, p_last_old text, p_changes integer,
  p_expected text, p_pending integer
)
returns setof text
language plpgsql
as $fn$
begin
  return next set_eq(
    format(
      $q$ select payer_id, kind::text, status::text, receiver_id from public.charges
          where game_id = %L $q$,
      p_game
    ),
    p_expected,
    p_label || 'a: valores, status e recebedor de cada um'
  );
  return next is(
    (select coalesce(sum(amount_cents), 0)::integer from public.charges
     where game_id = p_game and status = 'pending' and receiver_id = pg_temp.u(p_receiver)),
    p_pending,
    p_label || 'b: Pendente a receber ' || p_pending
  );
  return next is(
    (select coalesce(sum(amount_cents), 0)::integer from public.charges
     where game_id = p_game and status = 'paid' and receiver_id = pg_temp.u('A')),
    2000,
    p_label || 'c: Pago 2.000, ainda devido à Ana'
  );
  return next is(
    (select count(*)::integer from public.charges where game_id = p_game and payer_id = receiver_id)
    + (select count(*)::integer from (
         select payer_id from public.charges
         where game_id = p_game and status <> 'waived'
         group by payer_id having count(*) > 1
       ) d),
    0,
    p_label || 'd: nenhum valor com pagador igual ao recebedor, e no máximo um não Isento por pessoa'
  );
  return next results_eq(
    format($q$ select share_cents, total_cents from public.games where id = %L $q$, p_game),
    $q$ values (2000, 10000) $q$,
    p_label || 'e: share_cents e total_cents não mudam (RN36)'
  );
  return next results_eq(
    format(
      $q$ select g.receiver_id,
                 (select count(*)::integer from public.receiver_changes r
                  where r.game_id = g.id and r.after_completion),
                 (select count(*)::integer from public.audit_log a
                  where a.entity_id = g.id and a.event = 'receiver_changed')
          from public.games g where g.id = %L $q$,
      p_game
    ),
    format($q$ values (%L::uuid, %s, %s) $q$, pg_temp.u(p_receiver), p_changes, p_changes),
    p_label || 'f: recebedor gravado, com a troca em receiver_changes e em audit_log'
  );
  return next set_eq(
    $q$ select user_id from public.notifications where type = 'receiver_changed' $q$,
    format(
      $q$ select u from unnest(array[%L::uuid, %L::uuid]) u
          union
          select payer_id from public.charges where game_id = %L and status = 'pending'
          except
          select %L::uuid $q$,
      pg_temp.u(p_last_old), pg_temp.u(p_receiver), p_game, pg_temp.u('A')
    ),
    p_label || 'g: receiver_changed ao antigo e ao novo recebedor e a quem tem valor Pendente, exceto a Ana (RN115)'
  );
end;
$fn$;

-- V01. Ana → Carla, com o valor do Davi Em análise.
savepoint v01;
select pg_temp.v_base('00000000-0000-0000-0000-000000000761');
update public.charges set status = 'under_review'
where game_id = '00000000-0000-0000-0000-000000000761' and payer_id = pg_temp.u('D');
select set_config('t.v01', pg_temp.v_snapshot('00000000-0000-0000-0000-000000000761'), true);
select pg_temp.login_as(pg_temp.u('A'));
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000761', pg_temp.u('C')) $$,
  'P0001', 'RECEIVER_CHANGE_BLOCKED', 'V01a: RECEIVER_CHANGE_BLOCKED'
);
reset role;
select is(
  pg_temp.v_snapshot('00000000-0000-0000-0000-000000000761'), current_setting('t.v01'),
  'V01b: nada muda'
);
rollback to savepoint v01;

-- V02. Ana → Carla.
savepoint v02;
select pg_temp.v_base('00000000-0000-0000-0000-000000000762');
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000762', 'C');
select pg_temp.check_change(
  'V02', '00000000-0000-0000-0000-000000000762', 'C', 'A', 1,
  $$ values (pg_temp.u('B'), 'share', 'paid', pg_temp.u('A')),
            (pg_temp.u('C'), 'share', 'waived', pg_temp.u('A')),
            (pg_temp.u('D'), 'share', 'pending', pg_temp.u('C')),
            (pg_temp.u('E'), 'absence_penalty', 'pending', pg_temp.u('C')),
            (pg_temp.u('A'), 'share', 'pending', pg_temp.u('C')) $$,
  6000
);
rollback to savepoint v02;

-- V03. Ana → Bruno, que já pagou à Ana.
savepoint v03;
select pg_temp.v_base('00000000-0000-0000-0000-000000000763');
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000763', 'B');
select pg_temp.check_change(
  'V03', '00000000-0000-0000-0000-000000000763', 'B', 'A', 1,
  $$ values (pg_temp.u('B'), 'share', 'paid', pg_temp.u('A')),
            (pg_temp.u('C'), 'share', 'pending', pg_temp.u('B')),
            (pg_temp.u('D'), 'share', 'pending', pg_temp.u('B')),
            (pg_temp.u('E'), 'absence_penalty', 'pending', pg_temp.u('B')),
            (pg_temp.u('A'), 'share', 'pending', pg_temp.u('B')) $$,
  8000
);
rollback to savepoint v03;

-- V04. Ana → Bruno → Ana: o Bruno não ganha novo valor, porque já tem um Pago.
savepoint v04;
select pg_temp.v_base('00000000-0000-0000-0000-000000000764');
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000764', 'B', false);
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000764', 'A');
select pg_temp.check_change(
  'V04', '00000000-0000-0000-0000-000000000764', 'A', 'B', 2,
  $$ values (pg_temp.u('B'), 'share', 'paid', pg_temp.u('A')),
            (pg_temp.u('C'), 'share', 'pending', pg_temp.u('A')),
            (pg_temp.u('D'), 'share', 'pending', pg_temp.u('A')),
            (pg_temp.u('E'), 'absence_penalty', 'pending', pg_temp.u('A')),
            (pg_temp.u('A'), 'share', 'waived', pg_temp.u('B')) $$,
  6000
);
rollback to savepoint v04;

-- V05. Ana → Carla → Davi: a Carla, com valor Isento, ganha novo share.
savepoint v05;
select pg_temp.v_base('00000000-0000-0000-0000-000000000765');
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000765', 'C', false);
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000765', 'D');
select pg_temp.check_change(
  'V05', '00000000-0000-0000-0000-000000000765', 'D', 'C', 2,
  $$ values (pg_temp.u('B'), 'share', 'paid', pg_temp.u('A')),
            (pg_temp.u('C'), 'share', 'waived', pg_temp.u('A')),
            (pg_temp.u('C'), 'share', 'pending', pg_temp.u('D')),
            (pg_temp.u('D'), 'share', 'waived', pg_temp.u('C')),
            (pg_temp.u('E'), 'absence_penalty', 'pending', pg_temp.u('D')),
            (pg_temp.u('A'), 'share', 'pending', pg_temp.u('D')) $$,
  6000
);
rollback to savepoint v05;

-- V06. Ana → Edu, faltoso e ainda na lista: a multa dele fica Isenta.
savepoint v06;
select pg_temp.v_base('00000000-0000-0000-0000-000000000766');
select pg_temp.ana_changes('00000000-0000-0000-0000-000000000766', 'E');
select pg_temp.check_change(
  'V06', '00000000-0000-0000-0000-000000000766', 'E', 'A', 1,
  $$ values (pg_temp.u('B'), 'share', 'paid', pg_temp.u('A')),
            (pg_temp.u('C'), 'share', 'pending', pg_temp.u('E')),
            (pg_temp.u('D'), 'share', 'pending', pg_temp.u('E')),
            (pg_temp.u('E'), 'absence_penalty', 'waived', pg_temp.u('A')),
            (pg_temp.u('A'), 'share', 'pending', pg_temp.u('E')) $$,
  6000
);
rollback to savepoint v06;

-- V07. Ana → Edu, que saiu após o início.
savepoint v07;
select pg_temp.v_base('00000000-0000-0000-0000-000000000767', true);
select pg_temp.login_as(pg_temp.u('A'));
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000767', pg_temp.u('E')) $$,
  'P0001', 'RECEIVER_MUST_BE_PARTICIPANT', 'V07: Edu saiu após o início: RECEIVER_MUST_BE_PARTICIPANT'
);
reset role;
rollback to savepoint v07;

-- V08. Ana → Zeca (Fábio), fora da lista.
savepoint v08;
select pg_temp.v_base('00000000-0000-0000-0000-000000000768');
select pg_temp.login_as(pg_temp.u('A'));
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000768', pg_temp.u('Z')) $$,
  'P0001', 'RECEIVER_MUST_BE_PARTICIPANT', 'V08: Zeca fora da lista: RECEIVER_MUST_BE_PARTICIPANT'
);
reset role;
rollback to savepoint v08;

-- V09. Ana → Carla, sem chave Pix.
savepoint v09;
select pg_temp.v_base('00000000-0000-0000-0000-000000000769');
update public.profile_private set pix_key_type = null, pix_key = null where user_id = pg_temp.u('C');
select pg_temp.login_as(pg_temp.u('A'));
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000769', pg_temp.u('C')) $$,
  'P0001', 'RECEIVER_NEEDS_PIX_KEY', 'V09: Carla sem chave Pix: RECEIVER_NEEDS_PIX_KEY'
);
reset role;
rollback to savepoint v09;

-- V10. Ana → Ana.
savepoint v10;
select pg_temp.v_base('00000000-0000-0000-0000-000000000770');
select pg_temp.login_as(pg_temp.u('A'));
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000770', pg_temp.u('A')) $$,
  'P0001', 'RECEIVER_UNCHANGED', 'V10: RECEIVER_UNCHANGED'
);
reset role;
rollback to savepoint v10;

-- V11. Em jogo cancelado, com a Carla na lista.
savepoint v11;
select pg_temp.ended_game('00000000-0000-0000-0000-000000000771', 10000, 5, now() + interval '3 hours');
select pg_temp.join('00000000-0000-0000-0000-000000000771', pg_temp.u('C'));
update public.games set status = 'cancelled', cancelled_at = now()
where id = '00000000-0000-0000-0000-000000000771';
select pg_temp.login_as(pg_temp.u('A'));
set local role authenticated;
select throws_ok(
  $$ select public.change_receiver('00000000-0000-0000-0000-000000000771', pg_temp.u('C')) $$,
  'P0001', 'GAME_CANCELLED', 'V11: GAME_CANCELLED'
);
reset role;
rollback to savepoint v11;

-- R10. Sobra mínima.
select pg_temp.ended_game('00000000-0000-0000-0000-000000000710', 1000, 7);
select pg_temp.fill('00000000-0000-0000-0000-000000000710', 7);
select pg_temp.ana_calls('complete_game', 'r10', '00000000-0000-0000-0000-000000000710');
select pg_temp.check_split('R10', '00000000-0000-0000-0000-000000000710', 'r10', 143, 6, 858, 142);

select * from finish();
rollback;
