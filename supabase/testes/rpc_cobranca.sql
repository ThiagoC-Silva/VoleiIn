-- Cenários de dar baixa e isentar cobrança (migração rpc_cobranca): só o credor (RN13), só
-- depois do encerramento (RN07), o par de autor e momento, os avisos, a troca de recebedor
-- (RN20) e a âncora da retenção: depois do encerramento, nenhuma função altera cobrança
-- inativa, salvo a falta (RN19, docs/modelo-de-dados.md). Roda numa transação desfeita, a
-- partir do banco recém-resetado com o seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_cobranca.sql
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

-- Ids de grupos, jogos e cobranças, guardados como postgres para os cenários seguintes.
create temp table ids (nome text primary key, id uuid not null);
create function pg_temp.id(p_nome text) returns uuid language sql stable as $$ select id from ids where nome = p_nome $$;
-- Membro n do grupo: 90…0n.
create function pg_temp.m(p_n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-0000-0000-' || lpad(p_n::text, 12, '0'))::uuid
$$;
-- A cobrança da pessoa no jogo, como 'pendente:parte:1000'.
create function pg_temp.cobranca(p_jogo text, p_pessoa uuid) returns text language sql stable as $$
  select c.status || ':' || c.origem || ':' || c.valor
  from cobranca c join participacao p on p.id = c.participacao_id
  where p.jogo_id = pg_temp.id(p_jogo) and p.pessoa_id = p_pessoa
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
-- Como como_faz, mas aceita a recusa: a âncora da retenção roda tudo o que o app alcança.
create function pg_temp.tenta(p_pessoa uuid, p_comando text) returns void language plpgsql as $$
begin
  perform pg_temp.como(p_pessoa);
  begin
    execute p_comando;
  exception when others then
    null;
  end;
  reset role;
end;
$$;

grant select, insert on ids to authenticated;
grant execute on function pg_temp.id(text), pg_temp.m(integer), pg_temp.proximo(integer, time) to authenticated;

-- Elenco, inserido como postgres. Os membros entram em Sábado direto em membro_grupo,
-- porque o convite de grupo só chega no passo 9.
--   Ana    a0…  cria Sábado e os jogos; é a recebedora
--   Bruno  b0…  membro
--   Carlos c0…  membro, com chave; vira recebedor de g2
--   Dani   d0…  de fora
--   Membros 1 a 8 (90…)
insert into pessoa (id, nome, chave_pix) values
  ('a0000000-0000-0000-0000-000000000001', 'Ana Souza', 'ana@pix'),
  ('b0000000-0000-0000-0000-000000000001', 'Bruno Lima', null),
  ('c0000000-0000-0000-0000-000000000001', 'Carlos Dias', 'carlos@pix'),
  ('d0000000-0000-0000-0000-000000000001', 'Dani', null);
insert into pessoa (id, nome) select pg_temp.m(n), 'Membro ' || n from generate_series(1, 8) n;

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('sabado', criar_grupo('Areia de Sábado', '#3B6FE0', 3));
reset role;

insert into membro_grupo (grupo_id, pessoa_id, papel)
select pg_temp.id('sabado'), p, 'membro'
from (select unnest(array['b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001']::uuid[]) p
      union all select pg_temp.m(n) from generate_series(1, 8) n) membros;

-- g1: Ana recebe; Bruno, Carlos e Membros 1 a 3 confirmam; Membro 3 sai no prazo.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g1', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(1, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('g1'))$$)
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid,
                  pg_temp.m(1), pg_temp.m(2), pg_temp.m(3)]) p;
select pg_temp.como_faz(pg_temp.m(3), $$select cancelar_presenca(pg_temp.id('g1'))$$);
select pg_temp.guarda_cobrancas('g1');

-- Congelamento (RN07): antes do encerramento, nem o credor resolve.

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('credor dá baixa antes do encerramento',
  $$select dar_baixa(pg_temp.id('g1:Bruno Lima'))$$, 'pagamento_nao_liberado');
select pg_temp.espera_recusa('credor isenta antes do encerramento',
  $$select isentar_cobranca(pg_temp.id('g1:Bruno Lima'))$$, 'pagamento_nao_liberado');
select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('devedor dá baixa na própria cobrança antes do encerramento',
  $$select dar_baixa(pg_temp.id('g1:Bruno Lima'))$$, 'sem_permissao', '42501');
reset role;

update jogo set inicio = now() - interval '2 hours' where id = pg_temp.id('g1');
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('g1'))$$);

-- Papel (RN13): só o credor.

select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('devedor não dá baixa na própria cobrança',
  $$select dar_baixa(pg_temp.id('g1:Bruno Lima'))$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('devedor não isenta a própria cobrança',
  $$select isentar_cobranca(pg_temp.id('g1:Bruno Lima'))$$, 'sem_permissao', '42501');
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('outro participante não dá baixa',
  $$select dar_baixa(pg_temp.id('g1:Bruno Lima'))$$, 'sem_permissao', '42501');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem é de fora não isenta',
  $$select isentar_cobranca(pg_temp.id('g1:Bruno Lima'))$$, 'sem_permissao', '42501');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('cobrança que não existe',
  $$select dar_baixa('40000000-0000-0000-0000-0000000000ff')$$, 'sem_permissao', '42501');

-- Baixa e isenção (RF22, RF23).

select pg_temp.espera_ok('Ana dá baixa na cobrança de Bruno', $$select dar_baixa(pg_temp.id('g1:Bruno Lima'))$$);
select pg_temp.espera_ok('e repete o pedido', $$select dar_baixa(pg_temp.id('g1:Bruno Lima'))$$);
select pg_temp.espera_ok('Ana isenta a cobrança de Carlos', $$select isentar_cobranca(pg_temp.id('g1:Carlos Dias'))$$);
select pg_temp.espera_ok('e repete o pedido', $$select isentar_cobranca(pg_temp.id('g1:Carlos Dias'))$$);
reset role;

-- Membros 1 e 2 enviaram comprovante. O envio chega no passo 6; aqui, o status é gravado
-- como postgres.
update cobranca set status = 'comprovante_enviado' where id in (pg_temp.id('g1:Membro 1'), pg_temp.id('g1:Membro 2'));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('baixa de cobrança com comprovante enviado', $$select dar_baixa(pg_temp.id('g1:Membro 1'))$$);
select pg_temp.espera_ok('isenção de cobrança com comprovante enviado', $$select isentar_cobranca(pg_temp.id('g1:Membro 2'))$$);
select pg_temp.espera_recusa('baixa em cobrança isenta', $$select dar_baixa(pg_temp.id('g1:Carlos Dias'))$$, 'cobranca_resolvida');
select pg_temp.espera_recusa('isenção em cobrança paga', $$select isentar_cobranca(pg_temp.id('g1:Bruno Lima'))$$, 'cobranca_resolvida');
select pg_temp.espera_recusa('baixa em cobrança cancelada', $$select dar_baixa(pg_temp.id('g1:Membro 3'))$$, 'cobranca_resolvida');
select pg_temp.espera_recusa('isenção em cobrança cancelada', $$select isentar_cobranca(pg_temp.id('g1:Membro 3'))$$, 'cobranca_resolvida');
reset role;

select pg_temp.espera_verdade('baixa e isenção mudam o status e preenchem o par com Ana e agora; a cancelada fica sem par',
  pg_temp.cobranca('g1', 'b0000000-0000-0000-0000-000000000001') = 'confirmado:parte:1000'
  and pg_temp.cobranca('g1', 'c0000000-0000-0000-0000-000000000001') = 'isenta:parte:1000'
  and pg_temp.cobranca('g1', pg_temp.m(1)) = 'confirmado:parte:1000'
  and pg_temp.cobranca('g1', pg_temp.m(2)) = 'isenta:parte:1000'
  and pg_temp.cobranca('g1', pg_temp.m(3)) = 'cancelada:parte:1000'
  and (select count(*) from cobranca
       where id in (pg_temp.id('g1:Bruno Lima'), pg_temp.id('g1:Carlos Dias'), pg_temp.id('g1:Membro 1'), pg_temp.id('g1:Membro 2'))
         and confirmado_por = 'a0000000-0000-0000-0000-000000000001' and confirmado_em = now()) = 4
  and (select confirmado_por is null and confirmado_em is null from cobranca where id = pg_temp.id('g1:Membro 3')));
select pg_temp.espera_verdade('cobranca_confirmada uma vez a Bruno e a Membro 1; cobranca_isenta uma vez a Carlos e a Membro 2',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'cobranca_confirmada')
    = array[pg_temp.m(1), 'b0000000-0000-0000-0000-000000000001'::uuid]
  and (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'cobranca_isenta')
    = array[pg_temp.m(2), 'c0000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_verdade('os textos, levando à cobrança do próprio devedor, com a data do jogo sem vírgula',
  exists (select 1 from notificacao
          where tipo = 'cobranca_confirmada' and pessoa_id = 'b0000000-0000-0000-0000-000000000001'
            and cobranca_id = pg_temp.id('g1:Bruno Lima') and jogo_id is null
            and titulo = 'Ana confirmou seu pagamento'
            and corpo = 'R$ 10,00 · Areia de Sábado, '
                        || replace(privado.data_curta((select inicio from jogo where id = pg_temp.id('g1'))), ',', ''))
  and exists (select 1 from notificacao
          where tipo = 'cobranca_isenta' and pessoa_id = 'c0000000-0000-0000-0000-000000000001'
            and cobranca_id = pg_temp.id('g1:Carlos Dias') and jogo_id is null
            and titulo = 'Ana isentou sua cobrança'
            and corpo = 'R$ 10,00 · Areia de Sábado, '
                        || replace(privado.data_curta((select inicio from jogo where id = pg_temp.id('g1'))), ',', '')
                        || '. Nada a pagar.'
            and corpo ~ '^R\$ 10,00 · Areia de Sábado, (dom|seg|ter|qua|qui|sex|sáb) [0-9]{1,2} [a-z]{3}\. Nada a pagar\.$'));
select pg_temp.espera_verdade('nada além disso foi avisado ao credor',
  not exists (select 1 from notificacao where pessoa_id = 'a0000000-0000-0000-0000-000000000001'
              and tipo in ('cobranca_confirmada', 'cobranca_isenta')));

-- Troca de recebedor (RN20): só o novo credor resolve.

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g2', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002', pg_temp.proximo(1, '19:00'), 120, 10, 10000, null));
reset role;
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.id('g2'))$$)
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(4)]) p;
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001',
  $$select editar_jogo(pg_temp.id('g2'), p_recebedor => 'c0000000-0000-0000-0000-000000000001')$$);
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.id('g2');
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('g2'))$$);
select pg_temp.guarda_cobrancas('g2');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('o credor anterior não dá baixa', $$select dar_baixa(pg_temp.id('g2:Membro 4'))$$, 'sem_permissao', '42501');
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Carlos, o novo credor, dá baixa na cobrança de Membro 4', $$select dar_baixa(pg_temp.id('g2:Membro 4'))$$);
select pg_temp.espera_ok('e isenta a de Ana, que deixou de receber e passou a dever', $$select isentar_cobranca(pg_temp.id('g2:Ana Souza'))$$);
reset role;
select pg_temp.espera_verdade('o par leva Carlos, e os títulos, o primeiro nome dele',
  pg_temp.cobranca('g2', pg_temp.m(4)) = 'confirmado:parte:1000'
  and pg_temp.cobranca('g2', 'a0000000-0000-0000-0000-000000000001') = 'isenta:parte:1000'
  and (select count(*) from cobranca where id in (pg_temp.id('g2:Membro 4'), pg_temp.id('g2:Ana Souza'))
         and confirmado_por = 'c0000000-0000-0000-0000-000000000001') = 2
  and exists (select 1 from notificacao where pessoa_id = pg_temp.m(4) and tipo = 'cobranca_confirmada'
                and titulo = 'Carlos confirmou seu pagamento')
  and exists (select 1 from notificacao where pessoa_id = 'a0000000-0000-0000-0000-000000000001'
                and tipo = 'cobranca_isenta' and titulo = 'Carlos isentou sua cobrança'));

-- Âncora da retenção (RN19, docs/modelo-de-dados.md).
--
-- g3: Ana recebe, 8 vagas. Membros 1 a 7 completam o jogo, e Membro 8 e Bruno vão para a
-- fila. Perto do início, Membro 6 cancela tarde, e Membro 8 pega a vaga, isentando a multa.
-- De volta ao prazo, Membro 5 sai sem multa. Encerrado o jogo, Ana dá baixa nas cobranças de
-- Membros 1 e 3 e isenta as de Membros 2 e 4.

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('g3', criar_jogo(pg_temp.id('sabado'), '10000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001', pg_temp.proximo(2, '19:00'), 120, 8, 8000, null));
reset role;
select pg_temp.como_faz(pg_temp.m(n), $$select confirmar_presenca(pg_temp.id('g3'))$$) from generate_series(1, 8) n;
select pg_temp.como_faz('b0000000-0000-0000-0000-000000000001', $$select confirmar_presenca(pg_temp.id('g3'))$$);
update jogo set inicio = now() + interval '1 hour' where id = pg_temp.id('g3');
select pg_temp.como_faz(pg_temp.m(6), $$select cancelar_presenca(pg_temp.id('g3'))$$);
select pg_temp.como_faz(pg_temp.m(8), $$select confirmar_presenca(pg_temp.id('g3'))$$);
update jogo set inicio = pg_temp.proximo(2, '19:00') where id = pg_temp.id('g3');
select pg_temp.como_faz(pg_temp.m(5), $$select cancelar_presenca(pg_temp.id('g3'))$$);
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.id('g3');
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001', $$select encerrar_jogo(pg_temp.id('g3'))$$);
select pg_temp.guarda_cobrancas('g3');
select pg_temp.como_faz('a0000000-0000-0000-0000-000000000001',
  $$select dar_baixa(pg_temp.id('g3:Membro 1')), dar_baixa(pg_temp.id('g3:Membro 3')),
           isentar_cobranca(pg_temp.id('g3:Membro 2')), isentar_cobranca(pg_temp.id('g3:Membro 4'))$$);

select pg_temp.espera_verdade('g3 montado: duas pagas, duas isentas à mão, uma cancelada, uma multa isenta, duas pendentes e Bruno na fila',
  pg_temp.cobranca('g3', pg_temp.m(1)) = 'confirmado:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(2)) = 'isenta:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(3)) = 'confirmado:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(4)) = 'isenta:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(5)) = 'cancelada:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(6)) = 'isenta:cancelamento_tardio:1000'
  and pg_temp.cobranca('g3', pg_temp.m(7)) = 'pendente:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(8)) = 'pendente:parte:1000'
  and (select status from participacao where jogo_id = pg_temp.id('g3')
         and pessoa_id = 'b0000000-0000-0000-0000-000000000001') = 'lista_espera'
  and (select status from jogo where id = pg_temp.id('g3')) = 'encerrado');

-- Dentro da transação, now() não anda, e toda escrita já marcaria atualizado_em = now().
-- As cobranças inativas recuam um dia, com o gatilho desligado; qualquer escrita depois
-- disso as traz de volta a now().
alter table cobranca disable trigger tocar_atualizado_em;
update cobranca c set atualizado_em = now() - interval '1 day'
from participacao p
where p.id = c.participacao_id and p.jogo_id = pg_temp.id('g3') and c.status in ('confirmado', 'isenta', 'cancelada');
alter table cobranca enable trigger tocar_atualizado_em;

create temp table ancora as
select c.id, p.pessoa_id, c.status, c.origem, c.valor, c.credor_id, c.confirmado_por, c.confirmado_em, c.atualizado_em
from cobranca c join participacao p on p.id = c.participacao_id
where p.jogo_id = pg_temp.id('g3') and c.status in ('confirmado', 'isenta', 'cancelada');

select pg_temp.espera_verdade('seis cobranças inativas guardadas', (select count(*) from ancora) = 6);

-- Tudo o que o app alcança depois do encerramento, menos a falta, aceitando as recusas.
select pg_temp.espera_ok('baixa e isenção em toda cobrança de g3, pelo credor, pelo devedor e por um terceiro',
  $$select pg_temp.tenta(quem, format('select %s(%L)', funcao, c.id))
    from cobranca c join participacao p on p.id = c.participacao_id
    cross join unnest(array['dar_baixa', 'isentar_cobranca']) funcao
    cross join unnest(array['a0000000-0000-0000-0000-000000000001'::uuid, c.devedor_id,
                            'c0000000-0000-0000-0000-000000000001'::uuid]) quem
    where p.jogo_id = pg_temp.id('g3')$$);
select pg_temp.espera_ok('editar custo, vagas, data e recebedor; cancelar e encerrar de novo',
  $$select pg_temp.tenta('a0000000-0000-0000-0000-000000000001', comando)
    from unnest(array[
      format('select editar_jogo(%L, p_custo_total => 9000)', pg_temp.id('g3')),
      format('select editar_jogo(%L, p_vagas_total => 9)', pg_temp.id('g3')),
      format('select editar_jogo(%L, p_inicio => %L)', pg_temp.id('g3'), pg_temp.proximo(2, '20:00')),
      format('select editar_jogo(%L, p_recebedor => %L)', pg_temp.id('g3'), 'c0000000-0000-0000-0000-000000000001'),
      format('select cancelar_jogo(%L)', pg_temp.id('g3')),
      format('select encerrar_jogo(%L)', pg_temp.id('g3'))]) comando$$);
select pg_temp.espera_ok('confirmar e cancelar presença, como cada participante',
  $$select pg_temp.tenta(p.pessoa_id, format('select %s(%L)', funcao, p.jogo_id))
    from participacao p cross join unnest(array['confirmar_presenca', 'cancelar_presenca']) funcao
    where p.jogo_id = pg_temp.id('g3')$$);

select pg_temp.espera_verdade('nenhuma cobrança inativa mudou: nem o atualizado_em, nem o resto',
  not exists (select 1 from ancora a join cobranca c on c.id = a.id
              where (c.status, c.origem, c.valor, c.credor_id, c.confirmado_por, c.confirmado_em, c.atualizado_em)
                    is distinct from (a.status, a.origem, a.valor, a.credor_id, a.confirmado_por, a.confirmado_em, a.atualizado_em)));
select pg_temp.espera_verdade('as recusas eram de fato recusas: o jogo segue encerrado, com o custo, as vagas e o recebedor de antes',
  exists (select 1 from jogo where id = pg_temp.id('g3') and status = 'encerrado' and custo_total = 8000
            and vagas_total = 8 and recebedor_id = 'a0000000-0000-0000-0000-000000000001')
  and (select status from participacao where jogo_id = pg_temp.id('g3') and pessoa_id = pg_temp.m(5)) = 'cancelou_no_prazo'
  and (select status from participacao where jogo_id = pg_temp.id('g3')
         and pessoa_id = 'b0000000-0000-0000-0000-000000000001') = 'lista_espera');
select pg_temp.espera_verdade('a cobrança ativa, essa sim, o credor resolveu',
  pg_temp.cobranca('g3', pg_temp.m(7)) = 'confirmado:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(8)) = 'confirmado:parte:1000');

-- Por fim, a falta de cada participante, pela recebedora.
select pg_temp.espera_ok('marcar a falta de cada participante de g3',
  $$select pg_temp.tenta('a0000000-0000-0000-0000-000000000001', format('select marcar_falta(%L, %L)', p.jogo_id, p.pessoa_id))
    from participacao p where p.jogo_id = pg_temp.id('g3')$$);

select pg_temp.espera_verdade('só mudou a cobrança inativa cuja falta foi marcada: a paga e a isenta à mão, com origem falta',
  not exists (select 1 from ancora a join cobranca c on c.id = a.id
              join participacao p on p.id = c.participacao_id
              where (p.status = 'faltou') = (c.atualizado_em = a.atualizado_em))
  and (select array_agg(a.pessoa_id order by a.pessoa_id) from ancora a join cobranca c on c.id = a.id
       where c.atualizado_em <> a.atualizado_em)
      = array[pg_temp.m(1), pg_temp.m(2), pg_temp.m(3), pg_temp.m(4)]
  and pg_temp.cobranca('g3', pg_temp.m(1)) = 'confirmado:falta:1000'
  and pg_temp.cobranca('g3', pg_temp.m(2)) = 'isenta:falta:1000'
  and pg_temp.cobranca('g3', pg_temp.m(5)) = 'cancelada:parte:1000'
  and pg_temp.cobranca('g3', pg_temp.m(6)) = 'isenta:cancelamento_tardio:1000');

-- Privilégios.

select pg_temp.espera_verdade('authenticated executa dar_baixa e isentar_cobranca; anon não',
  has_function_privilege('authenticated', 'public.dar_baixa(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.isentar_cobranca(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.dar_baixa(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.isentar_cobranca(uuid)', 'execute'));
select pg_temp.espera_verdade('authenticated não executa as auxiliares de privado',
  not has_function_privilege('authenticated', 'privado.resolver_cobranca(uuid, public.cobranca_status)', 'execute')
  and not has_function_privilege('authenticated', 'privado.primeiro_nome(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.resumo_cobranca(uuid)', 'execute'));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_erro('authenticated chamando privado.resolver_cobranca é barrado',
  $$select privado.resolver_cobranca(pg_temp.id('g1:Membro 3'), 'confirmado')$$, '42501');
select pg_temp.espera_erro('o credor não muda a cobrança direto',
  $$update cobranca set status = 'confirmado' where id = pg_temp.id('g3:Membro 7')$$, '42501');
select pg_temp.como(null);
select pg_temp.espera_erro('anon chamando dar_baixa é barrado',
  $$select dar_baixa('00000000-0000-0000-0000-000000000000')$$, '42501');
reset role;

-- Auxiliares.
select pg_temp.espera_verdade('primeiro nome: a primeira palavra, sem espaços nas pontas',
  privado.primeiro_nome('a0000000-0000-0000-0000-000000000001') = 'Ana'
  and privado.primeiro_nome('d0000000-0000-0000-0000-000000000001') = 'Dani');

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
