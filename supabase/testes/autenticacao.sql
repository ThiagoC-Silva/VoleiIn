-- Asserções do passo 3: os gatilhos em auth.users que criam o perfil no primeiro acesso
-- (RN21) e apagam os aparelhos de push na troca de e-mail (RNF07). Detalhes em docs/stack.md,
-- seção Autenticação. Roda numa transação desfeita, a partir do banco recém-resetado.
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
-- caminho pelo serviço de autenticação é conferido ponta a ponta, não aqui.

-- Primeiro acesso ------------------------------------------------------------------------

select pg_temp.espera_ok('cadastro com nome cria o usuário',
  $c$insert into auth.users (id, email, raw_user_meta_data)
     values ('a0000000-0000-0000-0000-000000000001', 'carla@empresa.com', '{"nome": "  Carla  "}')$c$);

select pg_temp.espera_ok('cadastro de outra pessoa',
  $c$insert into auth.users (id, email, raw_user_meta_data)
     values ('b0000000-0000-0000-0000-000000000001', 'bruno@exemplo.com', '{"nome": "Bruno"}')$c$);

select pg_temp.espera_erro('cadastro sem nome é recusado',
  $c$insert into auth.users (id, email, raw_user_meta_data)
     values ('c0000000-0000-0000-0000-000000000001', 'semnome@exemplo.com', '{}')$c$,
  '23502');

select pg_temp.espera_erro('cadastro sem metadados é recusado',
  $c$insert into auth.users (id, email)
     values ('c0000000-0000-0000-0000-000000000002', 'semdados@exemplo.com')$c$,
  '23502');

select pg_temp.espera_erro('cadastro com nome só de espaços é recusado',
  $c$insert into auth.users (id, email, raw_user_meta_data)
     values ('c0000000-0000-0000-0000-000000000003', 'espacos@exemplo.com', '{"nome": "   "}')$c$,
  '23502');


select pg_temp.espera_verdade('o perfil nasce com o id do usuário e o nome sem espaços nas pontas',
  (select nome from pessoa where id = 'a0000000-0000-0000-0000-000000000001') = 'Carla');
select pg_temp.espera_verdade('o perfil nasce só com o nome; o resto do perfil fica para o RF02',
  (select avatar_url is null and telefone is null and chave_pix is null
   from pessoa where id = 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('cadastro recusado não deixa usuário nem perfil',
  not exists (select 1 from auth.users where id::text like 'c0000000%')
  and not exists (select 1 from pessoa where id::text like 'c0000000%'));

-- Troca de e-mail ------------------------------------------------------------------------

insert into dispositivo_push (pessoa_id, token_fcm, modelo_aparelho) values
  ('a0000000-0000-0000-0000-000000000001', 'token-celular-carla', 'Celular'),
  ('a0000000-0000-0000-0000-000000000001', 'token-tablet-carla', 'Tablet'),
  ('b0000000-0000-0000-0000-000000000001', 'token-celular-bruno', 'Celular');

-- Com a confirmação dupla, o pedido de troca grava o endereço novo em email_change;
-- email só muda depois das duas confirmações.
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

select pg_temp.espera_ok('troca confirmada nos dois endereços',
  $c$update auth.users set email = 'carla@gmail.com', email_change = ''
     where id = 'a0000000-0000-0000-0000-000000000001'$c$);
select pg_temp.espera_verdade('troca confirmada apaga todos os aparelhos do titular',
  not exists (select 1 from dispositivo_push where pessoa_id = 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('troca não toca nos aparelhos de outra pessoa',
  exists (select 1 from dispositivo_push where token_fcm = 'token-celular-bruno'));


select pg_temp.espera_verdade('troca mantém o perfil e o nome',
  (select nome from pessoa where id = 'a0000000-0000-0000-0000-000000000001') = 'Carla');

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
