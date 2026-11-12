-- RLS da conta (fatia 2).
-- Cenários P01 a P16 de docs/testes-referencia.md, seção 10.1.
-- Políticas e privilégios: docs/rls-matriz.md, fatia 2.
--
-- "Ana logada" é o papel authenticated com o sub da Ana, como a API faz
-- (docs/arquitetura-app.md, 14.4). O que prepara o cenário roda como postgres.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(42);

-- Personagens do seed (docs/setup.md, seção 8), criados aqui se faltarem, para o
-- teste rodar também sem o seed (docs/setup.md, 9.2).
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
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'bruno@voleiin.test', 'Bruno')
) as u (id, email, name)
on conflict do nothing;

-- Estado inicial dos cenários, igual com ou sem o seed.
update public.profiles
set name = v.name, nickname = null, photo_path = null, deleted_at = null
from (
  values
    ('00000000-0000-0000-0000-00000000000a'::uuid, 'Ana'),
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'Bruno')
) as v (id, name)
where profiles.id = v.id;

update public.profile_private
set phone = null, phone_visible = false, pix_key_type = null, pix_key = null
where user_id in (
  '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'
);

delete from public.terms_acceptances
where user_id in (
  '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'
);

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

select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

-- P01. Ana lê só o próprio perfil.
select results_eq(
  $$ select id from public.profiles $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P01: Ana logada vê só a própria linha de profiles'
);

-- P02. O apelido muda o nome exibido, e apagá-lo devolve o nome (RN100).
select lives_ok(
  $$ update public.profiles set nickname = 'Aninha'
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'P02a: Ana grava o próprio apelido'
);
select is(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'Aninha',
  'P02b: o display_name vira o apelido (RN100)'
);
select lives_ok(
  $$ update public.profiles set nickname = null
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'P02c: Ana apaga o próprio apelido'
);
select is(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'Ana',
  'P02d: sem apelido, o display_name volta ao name (RN100)'
);

-- P03. Ana não altera o perfil do Bruno.
select is(
  (with changed as (
     update public.profiles set name = 'Outro nome'
     where id = '00000000-0000-0000-0000-00000000000b'
     returning 1
   )
   select count(*) from changed),
  0::bigint,
  'P03a: update do name do Bruno não altera nenhuma linha'
);

reset role;
select is(
  (select name from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'Bruno',
  'P03b: o perfil do Bruno não muda'
);
set local role authenticated;

-- P04. Colunas fora da lista não são graváveis.
select throws_ok(
  $$ update public.profiles set deleted_at = now()
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P04a: update do próprio deleted_at devolve 42501'
);
select throws_ok(
  $$ update public.profiles set id = gen_random_uuid()
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P04b: update do próprio id devolve 42501'
);

-- P05. O photo_path só aponta para a pasta da própria pessoa.
select throws_ok(
  $$ update public.profiles
     set photo_path = 'profiles/00000000-0000-0000-0000-00000000000b/x.png'
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P05a: photo_path na pasta do Bruno é recusado pelo RLS'
);
select lives_ok(
  $$ update public.profiles
     set photo_path = 'profiles/00000000-0000-0000-0000-00000000000a/x.png'
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'P05b: photo_path na própria pasta é aceito'
);
select lives_ok(
  $$ update public.profiles set photo_path = null
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'P05c: photo_path nulo é aceito'
);

-- P06. Perfil anonimizado não é editável.
reset role;
update public.profiles set deleted_at = now()
where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;

select is(
  (with changed as (
     update public.profiles set name = 'Ana de novo'
     where id = '00000000-0000-0000-0000-00000000000a'
     returning 1
   )
   select count(*) from changed),
  0::bigint,
  'P06: com deleted_at preenchido, o update do próprio name não altera nenhuma linha'
);

reset role;
update public.profiles set deleted_at = null
where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;

-- P07. As duas linhas nascem pela trigger, nunca pelo app.
select throws_ok(
  $$ insert into public.profiles (id, name) values (gen_random_uuid(), 'Intruso') $$,
  '42501', null,
  'P07a: insert em profiles devolve 42501'
);
select throws_ok(
  $$ insert into public.profile_private (user_id)
     values ('00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'P07b: insert em profile_private devolve 42501'
);

-- P08. Dados privados: só os próprios.
select results_eq(
  $$ select user_id from public.profile_private $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P08a: Ana logada vê só a própria linha de profile_private'
);
select lives_ok(
  $$ update public.profile_private set phone = '+5586999991234'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P08b: Ana grava o próprio telefone'
);
select is(
  (select phone from public.profile_private
   where user_id = '00000000-0000-0000-0000-00000000000a'),
  '+5586999991234',
  'P08c: o telefone ficou gravado'
);
select is(
  (with changed as (
     update public.profile_private set phone = '+5586999990000'
     where user_id = '00000000-0000-0000-0000-00000000000b'
     returning 1
   )
   select count(*) from changed),
  0::bigint,
  'P08d: update do phone do Bruno não altera nenhuma linha'
);

-- P09. O dono da linha privada não muda.
select throws_ok(
  $$ update public.profile_private set user_id = '00000000-0000-0000-0000-00000000000b'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P09: update do próprio user_id em profile_private devolve 42501'
);

-- P10. Versões vigentes dos termos.
select set_eq(
  $$ select document::text, version from public.current_terms_versions() $$,
  $$ values ('terms_of_use', '1.0'), ('privacy_policy', '1.0') $$,
  'P10: current_terms_versions() devolve terms_of_use e privacy_policy na versão 1.0'
);

-- P11. Aceite próprio, com o instante do servidor.
select lives_ok(
  $$ insert into public.terms_acceptances (user_id, document, version)
     values ('00000000-0000-0000-0000-00000000000a', 'terms_of_use', '1.0') $$,
  'P11a: Ana insere o próprio aceite da versão vigente'
);
select is(
  (select accepted_at from public.terms_acceptances
   where user_id = '00000000-0000-0000-0000-00000000000a' and document = 'terms_of_use'),
  now(),
  'P11b: o accepted_at é o now() do servidor (RN02)'
);
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, document, version, accepted_at)
     values ('00000000-0000-0000-0000-00000000000a', 'privacy_policy', '1.0',
             now() - interval '1 year') $$,
  '42501', null,
  'P11c: aceite com accepted_at informado devolve 42501'
);

-- P12. Só a versão vigente e só em nome próprio.
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, document, version)
     values ('00000000-0000-0000-0000-00000000000a', 'privacy_policy', '0.9') $$,
  '42501', null,
  'P12a: aceite da versão 0.9 devolve 42501'
);
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, document, version)
     values ('00000000-0000-0000-0000-00000000000b', 'privacy_policy', '1.0') $$,
  '42501', null,
  'P12b: aceite em nome do Bruno devolve 42501'
);

-- P13. Ana lê só os próprios aceites.
reset role;
insert into public.terms_acceptances (user_id, document, version)
values
  ('00000000-0000-0000-0000-00000000000a', 'privacy_policy', '1.0'),
  ('00000000-0000-0000-0000-00000000000b', 'terms_of_use', '1.0'),
  ('00000000-0000-0000-0000-00000000000b', 'privacy_policy', '1.0');
set local role authenticated;

select results_eq(
  $$ select distinct user_id from public.terms_acceptances $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P13a: Ana logada vê só os próprios aceites'
);
select is(
  (select count(*) from public.terms_acceptances),
  2::bigint,
  'P13b: são os dois aceites da Ana'
);

-- P14. Sem login, nada.
reset role;
select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
set local role anon;

select throws_ok(
  $$ select id from public.profiles $$, '42501', null,
  'P14a: anon não lê profiles'
);
select throws_ok(
  $$ select user_id from public.profile_private $$, '42501', null,
  'P14b: anon não lê profile_private'
);
select throws_ok(
  $$ select id from public.terms_acceptances $$, '42501', null,
  'P14c: anon não lê terms_acceptances'
);
select throws_ok(
  $$ select * from public.current_terms_versions() $$, '42501', null,
  'P14d: anon não executa current_terms_versions()'
);

-- P15. Envio de foto: só na própria pasta de profiles/.
reset role;
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars',
             'profiles/00000000-0000-0000-0000-00000000000a/11111111-1111-4111-8111-111111111111.png') $$,
  'P15a: Ana envia arquivo para a própria pasta'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars',
             'profiles/00000000-0000-0000-0000-00000000000b/22222222-2222-4222-8222-222222222222.png') $$,
  '42501', null,
  'P15b: Ana não envia arquivo para a pasta do Bruno'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars',
             'groups/33333333-3333-4333-8333-333333333333/44444444-4444-4444-8444-444444444444.png') $$,
  '42501', null,
  'P15c: a pasta groups/ continua fechada até a fatia 3'
);

-- P16. Leitura, alteração e remoção: só os próprios arquivos.
reset role;
insert into storage.objects (bucket_id, name)
values ('avatars',
        'profiles/00000000-0000-0000-0000-00000000000b/55555555-5555-4555-8555-555555555555.png');
set local role authenticated;

select results_eq(
  $$ select name from storage.objects where bucket_id = 'avatars' $$,
  $$ values ('profiles/00000000-0000-0000-0000-00000000000a/11111111-1111-4111-8111-111111111111.png') $$,
  'P16a: Ana vê só o próprio arquivo'
);
select is(
  (with changed as (
     update storage.objects set name = name || '.bak' where bucket_id = 'avatars' returning 1
   )
   select count(*) from changed),
  0::bigint,
  'P16b: update em storage.objects não altera nenhuma linha (sem política de update)'
);

-- O Storage bloqueia o delete direto na tabela, fora da API dele. O teste liga a
-- mesma chave que a API liga, para exercitar só a política.
set local storage.allow_delete_query = 'true';

select is(
  (with removed as (
     delete from storage.objects where bucket_id = 'avatars' returning 1
   )
   select count(*) from removed),
  1::bigint,
  'P16c: o delete apaga só o arquivo da Ana'
);

reset role;
select is(
  (select count(*) from storage.objects
   where bucket_id = 'avatars'
     and name like 'profiles/00000000-0000-0000-0000-00000000000b/%'),
  1::bigint,
  'P16d: o arquivo do Bruno continua lá'
);
select is(
  (select count(*) from storage.objects
   where bucket_id = 'avatars'
     and name like 'profiles/00000000-0000-0000-0000-00000000000a/%'),
  0::bigint,
  'P16e: o arquivo da Ana foi apagado'
);

-- Bruno, por sua vez, vê só o dele: a regra vale para os dois lados.
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;

select results_eq(
  $$ select id from public.profiles $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid) $$,
  'P01b: Bruno logado vê só a própria linha de profiles'
);
select results_eq(
  $$ select name from storage.objects where bucket_id = 'avatars' $$,
  $$ values ('profiles/00000000-0000-0000-0000-00000000000b/55555555-5555-4555-8555-555555555555.png') $$,
  'P16f: Bruno vê só o próprio arquivo'
);

reset role;

select * from finish();
rollback;
