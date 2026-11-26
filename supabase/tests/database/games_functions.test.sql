-- Funções de jogo: criar, editar, cancelar e admins (fatia 4, etapas A e C).
-- Cenários J01 a J21 de docs/testes-referencia.md, seção 12.1. J01 a J13 são
-- da etapa A; J14 a J21 (cancelar e admins), da etapa C.
-- Contratos: docs/contratos-api.md, seção 4.
--
-- Base dos cenários (seção 12), inserida aqui sem depender do seed
-- (docs/arquitetura-app.md, 14.4): o grupo Quinta, com Ana admin e Bruno, Carla
-- e Edu membros. Diego sem grupo. Ana e Bruno com chave Pix; Carla e Edu sem.
-- Ana com telefone visível; Bruno com telefone oculto. Os jogos e as linhas de
-- grupo do seed são apagados dentro desta transação (research R6 de
-- specs/003-jogo-etapa-a), e o rollback do fim devolve tudo.
--
-- Jogo base (...0401): do Quinta, prazo em now() + 1 dia, início 2 h depois e
-- fim 2 h depois do início; total 9.000 e limite 3; Ana admin, recebedora e
-- primeira da lista. Cada cenário roda entre um savepoint e o rollback para ele.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(68);

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

-- =========================================================================
-- Criar (RF26 a RF32, RN05, RN06, RN20 a RN23, RN40)
-- =========================================================================

-- J01. Ana cria no Quinta, com espaços nas pontas do local.
savepoint j01;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.j01', public.create_game(
       '00000000-0000-0000-0000-000000000301', '  Quadra do Sesc  ', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     )::text, true) $$,
  'J01a: Ana cria o jogo'
);
reset role;
select is(pg_temp.saved('j01') ->> 'status', 'open', 'J01b: devolve status = open');
select matches(
  pg_temp.saved('j01') ->> 'invite_code', '^[0-9A-Za-z]{12}$',
  'J01c: devolve um invite_code de 12 caracteres base62'
);
select results_eq(
  format(
    $$ select location_name, created_by, receiver_id, group_id, invite_code
       from public.games where id = %L $$,
    pg_temp.saved('j01') ->> 'game_id'
  ),
  format(
    $$ values ('Quadra do Sesc'::text, '00000000-0000-0000-0000-00000000000a'::uuid,
              '00000000-0000-0000-0000-00000000000a'::uuid,
              '00000000-0000-0000-0000-000000000301'::uuid, %L::text) $$,
    pg_temp.saved('j01') ->> 'invite_code'
  ),
  'J01d: local sem os espaços das pontas, created_by e receiver_id = Ana, o grupo e o código devolvido'
);
select results_eq(
  format(
    $$ select user_id, added_by from public.game_admins where game_id = %L $$,
    pg_temp.saved('j01') ->> 'game_id'
  ),
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, null::uuid) $$,
  'J01e: game_admins tem só a Ana, com added_by nulo'
);
select results_eq(
  format(
    $$ select user_id, status::text, joined_at = now() from public.game_participants
       where game_id = %L $$,
    pg_temp.saved('j01') ->> 'game_id'
  ),
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, 'active'::text, true) $$,
  'J01f: uma passagem active da Ana, com joined_at = now()'
);
select results_eq(
  format(
    $$ select slot_limit from public.game_limit_history where game_id = %L $$,
    pg_temp.saved('j01') ->> 'game_id'
  ),
  $$ values (3) $$,
  'J01g: game_limit_history tem uma linha com 3'
);
select is_empty($$ select 1 from public.notifications $$, 'J01h: nenhuma notificação');
rollback to savepoint j01;

-- J02. Bruno cria um jogo avulso.
savepoint j02;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.j02', public.create_game(
       null, 'Praia do Coqueiro', 'https://maps.app.goo.gl/x',
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 4000, 4
     )::text, true) $$,
  'J02a: Bruno cria um jogo avulso'
);
reset role;
select results_eq(
  format(
    $$ select g.group_id, g.receiver_id,
              (select array_agg(user_id) from public.game_admins a where a.game_id = g.id),
              (select array_agg(user_id) from public.game_participants p where p.game_id = g.id)
       from public.games g where g.id = %L $$,
    pg_temp.saved('j02') ->> 'game_id'
  ),
  $$ values (null::uuid, '00000000-0000-0000-0000-00000000000b'::uuid,
            array['00000000-0000-0000-0000-00000000000b'::uuid],
            array['00000000-0000-0000-0000-00000000000b'::uuid]) $$,
  'J02b: group_id nulo e Bruno admin, recebedor e primeiro da lista (RN20)'
);
rollback to savepoint j02;

-- J03. Limite 1 já nasce Confirmado.
savepoint j03;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.j03', public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 1
     )::text, true) $$,
  'J03a: Ana cria com limite 1'
);
reset role;
select is(pg_temp.saved('j03') ->> 'status', 'confirmed', 'J03b: devolve status = confirmed (RN40)');
select is(
  (select status::text from public.games where id = (pg_temp.saved('j03') ->> 'game_id')::uuid),
  'confirmed', 'J03c: o jogo está confirmed'
);
rollback to savepoint j03;

-- J04. Carla sem chave Pix.
savepoint j04;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
set local role authenticated;
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'RECEIVER_NEEDS_PIX_KEY', 'J04a: Carla sem chave Pix recebe RECEIVER_NEEDS_PIX_KEY'
);
reset role;
select is_empty($$ select 1 from public.games $$, 'J04b: nenhuma linha em games (RN22)');
rollback to savepoint j04;

-- J05. Sem acesso ao grupo: não membro, grupo inexistente, grupo arquivado.
savepoint j05;
insert into public.groups (id, name, created_by, archived_at, archived_by)
values (
  '00000000-0000-0000-0000-000000000302', 'Antigo', '00000000-0000-0000-0000-00000000000a',
  now(), '00000000-0000-0000-0000-00000000000a'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'NOT_FOUND', 'J05a: Diego, fora do Quinta, recebe NOT_FOUND'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.create_game(
       '9b0d2a54-0000-4000-8000-000000000000', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'NOT_FOUND', 'J05b: grupo que não existe'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000302', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'NOT_FOUND', 'J05c: grupo arquivado'
);
reset role;
rollback to savepoint j05;

-- J06. Datas (RN23).
savepoint j06;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '26 hours' + interval '1 microsecond', now() + interval '26 hours',
       now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'INVALID_GAME_DATES', 'J06a: prazo 1 µs depois do início'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '26 hours', 9000, 3
     ) $$,
  'P0001', 'INVALID_GAME_DATES', 'J06b: início igual ao fim'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() - interval '1 hour', now(), now() + interval '2 hours', 9000, 3
     ) $$,
  'P0001', 'START_IN_PAST', 'J06c: início em now()'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() - interval '2 hours', now() - interval '1 hour', now() + interval '1 hour', 9000, 3
     ) $$,
  'P0001', 'START_IN_PAST', 'J06d: início 1 h antes de now()'
);
select lives_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '26 hours', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'J06e: prazo igual ao início é aceito (RN23)'
);
reset role;
rollback to savepoint j06;

-- J07. Entradas.
savepoint j07;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', '', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'INVALID_INPUT', 'J07a: local vazio'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', '   ', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'INVALID_INPUT', 'J07b: local só com espaços'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', repeat('a', 121), null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'INVALID_INPUT', 'J07c: local com 121 caracteres'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', 'http://maps.app.goo.gl/x',
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'INVALID_INPUT', 'J07d: link http://'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 0, 3
     ) $$,
  'P0001', 'INVALID_INPUT', 'J07e: total 0'
);
select throws_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 0
     ) $$,
  'P0001', 'INVALID_INPUT', 'J07f: limite 0'
);
select lives_ok(
  $$ select public.create_game(
       '00000000-0000-0000-0000-000000000301', repeat('a', 120), 'https://maps.app.goo.gl/x',
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 1, 1
     ) $$,
  'J07g: local de 120 caracteres, link https, total 1 e limite 1 são aceitos'
);
reset role;
rollback to savepoint j07;

-- J08. Sem sub no JWT.
savepoint j08;
select set_config('request.jwt.claims', '{"role": "authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ select public.create_game(
       null, 'Quadra do Sesc', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000, 3
     ) $$,
  'P0001', 'NOT_AUTHENTICATED', 'J08: create_game sem sub devolve NOT_AUTHENTICATED'
);
reset role;
rollback to savepoint j08;

-- =========================================================================
-- Editar (RF36, RN23, RN33 a RN35)
-- =========================================================================

-- J09. Ana edita o local e o horário; notifica Bruno, não Ana nem Edu.
savepoint j09;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
insert into public.game_waitlist (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() + interval '1 day', now() + interval '27 hours', now() + interval '29 hours', 9000
     ) $$,
  'J09a: Ana edita o jogo'
);
reset role;
select results_eq(
  $$ select location_name, starts_at = now() + interval '27 hours', ends_at = now() + interval '29 hours'
     from public.games where id = '00000000-0000-0000-0000-000000000401' $$,
  $$ values ('Ginásio Verdão'::text, true, true) $$,
  'J09b: local e horários gravados'
);
select results_eq(
  $$ select user_id, type::text, data ->> 'game_id', data ->> 'group_name', data ->> 'location_name',
            (data ->> 'starts_at')::timestamptz = now() + interval '27 hours'
     from public.notifications $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, 'game_updated'::text,
            '00000000-0000-0000-0000-000000000401'::text, 'Vôlei de Quinta'::text,
            'Ginásio Verdão'::text, true) $$,
  'J09c: só o Bruno é notificado (game_updated), com os dados do jogo'
);
rollback to savepoint j09;

-- J10. Bruno, membro na lista, e Diego, sem acesso.
savepoint j10;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000
     ) $$,
  'P0001', 'NOT_GAME_ADMIN', 'J10a: Bruno recebe NOT_GAME_ADMIN'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000
     ) $$,
  'P0001', 'NOT_FOUND', 'J10b: Diego recebe NOT_FOUND'
);
reset role;
rollback to savepoint j10;

-- J11. Jogo iniciado; jogo cancelado.
savepoint j11;
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
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000
     ) $$,
  'P0001', 'GAME_STARTED', 'J11a: jogo iniciado'
);
select throws_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000402', 'Ginásio Verdão', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000
     ) $$,
  'P0001', 'GAME_NOT_OPEN', 'J11b: jogo cancelado'
);
reset role;
rollback to savepoint j11;

-- J12. Datas inválidas na edição; nada muda.
savepoint j12;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() - interval '2 hours', now() - interval '1 hour', now() + interval '1 hour', 9000
     ) $$,
  'P0001', 'START_IN_PAST', 'J12a: início no passado'
);
select throws_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() + interval '27 hours', now() + interval '26 hours', now() + interval '28 hours', 9000
     ) $$,
  'P0001', 'INVALID_GAME_DATES', 'J12b: prazo depois do início'
);
reset role;
select results_eq(
  $$ select location_name, cancellation_deadline = now() + interval '1 day',
            starts_at = now() + interval '26 hours'
     from public.games where id = '00000000-0000-0000-0000-000000000401' $$,
  $$ values ('Quadra do Sesc'::text, true, true) $$,
  'J12c: nada muda'
);
rollback to savepoint j12;

-- J13. O prazo muda depois de um cancelamento fora do prazo (RN35).
savepoint j13;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '1 hour', now() + interval '1 hour', now() + interval '3 hours'
);
insert into public.game_participants (game_id, user_id, joined_at, status, left_at, late_cancellation)
values (
  '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b',
  now() - interval '2 hours', 'cancelled', now() - interval '30 minutes', true
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.update_game(
       '00000000-0000-0000-0000-000000000401', 'Quadra do Sesc', null,
       now() + interval '1 hour', now() + interval '1 hour', now() + interval '3 hours', 9000
     ) $$,
  'J13a: Ana muda o prazo para o início'
);
reset role;
select is(
  (select late_cancellation from public.game_participants
   where game_id = '00000000-0000-0000-0000-000000000401'
     and user_id = '00000000-0000-0000-0000-00000000000b'),
  true,
  'J13b: a passagem do Bruno continua com late_cancellation = true (RN35)'
);
rollback to savepoint j13;

-- =========================================================================
-- Etapa C: cancelar (RF39, RN43, RN67, RN114) e admins (RF34, RF35, RN25 a RN27)
-- =========================================================================


-- J14. Jogo base cheio (limite 3: Ana, Bruno e Carla), Edu na espera.
savepoint j14;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000c');
insert into public.game_waitlist (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000401') $$,
  'J14a: Ana cancela'
);
reset role;
select results_eq(
  $$ select status::text, cancelled_at = now(), cancelled_by from public.games
     where id = '00000000-0000-0000-0000-000000000401' $$,
  $$ values ('cancelled'::text, true, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'J14b: cancelled, cancelled_at = now() e cancelled_by = Ana'
);
select set_eq(
  $$ select user_id, type::text, data ->> 'game_id' as game_id from public.notifications $$,
  $$ values
       ('00000000-0000-0000-0000-00000000000b'::uuid, 'game_cancelled'::text, '00000000-0000-0000-0000-000000000401'::text),
       ('00000000-0000-0000-0000-00000000000c'::uuid, 'game_cancelled'::text, '00000000-0000-0000-0000-000000000401'::text),
       ('00000000-0000-0000-0000-00000000000e'::uuid, 'game_cancelled'::text, '00000000-0000-0000-0000-000000000401'::text) $$,
  'J14c: notifica Bruno, Carla e Edu (game_cancelled), e não Ana'
);
set local role authenticated;
select throws_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_NOT_OPEN', 'J14d: de novo, GAME_NOT_OPEN'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000e');
set local role authenticated;
select throws_ok(
  $$ select public.join_waitlist('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'GAME_NOT_OPEN', 'J14e: Edu na espera, GAME_NOT_OPEN'
);
reset role;
rollback to savepoint j14;

-- J15. Jogo iniciado; jogo depois do fim.
savepoint j15;
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000401',
  now() - interval '3 hours', now() - interval '1 hour', now() + interval '1 hour'
);
select pg_temp.make_game(
  '00000000-0000-0000-0000-000000000402',
  now() - interval '5 hours', now() - interval '3 hours', now() - interval '1 hour'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000401') $$,
  'J15a: jogo iniciado, aceito (RN43)'
);
select lives_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000402') $$,
  'J15b: jogo depois do fim, aceito'
);
reset role;
rollback to savepoint j15;

-- J16. Bruno, membro e não admin; Diego.
savepoint j16;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'NOT_GAME_ADMIN', 'J16a: Bruno'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.cancel_game('00000000-0000-0000-0000-000000000401') $$,
  'P0001', 'NOT_FOUND', 'J16b: Diego'
);
reset role;
rollback to savepoint j16;

-- J17 a J20 em sequência: Bruno vira admin, Ana deixa o papel, Bruno sai da lista.
savepoint j17;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
insert into public.game_waitlist (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.add_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  'J17a: Ana adiciona o Bruno'
);
reset role;
select is(
  (select added_by from public.game_admins
   where game_id = '00000000-0000-0000-0000-000000000401' and user_id = '00000000-0000-0000-0000-00000000000b'),
  '00000000-0000-0000-0000-00000000000a'::uuid, 'J17b: Bruno admin, com added_by = Ana'
);
set local role authenticated;
select throws_ok(
  $$ select public.add_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'ALREADY_GAME_ADMIN', 'J17c: de novo com o Bruno'
);
select throws_ok(
  $$ select public.add_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000e') $$,
  'P0001', 'ADMIN_MUST_BE_PARTICIPANT', 'J17d: Edu, na espera (RN27)'
);
select throws_ok(
  $$ select public.add_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000d') $$,
  'P0001', 'ADMIN_MUST_BE_PARTICIPANT', 'J17e: Diego'
);
reset role;
select is_empty($$ select 1 from public.notifications $$, 'J17f: nenhuma notificação');

-- J19. Depois do J17, Ana deixa de ser admin.
set local role authenticated;
select lives_ok(
  $$ select public.remove_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000a') $$,
  'J19a: Ana remove a si mesma'
);
reset role;
select results_eq(
  $$ select user_id from public.game_admins where game_id = '00000000-0000-0000-0000-000000000401' $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid) $$,
  'J19b: Bruno fica como único admin'
);
select results_eq(
  $$ select g.receiver_id, exists (
       select 1 from public.game_participants p
       where p.game_id = g.id and p.user_id = g.receiver_id and p.status = 'active')
     from public.games g where g.id = '00000000-0000-0000-0000-000000000401' $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, true) $$,
  'J19c: Ana continua na lista e recebedora'
);

-- J20. Bruno sai da lista antes do prazo e continua admin.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select lives_ok(
  $$ select public.leave_game('00000000-0000-0000-0000-000000000401') $$,
  'J20a: Bruno sai da lista'
);
reset role;
select ok(
  exists (select 1 from public.game_admins
          where game_id = '00000000-0000-0000-0000-000000000401' and user_id = '00000000-0000-0000-0000-00000000000b'),
  'J20b: Bruno continua admin (RN26)'
);
set local role authenticated;
select lives_ok(
  $$ select public.update_game('00000000-0000-0000-0000-000000000401', 'Ginásio Verdão', null,
       now() + interval '1 day', now() + interval '26 hours', now() + interval '28 hours', 9000) $$,
  'J20c: e o update_game dele é aceito'
);
reset role;
rollback to savepoint j17;

-- J18. Ana única admin.
savepoint j18;
select pg_temp.base_game();
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.remove_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000a') $$,
  'P0001', 'LAST_GAME_ADMIN', 'J18a: Ana remove a si mesma'
);
select throws_ok(
  $$ select public.remove_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000c') $$,
  'P0001', 'NOT_GAME_ADMIN_TARGET', 'J18b: Carla não é admin'
);
reset role;
rollback to savepoint j18;

-- J21. Bruno, membro e não admin; Diego.
savepoint j21;
select pg_temp.base_game();
select pg_temp.add_participant('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.add_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'NOT_GAME_ADMIN', 'J21a: Bruno'
);
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.add_game_admin('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'NOT_FOUND', 'J21b: Diego'
);
reset role;
rollback to savepoint j21;

-- Sem finish(): o rollback para cada savepoint apaga a tabela de resultados do
-- pgTAP (a numeração segue certa, porque vem de uma sequência). O pg_prove
-- confere o plano pelas linhas ok e not ok.
rollback;
