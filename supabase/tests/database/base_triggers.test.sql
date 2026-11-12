-- Triggers da base (fatia 1).
-- Cenários B15 a B23 (perfil), B25 a B28 (updated_at e histórico do limite),
-- B29 a B36 (invariantes de admin) e B37 (emit_notification) de
-- docs/testes-referencia.md, seção 9.2.
--
-- Nenhuma tabela está liberada ao app nesta fatia: os testes rodam como postgres
-- e chamam as triggers direto. Os testes das invariantes de admin usam
-- `set constraints all immediate` para disparar na hora a checagem adiada.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(30);

-- Ajudantes ------------------------------------------------------------------

-- Cria uma conta como o Supabase Auth faz, confirmada ou não.
create function pg_temp.mk_user(p_email text, p_meta jsonb, p_confirmed boolean)
returns uuid
language plpgsql
as $fn$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  )
  values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', p_email,
    'nao-usado-no-teste', case when p_confirmed then now() end,
    '{"provider": "email", "providers": ["email"]}'::jsonb, p_meta, now(), now(),
    '', '', '', ''
  );
  return v_id;
end;
$fn$;

-- Grupo ativo com Ana como admin.
create function pg_temp.mk_group(p_name text)
returns uuid
language plpgsql
as $fn$
declare
  v_id uuid;
begin
  insert into public.groups (name, created_by, invite_code)
  values (p_name, '00000000-0000-0000-0000-00000000000a',
          substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  returning id into v_id;

  insert into public.group_members (group_id, user_id, role)
  values (v_id, '00000000-0000-0000-0000-00000000000a', 'admin');

  return v_id;
end;
$fn$;

-- Jogo com Ana como recebedora. O admin é inserido pelo chamador.
create function pg_temp.mk_game(p_slot_limit integer)
returns uuid
language plpgsql
as $fn$
declare
  v_id uuid;
begin
  insert into public.games (
    created_by, location_name, cancellation_deadline, starts_at, ends_at,
    total_cents, slot_limit, receiver_id, invite_code
  )
  values (
    '00000000-0000-0000-0000-00000000000a', 'Quadra do teste',
    now() + interval '1 day', now() + interval '2 days', now() + interval '2 days 2 hours',
    20000, p_slot_limit, '00000000-0000-0000-0000-00000000000a',
    substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

-- Perfil criado na confirmação do e-mail (B15 a B23) -------------------------

-- As contas são criadas uma vez, numa tabela temporária: mk_user é volátil e
-- não pode ser chamada dentro de uma consulta de asserção.
create temporary table t_user (label text primary key, id uuid) on commit drop;

-- B15. Cadastro não confirmado não deixa perfil.
insert into t_user
values ('b15', pg_temp.mk_user('b15@voleiin.test', '{"name": "Carla Souza"}'::jsonb, false));

select is(
  (select count(*) from public.profiles where id = (select id from t_user where label = 'b15')),
  0::bigint,
  'B15a: cadastro sem confirmação não cria profiles'
);
select is(
  (select count(*) from public.profile_private
   where user_id = (select id from t_user where label = 'b15')),
  0::bigint,
  'B15b: cadastro sem confirmação não cria profile_private'
);

-- B16. A confirmação cria o perfil e a linha privada.
update auth.users set email_confirmed_at = now()
where id = (select id from t_user where label = 'b15');

select results_eq(
  $$ select p.name, p.nickname, p.display_name
     from public.profiles p
     where p.id = (select id from t_user where label = 'b15') $$,
  $$ values ('Carla Souza'::text, null::text, 'Carla Souza'::text) $$,
  'B16a: confirmação cria o perfil com name, nickname nulo e display_name (RN100)'
);
select results_eq(
  $$ select pp.phone, pp.phone_visible, pp.pix_key_type, pp.pix_key
     from public.profile_private pp
     where pp.user_id = (select id from t_user where label = 'b15') $$,
  $$ values (null::text, false, null::public.pix_key_type, null::text) $$,
  'B16b: profile_private nasce com phone_visible false e o resto nulo (RN101)'
);

-- B17. Sem `name`, vale `full_name`; o perfil nasce no próprio insert.
insert into t_user
values ('b17', pg_temp.mk_user('b17@voleiin.test', '{"full_name": "Carla Souza"}'::jsonb, true));
select is(
  (select p.name from public.profiles p where p.id = (select id from t_user where label = 'b17')),
  'Carla Souza',
  'B17: sem name, o perfil nasce com full_name já no insert confirmado'
);

-- B18. Com os dois, `name` ganha.
insert into t_user
values ('b18', pg_temp.mk_user(
  'b18@voleiin.test', '{"name": "Carla", "full_name": "Carla Souza"}'::jsonb, true));
select is(
  (select p.name from public.profiles p where p.id = (select id from t_user where label = 'b18')),
  'Carla',
  'B18: name tem precedência sobre full_name'
);

-- B19. Espaço nas pontas sai.
insert into t_user
values ('b19', pg_temp.mk_user('b19@voleiin.test', '{"name": "  Carla Souza  "}'::jsonb, true));
select is(
  (select p.name from public.profiles p where p.id = (select id from t_user where label = 'b19')),
  'Carla Souza',
  'B19: o nome vem sem espaço nas pontas'
);

-- B20. Nome longo é cortado em 80 caracteres, sem espaço nas pontas.
insert into t_user
values ('b20', pg_temp.mk_user(
  'b20@voleiin.test',
  jsonb_build_object('name', '  ' || repeat('a', 100) || '  '),
  true));
select results_eq(
  $$ select char_length(p.name), p.name = btrim(p.name)
     from public.profiles p
     where p.id = (select id from t_user where label = 'b20') $$,
  $$ values (80, true) $$,
  'B20: nome de 100 caracteres fica com os 80 primeiros, sem espaço nas pontas'
);

-- B21. Sem nome nos metadados, vale o início do e-mail.
insert into t_user
values ('b21', pg_temp.mk_user(
  'carla.souza@gmail.com', '{"name": "   ", "full_name": "  "}'::jsonb, true));
select is(
  (select p.name from public.profiles p where p.id = (select id from t_user where label = 'b21')),
  'carla.souza',
  'B21: sem name nem full_name, o nome vem do início do e-mail'
);

-- B22. Confirmar de novo não muda o perfil e não dá erro.
select lives_ok(
  $$ update auth.users set email_confirmed_at = now() + interval '1 minute'
     where id = (select id from t_user where label = 'b18') $$,
  'B22a: nova confirmação não dá erro'
);
select is(
  (select p.name from public.profiles p where p.id = (select id from t_user where label = 'b18')),
  'Carla',
  'B22b: nova confirmação não muda o perfil'
);

-- B23. O perfil nasce com os metadados do momento da confirmação (RF108).
-- O e-mail é o da Carla, digitado errado pelo Bruno no cadastro por e-mail.
insert into t_user
values ('b23', pg_temp.mk_user('carla.b23@voleiin.test', '{"name": "Bruno"}'::jsonb, false));
select is(
  (select count(*) from public.profiles where id = (select id from t_user where label = 'b23')),
  0::bigint,
  'B23a: o cadastro pendente do Bruno não deixa perfil'
);
update auth.users
set raw_user_meta_data = '{"name": "Carla Souza"}'::jsonb,
    email_confirmed_at = now()
where id = (select id from t_user where label = 'b23');
select is(
  (select p.name from public.profiles p where p.id = (select id from t_user where label = 'b23')),
  'Carla Souza',
  'B23b: o perfil nasce com o nome do Google, e nunca existiu perfil "Bruno"'
);

-- updated_at e histórico do limite (B25 a B28) -------------------------------

-- B25. O update grava updated_at com o relógio do servidor.
-- O grupo nasce com updated_at de um dia antes: a trigger é `before update`,
-- então o insert não a dispara.
create temporary table b25_group (id uuid) on commit drop;

with novo as (
  insert into public.groups (name, created_by, invite_code, updated_at)
  values ('Grupo do B25', '00000000-0000-0000-0000-00000000000a',
          substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
          now() - interval '1 day')
  returning id
)
insert into b25_group select id from novo;

insert into public.group_members (group_id, user_id, role)
select id, '00000000-0000-0000-0000-00000000000a', 'admin' from b25_group;

update public.groups set name = 'Grupo do B25, renomeado'
where id = (select id from b25_group);

select is(
  (select updated_at from public.groups where id = (select id from b25_group)),
  now(),
  'B25: update de groups põe updated_at = now()'
);

-- B26 a B28. Histórico do limite de vagas (RN62).
create temporary table b26_game (id uuid) on commit drop;
insert into b26_game select pg_temp.mk_game(10);
insert into public.game_admins (game_id, user_id)
select id, '00000000-0000-0000-0000-00000000000a' from b26_game;

select results_eq(
  $$ select slot_limit, effective_from = now()
     from public.game_limit_history
     where game_id = (select id from b26_game) $$,
  $$ values (10, true) $$,
  'B26: o insert do jogo grava uma linha de histórico com o limite e now()'
);

update public.games set slot_limit = 12 where id = (select id from b26_game);
select results_eq(
  $$ select slot_limit from public.game_limit_history
     where game_id = (select id from b26_game) order by slot_limit $$,
  $$ values (10), (12) $$,
  'B27: mudar o limite para 12 grava uma segunda linha'
);

update public.games set location_name = 'Outra quadra' where id = (select id from b26_game);
update public.games set slot_limit = 12 where id = (select id from b26_game);
select is(
  (select count(*) from public.game_limit_history where game_id = (select id from b26_game)),
  2::bigint,
  'B28: mudar o local, ou o limite para o mesmo valor, não grava linha nova'
);

-- Invariantes de admin (B29 a B36) -------------------------------------------
-- Grupos e jogos criados antes de trocar o modo das constraints.
create temporary table b29_group (id uuid) on commit drop;
insert into b29_group select pg_temp.mk_group('Grupo do B29');

create temporary table b31_group (id uuid) on commit drop;
insert into b31_group select pg_temp.mk_group('Grupo do B31');
insert into public.group_members (group_id, user_id, role)
select id, '00000000-0000-0000-0000-00000000000b', 'member' from b31_group;

create temporary table b33_group (id uuid) on commit drop;
insert into b33_group select pg_temp.mk_group('Grupo do B33');

create temporary table b35_game (id uuid) on commit drop;
insert into b35_game select pg_temp.mk_game(10);
insert into public.game_admins (game_id, user_id)
select id, '00000000-0000-0000-0000-00000000000a' from b35_game;

create temporary table b36_game (id uuid) on commit drop;
insert into b36_game select pg_temp.mk_game(10);
insert into public.game_admins (game_id, user_id)
select id, '00000000-0000-0000-0000-00000000000a' from b36_game;
insert into public.game_admins (game_id, user_id)
select id, '00000000-0000-0000-0000-00000000000b' from b36_game;

-- Dispara agora o que fica adiado para o fim da transação.
set constraints all immediate;

-- B29. O último admin não sai.
select throws_ok(
  $$ delete from public.group_members
     where group_id = (select id from b29_group)
       and user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001',
  'LAST_ADMIN',
  'B29: apagar o último admin do grupo devolve LAST_ADMIN (RN13)'
);

-- B30. O último admin não é rebaixado.
select throws_ok(
  $$ update public.group_members set role = 'member'
     where group_id = (select id from b29_group)
       and user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001',
  'LAST_ADMIN',
  'B30: rebaixar o último admin devolve LAST_ADMIN (RN13)'
);

-- B31. Trocar quem é admin, na mesma transação, é aceito.
select lives_ok(
  $$ update public.group_members set role = 'admin'
     where group_id = (select id from b31_group)
       and user_id = '00000000-0000-0000-0000-00000000000b' $$,
  'B31a: promover outro membro é aceito'
);
select lives_ok(
  $$ update public.group_members set role = 'member'
     where group_id = (select id from b31_group)
       and user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'B31b: rebaixar o antigo admin depois da promoção é aceito'
);

-- B32. Grupo ativo nasce com admin.
select throws_ok(
  $$ insert into public.groups (name, created_by)
     values ('Grupo sem admin', '00000000-0000-0000-0000-00000000000a') $$,
  'P0001',
  'LAST_ADMIN',
  'B32: grupo ativo sem membros devolve LAST_ADMIN (RN13)'
);

-- B33. Arquivar o grupo e tirar todos os membros é aceito (RN17).
select lives_ok(
  $$ update public.groups
     set archived_at = now(), archived_by = '00000000-0000-0000-0000-00000000000a',
         invite_code = null
     where id = (select id from b33_group) $$,
  'B33a: arquivar o grupo é aceito'
);
select lives_ok(
  $$ delete from public.group_members where group_id = (select id from b33_group) $$,
  'B33b: tirar todos os membros de um grupo arquivado é aceito'
);

-- B34. Jogo nasce com admin.
select throws_ok(
  $$ insert into public.games (
       created_by, location_name, cancellation_deadline, starts_at, ends_at,
       total_cents, slot_limit, receiver_id, invite_code
     )
     values (
       '00000000-0000-0000-0000-00000000000a', 'Quadra sem admin',
       now() + interval '1 day', now() + interval '2 days', now() + interval '2 days 2 hours',
       20000, 10, '00000000-0000-0000-0000-00000000000a', 'semadmin1234'
     ) $$,
  'P0001',
  'LAST_GAME_ADMIN',
  'B34: jogo sem admin devolve LAST_GAME_ADMIN (RN25)'
);

-- B35. O último admin do jogo não sai.
select throws_ok(
  $$ delete from public.game_admins where game_id = (select id from b35_game) $$,
  'P0001',
  'LAST_GAME_ADMIN',
  'B35: apagar o único admin do jogo devolve LAST_GAME_ADMIN (RN25)'
);

-- B36. Com dois admins, apagar um é aceito.
select lives_ok(
  $$ delete from public.game_admins
     where game_id = (select id from b36_game)
       and user_id = '00000000-0000-0000-0000-00000000000b' $$,
  'B36: com dois admins, apagar um é aceito (RN25)'
);

-- emit_notification (B37) ----------------------------------------------------

create temporary table b37_notification (id uuid) on commit drop;
insert into b37_notification
select private.emit_notification(
  'game_confirmed',
  '00000000-0000-0000-0000-00000000000a',
  jsonb_build_object('game_id', (select id from b36_game))
);

select isnt(
  (select id from b37_notification), null, 'B37a: emit_notification devolve o id da linha'
);
select results_eq(
  $$ select n.type::text, n.user_id, n.title, n.body, n.read_at, n.push_sent_at
     from public.notifications n
     where n.id = (select id from b37_notification) $$,
  $$ values (
       'game_confirmed'::text, '00000000-0000-0000-0000-00000000000a'::uuid,
       'game_confirmed'::text, ''::text, null::timestamptz, null::timestamptz
     ) $$,
  'B37b: a linha nasce com o tipo, o usuário e o texto provisório da fatia 1'
);
select is(
  (select n.data ->> 'game_id' from public.notifications n
   where n.id = (select id from b37_notification)),
  (select id::text from b36_game),
  'B37c: o data informado é gravado como veio'
);

select * from finish();
rollback;
