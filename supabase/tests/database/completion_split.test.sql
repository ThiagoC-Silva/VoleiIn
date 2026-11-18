-- Rateio (fatia 5, etapa A). Cenários R01 a R07, R09 e R10 de
-- docs/testes-referencia.md, seção 4, com as notas de "Em todos". R08 (isenção
-- manual depois da conclusão) é da etapa B (seção 13, "Cenários por etapa").
-- Contrato: complete_game (docs/contratos-api.md, seção 5).
--
-- Base da seção 13, como em completion_functions.test.sql.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(58);

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

-- R10. Sobra mínima.
select pg_temp.ended_game('00000000-0000-0000-0000-000000000710', 1000, 7);
select pg_temp.fill('00000000-0000-0000-0000-000000000710', 7);
select pg_temp.ana_calls('complete_game', 'r10', '00000000-0000-0000-0000-000000000710');
select pg_temp.check_split('R10', '00000000-0000-0000-0000-000000000710', 'r10', 143, 6, 858, 142);

select * from finish();
rollback;
