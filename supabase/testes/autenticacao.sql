-- Asserções do passo 3: os gatilhos em auth.users que conferem o nome no cadastro, criam o
-- perfil quando o e-mail fica confirmado (RN21) e apagam os aparelhos de push na troca de
-- e-mail e de senha (RNF07). Detalhes em docs/stack.md, seção Autenticação. Roda numa
-- transação desfeita, a partir do banco recém-resetado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql

-- Só os avisos interessam; o resultado de cada select vai para o lixo.
\o /dev/null

begin;

create temp sequence assercoes;

-- Executa o comando e exige que falhe com o sqlstate e, quando dada, a restrição esperados.
create function pg_temp.espera_erro(descricao text, comando text, estado text, restricao text default null)
returns void
language plpgsql
as $$
declare
  v_estado text;
  v_restricao text;
begin
  perform nextval('assercoes');
  begin
    execute comando;
  exception when others then
    get stacked diagnostics v_estado = returned_sqlstate, v_restricao = constraint_name;
    if v_estado <> estado or (restricao is not null and v_restricao is distinct from restricao) then
      raise exception 'FALHOU: % — esperava % %, veio % % (%)',
        descricao, estado, coalesce(restricao, ''), v_estado, coalesce(v_restricao, ''), sqlerrm;
    end if;
    return;
  end;
  raise exception 'FALHOU: % — o comando passou, mas deveria ser recusado', descricao;
end;
$$;

-- Executa o comando e exige que passe. O efeito fica na transação.
create function pg_temp.espera_ok(descricao text, comando text)
returns void
language plpgsql
as $$
begin
  perform nextval('assercoes');
  execute comando;
exception when others then
  raise exception 'FALHOU: % — esperava sucesso, veio % (%)', descricao, sqlstate, sqlerrm;
end;
$$;

-- Exige que a condição seja verdadeira.
create function pg_temp.espera_verdade(descricao text, condicao boolean)
returns void
language plpgsql
as $$
begin
  perform nextval('assercoes');
  if condicao is not true then
    raise exception 'FALHOU: %', descricao;
  end if;
end;
$$;

-- As escritas em auth.users são do postgres, que aqui não pode assumir o papel do Supabase Auth
-- (supabase_auth_admin). Os gatilhos são security definer, então rodam igual nos dois casos; o
-- caminho pelo serviço de autenticação é conferido ponta a ponta, não aqui. A senha aparece
-- como um texto qualquer em encrypted_password: aos gatilhos só importa se ela muda.

-- Cadastro com senha --------------------------------------------------------------------

select pg_temp.espera_ok('cadastro com senha cria o usuário pendente',
  $c$insert into auth.users (id, email, encrypted_password, raw_user_meta_data)
     values ('a0000000-0000-0000-0000-000000000001', 'carla@empresa.com', 'hash-1', '{"nome": "  Carla  "}')$c$);
select pg_temp.espera_verdade('cadastro pendente não tem perfil',
  not exists (select 1 from pessoa where id = 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.espera_ok('o código confirma o cadastro',
  $c$update auth.users set email_confirmed_at = now()
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('a confirmação cria o perfil com o id do usuário e o nome sem espaços nas pontas',
  (select nome from pessoa where id = 'a0000000-0000-0000-0000-000000000001') = 'Carla');
select pg_temp.espera_verdade('o perfil nasce só com o nome; o resto do perfil fica para o RF02',
  (select avatar_url is null and telefone is null and chave_pix is null
   from pessoa where id = 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.espera_ok('confirmar de novo quem já está confirmado',
  $c$update auth.users set email_confirmed_at = now()
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('nova confirmação não cria segundo perfil',
  (select count(*) from pessoa where id = 'a0000000-0000-0000-0000-000000000001') = 1);

select pg_temp.espera_ok('usuário inserido já confirmado, como pelo Studio',
  $c$insert into auth.users (id, email, encrypted_password, raw_user_meta_data, email_confirmed_at)
     values ('b0000000-0000-0000-0000-000000000001', 'bruno@exemplo.com', 'hash-b', '{"nome": "Bruno"}', now())$c$);
select pg_temp.espera_verdade('usuário já confirmado ganha o perfil no insert',
  (select nome from pessoa where id = 'b0000000-0000-0000-0000-000000000001') = 'Bruno');

-- Recusas de nome ------------------------------------------------------------------------

select pg_temp.espera_erro('cadastro sem nome é recusado',
  $c$insert into auth.users (id, email, raw_user_meta_data)
     values ('c0000000-0000-0000-0000-000000000001', 'semnome@exemplo.com', '{}')$c$,
  '23502', 'conferir_nome');

select pg_temp.espera_erro('cadastro sem metadados é recusado',
  $c$insert into auth.users (id, email)
     values ('c0000000-0000-0000-0000-000000000002', 'semdados@exemplo.com')$c$,
  '23502', 'conferir_nome');

select pg_temp.espera_erro('cadastro com nome só de espaços é recusado',
  $c$insert into auth.users (id, email, raw_user_meta_data)
     values ('c0000000-0000-0000-0000-000000000003', 'espacos@exemplo.com', '{"nome": "   "}')$c$,
  '23502', 'conferir_nome');

select pg_temp.espera_erro('conta Google sem nome é recusada',
  $c$insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at)
     values ('c0000000-0000-0000-0000-000000000004', 'semnome@gmail.com',
             '{"email": "semnome@gmail.com", "picture": "https://exemplo.com/foto.png"}', now())$c$,
  '23502', 'conferir_nome');

select pg_temp.espera_verdade('cadastro recusado não deixa usuário nem perfil',
  not exists (select 1 from auth.users where id::text like 'c0000000%')
  and not exists (select 1 from pessoa where id::text like 'c0000000%'));

-- Google ---------------------------------------------------------------------------------

select pg_temp.espera_ok('primeiro acesso pelo Google, que já nasce confirmado',
  $c$insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at)
     values ('d0000000-0000-0000-0000-000000000001', 'diana@gmail.com',
             '{"full_name": "Diana Souza", "name": "Diana Souza", "email": "diana@gmail.com",
               "avatar_url": "https://exemplo.com/diana.png", "picture": "https://exemplo.com/diana.png"}',
             now())$c$);
select pg_temp.espera_verdade('o perfil do Google nasce no insert, com o nome do Google',
  (select nome from pessoa where id = 'd0000000-0000-0000-0000-000000000001') = 'Diana Souza');
select pg_temp.espera_verdade('a foto do Google não é copiada para o perfil',
  (select avatar_url is null from pessoa where id = 'd0000000-0000-0000-0000-000000000001'));

insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('d0000000-0000-0000-0000-000000000002', 'edu@gmail.com', '{"nome": "Edu", "full_name": "Eduardo Lima"}', now()),
  ('d0000000-0000-0000-0000-000000000003', 'gabi@gmail.com', '{"full_name": "Gabi Alves", "name": "Gabriela"}', now()),
  ('d0000000-0000-0000-0000-000000000004', 'fabi@gmail.com', '{"full_name": " ", "name": "Fabi Rocha"}', now());
select pg_temp.espera_verdade('o nome do cadastro vence o do Google',
  (select nome from pessoa where id = 'd0000000-0000-0000-0000-000000000002') = 'Edu');
select pg_temp.espera_verdade('full_name vence name',
  (select nome from pessoa where id = 'd0000000-0000-0000-0000-000000000003') = 'Gabi Alves');
select pg_temp.espera_verdade('sem full_name, vale name',
  (select nome from pessoa where id = 'd0000000-0000-0000-0000-000000000004') = 'Fabi Rocha');

-- Nome acima de 60 caracteres (RN21): o gatilho corta, não recusa -------------------------

insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('d0000000-0000-0000-0000-000000000005', 'longo@gmail.com',
   jsonb_build_object('full_name', repeat('G', 80)), now()),
  ('d0000000-0000-0000-0000-000000000007', 'corte@gmail.com',
   jsonb_build_object('full_name', repeat('H', 59) || ' resto'), now());
select pg_temp.espera_verdade('nome do Google de 80 caracteres é cortado em 60',
  (select nome = repeat('G', 60) from pessoa where id = 'd0000000-0000-0000-0000-000000000005'));
select pg_temp.espera_verdade('o corte não deixa espaço no fim do nome',
  (select nome = repeat('H', 59) from pessoa where id = 'd0000000-0000-0000-0000-000000000007'));

insert into auth.users (id, email, raw_user_meta_data)
  values ('d0000000-0000-0000-0000-000000000006', 'longa@exemplo.com',
          jsonb_build_object('nome', repeat('C', 70)));
update auth.users set email_confirmed_at = now() where id = 'd0000000-0000-0000-0000-000000000006';
select pg_temp.espera_verdade('nome do cadastro com senha de 70 caracteres é cortado na confirmação',
  (select nome = repeat('C', 60) from pessoa where id = 'd0000000-0000-0000-0000-000000000006'));

-- Impostor -------------------------------------------------------------------------------

-- Alguém cadastra com senha o Gmail da Helena e não tem como confirmar. Quando a Helena entra
-- pelo Google, o serviço apaga a senha e troca os metadados pelos do Google antes de confirmar.
select pg_temp.espera_ok('cadastro pendente com o e-mail de outra pessoa',
  $c$insert into auth.users (id, email, encrypted_password, raw_user_meta_data)
     values ('e0000000-0000-0000-0000-000000000001', 'helena@gmail.com', 'hash-impostor', '{"nome": "Helena"}')$c$);
select pg_temp.espera_ok('a dona entra pelo Google e o serviço vincula ao cadastro pendente',
  $c$update auth.users
     set encrypted_password = null,
         raw_user_meta_data = '{"full_name": "Helena Costa", "name": "Helena Costa", "email": "helena@gmail.com"}',
         email_confirmed_at = now()
     where id = 'e0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('o perfil nasce com o nome do Google, não o do cadastro pendente',
  (select nome from pessoa where id = 'e0000000-0000-0000-0000-000000000001') = 'Helena Costa');

-- Troca de senha -------------------------------------------------------------------------

insert into dispositivo_push (pessoa_id, token_fcm, modelo_aparelho) values
  ('a0000000-0000-0000-0000-000000000001', 'token-celular-carla', 'Celular'),
  ('a0000000-0000-0000-0000-000000000001', 'token-tablet-carla', 'Tablet'),
  ('b0000000-0000-0000-0000-000000000001', 'token-celular-bruno', 'Celular');

select pg_temp.espera_ok('update que regrava a mesma senha',
  $c$update auth.users set encrypted_password = 'hash-1', last_sign_in_at = now()
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('senha repetida não apaga aparelho',
  (select count(*) from dispositivo_push where pessoa_id = 'a0000000-0000-0000-0000-000000000001') = 2);

select pg_temp.espera_ok('senha trocada pela redefinição por código',
  $c$update auth.users set encrypted_password = 'hash-2'
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('troca de senha apaga todos os aparelhos do titular',
  not exists (select 1 from dispositivo_push where pessoa_id = 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('troca de senha não toca nos aparelhos de outra pessoa',
  exists (select 1 from dispositivo_push where token_fcm = 'token-celular-bruno'));

-- Troca de e-mail ------------------------------------------------------------------------

-- O aparelho que confirmou a troca de senha registra a si mesmo de novo.
insert into dispositivo_push (pessoa_id, token_fcm, modelo_aparelho) values
  ('a0000000-0000-0000-0000-000000000001', 'token-celular-carla', 'Celular'),
  ('a0000000-0000-0000-0000-000000000001', 'token-tablet-carla', 'Tablet');

-- O pedido de troca grava o endereço novo em email_change; email só muda depois que
-- o código enviado ao endereço novo é confirmado.
select pg_temp.espera_ok('pedido de troca ainda não confirmado',
  $c$update auth.users set email_change = 'carla@gmail.com'
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('troca pela metade não apaga aparelho',
  (select count(*) from dispositivo_push where pessoa_id = 'a0000000-0000-0000-0000-000000000001') = 2);

select pg_temp.espera_ok('update que repete o mesmo e-mail',
  $c$update auth.users set email = 'carla@empresa.com', last_sign_in_at = now()
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('e-mail repetido não apaga aparelho',
  (select count(*) from dispositivo_push where pessoa_id = 'a0000000-0000-0000-0000-000000000001') = 2);

select pg_temp.espera_ok('troca confirmada pelo código no endereço novo',
  $c$update auth.users set email = 'carla@gmail.com', email_change = ''
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('troca confirmada apaga todos os aparelhos do titular',
  not exists (select 1 from dispositivo_push where pessoa_id = 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('troca não toca nos aparelhos de outra pessoa',
  exists (select 1 from dispositivo_push where token_fcm = 'token-celular-bruno'));

select pg_temp.espera_verdade('troca mantém um perfil só, com o mesmo nome',
  (select count(*) = 1 and min(nome) = 'Carla' from pessoa where id = 'a0000000-0000-0000-0000-000000000001'));

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
