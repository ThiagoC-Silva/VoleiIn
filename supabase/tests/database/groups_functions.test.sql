-- Funções de grupo (fatia 3).
-- Cenários G01 a G33 de docs/testes-referencia.md, seção 11.1.
-- Contratos: docs/contratos-api.md, seção 3.
--
-- Base dos cenários, inserida aqui sem depender do seed (docs/arquitetura-app.md,
-- 14.4): o grupo Quinta, com o código VoleiQuinta1, Ana admin e Bruno membro.
-- Carla e Diego não estão em nenhum grupo. As linhas de grupo do seed são
-- apagadas dentro desta transação (research R3 de specs/002-grupos), e o
-- rollback do fim devolve tudo.
--
-- Cada cenário roda entre um savepoint e o rollback para ele, para começar da
-- base. "Ana logada" é o papel authenticated com o sub da Ana; o que prepara e
-- confere o cenário roda como postgres. Valores devolvidos pelas funções ficam
-- em configurações locais (t.*), lidas com current_setting.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(94);

-- Personagens (docs/setup.md, seção 8), criados aqui se faltarem.
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

-- Limpeza das linhas de grupo do seed (research R3).
-- Desde a fatia 4, o seed também põe Ana, Bruno e Carla nos mesmos jogos, que
-- também são contexto: os jogos saem antes (research R6 de specs/003-jogo-etapa-a).
-- Valores do jogo concluído do seed (fatia 5) saem antes das passagens.
delete from public.charge_events;
delete from public.charges;
delete from public.game_waitlist;
delete from public.game_participants;
delete from public.game_admins;
delete from public.game_limit_history;
delete from public.games;
delete from public.group_join_requests;
delete from public.group_members;
update public.groups set invite_code = null where invite_code is not null;
delete from public.notifications;

-- Base: o Quinta. Os IDs de teste (...0301 em diante) não colidem com os do seed.
insert into public.groups (id, name, invite_code, created_by)
values (
  '00000000-0000-0000-0000-000000000301', 'Vôlei de Quinta', 'VoleiQuinta1',
  '00000000-0000-0000-0000-00000000000a'
);
insert into public.group_members (group_id, user_id, role)
values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'admin'),
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b', 'member');

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

-- Roda uma chamada com o papel atual e devolve o jsonb dela ou, se falhar,
-- { "error": <mensagem> }, para a asserção falhar sem abortar o arquivo.
create function pg_temp.call(p_sql text)
returns jsonb
language plpgsql
as $fn$
declare
  v_result jsonb;
begin
  execute p_sql into v_result;
  return v_result;
exception when others then
  return jsonb_build_object('error', sqlerrm);
end;
$fn$;

-- Papel de uma pessoa no Quinta (nulo se não é membro).
create function pg_temp.role_in_quinta(p_user uuid)
returns text
language sql
as $fn$
  select role::text from public.group_members
  where group_id = '00000000-0000-0000-0000-000000000301' and user_id = p_user;
$fn$;

-- =========================================================================
-- Criar e editar (RF14, RF18, RN10, RN11)
-- =========================================================================

-- G01. Criar com espaços nas pontas.
savepoint g01;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.g01', public.create_group('  Vôlei de Sábado  ')::text, true) $$,
  'G01a: Ana cria o grupo'
);
reset role;
select matches(
  pg_temp.saved('g01') ->> 'invite_code', '^[0-9A-Za-z]{12}$',
  'G01b: devolve um invite_code de 12 caracteres base62'
);
select results_eq(
  format(
    $$ select name, created_by, invite_code from public.groups where id = %L $$,
    pg_temp.saved('g01') ->> 'group_id'
  ),
  format(
    $$ values ('Vôlei de Sábado'::text, '00000000-0000-0000-0000-00000000000a'::uuid, %L::text) $$,
    pg_temp.saved('g01') ->> 'invite_code'
  ),
  'G01c: o grupo tem o nome sem os espaços das pontas, created_by = Ana e o código devolvido'
);
select results_eq(
  format(
    $$ select user_id, role::text from public.group_members where group_id = %L $$,
    pg_temp.saved('g01') ->> 'group_id'
  ),
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, 'admin'::text) $$,
  'G01d: Ana é a única linha em group_members, como admin (RN10)'
);
rollback to savepoint g01;

-- G02. Tamanho do nome.
savepoint g02;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.create_group('') $$, 'P0001', 'INVALID_INPUT', 'G02a: nome vazio'
);
select throws_ok(
  $$ select public.create_group('   ') $$, 'P0001', 'INVALID_INPUT', 'G02b: nome só com espaços'
);
select throws_ok(
  $$ select public.create_group(repeat('a', 61)) $$, 'P0001', 'INVALID_INPUT',
  'G02c: nome com 61 caracteres'
);
select lives_ok(
  $$ select public.create_group(repeat('a', 60)) $$, 'G02d: nome com 60 caracteres é aceito'
);
reset role;
rollback to savepoint g02;

-- G03. Sem sub no JWT.
savepoint g03;
select set_config('request.jwt.claims', '{"role": "authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ select public.create_group('Teste') $$, 'P0001', 'NOT_AUTHENTICATED',
  'G03: create_group sem sub devolve NOT_AUTHENTICATED'
);
reset role;
rollback to savepoint g03;

-- G04. Nome e foto; depois sem foto.
savepoint g04;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.update_group(
       '00000000-0000-0000-0000-000000000301', 'Quinta à noite',
       'groups/00000000-0000-0000-0000-000000000301/7f1c2b9e-1111-4a4a-9b9b-000000000001.png'
     ) $$,
  'G04a: Ana grava nome e foto'
);
reset role;
select results_eq(
  $$ select name, photo_path from public.groups where id = '00000000-0000-0000-0000-000000000301' $$,
  $$ values ('Quinta à noite'::text,
            'groups/00000000-0000-0000-0000-000000000301/7f1c2b9e-1111-4a4a-9b9b-000000000001.png'::text) $$,
  'G04b: nome e foto gravados'
);
set local role authenticated;
select lives_ok(
  $$ select public.update_group('00000000-0000-0000-0000-000000000301', 'Quinta à noite', null) $$,
  'G04c: Ana retira a foto'
);
reset role;
select is(
  (select photo_path from public.groups where id = '00000000-0000-0000-0000-000000000301'),
  null,
  'G04d: photo_path nulo'
);
rollback to savepoint g04;

-- G05. Foto fora da pasta do grupo e nome vazio.
savepoint g05;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.update_group(
       '00000000-0000-0000-0000-000000000301', 'Quinta',
       'groups/00000000-0000-0000-0000-000000000304/x.png') $$,
  'P0001', 'INVALID_INPUT', 'G05a: foto na pasta de outro grupo'
);
select throws_ok(
  $$ select public.update_group(
       '00000000-0000-0000-0000-000000000301', 'Quinta',
       'profiles/00000000-0000-0000-0000-00000000000a/x.png') $$,
  'P0001', 'INVALID_INPUT', 'G05b: foto na pasta de perfil da Ana'
);
select throws_ok(
  $$ select public.update_group('00000000-0000-0000-0000-000000000301', '', null) $$,
  'P0001', 'INVALID_INPUT', 'G05c: nome vazio'
);
reset role;
select results_eq(
  $$ select name, photo_path from public.groups where id = '00000000-0000-0000-0000-000000000301' $$,
  $$ values ('Vôlei de Quinta'::text, null::text) $$,
  'G05d: nada muda'
);
rollback to savepoint g05;

-- G06. Membro comum e quem não é membro.
savepoint g06;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.update_group('00000000-0000-0000-0000-000000000301', 'Outro', null) $$,
  'P0001', 'NOT_GROUP_ADMIN', 'G06a: Bruno recebe NOT_GROUP_ADMIN'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ select public.update_group('00000000-0000-0000-0000-000000000301', 'Outro', null) $$,
  'P0001', 'NOT_FOUND', 'G06b: Diego recebe NOT_FOUND'
);
reset role;
rollback to savepoint g06;

-- =========================================================================
-- Convite (RF15, RN11)
-- =========================================================================

-- G07 e G08. Regenerar invalida o anterior; a solicitação existente continua.
savepoint g07;
insert into public.group_join_requests (group_id, user_id)
values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d');
update public.groups set invite_code_updated_at = now() - interval '1 day'
where id = '00000000-0000-0000-0000-000000000301';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select set_config(
       't.g07', public.regenerate_group_invite('00000000-0000-0000-0000-000000000301')::text, true) $$,
  'G07a: Ana regenera o código'
);
reset role;
select ok(
  pg_temp.saved('g07') ->> 'invite_code' ~ '^[0-9A-Za-z]{12}$'
    and pg_temp.saved('g07') ->> 'invite_code' <> 'VoleiQuinta1',
  'G07b: devolve um código novo, diferente de VoleiQuinta1'
);
select results_eq(
  $$ select invite_code, invite_code_updated_at from public.groups
     where id = '00000000-0000-0000-0000-000000000301' $$,
  format($$ values (%L::text, now()) $$, pg_temp.saved('g07') ->> 'invite_code'),
  'G07c: o código novo está gravado, com invite_code_updated_at = now()'
);
select is(
  (select status::text from public.group_join_requests
   where user_id = '00000000-0000-0000-0000-00000000000d'),
  'pending',
  'G07d: a solicitação do Diego continua pending'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
set local role authenticated;
select throws_ok(
  $$ select public.request_group_join('VoleiQuinta1') $$,
  'P0001', 'INVITE_INVALID', 'G08a: o código antigo não vale mais'
);
select lives_ok(
  format($$ select public.request_group_join(%L) $$, pg_temp.saved('g07') ->> 'invite_code'),
  'G08b: o código novo é aceito'
);
reset role;
rollback to savepoint g07;

-- G09. Desativar e gerar de novo.
savepoint g09;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.invalidate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'G09a: Ana desativa o convite'
);
reset role;
select is(
  (select invite_code from public.groups where id = '00000000-0000-0000-0000-000000000301'),
  null,
  'G09b: invite_code nulo'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
set local role authenticated;
select throws_ok(
  $$ select public.request_group_join('VoleiQuinta1') $$,
  'P0001', 'INVITE_INVALID', 'G09c: Carla pede com o código desativado'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
select lives_ok(
  $$ select public.regenerate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'G09d: Ana gera um código novo'
);
reset role;
select matches(
  (select invite_code from public.groups where id = '00000000-0000-0000-0000-000000000301'),
  '^[0-9A-Za-z]{12}$',
  'G09e: o grupo tem um código novo'
);
rollback to savepoint g09;

-- G10. Membro comum e quem não é membro.
savepoint g10;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.regenerate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_GROUP_ADMIN', 'G10a: Bruno não regenera'
);
select throws_ok(
  $$ select public.invalidate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_GROUP_ADMIN', 'G10b: Bruno não desativa'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ select public.regenerate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_FOUND', 'G10c: Diego recebe NOT_FOUND ao regenerar'
);
select throws_ok(
  $$ select public.invalidate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_FOUND', 'G10d: Diego recebe NOT_FOUND ao desativar'
);
reset role;
rollback to savepoint g10;

-- =========================================================================
-- Solicitações (RF16, RF17, RN12)
-- =========================================================================

-- G11 a G13. Pedir, pedir de novo e pedir sendo membro.
savepoint g11;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select lives_ok(
  $$ select set_config('t.g11', public.request_group_join('VoleiQuinta1')::text, true) $$,
  'G11a: Diego pede para entrar'
);
reset role;
select results_eq(
  format(
    $$ select group_id, user_id, status::text from public.group_join_requests where id = %L $$,
    pg_temp.saved('g11') ->> 'request_id'
  ),
  $$ values ('00000000-0000-0000-0000-000000000301'::uuid,
            '00000000-0000-0000-0000-00000000000d'::uuid, 'pending'::text) $$,
  'G11b: a solicitação devolvida é do Diego no Quinta e fica pending'
);
select is(
  pg_temp.saved('g11') ->> 'group_id',
  '00000000-0000-0000-0000-000000000301',
  'G11c: devolve o group_id do Quinta'
);
select results_eq(
  $$ select user_id, type::text, data from public.notifications $$,
  format(
    $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, 'group_join_requested'::text,
              jsonb_build_object('group_id', '00000000-0000-0000-0000-000000000301',
                                 'group_name', 'Vôlei de Quinta', 'request_id', %L)) $$,
    pg_temp.saved('g11') ->> 'request_id'
  ),
  'G11d: notifica só a Ana (group_join_requested), com os dados do contrato'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.request_group_join('VoleiQuinta1') $$,
  'P0001', 'JOIN_REQUEST_PENDING', 'G12: Diego pede de novo'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$ select public.request_group_join('VoleiQuinta1') $$,
  'P0001', 'ALREADY_MEMBER', 'G13: Bruno já é membro'
);
reset role;
rollback to savepoint g11;

-- G14. Caixa diferente, código inexistente e grupo arquivado.
savepoint g14;
insert into public.groups (id, name, created_by, archived_at, archived_by)
values (
  '00000000-0000-0000-0000-000000000303', 'Antigo', '00000000-0000-0000-0000-00000000000a',
  now() - interval '1 day', '00000000-0000-0000-0000-00000000000a'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.request_group_join('voleiquinta1') $$,
  'P0001', 'INVITE_INVALID', 'G14a: outra caixa'
);
select throws_ok(
  $$ select public.request_group_join('VoleiQuinta2') $$,
  'P0001', 'INVITE_INVALID', 'G14b: código que não existe'
);
select throws_ok(
  $$ select public.request_group_join('VoleiAntigo1') $$,
  'P0001', 'INVITE_INVALID', 'G14c: código do grupo arquivado'
);
reset role;
rollback to savepoint g14;

-- G15. Aprovar.
savepoint g15;
with r as (
  insert into public.group_join_requests (group_id, user_id)
  values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d')
  returning id
)
select set_config('t.req', to_jsonb(id)::text, true) from r;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  format($$ select public.decide_join_request(%L, true) $$, pg_temp.saved('req') #>> '{}'),
  'G15a: Ana aprova'
);
reset role;
select results_eq(
  format(
    $$ select status::text, decided_by, decided_at from public.group_join_requests where id = %L $$,
    pg_temp.saved('req') #>> '{}'
  ),
  $$ values ('approved'::text, '00000000-0000-0000-0000-00000000000a'::uuid, now()) $$,
  'G15b: approved, decided_by = Ana, decided_at = now()'
);
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000d'), 'member',
  'G15c: Diego entra como member'
);
select results_eq(
  $$ select user_id, type::text, data from public.notifications $$,
  format(
    $$ values ('00000000-0000-0000-0000-00000000000d'::uuid, 'group_join_decided'::text,
              jsonb_build_object('group_id', '00000000-0000-0000-0000-000000000301',
                                 'group_name', 'Vôlei de Quinta', 'request_id', %L,
                                 'approved', true)) $$,
    pg_temp.saved('req') #>> '{}'
  ),
  'G15d: notifica o Diego (group_join_decided, approved: true)'
);
rollback to savepoint g15;

-- G16. Recusar e pedir de novo.
savepoint g16;
with r as (
  insert into public.group_join_requests (group_id, user_id)
  values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d')
  returning id
)
select set_config('t.req', to_jsonb(id)::text, true) from r;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  format($$ select public.decide_join_request(%L, false) $$, pg_temp.saved('req') #>> '{}'),
  'G16a: Ana recusa'
);
reset role;
select is(
  (select status::text from public.group_join_requests where id = (pg_temp.saved('req') #>> '{}')::uuid),
  'rejected',
  'G16b: rejected'
);
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000d'), null,
  'G16c: Diego não vira membro'
);
select results_eq(
  $$ select user_id, type::text, data from public.notifications $$,
  format(
    $$ values ('00000000-0000-0000-0000-00000000000d'::uuid, 'group_join_decided'::text,
              jsonb_build_object('group_id', '00000000-0000-0000-0000-000000000301',
                                 'group_name', 'Vôlei de Quinta', 'request_id', %L,
                                 'approved', false)) $$,
    pg_temp.saved('req') #>> '{}'
  ),
  'G16d: notifica o Diego (approved: false)'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select lives_ok(
  $$ select public.request_group_join('VoleiQuinta1') $$,
  'G16e: depois da recusa, Diego pode pedir de novo (RN12)'
);
reset role;
rollback to savepoint g16;

-- G17. Decidir o que já foi decidido.
savepoint g17;
with r as (
  insert into public.group_join_requests (group_id, user_id, status, decided_at, decided_by)
  values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000c',
          'approved', now(), '00000000-0000-0000-0000-00000000000a')
  returning id
)
select set_config('t.req', to_jsonb(id)::text, true) from r;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  format($$ select public.decide_join_request(%L, false) $$, pg_temp.saved('req') #>> '{}'),
  'P0001', 'REQUEST_NOT_PENDING', 'G17: solicitação já aprovada'
);
reset role;
rollback to savepoint g17;

-- G18. Quem não pode decidir.
savepoint g18;
with r as (
  insert into public.group_join_requests (group_id, user_id)
  values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d')
  returning id
)
select set_config('t.req', to_jsonb(id)::text, true) from r;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  format($$ select public.decide_join_request(%L, true) $$, pg_temp.saved('req') #>> '{}'),
  'P0001', 'NOT_FOUND', 'G18a: Bruno, membro comum, não vê a solicitação'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  format($$ select public.decide_join_request(%L, true) $$, pg_temp.saved('req') #>> '{}'),
  'P0001', 'NOT_GROUP_ADMIN', 'G18b: Diego não decide a própria'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000c');
select throws_ok(
  format($$ select public.decide_join_request(%L, true) $$, pg_temp.saved('req') #>> '{}'),
  'P0001', 'NOT_FOUND', 'G18c: Carla não vê a solicitação'
);
reset role;
rollback to savepoint g18;

-- =========================================================================
-- Papéis (RF23, RF24, RN10, RN13)
-- =========================================================================

-- G19. Promover e ser rebaixada pelo promovido.
savepoint g19;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.set_group_role(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b', 'admin') $$,
  'G19a: Ana promove Bruno'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select lives_ok(
  $$ select public.set_group_role(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'member') $$,
  'G19b: Bruno rebaixa Ana'
);
reset role;
select results_eq(
  $$ select user_id from public.group_members
     where group_id = '00000000-0000-0000-0000-000000000301' and role = 'admin' $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid) $$,
  'G19c: Bruno é o único admin'
);
rollback to savepoint g19;

-- G20. A única admin não se rebaixa.
savepoint g20;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.set_group_role(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'member') $$,
  'P0001', 'LAST_ADMIN', 'G20a: LAST_ADMIN'
);
reset role;
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000a'), 'admin',
  'G20b: Ana continua admin'
);
rollback to savepoint g20;

-- G21. O papel que a pessoa já tem.
savepoint g21;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is(
  pg_temp.call($$ select public.set_group_role(
    '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'admin') $$),
  '{"user_id": "00000000-0000-0000-0000-00000000000a", "role": "admin"}'::jsonb,
  'G21a: aceito, devolve { user_id, role }'
);
reset role;
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000a'), 'admin',
  'G21b: sem mudança'
);
rollback to savepoint g21;

-- G22. Alvo fora do grupo, membro comum e quem não é membro.
savepoint g22;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.set_group_role(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d', 'admin') $$,
  'P0001', 'TARGET_NOT_MEMBER', 'G22a: Ana promove o Diego, que não é membro'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$ select public.set_group_role(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a', 'member') $$,
  'P0001', 'NOT_GROUP_ADMIN', 'G22b: Bruno não rebaixa a Ana'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ select public.set_group_role(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b', 'admin') $$,
  'P0001', 'NOT_FOUND', 'G22c: Diego recebe NOT_FOUND'
);
reset role;
rollback to savepoint g22;

-- =========================================================================
-- Saída, remoção e exclusão (RF20, RF21, RF103, RN13, RN17)
-- =========================================================================

-- G23. Membro comum sai.
savepoint g23;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select is(
  pg_temp.call($$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$),
  '{"games_left": []}'::jsonb,
  'G23a: devolve games_left vazio (RN16 e jogos na fatia 4)'
);
reset role;
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000b'), null,
  'G23b: Bruno sai de group_members'
);
select is_empty($$ select id from public.notifications $$, 'G23c: nenhuma notificação');
rollback to savepoint g23;

-- G24. A única admin não sai.
savepoint g24;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'LAST_ADMIN', 'G24: LAST_ADMIN'
);
reset role;
rollback to savepoint g24;

-- G25. Único membro: só exclui o grupo.
savepoint g25;
insert into public.groups (id, name, invite_code, created_by)
values ('00000000-0000-0000-0000-000000000302', 'Solo', 'VoleiSolo123',
        '00000000-0000-0000-0000-00000000000a');
insert into public.group_members (group_id, user_id, role)
values ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-00000000000a', 'admin');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000302') $$,
  'P0001', 'LAST_ADMIN', 'G25: o único membro recebe LAST_ADMIN (RN13)'
);
reset role;
rollback to savepoint g25;

-- G26. Quem não é membro.
savepoint g26;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
set local role authenticated;
select throws_ok(
  $$ select public.leave_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_FOUND', 'G26: Diego recebe NOT_FOUND'
);
reset role;
rollback to savepoint g26;

-- G27. Remover um membro.
savepoint g27;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is(
  pg_temp.call($$ select public.remove_group_member(
    '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b') $$),
  '{"games_left": []}'::jsonb,
  'G27a: Ana remove Bruno'
);
reset role;
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000b'), null,
  'G27b: Bruno sai de group_members'
);
select results_eq(
  $$ select user_id, type::text, data from public.notifications $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, 'removed_from_group'::text,
            '{"group_id": "00000000-0000-0000-0000-000000000301",
              "group_name": "Vôlei de Quinta", "reason": "removed"}'::jsonb) $$,
  'G27c: notifica o Bruno (removed_from_group, reason: removed)'
);
rollback to savepoint g27;

-- G28. Remover outro admin.
savepoint g28;
update public.group_members set role = 'admin'
where group_id = '00000000-0000-0000-0000-000000000301'
  and user_id = '00000000-0000-0000-0000-00000000000b';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.remove_group_member(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b') $$,
  'G28a: Ana remove o Bruno admin'
);
reset role;
select is(
  pg_temp.role_in_quinta('00000000-0000-0000-0000-00000000000a'), 'admin',
  'G28b: Ana continua admin'
);
rollback to savepoint g28;

-- G29. Erros da remoção.
savepoint g29;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.remove_group_member(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a') $$,
  'P0001', 'CANNOT_REMOVE_SELF', 'G29a: Ana remove a si mesma'
);
select throws_ok(
  $$ select public.remove_group_member(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d') $$,
  'P0001', 'TARGET_NOT_MEMBER', 'G29b: Ana remove o Diego, que não é membro'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  $$ select public.remove_group_member(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000a') $$,
  'P0001', 'NOT_GROUP_ADMIN', 'G29c: Bruno remove a Ana'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ select public.remove_group_member(
       '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000b') $$,
  'P0001', 'NOT_FOUND', 'G29d: Diego recebe NOT_FOUND'
);
reset role;
rollback to savepoint g29;

-- G30 e G33. Excluir (arquivar) e, depois, tentar alterar.
savepoint g30;
with r as (
  insert into public.group_join_requests (group_id, user_id)
  values ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-00000000000d')
  returning id
)
select set_config('t.req', to_jsonb(id)::text, true) from r;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is(
  pg_temp.call($$ select public.archive_group('00000000-0000-0000-0000-000000000301') $$),
  '{"group_id": "00000000-0000-0000-0000-000000000301"}'::jsonb,
  'G30a: Ana exclui o Quinta'
);
reset role;
select results_eq(
  $$ select archived_at, archived_by, invite_code from public.groups
     where id = '00000000-0000-0000-0000-000000000301' $$,
  $$ values (now(), '00000000-0000-0000-0000-00000000000a'::uuid, null::text) $$,
  'G30b: archived_at = now(), archived_by = Ana, invite_code nulo'
);
select is_empty(
  $$ select user_id from public.group_members
     where group_id = '00000000-0000-0000-0000-000000000301' $$,
  'G30c: group_members vazio'
);
select results_eq(
  format(
    $$ select status::text, decided_at, decided_by from public.group_join_requests where id = %L $$,
    pg_temp.saved('req') #>> '{}'
  ),
  $$ values ('cancelled'::text, now(), null::uuid) $$,
  'G30d: a solicitação do Diego fica cancelled, com decided_at = now() e decided_by nulo'
);
select results_eq(
  $$ select user_id, type::text, data from public.notifications $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, 'removed_from_group'::text,
            '{"group_id": "00000000-0000-0000-0000-000000000301",
              "group_name": "Vôlei de Quinta", "reason": "archived"}'::jsonb) $$,
  'G30e: notifica o Bruno (reason: archived), e não a Ana'
);
select results_eq(
  $$ select event, actor_id, entity_id from public.audit_log
     where entity_id = '00000000-0000-0000-0000-000000000301' $$,
  $$ values ('group_archived'::text, '00000000-0000-0000-0000-00000000000a'::uuid,
            '00000000-0000-0000-0000-000000000301'::uuid) $$,
  'G30f: uma linha group_archived em audit_log, com actor_id = Ana'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.update_group('00000000-0000-0000-0000-000000000301', 'De volta', null) $$,
  'P0001', 'NOT_FOUND', 'G33a: update_group no grupo arquivado'
);
select throws_ok(
  $$ select public.regenerate_group_invite('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_FOUND', 'G33b: regenerate_group_invite no grupo arquivado'
);
reset role;
rollback to savepoint g30;

-- G31. Jogos Abertos ou Confirmados impedem a exclusão (RN17).
savepoint g31;
insert into public.games (
  id, group_id, created_by, location_name, cancellation_deadline, starts_at, ends_at,
  total_cents, slot_limit, receiver_id, invite_code
)
values (
  '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-00000000000a', 'Arena', now() + interval '1 day',
  now() + interval '1 day 2 hours', now() + interval '1 day 4 hours', 12000, 12,
  '00000000-0000-0000-0000-00000000000a', 'JogoQuinta01'
);
insert into public.game_admins (game_id, user_id)
values ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-00000000000a');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$ select public.archive_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'GROUP_HAS_ACTIVE_GAMES', 'G31a: jogo open'
);
reset role;
update public.games set status = 'confirmed' where id = '00000000-0000-0000-0000-000000000401';
set local role authenticated;
select throws_ok(
  $$ select public.archive_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'GROUP_HAS_ACTIVE_GAMES', 'G31b: jogo confirmed'
);
reset role;
update public.games set status = 'cancelled', cancelled_at = now()
where id = '00000000-0000-0000-0000-000000000401';
insert into public.games (
  id, group_id, created_by, location_name, cancellation_deadline, starts_at, ends_at,
  total_cents, slot_limit, receiver_id, invite_code, status, share_cents, completed_at,
  completion_mode
)
values (
  '00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000301',
  '00000000-0000-0000-0000-00000000000a', 'Arena', now() - interval '2 days',
  now() - interval '2 days', now() - interval '2 days' + interval '2 hours', 12000, 12,
  '00000000-0000-0000-0000-00000000000a', 'JogoQuinta02', 'completed', 1000,
  now() - interval '1 day', 'manual'
);
insert into public.game_admins (game_id, user_id)
values ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ select public.archive_group('00000000-0000-0000-0000-000000000301') $$,
  'G31c: só jogos cancelled e completed, a exclusão é aceita'
);
reset role;
rollback to savepoint g31;

-- G32. Membro comum e quem não é membro.
savepoint g32;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$ select public.archive_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_GROUP_ADMIN', 'G32a: Bruno não exclui'
);
select pg_temp.login_as('00000000-0000-0000-0000-00000000000d');
select throws_ok(
  $$ select public.archive_group('00000000-0000-0000-0000-000000000301') $$,
  'P0001', 'NOT_FOUND', 'G32b: Diego recebe NOT_FOUND'
);
reset role;
rollback to savepoint g32;

-- Sem finish(): o rollback para cada savepoint apaga a tabela de resultados do
-- pgTAP (a numeração segue certa, porque vem de uma sequência). O pg_prove
-- confere o plano pelas linhas ok e not ok.
rollback;
