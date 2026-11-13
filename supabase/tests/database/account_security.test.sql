-- RLS da conta (fatia 2).
-- Cenários P01 a P16 de docs/testes-referencia.md, seção 10.1.
-- Políticas e privilégios: docs/rls-matriz.md, "Fatia 2".
--
-- "Ana logada" é `role authenticated` com o `sub` da Ana, como a API faz
-- (docs/arquitetura-app.md, 14.4). Os dados de preparo são gravados como postgres.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(38);

-- Ajudantes ------------------------------------------------------------------

-- Personagens do seed, criados aqui se faltarem (docs/arquitetura-app.md, 14.4).
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

-- Estado conhecido, independente do seed: Ana sem apelido e sem foto.
update public.profiles set nickname = null, photo_path = null, deleted_at = null
where id = '00000000-0000-0000-0000-00000000000a';

-- Linhas alteradas por um comando, para provar "nenhuma linha alterada".
create function pg_temp.affected(p_sql text)
returns integer
language plpgsql
as $fn$
declare
  v_count integer;
begin
  execute p_sql;
  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

grant execute on function pg_temp.affected(text) to authenticated;

create function pg_temp.login_as(p_user uuid)
returns void
language sql
as $fn$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
$fn$;

-- profiles -------------------------------------------------------------------

select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

-- P01
select results_eq(
  $$ select id from public.profiles $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P01: Ana lê só a própria linha de profiles'
);

-- P02 (RN100)
select is(
  pg_temp.affected($$ update public.profiles set nickname = 'Aninha'
                      where id = '00000000-0000-0000-0000-00000000000a' $$),
  1,
  'P02a: Ana grava o próprio apelido'
);
select is(
  (select display_name from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  'Aninha',
  'P02b: com apelido, display_name é o apelido (RN100)'
);
select pg_temp.affected($$ update public.profiles set nickname = null
                           where id = '00000000-0000-0000-0000-00000000000a' $$);
select is(
  (select display_name = name from public.profiles where id = '00000000-0000-0000-0000-00000000000a'),
  true,
  'P02c: sem apelido, display_name volta ao nome (RN100)'
);

-- P03
select is(
  pg_temp.affected($$ update public.profiles set name = 'Invadido'
                      where id = '00000000-0000-0000-0000-00000000000b' $$),
  0,
  'P03a: Ana não altera o perfil do Bruno'
);
reset role;
select isnt(
  (select name from public.profiles where id = '00000000-0000-0000-0000-00000000000b'),
  'Invadido',
  'P03b: o perfil do Bruno não muda'
);
set local role authenticated;

-- P04
select throws_ok(
  $$ update public.profiles set deleted_at = now() where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P04a: Ana não grava o próprio deleted_at'
);
select throws_ok(
  $$ update public.profiles set id = gen_random_uuid() where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P04b: Ana não grava o próprio id'
);

-- P05
select throws_ok(
  $$ update public.profiles
     set photo_path = 'profiles/00000000-0000-0000-0000-00000000000b/x.png'
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P05a: Ana não aponta a foto para a pasta do Bruno'
);
select lives_ok(
  $$ update public.profiles
     set photo_path = 'profiles/00000000-0000-0000-0000-00000000000a/x.png'
     where id = '00000000-0000-0000-0000-00000000000a' $$,
  'P05b: Ana aponta a foto para a própria pasta'
);
select lives_ok(
  $$ update public.profiles set photo_path = null where id = '00000000-0000-0000-0000-00000000000a' $$,
  'P05c: Ana remove a própria foto'
);

-- P06
reset role;
update public.profiles set deleted_at = now() where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select is(
  pg_temp.affected($$ update public.profiles set name = 'Outro nome'
                      where id = '00000000-0000-0000-0000-00000000000a' $$),
  0,
  'P06: perfil anonimizado não é editado pela própria pessoa'
);
reset role;
update public.profiles set deleted_at = null where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;

-- P07
select throws_ok(
  $$ insert into public.profiles (id, name) values (gen_random_uuid(), 'Novo') $$,
  '42501', null,
  'P07a: Ana não insere em profiles'
);
select throws_ok(
  $$ insert into public.profile_private (user_id) values ('00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'P07b: Ana não insere em profile_private'
);

-- profile_private ------------------------------------------------------------

-- P08
select results_eq(
  $$ select user_id from public.profile_private $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P08a: Ana lê só a própria linha de profile_private'
);
select is(
  pg_temp.affected($$ update public.profile_private set phone = '+5586999991234'
                      where user_id = '00000000-0000-0000-0000-00000000000a' $$),
  1,
  'P08b: Ana grava o próprio telefone'
);
select is(
  pg_temp.affected($$ update public.profile_private set phone = '+5586999991234'
                      where user_id = '00000000-0000-0000-0000-00000000000b' $$),
  0,
  'P08c: Ana não altera o telefone do Bruno'
);

-- P09
select throws_ok(
  $$ update public.profile_private set user_id = '00000000-0000-0000-0000-00000000000b'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null,
  'P09: Ana não grava o próprio user_id'
);

-- terms_acceptances e current_terms_versions() -------------------------------

-- P10
select set_eq(
  $$ select document::text, version from public.current_terms_versions() $$,
  $$ values ('terms_of_use', '1.0'), ('privacy_policy', '1.0') $$,
  'P10: current_terms_versions() devolve os dois documentos na versão 1.0'
);

-- P11: Ana sem aceite.
reset role;
delete from public.terms_acceptances where user_id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select lives_ok(
  $$ insert into public.terms_acceptances (user_id, document, version)
     values ('00000000-0000-0000-0000-00000000000a', 'terms_of_use', '1.0') $$,
  'P11a: Ana aceita a versão vigente dos Termos de Uso'
);
select is(
  (select accepted_at from public.terms_acceptances
   where user_id = '00000000-0000-0000-0000-00000000000a' and document = 'terms_of_use'),
  now(),
  'P11b: accepted_at vem do now() do servidor (RN02)'
);
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, document, version, accepted_at)
     values ('00000000-0000-0000-0000-00000000000a', 'privacy_policy', '1.0', now() - interval '1 day') $$,
  '42501', null,
  'P11c: Ana não informa accepted_at'
);

-- P12
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, document, version)
     values ('00000000-0000-0000-0000-00000000000a', 'privacy_policy', '0.9') $$,
  '42501', null,
  'P12a: aceite de versão que não é a vigente é recusado'
);
select throws_ok(
  $$ insert into public.terms_acceptances (user_id, document, version)
     values ('00000000-0000-0000-0000-00000000000b', 'privacy_policy', '1.0') $$,
  '42501', null,
  'P12b: aceite em nome de outra pessoa é recusado'
);

-- P13: Ana e Bruno com aceites.
reset role;
insert into public.terms_acceptances (user_id, document, version)
values ('00000000-0000-0000-0000-00000000000b', 'terms_of_use', '1.0')
on conflict do nothing;
set local role authenticated;
select results_eq(
  $$ select distinct user_id from public.terms_acceptances $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'P13: Ana lê só os próprios aceites'
);

-- P14: sem login.
reset role;
set local role anon;
select throws_ok($$ select 1 from public.profiles $$, '42501', null, 'P14a: anon não lê profiles');
select throws_ok(
  $$ select 1 from public.profile_private $$, '42501', null, 'P14b: anon não lê profile_private'
);
select throws_ok(
  $$ select 1 from public.terms_acceptances $$, '42501', null, 'P14c: anon não lê terms_acceptances'
);
select throws_ok(
  $$ select * from public.current_terms_versions() $$, '42501', null,
  'P14d: anon não executa current_terms_versions()'
);
reset role;

-- Storage, bucket avatars ----------------------------------------------------

-- P15
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', 'profiles/00000000-0000-0000-0000-00000000000a/' || gen_random_uuid() || '.png') $$,
  'P15a: Ana envia foto para a própria pasta'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', 'profiles/00000000-0000-0000-0000-00000000000b/' || gen_random_uuid() || '.png') $$,
  '42501', null,
  'P15b: Ana não envia foto para a pasta do Bruno'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', 'groups/' || gen_random_uuid() || '/' || gen_random_uuid() || '.png') $$,
  '42501', null,
  'P15c: Ana não envia foto para groups/ (fatia 3)'
);
reset role;

-- P16: um arquivo da Ana e um do Bruno.
insert into storage.objects (bucket_id, name)
values
  ('avatars', 'profiles/00000000-0000-0000-0000-00000000000a/p16.png'),
  ('avatars', 'profiles/00000000-0000-0000-0000-00000000000b/p16.png');

set local role authenticated;
select is_empty(
  $$ select name from storage.objects
     where bucket_id = 'avatars'
       and name not like 'profiles/00000000-0000-0000-0000-00000000000a/%' $$,
  'P16a: Ana não vê arquivo fora da própria pasta'
);
select ok(
  exists (select 1 from storage.objects
          where name = 'profiles/00000000-0000-0000-0000-00000000000a/p16.png'),
  'P16b: Ana vê o próprio arquivo'
);
select is(
  pg_temp.affected($$ update storage.objects set metadata = '{}'::jsonb
                      where bucket_id = 'avatars' and name like '%/p16.png' $$),
  0,
  'P16c: update em storage.objects não altera nenhuma linha (sem política de update)'
);

-- A API do Storage liga esta opção para apagar; o teste faz o mesmo, para que
-- quem decida seja o RLS (trigger storage.protect_delete).
set local storage.allow_delete_query = 'true';
select is(
  pg_temp.affected($$ delete from storage.objects
                      where name = 'profiles/00000000-0000-0000-0000-00000000000b/p16.png' $$),
  0,
  'P16d: Ana não apaga o arquivo do Bruno'
);
select is(
  pg_temp.affected($$ delete from storage.objects
                      where name = 'profiles/00000000-0000-0000-0000-00000000000a/p16.png' $$),
  1,
  'P16e: Ana apaga o próprio arquivo'
);
reset role;
select ok(
  exists (select 1 from storage.objects
          where name = 'profiles/00000000-0000-0000-0000-00000000000b/p16.png'),
  'P16f: o arquivo do Bruno continua no bucket'
);

select * from finish();
rollback;
