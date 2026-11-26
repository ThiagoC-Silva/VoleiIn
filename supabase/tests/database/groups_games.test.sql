-- Saída e remoção do grupo com jogos (fatia 4, etapa C).
-- Cenários H01 a H10 de docs/testes-referencia.md, seção 12.3; estende a
-- seção 11.1, em que games_left voltava vazio.
-- Contratos: leave_group e remove_group_member (docs/contratos-api.md, seção 3).
--
-- Base e auxiliares: os de games_list.test.sql (research R6 de
-- specs/003-jogo-etapa-a). Cada cenário roda entre um savepoint e o rollback.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(27);

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
-- Valores do jogo concluído do seed (fatia 5) saem antes das passagens.
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

-- Detalhe (jsonb) do erro que a chamada levanta, como a pessoa.
create function pg_temp.error_detail(p_user uuid, p_sql text)
returns jsonb
language plpgsql
as $fn$
declare
  v_detail text;
begin
  perform pg_temp.login_as(p_user);
  begin
    set local role authenticated;
    execute p_sql;
    reset role;
  exception when others then
    get stacked diagnostics v_detail = pg_exception_detail;
    reset role;
    return nullif(v_detail, '')::jsonb;
  end;
  return null;
end;
$fn$;

-- Dados do H01: 401 com prazo vencido, limite 2, Ana e Bruno (Confirmado);
-- 402 cheio e não iniciado (Ana e Carla), com Bruno e Edu na espera.
create function pg_temp.h01_data()
returns void
language sql
as $fn$
  select pg_temp.make_game(
    '00000000-0000-0000-0000-000000000401',
    now() - interval '1 hour', now() + interval '2 hours', now() + interval '4 hours', 2
  );
  select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
  select pg_temp.make_game(
    '00000000-0000-0000-0000-000000000402',
    now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 2
  );
  select pg_temp.add_participant('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-00000000000c');
  insert into public.game_waitlist (game_id, user_id)
  values
    ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-00000000000b'),
    ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-00000000000e');
$fn$;

-- Os efeitos do H01 (usados também no H07). p_name guarda o retorno.
create function pg_temp.h01_checks(p_name text, p_prefix text)
returns setof text
language plpgsql
as $fn$
begin
  return next results_eq(
    $$ select status::text, removal_reason::text, late_cancellation, left_at = now()
       from public.game_participants
       where game_id = '00000000-0000-0000-0000-000000000401'
         and user_id = '00000000-0000-0000-0000-00000000000b' $$,
    $$ values ('removed'::text, 'left_group'::text, null::boolean, true) $$,
    p_prefix || 'a: passagem removed, left_group e late_cancellation nulo, mesmo depois do prazo (RN14)'
  );
  return next is(
    (select left_at from public.game_waitlist
     where game_id = '00000000-0000-0000-0000-000000000402' and user_id = '00000000-0000-0000-0000-00000000000b'),
    now(), p_prefix || 'b: a linha dele na espera fica com left_at = now()'
  );
  return next set_eq(
    format($$ select jsonb_array_elements_text(%L::jsonb -> 'games_left') $$, pg_temp.saved(p_name)),
    $$ values ('00000000-0000-0000-0000-000000000401'), ('00000000-0000-0000-0000-000000000402') $$,
    p_prefix || 'c: games_left traz os dois jogos'
  );
  return next results_eq(
    $$ select id, status::text from public.games
       where id in ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000402')
       order by id $$,
    $$ values ('00000000-0000-0000-0000-000000000401'::uuid, 'open'::text),
              ('00000000-0000-0000-0000-000000000402'::uuid, 'confirmed'::text) $$,
    p_prefix || 'd: o status de cada jogo é recalculado'
  );
end;
$fn$;

-- Bruno chama leave_group(quinta) e guarda o retorno em t.<p_name>.
create function pg_temp.bruno_leaves_group(p_name text)
returns void
language plpgsql
as $fn$
begin
  perform pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
  set local role authenticated;
  perform set_config(
    't.' || p_name, public.leave_group('00000000-0000-0000-0000-000000000301')::text, true
  );
  reset role;
end;
$fn$;

-- H01. Bruno sai do Quinta com passagem depois do prazo e linha na espera.
savepoint h01;
select pg_temp.h01_data();
select lives_ok($$ select pg_temp.bruno_leaves_group('h01') $$, 'H01: Bruno sai do Quinta');
select pg_temp.h01_checks('h01', 'H01');
rollback to savepoint h01;

-- H02. Passagem em jogo iniciado e em jogo concluído, inseridos direto.
savepoint h02;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000403',
  now() - interval '3 hours', now() - interval '1 hour', now() + interval '1 hour'
);
select pg_temp.add_participant('00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-00000000000b');
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000404',
  now() - interval '2 days', now() - interval '1 day', now() - interval '22 hours'
);
select pg_temp.add_participant('00000000-0000-0000-0000-000000000404', '00000000-0000-0000-0000-00000000000b');
update public.games set status = 'completed', completed_at = now(), share_cents = 4500, completion_mode = 'manual'
where id = '00000000-0000-0000-0000-000000000404';
select pg_temp.bruno_leaves_group('h02');
select is(
  (select count(*) from public.game_participants
   where user_id = '00000000-0000-0000-0000-00000000000b' and status = 'active'),
  2::bigint, 'H02a: as duas passagens não mudam (RN14, item 3)'
);
select is(pg_temp.saved('h02') -> 'games_left', '[]'::jsonb, 'H02b: games_left vazio');
rollback to savepoint h02;

-- H03. Bruno admin, junto da Ana, de um jogo Aberto, de um iniciado e de um cancelado.
savepoint h03;
select pg_temp.base_game();
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() - interval '3 hours', now() - interval '1 hour', now() + interval '1 hour'
);
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000403',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours'
);
update public.games
set status = 'cancelled', cancelled_at = now(), cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000403';
insert into public.game_admins (game_id, user_id, added_by)
select g, '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a'
from unnest(array[
  '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000402',
  '00000000-0000-0000-0000-000000000403'
]::uuid[]) g;
select pg_temp.bruno_leaves_group('h03');
select results_eq(
  $$ select game_id from public.game_admins where user_id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values ('00000000-0000-0000-0000-000000000403'::uuid) $$,
  'H03: Bruno sai de game_admins no Aberto e no iniciado, e continua no cancelado (RN14, item 2)'
);
rollback to savepoint h03;

-- H04. Bruno único admin de um jogo Aberto, com a Ana recebedora.
savepoint h04;
select pg_temp.base_game();
update public.game_admins set user_id = '00000000-0000-0000-0000-00000000000b'
where game_id = '00000000-0000-0000-0000-000000000401';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'MEMBER_IS_ONLY_GAME_ADMIN', 'H04a: MEMBER_IS_ONLY_GAME_ADMIN'
);
reset role;
select is(
  pg_temp.error_detail('00000000-0000-0000-0000-00000000000b',
    $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$),
  '{"game_ids": ["00000000-0000-0000-0000-000000000401"]}'::jsonb, 'H04b: detail.game_ids = esse jogo'
);
select ok(
  exists (select 1 from public.group_members
          where group_id = '00000000-0000-0000-0000-000000000301' and user_id = '00000000-0000-0000-0000-00000000000b'),
  'H04c: nada muda'
);
rollback to savepoint h04;

-- H05. Bruno criou um jogo Aberto: recebedor e único admin.
savepoint h05;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours',
  3, '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b'
);
select is(
  pg_temp.error_detail('00000000-0000-0000-0000-00000000000b',
    $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$),
  '{"game_ids": ["00000000-0000-0000-0000-000000000401"]}'::jsonb, 'H05a: detail.game_ids = esse jogo'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'MEMBER_IS_RECEIVER', 'H05b: ser recebedor vem antes'
);
reset role;
rollback to savepoint h05;

-- H06. Bruno recebedor de um jogo iniciado.
savepoint h06;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now() - interval '1 hour', now() + interval '1 hour',
  3, '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'MEMBER_IS_RECEIVER', 'H06: jogo iniciado também bloqueia (RN16)'
);
reset role;
rollback to savepoint h06;

-- H07. Ana remove o Bruno com os dados do H01; depois com os do H05.
savepoint h07;
select pg_temp.h01_data();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.h07', public.remove_group_member(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b')::text, true) $$,
  'H07: Ana remove o Bruno'
);
reset role;
select pg_temp.h01_checks('h07', 'H07');
select ok(
  exists (select 1 from public.notifications
          where user_id = '00000000-0000-0000-0000-00000000000b' and type = 'removed_from_group'),
  'H07e: notifica o Bruno (removed_from_group)'
);
rollback to savepoint h07;
savepoint h07b;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours',
  3, '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.remove_group_member('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'MEMBER_IS_RECEIVER', 'H07f: com os dados do H05, MEMBER_IS_RECEIVER'
);
reset role;
rollback to savepoint h07b;

-- H08. Bruno recebedor de um avulso Aberto e na lista de outro avulso.
savepoint h08;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours',
  3, null, '00000000-0000-0000-0000-00000000000b'
);
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 3, null
);
select pg_temp.add_participant('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-00000000000b');
select lives_ok($$ select pg_temp.bruno_leaves_group('h08') $$, 'H08a: aceito');
select is(
  (select count(*) from public.game_participants
   where user_id = '00000000-0000-0000-0000-00000000000b' and status = 'active'),
  2::bigint, 'H08b: os jogos avulsos não mudam'
);
rollback to savepoint h08;

-- H09. Bruno único admin de um jogo cancelado.
savepoint h09;
select pg_temp.base_game();
update public.game_admins set user_id = '00000000-0000-0000-0000-00000000000b'
where game_id = '00000000-0000-0000-0000-000000000401';
update public.games
set status = 'cancelled', cancelled_at = now(), cancelled_by = '00000000-0000-0000-0000-00000000000a'
where id = '00000000-0000-0000-0000-000000000401';
select lives_ok($$ select pg_temp.bruno_leaves_group('h09') $$, 'H09: aceito, só open e confirmed bloqueiam');
rollback to savepoint h09;

-- H10. Depois do H01, mais um jogo do Quinta sem passagem do Bruno.
savepoint h10;
select pg_temp.h01_data();
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000405',
  now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours'
);
select pg_temp.bruno_leaves_group('h10');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select set_eq(
  $$ select id from public.games $$,
  $$ values ('00000000-0000-0000-0000-000000000401'::uuid), ('00000000-0000-0000-0000-000000000402'::uuid) $$,
  'H10a: vê só os dois jogos em que teve passagem'
);
select throws_ok(
  $$ select public.join_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'NO_GAME_ACCESS', 'H10b: join_game'
);
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'NO_GAME_ACCESS', 'H10c: join_waitlist'
);
reset role;
rollback to savepoint h10;

-- Sem finish(): o rollback para cada savepoint apaga a tabela de resultados do
-- pgTAP. O pg_prove confere o plano pelas linhas ok e not ok.
rollback;
