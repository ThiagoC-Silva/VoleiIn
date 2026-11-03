-- Cenários da visão cobranca_vencimento (migração visoes): o prazo (RN07), a marca de
-- vencida (RN26), a política de linha da visão (RN19, RNF02) e a concordância com a
-- listar_participantes, que passou a ler daqui. Roda numa transação desfeita, a partir do
-- banco recém-resetado com o seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/visoes.sql
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

-- Ids de grupos, jogos e cobranças, guardados como postgres para os cenários seguintes.
create temp table ids (nome text primary key, id uuid not null);
create function pg_temp.id(p_nome text) returns uuid language sql stable as $$ select id from ids where nome = p_nome $$;
-- Membro n dos grupos: 90…0n.
create function pg_temp.m(p_n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-0000-0000-' || lpad(p_n::text, 12, '0'))::uuid
$$;
-- Guarda o id de cada cobrança do jogo como '<jogo>:<nome da pessoa>'.
create function pg_temp.guarda_cobrancas(p_jogo text) returns void language sql as $$
  insert into ids
  select p_jogo || ':' || pe.nome, c.id
  from cobranca c join participacao p on p.id = c.participacao_id join pessoa pe on pe.id = p.pessoa_id
  where p.jogo_id = pg_temp.id(p_jogo)
  on conflict (nome) do update set id = excluded.id;
$$;
-- Age como a pessoa num comando só e volta ao postgres.
create function pg_temp.como_faz(p_pessoa uuid, p_comando text) returns void language plpgsql as $$
begin
  perform pg_temp.como(p_pessoa);
  execute p_comando;
  reset role;
end;
$$;
-- A marca da cobrança da pessoa no jogo, lida da visão como postgres (sem política de linha).
create function pg_temp.vencida(p_jogo text, p_pessoa uuid) returns boolean language sql stable as $$
  select cv.vencida from cobranca_vencimento cv
  join participacao p on p.id = cv.participacao_id
  where p.jogo_id = pg_temp.id(p_jogo) and cv.devedor_id = p_pessoa
$$;

grant select, insert on ids to authenticated;
grant execute on function pg_temp.id(text), pg_temp.m(integer), pg_temp.proximo(integer, time) to authenticated;

-- Elenco, inserido como postgres. Os membros entram direto em membro_grupo, porque o
-- convite de grupo só chega no passo 9.
--   Ana    a0…  cria Sábado, os jogos dele e o avulso; é a recebedora deles
--   Bruno  b0…  membro de Sábado; devedor em quase tudo
--   Carlos c0…  membro de Sábado, com chave; cria Quinta e recebe lá
--   Membros 1 a 3 (90…), membros dos dois grupos
insert into pessoa (id, nome, chave_pix) values
  ('a0000000-0000-0000-0000-000000000001', 'Ana Souza', 'ana@pix'),
  ('b0000000-0000-0000-0000-000000000001', 'Bruno Lima', null),
  ('c0000000-0000-0000-0000-000000000001', 'Carlos Dias', 'carlos@pix');
insert into pessoa (id, nome) select pg_temp.m(n), 'Membro ' || n from generate_series(1, 3) n;

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('sabado', criar_grupo('Areia de Sábado', '#3B6FE0', 3));
reset role;
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
insert into ids values ('quinta', criar_grupo('Quinta no Ginásio', '#0FA3A0', 3));
reset role;

insert into membro_grupo (grupo_id, pessoa_id, papel)
select pg_temp.id('sabado'), p, 'membro'
from (select unnest(array['b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001']::uuid[]) p
      union all select pg_temp.m(n) from generate_series(1, 3) n) membros;
insert into membro_grupo (grupo_id, pessoa_id, papel)
select pg_temp.id('quinta'), pg_temp.m(n), 'membro' from generate_series(1, 3) n;

-- g1, de Sábado: encerrado e passado do prazo, com um status de cobrança de cada tipo.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g1', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(1, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('g1'))$$)
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
                  pg_temp.m(1), pg_temp.m(2), pg_temp.m(3)]) p;
select pg_temp.como_faz(pg_temp.m(3), $$select cancelar_presenca(pg_temp.id('g1'))$$);
select pg_temp.guarda_cobrancas('g1');

-- g2, de Sábado: encerrado, mas ainda dentro das 24 h.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g2', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(2, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz('b0000000-0000-0000-0000-000000000001', $$select confirmar_presenca(pg_temp.id('g2'))$$);

-- g3, de Sábado: segue aberto. Bruno e Membro 3 confirmam.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g3', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(3, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('g3'))$$)
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(3)]) p;

-- g4, de Sábado: cancelado antes do início (RN23), com a cobrança cancelada junto.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g4', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002', pg_temp.proximo(3, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz('b0000000-0000-0000-0000-000000000001', $$select confirmar_presenca(pg_temp.id('g4'))$$);
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select cancelar_jogo(pg_temp.id('g4'))$$);

-- g5, avulso da Ana, que recebe: encerrado e passado do prazo. Quem é de fora de um avulso
-- não confirma sem convite (passo 9), então a participação anterior entra como postgres,
-- do mesmo jeito que em rpc_presenca.sql.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g5', criar_jogo(null, '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(4, '19:00'), 120, 10, 10000, 3));
reset role;
insert into participacao (jogo_id, pessoa_id, status, cancelado_em)
select pg_temp.id('g5'), p, 'cancelou_no_prazo', now()
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(1)]) p;
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('g5'))$$)
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(1)]) p;

-- gq, de Quinta: encerrado e passado do prazo, com o Carlos recebendo. É a dívida de outra
-- turma, que não pode marcar ninguém em Sábado nem no avulso da Ana.
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
insert into ids values ('gq', criar_jogo(pg_temp.id('quinta'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002', pg_temp.proximo(1, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('gq'))$$)
from unnest(array[pg_temp.m(1), pg_temp.m(3)]) p;

-- O tempo anda: dentro da transação now() não muda, então o início é que recua (como nas
-- suítes do passo 4). g1, g5 e gq ficam passados do vencimento; g2, ainda dentro das 24 h.
update jogo set inicio = now() - interval '30 hours'
where id in (pg_temp.id('g1'), pg_temp.id('g5'), pg_temp.id('gq'));
update jogo set inicio = now() - interval '3 hours' where id = pg_temp.id('g2');

select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('g1'))$$);
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('g2'))$$);
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('g5'))$$);
select pg_temp.como_faz('c0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('gq'))$$);

select pg_temp.guarda_cobrancas('g5');

-- Os outros status de cobrança em g1, já encerrado: o envio do comprovante chega no passo 6,
-- então o status entra como postgres; a baixa e a isenção vão pelo caminho real.
update cobranca set status = 'comprovante_enviado' where id = pg_temp.id('g1:Carlos Dias');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Ana dá baixa na cobrança de Membro 1 em g1',
  $$select dar_baixa(pg_temp.id('g1:Membro 1'))$$);
select pg_temp.espera_ok('Ana isenta a cobrança de Membro 2 em g1',
  $$select isentar_cobranca(pg_temp.id('g1:Membro 2'))$$);
-- E na do avulso também, para a única dívida vencida do Membro 1 ser a de Quinta, com o
-- Carlos: é o que faz a asserção do recorte de turma no avulso dizer algo.
select pg_temp.espera_ok('Ana dá baixa na cobrança de Membro 1 em g5',
  $$select dar_baixa(pg_temp.id('g5:Membro 1'))$$);
reset role;


-- O prazo (RN07): 24 h depois do encerramento previsto, que é início + duração + 1 h.

select pg_temp.espera_verdade('vence_em é início + duração + 1 h + 24 h em todo jogo',
  not exists (
    select 1 from cobranca_vencimento cv
    join participacao p on p.id = cv.participacao_id
    join jogo j on j.id = p.jogo_id
    where cv.vence_em is distinct from
          j.inicio + make_interval(mins => j.duracao_minutos) + interval '1 hour' + interval '24 hours'));
select pg_temp.espera_verdade('e bate com privado.vencimento e com a janela de falta da RN04',
  (select cv.vence_em = privado.vencimento(j.inicio, j.duracao_minutos)
   from cobranca_vencimento cv
   join participacao p on p.id = cv.participacao_id
   join jogo j on j.id = p.jogo_id
   where cv.id = pg_temp.id('g1:Bruno Lima')));


-- A marca de vencida (RN26): pendente, jogo encerrado e prazo passado.

select pg_temp.espera_verdade('Bruno, pendente em g1, está vencido',
  pg_temp.vencida('g1', 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('Carlos não está vencido: mandou comprovante',
  pg_temp.vencida('g1', 'c0000000-0000-0000-0000-000000000001') = false);
select pg_temp.espera_verdade('Membro 1 não está vencido: cobrança confirmada',
  pg_temp.vencida('g1', pg_temp.m(1)) = false);
select pg_temp.espera_verdade('Membro 2 não está vencido: cobrança isenta',
  pg_temp.vencida('g1', pg_temp.m(2)) = false);
select pg_temp.espera_verdade('Membro 3 não está vencido: cancelou no prazo, cobrança cancelada',
  pg_temp.vencida('g1', pg_temp.m(3)) = false);
select pg_temp.espera_verdade('Bruno não está vencido em g2: encerrado, mas dentro das 24 h',
  pg_temp.vencida('g2', 'b0000000-0000-0000-0000-000000000001') = false);
select pg_temp.espera_verdade('Bruno não está vencido em g3: o jogo segue aberto',
  pg_temp.vencida('g3', 'b0000000-0000-0000-0000-000000000001') = false);
select pg_temp.espera_verdade('Bruno não está vencido em g4: jogo cancelado e cobrança cancelada',
  pg_temp.vencida('g4', 'b0000000-0000-0000-0000-000000000001') = false);
select pg_temp.espera_verdade('a recebedora não aparece na visão: não deve a si mesma (RN07)',
  not exists (select 1 from cobranca_vencimento cv
              join participacao p on p.id = cv.participacao_id
              where p.jogo_id = pg_temp.id('g1')
                and cv.devedor_id = 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('nenhuma cobrança fica fora da visão',
  (select count(*) from cobranca_vencimento) = (select count(*) from cobranca));


-- Política de linha da visão (RN19, RNF02): devedor e credor, mais ninguém.

select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_verdade('Bruno vê as cobranças dele, e só elas',
  (select count(*) > 0 and bool_and(devedor_id = 'b0000000-0000-0000-0000-000000000001'
                                    or credor_id = 'b0000000-0000-0000-0000-000000000001')
   from cobranca_vencimento));
select pg_temp.espera_verdade('a contagem na visão é a mesma da tabela, pela mesma política',
  (select count(*) from cobranca_vencimento) = (select count(*) from cobranca));
select pg_temp.espera_verdade('Bruno vê a própria marca de vencida em g1',
  (select vencida from cobranca_vencimento where id = pg_temp.id('g1:Bruno Lima')));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_verdade('Ana, credora, vê a cobrança de Bruno em g1',
  (select vencida from cobranca_vencimento where id = pg_temp.id('g1:Bruno Lima')));
select pg_temp.espera_verdade('Ana não vê a cobrança de Membro 1 em gq, que é com o Carlos',
  not exists (select 1 from cobranca_vencimento where id = pg_temp.id('gq:Membro 1')));

select pg_temp.como(pg_temp.m(3));
select pg_temp.espera_verdade('Membro 3 não vê a cobrança de Bruno, do mesmo jogo',
  not exists (select 1 from cobranca_vencimento where id = pg_temp.id('g1:Bruno Lima')));

select pg_temp.como(null);
select pg_temp.espera_erro('anon não lê a visão', $$select count(*) from cobranca_vencimento$$, '42501');
reset role;


-- Concordância com a listar_participantes (RN26), que agora lê a visão.

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_verdade('Ana, admin e recebedora, vê Bruno marcado em g1',
  (select debito_vencido from listar_participantes(pg_temp.id('g1'))
   where pessoa_id = 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('e também em g3, que está aberto: a dívida é da mesma turma',
  (select debito_vencido from listar_participantes(pg_temp.id('g3'))
   where pessoa_id = 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('no avulso g5, Bruno é marcado pela dívida com a mesma recebedora',
  (select debito_vencido from listar_participantes(pg_temp.id('g5'))
   where pessoa_id = 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('Carlos não é marcado em g1: mandou comprovante',
  (select debito_vencido = false from listar_participantes(pg_temp.id('g1'))
   where pessoa_id = 'c0000000-0000-0000-0000-000000000001'));

-- O recorte de turma fica na listar_participantes, não na visão: as duas afirmações abaixo
-- são sobre a mesma cobrança, vista dos dois lados.
select pg_temp.espera_verdade('Membro 3 não é marcado em g3: a dívida vencida dele é de Quinta',
  (select debito_vencido = false from listar_participantes(pg_temp.id('g3'))
   where pessoa_id = pg_temp.m(3)));
select pg_temp.espera_verdade('Membro 1 não é marcado no avulso g5: a dívida vencida dele é com o Carlos',
  (select debito_vencido = false from listar_participantes(pg_temp.id('g5'))
   where pessoa_id = pg_temp.m(1)));
reset role;
select pg_temp.espera_verdade('e a visão confirma que as duas dívidas de Quinta estão vencidas',
  pg_temp.vencida('gq', pg_temp.m(1)) and pg_temp.vencida('gq', pg_temp.m(3)));

-- Varredura: para todo jogo em que a Ana vê a marca, a lista e a visão dizem o mesmo. Ana é
-- credora de tudo que ela compara aqui, então a visão não lhe esconde linha; o recorte de
-- turma está nas duas asserções acima, que olham dívida de outro credor.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_verdade('a lista e a visão concordam em todo participante dos jogos da Ana',
  not exists (
    select 1
    from jogo j
    join participacao p on p.jogo_id = j.id
    join lateral listar_participantes(j.id) l on l.pessoa_id = p.pessoa_id
    where j.id <> pg_temp.id('gq')
      and l.debito_vencido is distinct from exists (
        select 1 from cobranca_vencimento cv
        where cv.devedor_id = p.pessoa_id
          and cv.vencida
          and case when j.grupo_id is not null then cv.grupo_id = j.grupo_id
                   else cv.credor_id = j.recebedor_id end)));
reset role;

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
