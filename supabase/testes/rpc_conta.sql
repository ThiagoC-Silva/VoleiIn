-- Cenários de excluir a conta (migração rpc_conta): as três recusas, na ordem (RN27), e,
-- sem pendência, a anonimização do perfil, a chave dos jogos apagada (RNF04), a saída dos
-- grupos e das filas abertas, os aparelhos apagados e o usuário fora de auth.users, com o
-- histórico preservado. Roda numa transação desfeita, a partir do banco recém-resetado com o
-- seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_conta.sql
--
-- Local do seed: Arena Beira-Mar (10…01, por_quadra, Quadras 1 e 2, seg a sex 18h–23h).


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

-- Executa o comando e exige a recusa de uma função: o sqlstate (P0001 para regra
-- violada, 42501 para falta de papel) e o código estável na mensagem.
create function pg_temp.espera_recusa(descricao text, comando text, codigo text, estado text default 'P0001')
returns void
language plpgsql
as $$
begin
  perform nextval('assercoes');
  begin
    execute comando;
  exception when others then
    if sqlstate <> estado or sqlerrm <> codigo then
      raise exception 'FALHOU: % — esperava % %, veio % %', descricao, estado, codigo, sqlstate, sqlerrm;
    end if;
    return;
  end;
  raise exception 'FALHOU: % — o comando passou, mas deveria ser recusado com %', descricao, codigo;
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

-- Passa a agir como a pessoa, do jeito que a API do Supabase faz: papel authenticated
-- e o id no JWT, lido por auth.uid(). Sem pessoa, age como anon. "reset role" volta ao postgres.
create function pg_temp.como(p_pessoa uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('role', case when p_pessoa is null then 'anon' else 'authenticated' end, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_pessoa, 'role', case when p_pessoa is null then 'anon' else 'authenticated' end)::text,
    true);
end;
$$;

-- O arnês é do postgres; os papéis do app precisam alcançá-lo depois da troca.
grant usage on sequence assercoes to authenticated, anon;
grant execute on function
  pg_temp.espera_erro(text, text, text, text),
  pg_temp.espera_recusa(text, text, text, text),
  pg_temp.espera_ok(text, text),
  pg_temp.espera_verdade(text, boolean),
  pg_temp.como(uuid)
to authenticated, anon;


-- Próximo dia da semana (0 é domingo) à hora dada em Brasília, sempre de amanhã em diante.
create function pg_temp.proximo(p_dia integer, p_hora time)
returns timestamptz
language sql
stable
as $$
  select ((hoje + (((p_dia - extract(dow from hoje)::int + 6) % 7) + 1)) + p_hora)
         at time zone 'America/Sao_Paulo'
  from (select (now() at time zone 'America/Sao_Paulo')::date as hoje) h;
$$;

create temp table ids (nome text primary key, id uuid not null);
create function pg_temp.id(p_nome text) returns uuid language sql stable as $$ select id from ids where nome = p_nome $$;
create function pg_temp.m(p_n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-0000-0000-' || lpad(p_n::text, 12, '0'))::uuid
$$;
create function pg_temp.tito() returns uuid language sql immutable as $$ select '70000000-0000-0000-0000-000000000001'::uuid $$;
create function pg_temp.ana() returns uuid language sql immutable as $$ select 'a0000000-0000-0000-0000-000000000001'::uuid $$;
-- A cobrança da pessoa no jogo.
create function pg_temp.cob(p_jogo text, p_pessoa uuid) returns uuid language sql stable as $$
  select c.id from cobranca c join participacao p on p.id = c.participacao_id
  where p.jogo_id = pg_temp.id(p_jogo) and p.pessoa_id = p_pessoa
$$;
-- Status e posição da pessoa no jogo, como 'lista_espera:2'.
create function pg_temp.situacao(p_jogo text, p_pessoa uuid) returns text language sql stable as $$
  select status || coalesce(':' || posicao_espera, '') from participacao
  where jogo_id = pg_temp.id(p_jogo) and pessoa_id = p_pessoa
$$;
-- Age como a pessoa num comando só e volta ao postgres.
create function pg_temp.como_faz(p_pessoa uuid, p_comando text) returns void language plpgsql as $$
begin
  perform pg_temp.como(p_pessoa);
  execute p_comando;
  reset role;
end;
$$;

grant select, insert on ids to authenticated;
grant execute on function pg_temp.id(text), pg_temp.m(integer), pg_temp.proximo(integer, time),
  pg_temp.tito(), pg_temp.ana() to authenticated;

-- Elenco. Tito, o titular, nasce pelo caminho real: o usuário confirmado em auth.users cria
-- a pessoa pelo gatilho (migração autenticacao). Os outros entram direto em pessoa, que não
-- tem chave estrangeira para auth.users.
--   Tito   70…  titular; cria Areia de Sábado e Solo, onde fica sozinho; membro de Quinta
--   Ana    a0…  cria Vôlei de Quinta; membro de Sábado
--   Membros 1 e 2 (90…), de Quinta
insert into auth.users (id, email, encrypted_password, raw_user_meta_data, email_confirmed_at)
values (pg_temp.tito(), 'tito@exemplo.com', 'hash-tito', '{"nome": "Tito Souza"}', now());
update pessoa set chave_pix = 'tito@pix', telefone = '+55 85 99999-0000', avatar_url = 'https://exemplo.com/tito.png'
where id = pg_temp.tito();
insert into pessoa (id, nome, chave_pix) values (pg_temp.ana(), 'Ana Souza', 'ana@pix');
insert into pessoa (id, nome) select pg_temp.m(n), 'Membro ' || n from generate_series(1, 2) n;

insert into dispositivo_push (pessoa_id, token_fcm, modelo_aparelho) values
  (pg_temp.tito(), 'token-tito-1', 'Moto G'),
  (pg_temp.tito(), 'token-tito-2', 'Galaxy A'),
  (pg_temp.ana(), 'token-ana', 'Redmi');

select pg_temp.espera_verdade('o gatilho criou o perfil de Tito',
  (select nome from pessoa where id = pg_temp.tito()) = 'Tito Souza');

select pg_temp.como(pg_temp.tito());
insert into ids values
  ('sabado', criar_grupo('Areia de Sábado', '#3B6FE0', 3)),
  ('solo', criar_grupo('Solo', '#0FA3A0', 3));
select pg_temp.como(pg_temp.ana());
insert into ids values ('quinta', criar_grupo('Vôlei de Quinta', '#7B5CE6', 3));
reset role;

insert into membro_grupo (grupo_id, pessoa_id, papel) values
  (pg_temp.id('sabado'), pg_temp.ana(), 'membro'),
  (pg_temp.id('quinta'), pg_temp.tito(), 'membro'),
  (pg_temp.id('quinta'), pg_temp.m(1), 'membro'),
  (pg_temp.id('quinta'), pg_temp.m(2), 'membro');

-- Jogos.
--   j1  Quinta, Ana recebe; Tito confirma e deve a ela
--   j2  Sábado, Tito recebe; Ana confirma e deve a ele
--   j3  Solo, Tito recebe e joga sozinho
--   j4  Quinta, 2 vagas: Ana e Membro 1; Tito e Membro 2 na fila
--   j5  Quinta, 1 vaga: Ana; Tito na fila; encerra com ele lá
select pg_temp.como(pg_temp.ana());
insert into ids values
  ('j1', criar_jogo(pg_temp.id('quinta'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                    pg_temp.proximo(1, '19:00'), 120, 10, 10000, null)),
  ('j4', criar_jogo(pg_temp.id('quinta'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
                    pg_temp.proximo(2, '19:00'), 120, 2, 4000, null)),
  ('j5', criar_jogo(pg_temp.id('quinta'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                    pg_temp.proximo(3, '19:00'), 120, 1, 4000, null));
select pg_temp.como(pg_temp.tito());
insert into ids values
  ('j2', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
                    pg_temp.proximo(1, '19:00'), 120, 10, 10000, null)),
  ('j3', criar_jogo(pg_temp.id('solo'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                    pg_temp.proximo(2, '19:00'), 120, 10, 10000, null));
reset role;

select pg_temp.como_faz(pg_temp.tito(), $$select confirmar_presenca(pg_temp.id('j1'))$$);
select pg_temp.como_faz(pg_temp.ana(), $$select confirmar_presenca(pg_temp.id('j2'))$$);
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('j4'))$$)
from unnest(array[pg_temp.m(1), pg_temp.tito(), pg_temp.m(2)]) p;
select pg_temp.como_faz(pg_temp.tito(), $$select confirmar_presenca(pg_temp.id('j5'))$$);

select pg_temp.espera_verdade('montado: Tito deve em j1, recebe em j2 e j3, e está nas filas de j4 e j5',
  (select status from cobranca where id = pg_temp.cob('j1', pg_temp.tito())) = 'pendente'
  and (select credor_id from cobranca where id = pg_temp.cob('j2', pg_temp.ana())) = pg_temp.tito()
  and (select chave_pix_recebedor from jogo where id = pg_temp.id('j2')) = 'tito@pix'
  and pg_temp.situacao('j4', pg_temp.tito()) = 'lista_espera:1'
  and pg_temp.situacao('j4', pg_temp.m(2)) = 'lista_espera:2'
  and pg_temp.situacao('j5', pg_temp.tito()) = 'lista_espera:1');

-- j5 termina com Tito na fila.
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.id('j5');
select pg_temp.como_faz(pg_temp.ana(), $$select encerrar_jogo(pg_temp.id('j5'))$$);

-- Recusas, na ordem (RN27).

select pg_temp.como(pg_temp.tito());
select pg_temp.espera_recusa('com as três pendências, a primeira é a cobrança em aberto',
  $$select excluir_conta()$$, 'cobranca_em_aberto');
reset role;

-- Ana dá baixa na cobrança de Tito em j1, depois do encerramento.
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.id('j1');
select pg_temp.como_faz(pg_temp.ana(), $$select encerrar_jogo(pg_temp.id('j1'))$$);
select pg_temp.como_faz(pg_temp.ana(), format('select dar_baixa(%L)', pg_temp.cob('j1', pg_temp.tito())));

select pg_temp.como(pg_temp.tito());
select pg_temp.espera_recusa('sem dever nada, ainda tem a receber: cobrança em aberto como credor',
  $$select excluir_conta()$$, 'cobranca_em_aberto');
reset role;

-- Tito encerra j2 e isenta a cobrança de Ana.
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.id('j2');
select pg_temp.como_faz(pg_temp.tito(), $$select encerrar_jogo(pg_temp.id('j2'))$$);
select pg_temp.como_faz(pg_temp.tito(), format('select isentar_cobranca(%L)', pg_temp.cob('j2', pg_temp.ana())));

select pg_temp.como(pg_temp.tito());
select pg_temp.espera_recusa('resolvidas as cobranças, admin único de Sábado, com Ana como membro',
  $$select excluir_conta()$$, 'promova_outro_admin');
select pg_temp.espera_ok('Tito promove Ana', $$select promover_admin(pg_temp.id('sabado'), pg_temp.ana())$$);
select pg_temp.espera_recusa('promovida Ana, resta ser recebedor de j3, aberto; Solo, onde ele é o último membro, não bloqueia',
  $$select excluir_conta()$$, 'recebedor_de_jogo_aberto');
select pg_temp.espera_ok('Tito cancela j3', $$select cancelar_jogo(pg_temp.id('j3'))$$);
reset role;

select pg_temp.espera_verdade('as recusas não mexeram em nada: o perfil, os grupos e as filas seguem como estavam',
  (select nome || ':' || chave_pix from pessoa where id = pg_temp.tito()) = 'Tito Souza:tito@pix'
  and (select count(*) from membro_grupo where pessoa_id = pg_temp.tito()) = 3
  and (select count(*) from dispositivo_push where pessoa_id = pg_temp.tito()) = 2
  and pg_temp.situacao('j4', pg_temp.tito()) = 'lista_espera:1'
  and exists (select 1 from auth.users where id = pg_temp.tito()));

-- Exclusão (RN27, RNF04).

select pg_temp.como(pg_temp.tito());
select pg_temp.espera_ok('sem pendência, Tito exclui a conta: j2 encerrado e j3 cancelado, em que é o recebedor, não bloqueiam',
  $$select excluir_conta()$$);
select pg_temp.espera_ok('e repete o pedido, com o token ainda válido', $$select excluir_conta()$$);
reset role;

select pg_temp.espera_verdade('o perfil fica anonimizado: Jogador removido, sem foto, telefone nem chave',
  exists (select 1 from pessoa where id = pg_temp.tito() and nome = 'Jogador removido'
            and avatar_url is null and telefone is null and chave_pix is null));
select pg_temp.espera_verdade('a chave copiada sumiu dos jogos em que ele é o recebedor, e só deles',
  (select chave_pix_recebedor from jogo where id = pg_temp.id('j2')) is null
  and (select chave_pix_recebedor from jogo where id = pg_temp.id('j3')) is null
  and (select chave_pix_recebedor from jogo where id = pg_temp.id('j1')) = 'ana@pix');
select pg_temp.espera_verdade('fora de todos os grupos; Sábado fica com Ana como admin, e Solo, vazio',
  not exists (select 1 from membro_grupo where pessoa_id = pg_temp.tito())
  and (select array_agg(pessoa_id::text || ':' || papel) from membro_grupo where grupo_id = pg_temp.id('sabado'))
      = array['a0000000-0000-0000-0000-000000000001:admin']
  and not exists (select 1 from membro_grupo where grupo_id = pg_temp.id('solo')));
select pg_temp.espera_verdade('os aparelhos de Tito foram apagados, e o de Ana ficou',
  not exists (select 1 from dispositivo_push where pessoa_id = pg_temp.tito())
  and exists (select 1 from dispositivo_push where pessoa_id = pg_temp.ana() and token_fcm = 'token-ana'));
select pg_temp.espera_verdade('na fila do jogo aberto, saiu no prazo, e Membro 2 subiu',
  pg_temp.situacao('j4', pg_temp.tito()) = 'cancelou_no_prazo'
  and (select cancelado_em from participacao where jogo_id = pg_temp.id('j4') and pessoa_id = pg_temp.tito()) = now()
  and pg_temp.situacao('j4', pg_temp.m(2)) = 'lista_espera:1'
  and not exists (select 1 from cobranca where id = pg_temp.cob('j4', pg_temp.tito())));
select pg_temp.espera_verdade('na fila do jogo encerrado, continua lista_espera (RN17)',
  pg_temp.situacao('j5', pg_temp.tito()) = 'lista_espera:1');
select pg_temp.espera_verdade('o usuário saiu de auth.users',
  not exists (select 1 from auth.users where id = pg_temp.tito()));
select pg_temp.espera_verdade('participações e cobranças encerradas continuam, apontando ao perfil anonimizado',
  pg_temp.situacao('j1', pg_temp.tito()) = 'confirmado'
  and exists (select 1 from cobranca where id = pg_temp.cob('j1', pg_temp.tito())
                and devedor_id = pg_temp.tito() and credor_id = pg_temp.ana() and status = 'confirmado')
  and exists (select 1 from cobranca where id = pg_temp.cob('j2', pg_temp.ana())
                and devedor_id = pg_temp.ana() and credor_id = pg_temp.tito() and status = 'isenta'
                and confirmado_por = pg_temp.tito())
  and (select recebedor_id from jogo where id = pg_temp.id('j2')) = pg_temp.tito()
  and (select criador_id from jogo where id = pg_temp.id('j3')) = pg_temp.tito());

-- Privilégios.

select pg_temp.espera_verdade('authenticated executa excluir_conta; anon não',
  has_function_privilege('authenticated', 'public.excluir_conta()', 'execute')
  and not has_function_privilege('anon', 'public.excluir_conta()', 'execute'));
select pg_temp.como(null);
select pg_temp.espera_erro('anon chamando excluir_conta é barrado', $$select excluir_conta()$$, '42501');
reset role;

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
