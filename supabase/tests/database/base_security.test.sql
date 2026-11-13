-- Segurança da base (fatia 1).
-- Cenários B01 a B10 de docs/testes-referencia.md, seção 9.1.
-- Documento de referência das políticas e privilégios: docs/rls-matriz.md.
--
-- B03, B04, B06 e B10 comparam o banco com uma LISTA ESPERADA. Na fatia 1 as
-- listas eram vazias. Cada fatia acrescenta aqui, no mesmo PR, as políticas, os
-- privilégios e as funções que concede (docs/rls-matriz.md, 5). As listas abaixo
-- são as da fatia 2 (docs/testes-referencia.md, seção 10).

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

-- B01. Nenhuma tabela de public sem RLS. É o teste "tabela sem RLS" do CI.
select is_empty(
  $$ select c.relname::text
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and not c.relrowsecurity
       and not exists (select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') $$,
  'B01: toda tabela de public tem RLS ativado'
);

-- B02. Exatamente as 20 tabelas da seção 4 do modelo-dados.md.
select set_eq(
  $$ select c.relname::text
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('r', 'p')
       and not exists (select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') $$,
  array[
    'profiles', 'profile_private', 'terms_acceptances',
    'groups', 'group_members', 'group_join_requests',
    'games', 'game_limit_history', 'game_admins', 'game_participants', 'game_waitlist',
    'receiver_changes', 'charges', 'charge_events', 'receipts',
    'device_tokens', 'notification_preferences', 'notifications',
    'scheduled_notifications_log', 'audit_log'
  ],
  'B02: public tem exatamente as 20 tabelas do modelo de dados'
);

-- B03. Políticas de public. Lista esperada da fatia 2 (rls-matriz.md, Fatia 2).
select set_eq(
  $$ select tablename || '.' || policyname from pg_policies where schemaname = 'public' $$,
  array[
    'profiles.profiles_select_own',
    'profiles.profiles_update_own',
    'profile_private.profile_private_select_own',
    'profile_private.profile_private_update_own',
    'terms_acceptances.terms_acceptances_select_own',
    'terms_acceptances.terms_acceptances_insert_own'
  ],
  'B03: as políticas de public são exatamente as da fatia 2'
);

-- B04. Privilégios de tabela e de coluna de anon e authenticated em public.
-- Lista esperada da fatia 2. anon continua sem nenhum.
select set_eq(
  $$ select a.grantee::regrole::text || ' ' || c.relname || ' ' || a.privilege_type
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     cross join aclexplode(c.relacl) a
     where n.nspname = 'public'
       and a.grantee::regrole::text in ('anon', 'authenticated') $$,
  array[
    'authenticated profiles SELECT',
    'authenticated profile_private SELECT',
    'authenticated terms_acceptances SELECT'
  ],
  'B04a: privilégios de tabela de anon e authenticated são os da fatia 2'
);

select set_eq(
  $$ select a.grantee::regrole::text || ' ' || c.relname || '.' || att.attname || ' ' || a.privilege_type
     from pg_attribute att
     join pg_class c on c.oid = att.attrelid
     join pg_namespace n on n.oid = c.relnamespace
     cross join aclexplode(att.attacl) a
     where n.nspname = 'public'
       and a.grantee::regrole::text in ('anon', 'authenticated') $$,
  array[
    'authenticated profiles.name UPDATE',
    'authenticated profiles.nickname UPDATE',
    'authenticated profiles.photo_path UPDATE',
    'authenticated profile_private.phone UPDATE',
    'authenticated profile_private.phone_visible UPDATE',
    'authenticated profile_private.pix_key_type UPDATE',
    'authenticated profile_private.pix_key UPDATE',
    'authenticated terms_acceptances.user_id INSERT',
    'authenticated terms_acceptances.document INSERT',
    'authenticated terms_acceptances.version INSERT'
  ],
  'B04b: privilégios de coluna de anon e authenticated são os da fatia 2'
);

-- B06. Funções de public que anon ou authenticated podem executar, fora as de
-- extensões. Lista esperada da fatia 2: só current_terms_versions(), e só por
-- authenticated (contratos-api.md, seção 9).
-- Este é o teste que cobra o `revoke execute ... from public, anon` de toda
-- função nova (docs/arquitetura-app.md, 14.3).
select set_eq(
  $$ select r.rolname || ' ' || p.oid::regprocedure::text
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     cross join (values ('anon'), ('authenticated')) as r (rolname)
     where n.nspname = 'public'
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
       and has_function_privilege(r.rolname, p.oid, 'execute') $$,
  array['authenticated current_terms_versions()'],
  'B06: as funções de public executáveis pelo app são as da fatia 2'
);

-- B05. Tabela e função criadas depois da primeira migração nascem fechadas.
create table public.b05_probe_table (id integer);
create function public.b05_probe_function() returns integer language sql as $probe$ select 1 $probe$;

select is_empty(
  $$ select case when a.grantee = 0 then 'public' else a.grantee::regrole::text end
     from pg_class c
     cross join aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
     where c.oid = 'public.b05_probe_table'::regclass
       and (a.grantee = 0 or a.grantee::regrole::text in ('anon', 'authenticated')) $$,
  'B05a: tabela nova em public nasce sem privilégio para anon, authenticated e public'
);

-- B05b. Função nova em public nasce COM o `execute` que o Postgres dá ao papel
-- `public`, e nenhuma configuração remove essa concessão
-- (docs/rls-matriz.md, seção 1). É por isso que toda função de public leva o
-- `revoke execute ... from public, anon` logo depois do `create`
-- (docs/arquitetura-app.md, 14.3), cobrado pelo B06 acima.
--
-- Se esta asserção falhar, o Postgres mudou de comportamento: aí o documento
-- pode voltar a prometer que função nova nasce fechada.
select ok(
  has_function_privilege('authenticated', 'public.b05_probe_function()', 'execute'),
  'B05b: função nova em public é executável até levar o revoke explícito'
);

drop function public.b05_probe_function();
drop table public.b05_probe_table;

-- B07. O esquema private não é alcançável pelo app.
select ok(not has_schema_privilege('anon', 'private', 'usage'), 'B07a: anon sem usage em private');
select ok(
  not has_schema_privilege('authenticated', 'private', 'usage'),
  'B07b: authenticated sem usage em private'
);
select ok(
  not has_function_privilege(
    'anon', 'private.emit_notification(public.notification_type, uuid, jsonb)', 'execute'
  ),
  'B07c: anon sem execute em private.emit_notification'
);
select ok(
  not has_function_privilege(
    'authenticated', 'private.emit_notification(public.notification_type, uuid, jsonb)', 'execute'
  ),
  'B07d: authenticated sem execute em private.emit_notification'
);

-- B08. Usuário autenticado não lê nem escreve nada.
-- Simulação do usuário como a API faz (docs/arquitetura-app.md, 14.4).
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '00000000-0000-0000-0000-00000000000a', 'role', 'authenticated')::text,
  true
);
set local role authenticated;

-- Até a fatia 1 o select era em profiles, que a fatia 2 libera para a própria
-- linha (testes-referencia.md, 9.1).
select throws_ok(
  $$ select id from public.groups $$,
  '42501',
  null,
  'B08a: select em groups como authenticated devolve 42501'
);

select throws_ok(
  $$ insert into public.notifications (user_id, type, title, body)
     values ('00000000-0000-0000-0000-00000000000a', 'game_confirmed', 'x', '') $$,
  '42501',
  null,
  'B08b: insert em notifications como authenticated devolve 42501'
);

reset role;

-- B09. Buckets privados, com os limites da rls-matriz.md (seção 3).
select is(
  (select count(*) from storage.buckets where id in ('avatars', 'receipts')),
  2::bigint,
  'B09a: os buckets avatars e receipts existem'
);
select is(
  (select bool_or(public) from storage.buckets where id in ('avatars', 'receipts')),
  false,
  'B09b: os dois buckets são privados'
);
select is(
  (select file_size_limit from storage.buckets where id = 'avatars'),
  2097152::bigint,
  'B09c: avatars aceita até 2 MB (RN106)'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'avatars'),
  array['image/jpeg', 'image/png', 'image/webp'],
  'B09d: avatars aceita JPEG, PNG e WebP (RN106)'
);
select is(
  (select file_size_limit from storage.buckets where id = 'receipts'),
  10485760::bigint,
  'B09e: receipts aceita até 10 MB (RN87)'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'receipts'),
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'],
  'B09f: receipts aceita imagem e PDF (RN87)'
);

-- B10. Comprovantes continuam fechados; avatars tem só as políticas da fatia 2.
-- Até a fatia 1 o caminho testado era avatars/profiles/<uid>/x.png, que a
-- fatia 2 libera ao próprio usuário (testes-referencia.md, 9.1).
set local role authenticated;

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('receipts', gen_random_uuid()::text || '/x.png') $$,
  '42501',
  null,
  'B10a: insert em storage.objects, bucket receipts, como authenticated é recusado'
);

reset role;

select set_eq(
  $$ select policyname::text
     from pg_policies
     where schemaname = 'storage'
       and tablename = 'objects'
       and (coalesce(qual, '') || coalesce(with_check, '')) like any (array['%avatars%', '%receipts%']) $$,
  array['avatars_profile_select_own', 'avatars_profile_insert_own', 'avatars_profile_delete_own'],
  'B10b: as políticas de storage.objects que citam avatars ou receipts são as da fatia 2'
);

select * from finish();
rollback;
