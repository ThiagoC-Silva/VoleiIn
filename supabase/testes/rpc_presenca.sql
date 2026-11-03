-- Cenários de confirmar e cancelar presença e de marcar falta (migração rpc_presenca): papel
-- (RN13), cobrança (RN07), fila (RN08), isenção do cancelante tardio (RN05), reconfirmação
-- (RN25), trava (RNF09), falta (RN04) e o aviso de prazo de editar_grupo (RN11), que precisa
-- de confirmados. Roda numa transação desfeita, a partir do banco recém-resetado com o
-- seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_presenca.sql
--
-- O cancelamento tardio dos cenários da RN05 aproxima o início do jogo de now(), como se o
-- tempo tivesse passado, e o devolve depois, para os cancelamentos no prazo seguintes.

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
-- Membro n do grupo: 90…0n.
create function pg_temp.m(p_n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-0000-0000-' || lpad(p_n::text, 12, '0'))::uuid
$$;
-- Status e posição da pessoa no jogo, como 'lista_espera:2'.
create function pg_temp.situacao(p_jogo text, p_pessoa uuid) returns text language sql stable as $$
  select status || coalesce(':' || posicao_espera, '') from participacao
  where jogo_id = pg_temp.id(p_jogo) and pessoa_id = p_pessoa
$$;
-- A cobrança da pessoa no jogo, como 'pendente:parte:1000'.
create function pg_temp.cobranca(p_jogo text, p_pessoa uuid) returns text language sql stable as $$
  select c.status || ':' || c.origem || ':' || c.valor
  from cobranca c join participacao p on p.id = c.participacao_id
  where p.jogo_id = pg_temp.id(p_jogo) and p.pessoa_id = p_pessoa
$$;
-- Confirma como a pessoa e guarda o status devolvido.
create temp table devolvido (pessoa uuid, jogo text, status participacao_status);
create function pg_temp.confirma(p_pessoa uuid, p_jogo text) returns void language plpgsql as $$
begin
  perform pg_temp.como(p_pessoa);
  insert into devolvido values (p_pessoa, p_jogo, confirmar_presenca(pg_temp.id(p_jogo)));
  reset role;
end;
$$;
-- Cancela como a pessoa e guarda o status devolvido. Dentro da transação, now() é o
-- mesmo em todo comando: quando a ordem dos cancelamentos importa (RN05), p_quando
-- move cancelado_em para trás, como postgres.
create function pg_temp.cancela(p_pessoa uuid, p_jogo text, p_quando timestamptz default null)
returns void language plpgsql as $$
begin
  perform pg_temp.como(p_pessoa);
  insert into devolvido values (p_pessoa, p_jogo, cancelar_presenca(pg_temp.id(p_jogo)));
  reset role;
  if p_quando is not null then
    update participacao set cancelado_em = p_quando
    where jogo_id = pg_temp.id(p_jogo) and pessoa_id = p_pessoa;
  end if;
end;
$$;
-- Move o início do jogo, como postgres: é assim que o tempo passa nos cenários.
create function pg_temp.inicio(p_jogo text, p_inicio timestamptz) returns void language sql as $$
  update jogo set inicio = p_inicio where id = pg_temp.id(p_jogo);
$$;

grant select, insert on ids, devolvido to authenticated;
grant execute on function pg_temp.proximo(integer, time), pg_temp.id(text), pg_temp.m(integer) to authenticated;

-- Elenco, inserido como postgres. Os membros entram em Sábado direto em membro_grupo,
-- porque o convite de grupo só chega no passo 9.
--   Ana    a0…  cria Sábado (prazo 3 h) e quase todos os jogos; é a recebedora
--   Bruno  b0…  membro; cancela tarde primeiro
--   Carlos c0…  membro; cancela tarde depois
--   Dani   d0…  de fora, com chave; cria um avulso
--   Eva    e0…  membro; substituta
--   Fabi   f0…  membro; substituta
--   Membros 1 a 13 (90…), para encher jogos
insert into pessoa (id, nome, chave_pix) values
  ('a0000000-0000-0000-0000-000000000001', 'Ana Souza', 'ana@pix'),
  ('b0000000-0000-0000-0000-000000000001', 'Bruno Lima', null),
  ('c0000000-0000-0000-0000-000000000001', 'Carlos', null),
  ('d0000000-0000-0000-0000-000000000001', 'Dani', 'dani@pix'),
  ('e0000000-0000-0000-0000-000000000001', 'Eva', null),
  ('f0000000-0000-0000-0000-000000000001', 'Fabi', null);
insert into pessoa (id, nome) select pg_temp.m(n), 'Membro ' || n from generate_series(1, 13) n;

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('sabado', criar_grupo('Areia de Sábado', '#3B6FE0', 3));
reset role;

insert into membro_grupo (grupo_id, pessoa_id, papel)
select pg_temp.id('sabado'), p, 'membro'
from (select unnest(array['b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
                          'e0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001']::uuid[]) p
      union all select pg_temp.m(n) from generate_series(1, 13) n) membros;

-- Jogos, criados pelas funções. Segunda 19h na Arena e semelhantes.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values
  -- R$ 100,00 em 10 vagas, segue o prazo do grupo.
  ('dez', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                     pg_temp.proximo(1, '19:00'), 120, 10, 10000, null)),
  -- R$ 30,00 em 3 vagas: os dois cenários da RN05.
  ('rn05a', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                       pg_temp.proximo(2, '19:00'), 120, 3, 3000, null)),
  ('rn05b', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
                       pg_temp.proximo(2, '19:00'), 120, 3, 3000, null)),
  -- Prazo próprio de 4 h.
  ('proprio', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                         pg_temp.proximo(3, '19:00'), 120, 10, 10000, 4)),
  ('comeca', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
                        pg_temp.proximo(3, '19:00'), 120, 10, 10000, null)),
  ('cancelado', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                           pg_temp.proximo(4, '19:00'), 120, 10, 10000, null));
reset role;

-- Membro 1 cria um jogo com Ana recebendo.
select pg_temp.como(pg_temp.m(1));
insert into ids values ('do_membro', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002', pg_temp.proximo(4, '19:00'), 60, 10, 10000, null,
  'a0000000-0000-0000-0000-000000000001'));
-- Dani cria um avulso no Ginásio.
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
insert into ids values ('avulso', criar_jogo(null, '10000000-0000-0000-0000-000000000002', null,
  pg_temp.proximo(0, '10:00'), 60, 10, 10000, 2));
reset role;

-- Papel (RN13).

select pg_temp.espera_ok('membro confirma', $$select pg_temp.confirma(pg_temp.m(1), 'dez')$$);
select pg_temp.espera_verdade('o membro fica confirmado, agora, com cobrança pendente de parte no valor por vaga',
  pg_temp.situacao('dez', pg_temp.m(1)) = 'confirmado'
  and (select confirmado_em from participacao where jogo_id = pg_temp.id('dez') and pessoa_id = pg_temp.m(1)) = now()
  and pg_temp.cobranca('dez', pg_temp.m(1)) = 'pendente:parte:1000'
  and exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
              where p.jogo_id = pg_temp.id('dez') and p.pessoa_id = pg_temp.m(1)
                and c.devedor_id = pg_temp.m(1) and c.credor_id = 'a0000000-0000-0000-0000-000000000001'
                and c.confirmado_por is null and c.confirmado_em is null)
  and (select status from devolvido where pessoa = pg_temp.m(1)) = 'confirmado');

select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem não é membro não confirma no jogo do grupo',
  $$select confirmar_presenca(pg_temp.id('dez'))$$, 'sem_permissao', '42501');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('avulso: quem não tem vínculo não confirma',
  $$select confirmar_presenca(pg_temp.id('avulso'))$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('jogo que não existe',
  $$select confirmar_presenca('40000000-0000-0000-0000-0000000000ff')$$, 'sem_permissao', '42501');
reset role;

-- Ana passa a ter vínculo com o avulso: uma participação antiga, cancelada no prazo.
insert into participacao (jogo_id, pessoa_id, status, cancelado_em)
values (pg_temp.id('avulso'), 'a0000000-0000-0000-0000-000000000001', 'cancelou_no_prazo', now());

select pg_temp.espera_ok('avulso: com participação, Ana confirma', $$select pg_temp.confirma('a0000000-0000-0000-0000-000000000001', 'avulso')$$);
select pg_temp.espera_verdade('no avulso, Ana deve a parte dela a Dani',
  pg_temp.situacao('avulso', 'a0000000-0000-0000-0000-000000000001') = 'confirmado'
  and pg_temp.cobranca('avulso', 'a0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000'
  and exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
              where p.jogo_id = pg_temp.id('avulso') and c.credor_id = 'd0000000-0000-0000-0000-000000000001'));

-- Recebedor (RN07).

select pg_temp.espera_ok('Ana, recebedora do jogo do Membro 1, confirma', $$select pg_temp.confirma('a0000000-0000-0000-0000-000000000001', 'do_membro')$$);
select pg_temp.espera_verdade('a recebedora confirma sem cobrança; o criador deve a ela',
  pg_temp.situacao('do_membro', 'a0000000-0000-0000-0000-000000000001') = 'confirmado'
  and pg_temp.cobranca('do_membro', 'a0000000-0000-0000-0000-000000000001') is null
  and pg_temp.cobranca('do_membro', pg_temp.m(1)) = 'pendente:parte:1000');

select pg_temp.espera_ok('mais oito membros confirmam no jogo de dez vagas',
  $$select pg_temp.confirma(pg_temp.m(n), 'dez') from generate_series(2, 9) n$$);
select pg_temp.espera_verdade('R$ 100,00 em 10 vagas com a recebedora jogando: 9 cobranças de R$ 10,00',
  (select count(*) from participacao where jogo_id = pg_temp.id('dez') and status = 'confirmado') = 10
  and (select count(*) || ':' || sum(c.valor) from cobranca c join participacao p on p.id = c.participacao_id
       where p.jogo_id = pg_temp.id('dez') and c.status = 'pendente' and c.valor = 1000) = '9:9000'
  and pg_temp.cobranca('dez', 'a0000000-0000-0000-0000-000000000001') is null);

-- Toque repetido (RNF10).

select pg_temp.espera_ok('o membro confirma de novo', $$select pg_temp.confirma(pg_temp.m(1), 'dez')$$);
select pg_temp.espera_ok('a recebedora confirma de novo', $$select pg_temp.confirma('a0000000-0000-0000-0000-000000000001', 'dez')$$);
select pg_temp.espera_verdade('o toque repetido devolve confirmado, sem segunda participação nem segunda cobrança',
  (select count(*) from participacao where jogo_id = pg_temp.id('dez') and pessoa_id = pg_temp.m(1)) = 1
  and (select count(*) from cobranca c join participacao p on p.id = c.participacao_id
       where p.jogo_id = pg_temp.id('dez') and p.pessoa_id = pg_temp.m(1)) = 1
  and (select count(*) from participacao where jogo_id = pg_temp.id('dez')) = 10
  and (select array_agg(status) from devolvido where pessoa = pg_temp.m(1) and jogo = 'dez') = array['confirmado', 'confirmado']::participacao_status[]);

-- Lista de espera (RN08).

select pg_temp.espera_ok('jogo cheio: Membro 10, Membro 11 e Membro 12 vão para a lista',
  $$select pg_temp.confirma(pg_temp.m(n), 'dez') from generate_series(10, 12) n$$);
select pg_temp.espera_ok('Membro 10 confirma de novo', $$select pg_temp.confirma(pg_temp.m(10), 'dez')$$);
select pg_temp.espera_verdade('posições 1, 2 e 3, sem cobrança, e a repetição não muda a posição',
  pg_temp.situacao('dez', pg_temp.m(10)) = 'lista_espera:1'
  and pg_temp.situacao('dez', pg_temp.m(11)) = 'lista_espera:2'
  and pg_temp.situacao('dez', pg_temp.m(12)) = 'lista_espera:3'
  and pg_temp.cobranca('dez', pg_temp.m(10)) is null
  and (select array_agg(status) from devolvido where pessoa = pg_temp.m(10)) = array['lista_espera', 'lista_espera']::participacao_status[]);

-- Abre uma vaga: Membro 5 cancela no prazo.
select pg_temp.cancela(pg_temp.m(5), 'dez');

select pg_temp.espera_ok('vaga livre com fila: Membro 13, de fora da lista, confirma primeiro',
  $$select pg_temp.confirma(pg_temp.m(13), 'dez')$$);
select pg_temp.espera_verdade('a vaga fica com Membro 13, e a lista segue igual',
  pg_temp.situacao('dez', pg_temp.m(13)) = 'confirmado'
  and pg_temp.situacao('dez', pg_temp.m(10)) = 'lista_espera:1'
  and pg_temp.situacao('dez', pg_temp.m(11)) = 'lista_espera:2'
  and pg_temp.situacao('dez', pg_temp.m(12)) = 'lista_espera:3');

-- Outra vaga: Membro 6 cancela no prazo, e quem pega é o segundo da lista.
select pg_temp.cancela(pg_temp.m(6), 'dez');

select pg_temp.espera_ok('Membro 11, segundo da lista, confirma primeiro', $$select pg_temp.confirma(pg_temp.m(11), 'dez')$$);
select pg_temp.espera_verdade('Membro 11 sai da lista com cobrança, e o terceiro sobe para segundo',
  pg_temp.situacao('dez', pg_temp.m(11)) = 'confirmado'
  and pg_temp.cobranca('dez', pg_temp.m(11)) = 'pendente:parte:1000'
  and pg_temp.situacao('dez', pg_temp.m(10)) = 'lista_espera:1'
  and pg_temp.situacao('dez', pg_temp.m(12)) = 'lista_espera:2');

-- Reconfirmação de quem cancelou no prazo (RN25).

select pg_temp.espera_ok('Membro 5, que cancelou no prazo, reconfirma com o jogo cheio',
  $$select pg_temp.confirma(pg_temp.m(5), 'dez')$$);
select pg_temp.espera_verdade('sem vaga, a reconfirmação cai no fim da lista, e a cobrança segue cancelada',
  pg_temp.situacao('dez', pg_temp.m(5)) = 'lista_espera:3'
  and pg_temp.cobranca('dez', pg_temp.m(5)) = 'cancelada:parte:1000');

select pg_temp.cancela(pg_temp.m(7), 'dez');
create temp table cobranca_m5 as
select c.id from cobranca c join participacao p on p.id = c.participacao_id
where p.jogo_id = pg_temp.id('dez') and p.pessoa_id = pg_temp.m(5);

select pg_temp.espera_ok('com vaga, Membro 5 confirma da lista', $$select pg_temp.confirma(pg_temp.m(5), 'dez')$$);
select pg_temp.espera_verdade('a mesma cobrança é reaberta como pendente de parte, e a lista não tem buraco',
  pg_temp.situacao('dez', pg_temp.m(5)) = 'confirmado'
  and pg_temp.cobranca('dez', pg_temp.m(5)) = 'pendente:parte:1000'
  and (select c.id from cobranca c join participacao p on p.id = c.participacao_id
       where p.jogo_id = pg_temp.id('dez') and p.pessoa_id = pg_temp.m(5)) = (select id from cobranca_m5)
  and pg_temp.situacao('dez', pg_temp.m(10)) = 'lista_espera:1'
  and pg_temp.situacao('dez', pg_temp.m(12)) = 'lista_espera:2');

-- RN05: isenção do cancelante tardio, na ordem dos cancelamentos.

select pg_temp.espera_ok('rn05b: Bruno e Carlos confirmam e lotam o jogo de 3 vagas',
  $$select pg_temp.confirma(p, 'rn05b') from unnest(array['b0000000-0000-0000-0000-000000000001',
      'c0000000-0000-0000-0000-000000000001']::uuid[]) p$$);
-- Bruno cancela tarde primeiro; Carlos, depois.
select pg_temp.inicio('rn05b', now() + interval '1 hour');
select pg_temp.cancela('b0000000-0000-0000-0000-000000000001', 'rn05b', now() - interval '2 hours');
select pg_temp.cancela('c0000000-0000-0000-0000-000000000001', 'rn05b', now() - interval '1 hour');
select pg_temp.inicio('rn05b', pg_temp.proximo(2, '19:00'));

select pg_temp.espera_ok('Eva confirma', $$select pg_temp.confirma('e0000000-0000-0000-0000-000000000001', 'rn05b')$$);
select pg_temp.espera_verdade('a primeira confirmação isenta a multa de Bruno, sem autor, e só a dele',
  pg_temp.cobranca('rn05b', 'b0000000-0000-0000-0000-000000000001') = 'isenta:cancelamento_tardio:1000'
  and pg_temp.cobranca('rn05b', 'c0000000-0000-0000-0000-000000000001') = 'pendente:cancelamento_tardio:1000'
  and pg_temp.cobranca('rn05b', 'e0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000'
  and exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
              where p.jogo_id = pg_temp.id('rn05b') and p.pessoa_id = 'b0000000-0000-0000-0000-000000000001'
                and c.confirmado_por is null and c.confirmado_em is null));
select pg_temp.espera_verdade('Bruno recebe o aviso da isenção, com o texto aprovado, levando à cobrança',
  exists (select 1 from notificacao n
          join cobranca c on c.id = n.cobranca_id
          join participacao p on p.id = c.participacao_id
          where n.pessoa_id = 'b0000000-0000-0000-0000-000000000001' and n.tipo = 'cobranca_isenta'
            and p.jogo_id = pg_temp.id('rn05b') and n.jogo_id is null
            and n.titulo = 'Multa isenta'
            and n.corpo = format('Outra pessoa confirmou presença em Areia de Sábado, %s. Os R$ 10,00 da sua multa não são mais devidos.',
                                 privado.data_curta(pg_temp.proximo(2, '19:00')))));

select pg_temp.espera_ok('Fabi confirma', $$select pg_temp.confirma('f0000000-0000-0000-0000-000000000001', 'rn05b')$$);
select pg_temp.espera_verdade('a segunda confirmação isenta a de Carlos',
  pg_temp.cobranca('rn05b', 'c0000000-0000-0000-0000-000000000001') = 'isenta:cancelamento_tardio:1000'
  and (select count(*) from notificacao where tipo = 'cobranca_isenta') = 2
  and exists (select 1 from notificacao where tipo = 'cobranca_isenta' and pessoa_id = 'c0000000-0000-0000-0000-000000000001'));

-- RN25: Bruno, isento, volta. Jogo cheio: lista; com vaga, a cobrança isenta é reaberta.
select pg_temp.espera_ok('Bruno, isento, reconfirma com o jogo cheio', $$select pg_temp.confirma('b0000000-0000-0000-0000-000000000001', 'rn05b')$$);
select pg_temp.espera_verdade('Bruno vai para a lista, e a multa dele segue isenta',
  pg_temp.situacao('rn05b', 'b0000000-0000-0000-0000-000000000001') = 'lista_espera:1'
  and pg_temp.cobranca('rn05b', 'b0000000-0000-0000-0000-000000000001') = 'isenta:cancelamento_tardio:1000');

select pg_temp.cancela('f0000000-0000-0000-0000-000000000001', 'rn05b');

select pg_temp.espera_ok('com vaga, Bruno confirma', $$select pg_temp.confirma('b0000000-0000-0000-0000-000000000001', 'rn05b')$$);
select pg_temp.espera_verdade('a cobrança isenta de Bruno é reaberta como pendente de parte',
  pg_temp.situacao('rn05b', 'b0000000-0000-0000-0000-000000000001') = 'confirmado'
  and pg_temp.cobranca('rn05b', 'b0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000'
  and (select count(*) from cobranca c join participacao p on p.id = c.participacao_id
       where p.jogo_id = pg_temp.id('rn05b') and p.pessoa_id = 'b0000000-0000-0000-0000-000000000001') = 1);

-- A reconfirmação do próprio cancelante tardio não isenta o outro.
select pg_temp.espera_ok('rn05a: Bruno e Carlos confirmam',
  $$select pg_temp.confirma(p, 'rn05a') from unnest(array['b0000000-0000-0000-0000-000000000001',
      'c0000000-0000-0000-0000-000000000001']::uuid[]) p$$);
select pg_temp.inicio('rn05a', now() + interval '1 hour');
select pg_temp.cancela('b0000000-0000-0000-0000-000000000001', 'rn05a', now() - interval '2 hours');
select pg_temp.cancela('c0000000-0000-0000-0000-000000000001', 'rn05a', now() - interval '1 hour');
select pg_temp.inicio('rn05a', pg_temp.proximo(2, '19:00'));

select pg_temp.espera_ok('Bruno, cancelante tardio, reconfirma', $$select pg_temp.confirma('b0000000-0000-0000-0000-000000000001', 'rn05a')$$);
select pg_temp.espera_verdade('a multa de Bruno vira parte, e a de Carlos segue pendente',
  pg_temp.cobranca('rn05a', 'b0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000'
  and pg_temp.cobranca('rn05a', 'c0000000-0000-0000-0000-000000000001') = 'pendente:cancelamento_tardio:1000'
  and (select count(*) from notificacao where tipo = 'cobranca_isenta') = 2);

select pg_temp.espera_ok('Eva confirma', $$select pg_temp.confirma('e0000000-0000-0000-0000-000000000001', 'rn05a')$$);
select pg_temp.espera_verdade('agora a de Carlos é isenta',
  pg_temp.cobranca('rn05a', 'c0000000-0000-0000-0000-000000000001') = 'isenta:cancelamento_tardio:1000');

-- Cancelante tardio que passou pela lista: ao pegar a vaga, ainda não isenta o outro.
select pg_temp.espera_ok('Carlos, isento, reconfirma com rn05a cheio', $$select pg_temp.confirma('c0000000-0000-0000-0000-000000000001', 'rn05a')$$);
select pg_temp.espera_verdade('Carlos vai para a lista', pg_temp.situacao('rn05a', 'c0000000-0000-0000-0000-000000000001') = 'lista_espera:1');
select pg_temp.inicio('rn05a', now() + interval '1 hour');
select pg_temp.cancela('e0000000-0000-0000-0000-000000000001', 'rn05a');
select pg_temp.inicio('rn05a', pg_temp.proximo(2, '19:00'));
select pg_temp.espera_ok('Eva cancela tarde, e Carlos confirma da lista', $$select pg_temp.confirma('c0000000-0000-0000-0000-000000000001', 'rn05a')$$);
select pg_temp.espera_verdade('a volta de Carlos reabre a cobrança dele como parte e não isenta a multa pendente de Eva',
  pg_temp.situacao('rn05a', 'c0000000-0000-0000-0000-000000000001') = 'confirmado'
  and pg_temp.cobranca('rn05a', 'c0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000'
  and pg_temp.cobranca('rn05a', 'e0000000-0000-0000-0000-000000000001') = 'pendente:cancelamento_tardio:1000');

select pg_temp.cancela('b0000000-0000-0000-0000-000000000001', 'rn05a');
select pg_temp.espera_ok('Bruno cancela no prazo, e Fabi, de fora da lista, ocupa a vaga', $$select pg_temp.confirma('f0000000-0000-0000-0000-000000000001', 'rn05a')$$);
select pg_temp.espera_verdade('a confirmação de Fabi isenta a multa de Eva',
  pg_temp.cobranca('rn05a', 'e0000000-0000-0000-0000-000000000001') = 'isenta:cancelamento_tardio:1000'
  and (select count(*) from notificacao where tipo = 'cobranca_isenta') = 4);

-- Cancelar presença (RF15): prazo, multa, lista de espera e vaga liberada.

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values
  -- Segue o prazo do grupo, 3 h.
  ('c_grupo', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
                         pg_temp.proximo(5, '19:00'), 120, 10, 10000, null)),
  -- Prazo próprio de 1 h, que vence o do grupo.
  ('c_proprio', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
                           pg_temp.proximo(5, '19:00'), 120, 10, 10000, 1)),
  -- Prazo de 500 h: nasce com o prazo sem multa vencido (RN02).
  ('c_vencido', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000002', null,
                           pg_temp.proximo(6, '10:00'), 60, 10, 10000, 500)),
  -- Idem, mas remarcado: cancelamento_livre_ate no futuro.
  ('c_livre', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000002', null,
                         pg_temp.proximo(6, '12:00'), 60, 10, 10000, 500)),
  -- Duas vagas, para a fila.
  ('c_fila', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000002', null,
                        pg_temp.proximo(0, '12:00'), 60, 2, 10000, null));
reset role;

-- No prazo (RN02) e reconfirmação (RN25).
select pg_temp.confirma(pg_temp.m(3), 'c_grupo');
create temp table cobranca_c_grupo as
select c.id from cobranca c join participacao p on p.id = c.participacao_id
where p.jogo_id = pg_temp.id('c_grupo') and p.pessoa_id = pg_temp.m(3);

select pg_temp.espera_ok('Membro 3 cancela no prazo', $$select pg_temp.cancela(pg_temp.m(3), 'c_grupo')$$);
select pg_temp.espera_verdade('no prazo: cancelou_no_prazo, agora, e a cobrança cancelada',
  pg_temp.situacao('c_grupo', pg_temp.m(3)) = 'cancelou_no_prazo'
  and (select cancelado_em from participacao where jogo_id = pg_temp.id('c_grupo') and pessoa_id = pg_temp.m(3)) = now()
  and pg_temp.cobranca('c_grupo', pg_temp.m(3)) = 'cancelada:parte:1000'
  and (select status from devolvido where pessoa = pg_temp.m(3) and jogo = 'c_grupo' order by ctid desc limit 1) = 'cancelou_no_prazo');
select pg_temp.espera_ok('cancelar de novo', $$select pg_temp.cancela(pg_temp.m(3), 'c_grupo')$$);
select pg_temp.espera_verdade('cancelar duas vezes não muda nada e devolve o status atual',
  pg_temp.situacao('c_grupo', pg_temp.m(3)) = 'cancelou_no_prazo'
  and pg_temp.cobranca('c_grupo', pg_temp.m(3)) = 'cancelada:parte:1000'
  and (select status from devolvido where pessoa = pg_temp.m(3) and jogo = 'c_grupo' order by ctid desc limit 1) = 'cancelou_no_prazo');
select pg_temp.espera_ok('Membro 3 reconfirma', $$select pg_temp.confirma(pg_temp.m(3), 'c_grupo')$$);
select pg_temp.espera_verdade('reconfirmar reabre a mesma cobrança, pendente de parte',
  pg_temp.situacao('c_grupo', pg_temp.m(3)) = 'confirmado'
  and pg_temp.cobranca('c_grupo', pg_temp.m(3)) = 'pendente:parte:1000'
  and (select c.id from cobranca c join participacao p on p.id = c.participacao_id
       where p.jogo_id = pg_temp.id('c_grupo') and p.pessoa_id = pg_temp.m(3)) = (select id from cobranca_c_grupo));

select pg_temp.como(pg_temp.m(4));
select pg_temp.espera_verdade('quem não participa cancela sem efeito e recebe vazio',
  cancelar_presenca(pg_temp.id('c_grupo')) is null);
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem não vê o jogo é recusado',
  $$select cancelar_presenca(pg_temp.id('c_grupo'))$$, 'sem_permissao', '42501');
reset role;

-- Fora do prazo (RN03): o prazo do grupo vale quando o jogo não tem o próprio; o do jogo vence.
select pg_temp.confirma(pg_temp.m(4), 'c_proprio');
select pg_temp.inicio('c_grupo', now() + interval '2 hours');
select pg_temp.inicio('c_proprio', now() + interval '2 hours');

select pg_temp.espera_ok('a 2 h do início, Membro 3 cancela no jogo que segue as 3 h do grupo',
  $$select pg_temp.cancela(pg_temp.m(3), 'c_grupo')$$);
select pg_temp.espera_verdade('fora do prazo: cancelou_fora_do_prazo e multa de cancelamento_tardio pelo mesmo valor',
  pg_temp.situacao('c_grupo', pg_temp.m(3)) = 'cancelou_fora_do_prazo'
  and pg_temp.cobranca('c_grupo', pg_temp.m(3)) = 'pendente:cancelamento_tardio:1000'
  and (select status from devolvido where pessoa = pg_temp.m(3) and jogo = 'c_grupo' order by ctid desc limit 1) = 'cancelou_fora_do_prazo');
select pg_temp.espera_ok('a 2 h do início, Membro 4 cancela no jogo de prazo próprio de 1 h',
  $$select pg_temp.cancela(pg_temp.m(4), 'c_proprio')$$);
select pg_temp.espera_verdade('o prazo do jogo vence o do grupo: no prazo',
  pg_temp.situacao('c_proprio', pg_temp.m(4)) = 'cancelou_no_prazo'
  and pg_temp.cobranca('c_proprio', pg_temp.m(4)) = 'cancelada:parte:1000');

-- Jogo criado com o prazo já vencido (RN02).
select pg_temp.confirma(pg_temp.m(8), 'c_vencido');
select pg_temp.espera_ok('Membro 8 cancela no jogo que nasceu com o prazo vencido',
  $$select pg_temp.cancela(pg_temp.m(8), 'c_vencido')$$);
select pg_temp.espera_verdade('o primeiro cancelamento já é tardio',
  pg_temp.situacao('c_vencido', pg_temp.m(8)) = 'cancelou_fora_do_prazo'
  and pg_temp.cobranca('c_vencido', pg_temp.m(8)) = 'pendente:cancelamento_tardio:1000');
select pg_temp.espera_ok('Ana, a recebedora, cancela tarde', $$select pg_temp.cancela('a0000000-0000-0000-0000-000000000001', 'c_vencido')$$);
select pg_temp.espera_verdade('a recebedora cancela tarde sem multa: não tem cobrança',
  pg_temp.situacao('c_vencido', 'a0000000-0000-0000-0000-000000000001') = 'cancelou_fora_do_prazo'
  and pg_temp.cobranca('c_vencido', 'a0000000-0000-0000-0000-000000000001') is null);

-- cancelamento_livre_ate no futuro (RN20).
select pg_temp.confirma(pg_temp.m(9), 'c_livre');
update jogo set cancelamento_livre_ate = inicio where id = pg_temp.id('c_livre');
select pg_temp.espera_ok('Membro 9 cancela no jogo remarcado, depois do prazo normal',
  $$select pg_temp.cancela(pg_temp.m(9), 'c_livre')$$);
select pg_temp.espera_verdade('cancelamento_livre_ate no futuro deixa o cancelamento sem multa',
  pg_temp.situacao('c_livre', pg_temp.m(9)) = 'cancelou_no_prazo'
  and pg_temp.cobranca('c_livre', pg_temp.m(9)) = 'cancelada:parte:1000');

-- Lista de espera (RN08) e vaga liberada.
select pg_temp.confirma(pg_temp.m(1), 'c_fila');
select pg_temp.confirma(p, 'c_fila') from unnest(array['e0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001']::uuid[]) p;
select pg_temp.espera_verdade('fila: Eva(1), Bruno(2), Carlos(3)',
  pg_temp.situacao('c_fila', 'e0000000-0000-0000-0000-000000000001') = 'lista_espera:1'
  and pg_temp.situacao('c_fila', 'b0000000-0000-0000-0000-000000000001') = 'lista_espera:2'
  and pg_temp.situacao('c_fila', 'c0000000-0000-0000-0000-000000000001') = 'lista_espera:3');

-- A 1 h do início, sair da lista ainda é no prazo.
select pg_temp.inicio('c_fila', now() + interval '1 hour');
select pg_temp.espera_ok('Bruno sai da lista', $$select pg_temp.cancela('b0000000-0000-0000-0000-000000000001', 'c_fila')$$);
select pg_temp.espera_verdade('sair da lista é cancelou_no_prazo, sem cobrança, e a fila fica Eva(1), Carlos(2)',
  pg_temp.situacao('c_fila', 'b0000000-0000-0000-0000-000000000001') = 'cancelou_no_prazo'
  and pg_temp.cobranca('c_fila', 'b0000000-0000-0000-0000-000000000001') is null
  and pg_temp.situacao('c_fila', 'e0000000-0000-0000-0000-000000000001') = 'lista_espera:1'
  and pg_temp.situacao('c_fila', 'c0000000-0000-0000-0000-000000000001') = 'lista_espera:2'
  and not exists (select 1 from notificacao where tipo = 'vaga_liberada' and jogo_id = pg_temp.id('c_fila')));

select pg_temp.espera_ok('Membro 1, confirmado, cancela com fila', $$select pg_temp.cancela(pg_temp.m(1), 'c_fila')$$);
select pg_temp.espera_verdade('cada pessoa da fila recebe um vaga_liberada, com o texto do G1; quem saiu, não',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao
   where tipo = 'vaga_liberada' and jogo_id = pg_temp.id('c_fila'))
  = array['c0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001']::uuid[]
  and not exists (select 1 from notificacao where tipo = 'vaga_liberada' and jogo_id = pg_temp.id('c_fila')
                  and (titulo <> 'Abriu uma vaga em Areia de Sábado'
                       or corpo <> format('%s · %s. Fica com quem confirmar primeiro.',
                                          privado.data_curta(now() + interval '1 hour'), privado.hora(now() + interval '1 hour'))
                       or cobranca_id is not null)));
select pg_temp.espera_verdade('a vaga não é dada a ninguém: a fila segue como estava',
  pg_temp.situacao('c_fila', 'e0000000-0000-0000-0000-000000000001') = 'lista_espera:1'
  and (select count(*) from participacao where jogo_id = pg_temp.id('c_fila') and status = 'confirmado') = 1);

select pg_temp.espera_ok('Eva confirma e fica com a vaga', $$select pg_temp.confirma('e0000000-0000-0000-0000-000000000001', 'c_fila')$$);
select pg_temp.espera_ok('Ana, a recebedora, cancela com a fila só com Carlos', $$select pg_temp.cancela('a0000000-0000-0000-0000-000000000001', 'c_fila')$$);
select pg_temp.espera_verdade('o novo anúncio vai só a Carlos, e Eva não recebe outro',
  (select count(*) from notificacao where tipo = 'vaga_liberada' and jogo_id = pg_temp.id('c_fila')
     and pessoa_id = 'c0000000-0000-0000-0000-000000000001') = 2
  and (select count(*) from notificacao where tipo = 'vaga_liberada' and jogo_id = pg_temp.id('c_fila')
     and pessoa_id = 'e0000000-0000-0000-0000-000000000001') = 1);
select pg_temp.espera_ok('Carlos confirma, e Eva cancela com a fila vazia', $$select pg_temp.confirma('c0000000-0000-0000-0000-000000000001', 'c_fila'), pg_temp.cancela('e0000000-0000-0000-0000-000000000001', 'c_fila')$$);
select pg_temp.espera_verdade('fila vazia: ninguém é avisado',
  (select count(*) from notificacao where tipo = 'vaga_liberada' and jogo_id = pg_temp.id('c_fila')) = 3);

-- Depois do início e jogo fechado.
select pg_temp.inicio('c_grupo', now() - interval '1 minute');
select pg_temp.como(pg_temp.m(3));
select pg_temp.espera_recusa('depois do início, cancelar é recusado',
  $$select cancelar_presenca(pg_temp.id('c_grupo'))$$, 'jogo_ja_comecou');
reset role;
update jogo set status = 'cancelado' where id = pg_temp.id('c_proprio');
select pg_temp.como(pg_temp.m(4));
select pg_temp.espera_recusa('jogo cancelado, recusado',
  $$select cancelar_presenca(pg_temp.id('c_proprio'))$$, 'jogo_fechado');
reset role;

-- Jogo que começou e jogo cancelado (RN06).

select pg_temp.espera_ok('Membro 2 confirma antes do início', $$select pg_temp.confirma(pg_temp.m(2), 'comeca')$$);
update jogo set inicio = now() - interval '1 minute' where id = pg_temp.id('comeca');
update jogo set status = 'cancelado' where id = pg_temp.id('cancelado');

select pg_temp.como(pg_temp.m(3));
select pg_temp.espera_recusa('depois do início, recusado',
  $$select confirmar_presenca(pg_temp.id('comeca'))$$, 'jogo_ja_comecou');
select pg_temp.como(pg_temp.m(2));
select pg_temp.espera_recusa('depois do início, até quem já confirmou é recusado',
  $$select confirmar_presenca(pg_temp.id('comeca'))$$, 'jogo_ja_comecou');
select pg_temp.como(pg_temp.m(3));
select pg_temp.espera_recusa('jogo cancelado, recusado',
  $$select confirmar_presenca(pg_temp.id('cancelado'))$$, 'jogo_fechado');
reset role;
update jogo set status = 'encerrado' where id = pg_temp.id('comeca');
select pg_temp.como(pg_temp.m(3));
select pg_temp.espera_recusa('jogo encerrado, recusado',
  $$select confirmar_presenca(pg_temp.id('comeca'))$$, 'jogo_fechado');
reset role;

-- Aviso de prazo do grupo (RN11), pendente da T03.

select pg_temp.espera_ok('Membro 4 confirma no jogo de prazo próprio', $$select pg_temp.confirma(pg_temp.m(4), 'proprio')$$);
-- Um jogo remarcado: o prazo sem multa é o próprio início, e mudar o do grupo não o muda.
update jogo set cancelamento_livre_ate = inicio where id = pg_temp.id('do_membro');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Ana muda o prazo do grupo de 3 h para 5 h',
  $$select editar_grupo(pg_temp.id('sabado'), 'Areia de Sábado', '#3B6FE0', 5)$$);
reset role;

select pg_temp.espera_verdade('avisa cada confirmado do jogo que segue o grupo, menos Ana, que editou',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao
   where tipo = 'regra_grupo_alterada' and jogo_id = pg_temp.id('dez'))
  = (select array_agg(pessoa_id order by pessoa_id) from participacao
     where jogo_id = pg_temp.id('dez') and status = 'confirmado'
       and pessoa_id <> 'a0000000-0000-0000-0000-000000000001')
  and (select count(*) from notificacao where tipo = 'regra_grupo_alterada' and jogo_id = pg_temp.id('dez')) = 9);
select pg_temp.espera_verdade('o texto diz o prazo novo e o prazo sem multa do jogo',
  exists (select 1 from notificacao
          where tipo = 'regra_grupo_alterada' and jogo_id = pg_temp.id('dez') and pessoa_id = pg_temp.m(1)
            and titulo = 'Novo prazo sem multa em Areia de Sábado'
            and corpo = privado.corpo_regra_grupo(5, pg_temp.proximo(1, '19:00'), pg_temp.proximo(1, '19:00') - interval '5 hours')
            and cobranca_id is null));
select pg_temp.espera_verdade('não avisa quem está na lista nem quem cancelou',
  not exists (select 1 from notificacao where tipo = 'regra_grupo_alterada'
              and pessoa_id in (pg_temp.m(10), pg_temp.m(12), pg_temp.m(6), pg_temp.m(7))));
select pg_temp.espera_verdade('não avisa no jogo de prazo próprio, no remarcado, no que começou nem no cancelado',
  not exists (select 1 from notificacao where tipo = 'regra_grupo_alterada'
              and jogo_id in (pg_temp.id('proprio'), pg_temp.id('do_membro'), pg_temp.id('comeca'), pg_temp.id('cancelado'))));
select pg_temp.espera_verdade('avisa também nos jogos da RN05 e na fila, que seguem o grupo',
  (select array_agg(distinct nome order by nome) from notificacao n join ids on ids.id = n.jogo_id
   where n.tipo = 'regra_grupo_alterada') = array['c_fila', 'dez', 'rn05a', 'rn05b']);

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('mudar só a cor depois não avisa de novo',
  $$select editar_grupo(pg_temp.id('sabado'), 'Areia de Sábado', '#7B5CE6', 5)$$);
reset role;
select pg_temp.espera_verdade('o número de avisos de prazo não mudou',
  (select count(*) from notificacao where tipo = 'regra_grupo_alterada')
  = (select count(*) from participacao p
     where p.status = 'confirmado' and p.pessoa_id <> 'a0000000-0000-0000-0000-000000000001'
       and p.jogo_id in (pg_temp.id('dez'), pg_temp.id('rn05a'), pg_temp.id('rn05b'), pg_temp.id('c_fila'))));

-- Marcar falta (RF18, RN04).

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select promover_admin(pg_temp.id('sabado'), 'f0000000-0000-0000-0000-000000000001');
reset role;

-- f1: Membro 1 cria com Ana recebendo. Ana e Membros 2 a 7 confirmam, e Membro 7 sai no prazo.
select pg_temp.como(pg_temp.m(1));
insert into ids values ('f1', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(1, '19:00') + interval '14 days', 120, 10, 10000, null,
  'a0000000-0000-0000-0000-000000000001'));
reset role;
select pg_temp.confirma(p, 'f1')
from unnest(array['a0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(2), pg_temp.m(3), pg_temp.m(4),
                  pg_temp.m(5), pg_temp.m(6), pg_temp.m(7)]) p;
select pg_temp.cancela(pg_temp.m(7), 'f1');

-- O fim reservado passou, mas o jogo segue aberto.
select pg_temp.inicio('f1', now() - interval '2 hours');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('antes do encerramento, mesmo depois do fim reservado',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(2))$$, 'jogo_nao_encerrado');
select pg_temp.espera_ok('Ana, admin, encerra f1', $$select encerrar_jogo(pg_temp.id('f1'))$$);
reset role;

-- Ana dá baixa na cobrança de Membro 3 e isenta a de Membro 4. As funções chegam na T10;
-- aqui, o par de autor e momento é gravado como postgres.
update cobranca c set status = 'confirmado', confirmado_por = 'a0000000-0000-0000-0000-000000000001', confirmado_em = now()
from participacao p where p.id = c.participacao_id and p.jogo_id = pg_temp.id('f1') and p.pessoa_id = pg_temp.m(3);
update cobranca c set status = 'isenta', confirmado_por = 'a0000000-0000-0000-0000-000000000001', confirmado_em = now()
from participacao p where p.id = c.participacao_id and p.jogo_id = pg_temp.id('f1') and p.pessoa_id = pg_temp.m(4);

select pg_temp.como(pg_temp.m(1));
select pg_temp.espera_recusa('o criador que não é recebedor nem admin não marca',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(2))$$, 'sem_permissao', '42501');
select pg_temp.como('e0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('membro comum não marca',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(2))$$, 'sem_permissao', '42501');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem é de fora não marca',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(2))$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('marcar falta em jogo que não existe',
  $$select marcar_falta('40000000-0000-0000-0000-0000000000ff', pg_temp.m(2))$$, 'sem_permissao', '42501');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Ana, a recebedora, marca a falta de Membro 2', $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(2))$$);
select pg_temp.espera_ok('e repete o pedido', $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(2))$$);
select pg_temp.espera_recusa('quem saiu no prazo não falta',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(7))$$, 'nao_confirmado');
select pg_temp.espera_recusa('quem nunca participou não falta',
  $$select marcar_falta(pg_temp.id('f1'), 'e0000000-0000-0000-0000-000000000001')$$, 'nao_confirmado');
select pg_temp.como('f0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Fabi, admin que não recebe, marca a falta de Membro 3, já paga',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(3))$$);
select pg_temp.espera_ok('e a de Membro 4, isenta', $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(4))$$);
select pg_temp.espera_ok('e a de Ana, a recebedora, que confirmou e não foi',
  $$select marcar_falta(pg_temp.id('f1'), 'a0000000-0000-0000-0000-000000000001')$$);
reset role;

select pg_temp.espera_verdade('participação e origem mudam juntas, com o mesmo valor, qualquer que seja o status',
  pg_temp.situacao('f1', pg_temp.m(2)) = 'faltou' and pg_temp.cobranca('f1', pg_temp.m(2)) = 'pendente:falta:1000'
  and pg_temp.situacao('f1', pg_temp.m(3)) = 'faltou' and pg_temp.cobranca('f1', pg_temp.m(3)) = 'confirmado:falta:1000'
  and pg_temp.situacao('f1', pg_temp.m(4)) = 'faltou' and pg_temp.cobranca('f1', pg_temp.m(4)) = 'isenta:falta:1000'
  and not exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
                  where p.jogo_id = pg_temp.id('f1') and p.pessoa_id in (pg_temp.m(3), pg_temp.m(4))
                    and c.confirmado_por is distinct from 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('a recebedora vira faltou, sem cobrança a mudar',
  pg_temp.situacao('f1', 'a0000000-0000-0000-0000-000000000001') = 'faltou'
  and pg_temp.cobranca('f1', 'a0000000-0000-0000-0000-000000000001') is null);
select pg_temp.espera_verdade('quem não foi marcado fica como estava',
  pg_temp.situacao('f1', pg_temp.m(5)) = 'confirmado' and pg_temp.cobranca('f1', pg_temp.m(5)) = 'pendente:parte:1000'
  and pg_temp.situacao('f1', pg_temp.m(1)) = 'confirmado' and pg_temp.cobranca('f1', pg_temp.m(1)) = 'pendente:parte:1000'
  and pg_temp.situacao('f1', pg_temp.m(7)) = 'cancelou_no_prazo' and pg_temp.cobranca('f1', pg_temp.m(7)) = 'cancelada:parte:1000');
select pg_temp.espera_verdade('falta_marcada uma vez a cada faltoso',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'falta_marcada')
  = array[pg_temp.m(2), pg_temp.m(3), pg_temp.m(4), 'a0000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_verdade('com cobrança, o aviso leva a ela, com o nome inteiro de quem marcou e a data sem vírgula',
  exists (select 1 from notificacao n join cobranca c on c.id = n.cobranca_id
          where n.tipo = 'falta_marcada' and n.pessoa_id = pg_temp.m(2) and c.devedor_id = pg_temp.m(2)
            and n.jogo_id is null and n.titulo = 'Falta marcada'
            and n.corpo = format('Ana Souza marcou sua falta em Areia de Sábado, %s. O valor da cobrança não muda.',
                                 replace(privado.data_curta(now() - interval '2 hours'), ',', ''))
            and n.corpo ~ '^Ana Souza marcou sua falta em Areia de Sábado, (dom|seg|ter|qua|qui|sex|sáb) [0-9]{1,2} [a-z]{3}\. ')
  and exists (select 1 from notificacao where tipo = 'falta_marcada' and pessoa_id = pg_temp.m(3)
                and corpo = format('Fabi marcou sua falta em Areia de Sábado, %s. O valor da cobrança não muda.',
                                   replace(privado.data_curta(now() - interval '2 hours'), ',', ''))));
select pg_temp.espera_verdade('sem cobrança, o da recebedora perde a frase do valor e leva ao jogo',
  exists (select 1 from notificacao
          where tipo = 'falta_marcada' and pessoa_id = 'a0000000-0000-0000-0000-000000000001'
            and jogo_id = pg_temp.id('f1') and cobranca_id is null and titulo = 'Falta marcada'
            and corpo = format('Fabi marcou sua falta em Areia de Sábado, %s.',
                               replace(privado.data_curta(now() - interval '2 hours'), ',', ''))));

-- A janela fecha 24 h depois do encerramento previsto: início + 2 h de jogo + 1 h + 24 h.
select pg_temp.inicio('f1', now() - interval '27 hours 1 minute');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('um minuto depois da janela',
  $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(5))$$, 'janela_de_falta_encerrada');
reset role;
select pg_temp.inicio('f1', now() - interval '27 hours');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('no último instante da janela', $$select marcar_falta(pg_temp.id('f1'), pg_temp.m(5))$$);
reset role;
select pg_temp.espera_verdade('Membro 5 faltou no limite da janela',
  pg_temp.situacao('f1', pg_temp.m(5)) = 'faltou' and pg_temp.cobranca('f1', pg_temp.m(5)) = 'pendente:falta:1000');

-- f2: no avulso, só o recebedor marca. Dani cria com Ana recebendo, e Ana confirma.
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
insert into ids values ('f2', criar_jogo(null, '10000000-0000-0000-0000-000000000002', null,
  pg_temp.proximo(0, '10:00') + interval '14 days', 60, 10, 10000, 2, 'a0000000-0000-0000-0000-000000000001'));
reset role;
select pg_temp.confirma('a0000000-0000-0000-0000-000000000001', 'f2');
select pg_temp.inicio('f2', now() - interval '1 hour');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Dani, a criadora, encerra o avulso', $$select encerrar_jogo(pg_temp.id('f2'))$$);
select pg_temp.espera_recusa('no avulso, a criadora que não recebe não marca',
  $$select marcar_falta(pg_temp.id('f2'), 'a0000000-0000-0000-0000-000000000001')$$, 'sem_permissao', '42501');
select pg_temp.como('f0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('no avulso, admin de grupo não marca',
  $$select marcar_falta(pg_temp.id('f2'), 'd0000000-0000-0000-0000-000000000001')$$, 'sem_permissao', '42501');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('no avulso, a recebedora marca a falta da criadora',
  $$select marcar_falta(pg_temp.id('f2'), 'd0000000-0000-0000-0000-000000000001')$$);
reset role;
select pg_temp.espera_verdade('Dani faltou e deve a falta a Ana; o aviso diz o nome do local',
  pg_temp.situacao('f2', 'd0000000-0000-0000-0000-000000000001') = 'faltou'
  and pg_temp.cobranca('f2', 'd0000000-0000-0000-0000-000000000001') = 'pendente:falta:1000'
  and exists (select 1 from notificacao where tipo = 'falta_marcada' and pessoa_id = 'd0000000-0000-0000-0000-000000000001'
                and corpo like 'Ana Souza marcou sua falta em Ginásio Municipal, %. O valor da cobrança não muda.'));

-- Privilégios.

select pg_temp.espera_verdade('authenticated executa marcar_falta; anon não',
  has_function_privilege('authenticated', 'public.marcar_falta(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.marcar_falta(uuid, uuid)', 'execute'));
select pg_temp.espera_verdade('authenticated executa confirmar_presenca e cancelar_presenca; anon não',
  has_function_privilege('authenticated', 'public.confirmar_presenca(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.confirmar_presenca(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.cancelar_presenca(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.cancelar_presenca(uuid)', 'execute'));
select pg_temp.espera_verdade('authenticated não executa as auxiliares de privado',
  not has_function_privilege('authenticated', 'privado.confirmar(uuid, uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.reais(integer)', 'execute')
  and not has_function_privilege('authenticated', 'privado.nome_jogo(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.anunciar_vaga(uuid)', 'execute'));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_erro('authenticated chamando privado.confirmar para outra pessoa é barrado',
  $$select privado.confirmar(pg_temp.id('dez'), pg_temp.m(13))$$, '42501');
select pg_temp.espera_erro('authenticated não insere participação direto',
  $$insert into participacao (jogo_id, pessoa_id, status) values (pg_temp.id('dez'), 'a0000000-0000-0000-0000-000000000001', 'confirmado')$$,
  '42501');
select pg_temp.como(null);
select pg_temp.espera_erro('anon chamando confirmar_presenca é barrado',
  $$select confirmar_presenca('00000000-0000-0000-0000-000000000000')$$, '42501');
reset role;

-- Formatação de dinheiro dos avisos.
select pg_temp.espera_verdade('reais: centavos, milhar com ponto, zero',
  privado.reais(1429) = 'R$ 14,29' and privado.reais(1000) = 'R$ 10,00' and privado.reais(5) = 'R$ 0,05'
  and privado.reais(0) = 'R$ 0,00' and privado.reais(123456) = 'R$ 1.234,56' and privado.reais(100000000) = 'R$ 1.000.000,00');
select pg_temp.espera_verdade('nome do jogo: o grupo, ou o local no avulso',
  privado.nome_jogo(pg_temp.id('dez')) = 'Areia de Sábado' and privado.nome_jogo(pg_temp.id('avulso')) = 'Ginásio Municipal');

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
