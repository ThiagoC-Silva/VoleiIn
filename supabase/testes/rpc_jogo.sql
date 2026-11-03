-- Cenários de criar, duplicar, editar, cancelar e encerrar jogo (migração rpc_jogo): preço por
-- vaga (RN01, RN16), o criador confirmado (RN24), a chave do recebedor (RN24, RN28), o papel
-- de quem cria (RN13), as checagens de quadra e funcionamento (RN15), o cancelamento do jogo
-- (RN23) e o encerramento com o pagamento liberado (RN17, RN07). Roda numa transação
-- desfeita, a partir do banco recém-resetado com o seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_jogo.sql
--
-- Locais do seed: Arena Beira-Mar (10…01, por_quadra, Quadras 1 e 2, seg a sex 18h–23h,
-- sáb 20h–2h) e Ginásio Municipal (10…02, por_horario, capacidade 2, todo dia 7h–22h,
-- sex também 19h–0h).

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


-- Próximo dia da semana (0 é domingo) à hora dada em Brasília, sempre de amanhã em
-- diante, para a suíte passar em qualquer dia.
create function pg_temp.proximo(p_dia integer, p_hora time)
returns timestamptz
language sql
stable
as $$
  select ((hoje + (((p_dia - extract(dow from hoje)::int + 6) % 7) + 1)) + p_hora)
         at time zone 'America/Sao_Paulo'
  from (select (now() at time zone 'America/Sao_Paulo')::date as hoje) h;
$$;

-- Ids dos jogos criados pelas funções, guardados para os cenários seguintes.
create temp table ids (nome text primary key, id uuid not null);
grant select, insert on ids to authenticated;
grant execute on function pg_temp.proximo(integer, time) to authenticated;

-- Atalhos para o local e as quadras do seed.
create function pg_temp.arena() returns uuid language sql immutable as $$ select '10000000-0000-0000-0000-000000000001'::uuid $$;
create function pg_temp.ginasio() returns uuid language sql immutable as $$ select '10000000-0000-0000-0000-000000000002'::uuid $$;
create function pg_temp.q1() returns uuid language sql immutable as $$ select '20000000-0000-0000-0000-000000000001'::uuid $$;
create function pg_temp.q2() returns uuid language sql immutable as $$ select '20000000-0000-0000-0000-000000000002'::uuid $$;
create function pg_temp.jogo(p_nome text) returns uuid language sql stable as $$ select id from ids where nome = p_nome $$;
grant execute on function pg_temp.arena(), pg_temp.ginasio(), pg_temp.q1(), pg_temp.q2(), pg_temp.jogo(text)
to authenticated;

-- Elenco, inserido como postgres. Bruno e Carlos entram em Sábado direto em membro_grupo,
-- porque o convite de grupo só chega no passo 9.
--   Ana    a0…  cria Sábado (prazo 3 h); tem chave
--   Bruno  b0…  membro de Sábado, sem chave
--   Carlos c0…  membro de Sábado, com chave
--   Dani   d0…  de fora, com chave; cria avulso
insert into pessoa (id, nome, chave_pix) values
  ('a0000000-0000-0000-0000-000000000001', 'Ana Souza', 'ana@pix'),
  ('b0000000-0000-0000-0000-000000000001', 'Bruno Lima', null),
  ('c0000000-0000-0000-0000-000000000001', 'Carlos', 'carlos@pix'),
  ('d0000000-0000-0000-0000-000000000001', 'Dani', 'dani@pix');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('sabado', criar_grupo('Areia de Sábado', '#3B6FE0', 3));
reset role;

insert into membro_grupo (grupo_id, pessoa_id, papel)
select pg_temp.jogo('sabado'), p, 'membro'
from unnest(array['b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001']::uuid[]) p;

-- Criar no grupo: preço, criador confirmado e recebedor (RN01, RN16, RN24).

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Ana cria J1: segunda 19h, Quadra 1, 2 h, R$ 100,00 em 7 vagas',
  $$insert into ids values ('j1', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(),
      pg_temp.proximo(1, '19:00'), 120, 7, 10000, null))$$);
select pg_temp.espera_ok('Ana cria J2 na quadra vizinha, no mesmo horário: R$ 100,00 em 10 vagas',
  $$insert into ids values ('j2', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
      pg_temp.proximo(1, '19:00'), 60, 10, 10000, 4))$$);

reset role;

select pg_temp.espera_verdade('10000 em 7 vagas dá 1429', (select preco_por_vaga from jogo where id = pg_temp.jogo('j1')) = 1429);
select pg_temp.espera_verdade('10000 em 10 vagas dá 1000', (select preco_por_vaga from jogo where id = pg_temp.jogo('j2')) = 1000);
select pg_temp.espera_verdade('J1 nasce aberto, de Ana, com a chave do perfil dela e o prazo do grupo',
  exists (select 1 from jogo where id = pg_temp.jogo('j1') and status = 'aberto'
            and grupo_id = pg_temp.jogo('sabado')
            and criador_id = 'a0000000-0000-0000-0000-000000000001'
            and recebedor_id = 'a0000000-0000-0000-0000-000000000001'
            and chave_pix_recebedor = 'ana@pix'
            and prazo_cancelamento_horas is null and cancelamento_livre_ate is null));
select pg_temp.espera_verdade('criadora recebedora nasce confirmada, sem cobrança',
  (select array_agg(pessoa_id::text || ':' || status) from participacao where jogo_id = pg_temp.jogo('j1'))
    = array['a0000000-0000-0000-0000-000000000001:confirmado']
  and (select confirmado_em from participacao where jogo_id = pg_temp.jogo('j1')) = now()
  and not exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
                  where p.jogo_id = pg_temp.jogo('j1')));
select pg_temp.espera_verdade('prazo sem multa de J1: início menos as 3 h do grupo',
  privado.prazo_sem_multa(pg_temp.jogo('j1')) = pg_temp.proximo(1, '19:00') - interval '3 hours');
select pg_temp.espera_verdade('prazo sem multa de J2: início menos as 4 h do próprio jogo',
  privado.prazo_sem_multa(pg_temp.jogo('j2')) = pg_temp.proximo(1, '19:00') - interval '4 hours');

select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Bruno cria J3 com Ana recebendo: terça 19h, Quadra 1',
  $$insert into ids values ('j3', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(),
      pg_temp.proximo(2, '19:00'), 120, 7, 10000, null, 'a0000000-0000-0000-0000-000000000001'))$$);
select pg_temp.espera_recusa('Bruno recebendo, sem chave no perfil e sem chave digitada',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
      pg_temp.proximo(2, '19:00'), 120, 10, 10000, null)$$, 'recebedor_sem_chave');
select pg_temp.espera_recusa('chave digitada só de espaços conta como vazia',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
      pg_temp.proximo(2, '19:00'), 120, 10, 10000, null, null, '   ')$$, 'recebedor_sem_chave');
select pg_temp.espera_ok('Bruno recebendo, com a chave digitada: J4, terça 19h, Quadra 2',
  $$insert into ids values ('j4', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
      pg_temp.proximo(2, '19:00'), 120, 10, 10000, null, null, 'bruno-digitada'))$$);

reset role;

select pg_temp.espera_verdade('criador com outro recebedor nasce confirmado com cobrança de parte',
  exists (select 1 from participacao p join cobranca c on c.participacao_id = p.id
          where p.jogo_id = pg_temp.jogo('j3') and p.pessoa_id = 'b0000000-0000-0000-0000-000000000001'
            and p.status = 'confirmado'
            and c.devedor_id = 'b0000000-0000-0000-0000-000000000001'
            and c.credor_id = 'a0000000-0000-0000-0000-000000000001'
            and c.valor = 1429 and c.origem = 'parte' and c.status = 'pendente'
            and c.confirmado_por is null and c.confirmado_em is null)
  and (select chave_pix_recebedor from jogo where id = pg_temp.jogo('j3')) = 'ana@pix');
select pg_temp.espera_verdade('J4 guarda a chave digitada, e o perfil de Bruno segue sem chave',
  (select chave_pix_recebedor from jogo where id = pg_temp.jogo('j4')) = 'bruno-digitada'
  and (select chave_pix from pessoa where id = 'b0000000-0000-0000-0000-000000000001') is null
  and not exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
                  where p.jogo_id = pg_temp.jogo('j4')));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Ana cria J5 com Carlos recebendo e outra chave digitada: quarta 19h',
  $$insert into ids values ('j5', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(),
      pg_temp.proximo(3, '19:00'), 60, 10, 10000, null, 'c0000000-0000-0000-0000-000000000001', 'carlos-outra'))$$);
select pg_temp.espera_recusa('recebedor que a criadora não conhece',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
      pg_temp.proximo(3, '19:00'), 60, 10, 10000, null, 'd0000000-0000-0000-0000-000000000001')$$,
  'recebedor_desconhecido');
select pg_temp.espera_recusa('recebedor que não existe',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
      pg_temp.proximo(3, '19:00'), 60, 10, 10000, null, 'f0000000-0000-0000-0000-000000000001')$$,
  'recebedor_desconhecido');

reset role;

select pg_temp.espera_verdade('a chave digitada para Carlos não altera o perfil dele',
  (select chave_pix_recebedor from jogo where id = pg_temp.jogo('j5')) = 'carlos-outra'
  and (select chave_pix from pessoa where id = 'c0000000-0000-0000-0000-000000000001') = 'carlos@pix');

select pg_temp.espera_verdade('Ana, criadora de J5 sem ser a recebedora, deve a parte dela a Carlos',
  exists (select 1 from participacao p join cobranca c on c.participacao_id = p.id
          where p.jogo_id = pg_temp.jogo('j5') and p.pessoa_id = 'a0000000-0000-0000-0000-000000000001'
            and c.credor_id = 'c0000000-0000-0000-0000-000000000001' and c.valor = 1000));

-- Papel e campos (RN12, RN13).

select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('quem não é membro não cria no grupo',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null,
      pg_temp.proximo(0, '10:00'), 60, 10, 10000, null)$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('avulso sem prazo',
  $$select criar_jogo(null, pg_temp.ginasio(), null, pg_temp.proximo(0, '10:00'), 60, 10, 10000, null)$$,
  'prazo_invalido');
select pg_temp.espera_recusa('prazo negativo',
  $$select criar_jogo(null, pg_temp.ginasio(), null, pg_temp.proximo(0, '10:00'), 60, 10, 10000, -1)$$,
  'prazo_invalido');
select pg_temp.espera_recusa('início no passado',
  $$select criar_jogo(null, pg_temp.ginasio(), null, now() - interval '1 hour', 60, 10, 10000, 2)$$,
  'inicio_no_passado');
select pg_temp.espera_recusa('vagas zero',
  $$select criar_jogo(null, pg_temp.ginasio(), null, pg_temp.proximo(0, '10:00'), 60, 0, 10000, 2)$$,
  'vagas_invalidas');
select pg_temp.espera_recusa('duração zero',
  $$select criar_jogo(null, pg_temp.ginasio(), null, pg_temp.proximo(0, '10:00'), 0, 10, 10000, 2)$$,
  'duracao_invalida');
select pg_temp.espera_recusa('custo negativo',
  $$select criar_jogo(null, pg_temp.ginasio(), null, pg_temp.proximo(0, '10:00'), 60, 10, -1, 2)$$,
  'custo_invalido');
select pg_temp.espera_ok('qualquer pessoa cria avulso: Dani, domingo 10h no Ginásio, custo zero',
  $$insert into ids values ('avulso', criar_jogo(null, pg_temp.ginasio(), null,
      pg_temp.proximo(0, '10:00'), 60, 10, 0, 2))$$);

reset role;

select pg_temp.espera_verdade('o avulso guarda o próprio prazo e não tem grupo',
  exists (select 1 from jogo where id = pg_temp.jogo('avulso') and grupo_id is null
            and prazo_cancelamento_horas = 2 and preco_por_vaga = 0 and chave_pix_recebedor = 'dani@pix')
  and privado.prazo_sem_multa(pg_temp.jogo('avulso')) = pg_temp.proximo(0, '10:00') - interval '2 hours');

-- RN15: quadra, ocupação e funcionamento.

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('Arena exige quadra',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), null, pg_temp.proximo(4, '19:00'), 60, 10, 10000, null)$$,
  'quadra_obrigatoria');
select pg_temp.espera_recusa('Ginásio não aceita quadra',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), pg_temp.q1(), pg_temp.proximo(4, '10:00'), 60, 10, 10000, null)$$,
  'quadra_invalida');
select pg_temp.espera_recusa('local que não existe',
  $$select criar_jogo(pg_temp.jogo('sabado'), '10000000-0000-0000-0000-0000000000ff', null, pg_temp.proximo(4, '10:00'), 60, 10, 10000, null)$$,
  'local_invalido');
select pg_temp.espera_recusa('mesma quadra, horário sobreposto',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(1, '20:00'), 60, 10, 10000, null)$$,
  'quadra_ocupada');
select pg_temp.espera_recusa('mesma quadra, começando antes e terminando dentro',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(1, '18:00'), 90, 10, 10000, null)$$,
  'quadra_ocupada');
select pg_temp.espera_ok('mesma quadra, começando quando o outro termina',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(1, '21:00'), 60, 10, 10000, null)$$);
select pg_temp.espera_recusa('fora da faixa: segunda das 22h à 0h, com a Arena fechando às 23h',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(), pg_temp.proximo(1, '22:00'), 120, 10, 10000, null)$$,
  'fora_do_funcionamento');
select pg_temp.espera_recusa('fora da faixa: domingo, sem faixa na Arena',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(), pg_temp.proximo(0, '19:00'), 60, 10, 10000, null)$$,
  'fora_do_funcionamento');
select pg_temp.espera_ok('sábado das 23h à 1h na Arena, atravessando a meia-noite',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(6, '23:00'), 120, 10, 10000, null)$$);
select pg_temp.espera_ok('domingo da 1h às 2h na Arena, ainda na faixa de sábado',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(), pg_temp.proximo(0, '01:00'), 60, 10, 10000, null)$$);
select pg_temp.espera_recusa('domingo da 1h às 3h na Arena passa do fim da faixa de sábado',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(0, '01:00'), 120, 10, 10000, null)$$,
  'fora_do_funcionamento');
select pg_temp.espera_ok('sexta das 22h à 0h no Ginásio, na faixa que fecha à meia-noite',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(5, '22:00'), 120, 10, 10000, null)$$);
select pg_temp.espera_recusa('sexta das 23h à 1h no Ginásio passa da meia-noite',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(5, '23:00'), 120, 10, 10000, null)$$,
  'fora_do_funcionamento');
select pg_temp.espera_recusa('sábado das 21h às 23h no Ginásio, que fecha às 22h',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(6, '21:00'), 120, 10, 10000, null)$$,
  'fora_do_funcionamento');

-- Ginásio: capacidade 2.
select pg_temp.espera_ok('Ginásio, quarta 10h às 11h',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(3, '10:00'), 60, 10, 10000, null)$$);
select pg_temp.espera_ok('Ginásio, quarta 10h30 às 11h30: dois simultâneos',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(3, '10:30'), 60, 10, 10000, null)$$);
select pg_temp.espera_recusa('Ginásio, quarta 10h15 às 10h45: o terceiro',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(3, '10:15'), 30, 10, 10000, null)$$,
  'local_lotado');
select pg_temp.espera_recusa('Ginásio, quarta 9h às 10h45: livre no início, lotado quando o segundo começa',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(3, '09:00'), 105, 10, 10000, null)$$,
  'local_lotado');
select pg_temp.espera_ok('Ginásio, quarta 11h às 12h: o das 10h já terminou',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.ginasio(), null, pg_temp.proximo(3, '11:00'), 60, 10, 10000, null)$$);

reset role;

-- Jogo cancelado não ocupa; encerrado ocupa. O status é mudado como postgres, como atalho:
-- cancelar e encerrar pelas funções têm cenários próprios adiante.
update jogo set status = 'cancelado' where id = pg_temp.jogo('j3');
update jogo set status = 'encerrado' where id = pg_temp.jogo('j2');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('a quadra de um jogo cancelado está livre',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(2, '19:00'), 120, 10, 10000, null)$$);
select pg_temp.espera_recusa('a quadra de um jogo encerrado segue ocupada',
  $$select criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(), pg_temp.proximo(1, '19:30'), 60, 10, 10000, null)$$,
  'quadra_ocupada');

reset role;

select pg_temp.espera_verdade('as recusas não deixaram jogo, participação nem cobrança pela metade',
  (select count(*) from jogo) = 14
  and (select count(*) from participacao) = 14
  and (select count(*) from cobranca) = 2);

-- Duplicar (RN28).

-- A chave de Ana mudou depois de J1; Carlos joga J1.
update pessoa set chave_pix = 'ana-nova' where id = 'a0000000-0000-0000-0000-000000000001';
insert into participacao (jogo_id, pessoa_id, status, confirmado_em)
values (pg_temp.jogo('j1'), 'c0000000-0000-0000-0000-000000000001', 'confirmado', now());

select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Bruno, membro, duplica J1 para a semana seguinte',
  $$insert into ids values ('j1b', duplicar_jogo(pg_temp.jogo('j1'), pg_temp.proximo(1, '19:00') + interval '7 days'))$$);
select pg_temp.espera_recusa('duplicar no horário da origem esbarra na própria origem',
  $$select duplicar_jogo(pg_temp.jogo('j1'), pg_temp.proximo(1, '19:00'))$$, 'quadra_ocupada');
select pg_temp.espera_recusa('duplicar para o passado',
  $$select duplicar_jogo(pg_temp.jogo('j1'), now() - interval '1 day')$$, 'inicio_no_passado');
select pg_temp.espera_recusa('a chave digitada da origem não é copiada: Bruno segue sem chave no perfil',
  $$select duplicar_jogo(pg_temp.jogo('j4'), pg_temp.proximo(2, '19:00') + interval '7 days')$$, 'recebedor_sem_chave');
select pg_temp.espera_ok('com a chave digitada de novo, duplica',
  $$insert into ids values ('j4b', duplicar_jogo(pg_temp.jogo('j4'), pg_temp.proximo(2, '19:00') + interval '7 days', 'bruno-de-novo'))$$);
select pg_temp.espera_recusa('duplicar jogo que não existe',
  $$select duplicar_jogo('40000000-0000-0000-0000-0000000000ff', pg_temp.proximo(2, '19:00'))$$,
  'sem_permissao', '42501');

reset role;

select pg_temp.espera_verdade('J1b copia grupo, local, quadra, duração, vagas, custo, recebedor e prazo',
  exists (select 1 from jogo n join jogo o on o.id = pg_temp.jogo('j1')
          where n.id = pg_temp.jogo('j1b')
            and n.grupo_id = o.grupo_id and n.local_id = o.local_id and n.quadra_id = o.quadra_id
            and n.duracao_minutos = o.duracao_minutos and n.vagas_total = o.vagas_total
            and n.custo_total = o.custo_total and n.preco_por_vaga = o.preco_por_vaga
            and n.recebedor_id = o.recebedor_id
            and n.prazo_cancelamento_horas is not distinct from o.prazo_cancelamento_horas
            and n.inicio = o.inicio + interval '7 days'
            and n.status = 'aberto' and n.cancelamento_livre_ate is null));
select pg_temp.espera_verdade('quem duplica é o criador do jogo novo',
  (select criador_id from jogo where id = pg_temp.jogo('j1b')) = 'b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_verdade('a chave vem do perfil atual de Ana, não da origem',
  (select chave_pix_recebedor from jogo where id = pg_temp.jogo('j1b')) = 'ana-nova'
  and (select chave_pix_recebedor from jogo where id = pg_temp.jogo('j1')) = 'ana@pix');
select pg_temp.espera_verdade('nenhuma participação copiada: só Bruno, confirmado, devendo a Ana',
  (select array_agg(p.pessoa_id::text || ':' || p.status || ':' || c.valor || ':' || c.credor_id)
   from participacao p left join cobranca c on c.participacao_id = p.id
   where p.jogo_id = pg_temp.jogo('j1b'))
  = array['b0000000-0000-0000-0000-000000000001:confirmado:1429:a0000000-0000-0000-0000-000000000001']);
select pg_temp.espera_verdade('J4b guarda a chave digitada agora',
  (select chave_pix_recebedor from jogo where id = pg_temp.jogo('j4b')) = 'bruno-de-novo');

select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('quem não é membro não duplica jogo do grupo',
  $$select duplicar_jogo(pg_temp.jogo('j1'), pg_temp.proximo(1, '19:00') + interval '14 days')$$,
  'sem_permissao', '42501');
select pg_temp.espera_ok('Dani duplica o próprio avulso',
  $$insert into ids values ('avulso_b', duplicar_jogo(pg_temp.jogo('avulso'), pg_temp.proximo(0, '10:00') + interval '7 days'))$$);

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('quem não criou o avulso não o duplica',
  $$select duplicar_jogo(pg_temp.jogo('avulso'), pg_temp.proximo(0, '10:00') + interval '14 days')$$,
  'sem_permissao', '42501');

reset role;

select pg_temp.espera_verdade('o avulso duplicado segue sem grupo e com o prazo da origem',
  exists (select 1 from jogo where id = pg_temp.jogo('avulso_b') and grupo_id is null
            and prazo_cancelamento_horas = 2 and criador_id = 'd0000000-0000-0000-0000-000000000001'));

-- Auxiliares.

update jogo set cancelamento_livre_ate = inicio where id = pg_temp.jogo('j1');

select pg_temp.espera_verdade('remarcado, o prazo sem multa é o cancelamento_livre_ate, mais tardio que o normal',
  privado.prazo_sem_multa(pg_temp.jogo('j1')) = (select inicio from jogo where id = pg_temp.jogo('j1')));

-- RN25: a cobrança cancelada é reaberta, a mesma, com o valor por vaga atual.
create temp table antes as
select c.id, c.participacao_id from cobranca c join participacao p on p.id = c.participacao_id
where p.jogo_id = pg_temp.jogo('j1b');

update cobranca set status = 'cancelada' where id = (select id from antes);
update jogo set custo_total = 12000, preco_por_vaga = 1715 where id = pg_temp.jogo('j1b');

create temp table reaberta as select privado.nascer_cobranca((select participacao_id from antes)) as id;

select pg_temp.espera_verdade('nascer_cobranca reabre a mesma cobrança, pendente de parte, com o valor atual',
  (select id from reaberta) = (select id from antes)
  and (select count(*) from cobranca where participacao_id = (select participacao_id from antes)) = 1
  and exists (select 1 from cobranca where id = (select id from antes)
                and status = 'pendente' and origem = 'parte' and valor = 1715));

select pg_temp.espera_erro('nascer_cobranca do recebedor é barrada pelo check',
  $$select privado.nascer_cobranca((select id from participacao where jogo_id = pg_temp.jogo('j1')
      and pessoa_id = 'a0000000-0000-0000-0000-000000000001'))$$,
  '23514', 'cobranca_devedor_nao_e_credor');

-- Editar (RF10, RN20). Confirmações e cancelamentos pelas funções de rpc_presenca.

insert into pessoa (id, nome) select ('90000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'Membro ' || n
from generate_series(1, 6) n;
insert into membro_grupo (grupo_id, pessoa_id, papel)
select pg_temp.jogo('sabado'), ('90000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'membro'
from generate_series(1, 6) n;

create function pg_temp.m(p_n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-0000-0000-' || lpad(p_n::text, 12, '0'))::uuid
$$;
-- Age como a pessoa num comando só e volta ao postgres.
create function pg_temp.como_faz(p_pessoa uuid, p_comando text) returns void language plpgsql as $$
begin
  perform pg_temp.como(p_pessoa);
  execute p_comando;
  reset role;
end;
$$;
create function pg_temp.cobranca(p_jogo text, p_pessoa uuid) returns text language sql stable as $$
  select c.status || ':' || c.origem || ':' || c.valor
  from cobranca c join participacao p on p.id = c.participacao_id
  where p.jogo_id = pg_temp.jogo(p_jogo) and p.pessoa_id = p_pessoa
$$;
grant execute on function pg_temp.m(integer) to authenticated;

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select promover_admin(pg_temp.jogo('sabado'), 'c0000000-0000-0000-0000-000000000001');
insert into ids values
  ('e1', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(4, '19:00'), 120, 10, 10000, null)),
  ('e2', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(), pg_temp.proximo(4, '19:00'), 120, 10, 10000, null)),
  ('e3', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(), pg_temp.proximo(5, '19:00'), 120, 10, 10000, null));
reset role;

-- e1: Ana recebe; Membros 1 a 3 confirmados; Membro 4 com multa de cancelamento tardio.
select pg_temp.como_faz(pg_temp.m(n), $$select confirmar_presenca(pg_temp.jogo('e1'))$$) from generate_series(1, 4) n;
update jogo set inicio = now() + interval '1 hour' where id = pg_temp.jogo('e1');
select pg_temp.como_faz(pg_temp.m(4), $$select cancelar_presenca(pg_temp.jogo('e1'))$$);
update jogo set inicio = pg_temp.proximo(4, '19:00') where id = pg_temp.jogo('e1');

select pg_temp.espera_verdade('e1 montado: três partes e uma multa de R$ 10,00',
  pg_temp.cobranca('e1', pg_temp.m(1)) = 'pendente:parte:1000'
  and pg_temp.cobranca('e1', pg_temp.m(4)) = 'pendente:cancelamento_tardio:1000');

-- Papel (RN13).
select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('membro comum não edita',
  $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => 14000)$$, 'sem_permissao', '42501');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem é de fora não edita',
  $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => 14000)$$, 'sem_permissao', '42501');
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('admin que não criou não troca o recebedor',
  $$select editar_jogo(pg_temp.jogo('e1'), p_recebedor => 'c0000000-0000-0000-0000-000000000001')$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('custo negativo',
  $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => -1)$$, 'custo_invalido');

-- Custo (RN01).
select pg_temp.espera_ok('Carlos, admin, muda o custo de R$ 100,00 para R$ 140,00',
  $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => 14000)$$);
select pg_temp.espera_ok('e repete o mesmo pedido', $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => 14000)$$);
reset role;

select pg_temp.espera_verdade('preço e cobranças ativas passam a 1400, a multa também',
  (select preco_por_vaga || ':' || custo_total from jogo where id = pg_temp.jogo('e1')) = '1400:14000'
  and pg_temp.cobranca('e1', pg_temp.m(1)) = 'pendente:parte:1400'
  and pg_temp.cobranca('e1', pg_temp.m(3)) = 'pendente:parte:1400'
  and pg_temp.cobranca('e1', pg_temp.m(4)) = 'pendente:cancelamento_tardio:1400');
select pg_temp.espera_verdade('a mudança de custo não é remarcação',
  (select cancelamento_livre_ate from jogo where id = pg_temp.jogo('e1')) is null);
select pg_temp.espera_verdade('valor_recalculado aos três confirmados e à multada, uma vez só, levando à cobrança',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'valor_recalculado')
    = array[pg_temp.m(1), pg_temp.m(2), pg_temp.m(3), pg_temp.m(4)]
  and not exists (select 1 from notificacao where tipo = 'valor_recalculado' and (cobranca_id is null or jogo_id is not null)));
select pg_temp.espera_verdade('o texto da parte e o da multa',
  exists (select 1 from notificacao where tipo = 'valor_recalculado' and pessoa_id = pg_temp.m(1)
            and titulo = 'Areia de Sábado mudou o custo'
            and corpo = 'Total R$ 140,00. Sua parte passou para R$ 14,00.')
  and exists (select 1 from notificacao where tipo = 'valor_recalculado' and pessoa_id = pg_temp.m(4)
            and titulo = 'Areia de Sábado mudou o custo'
            and corpo = 'Total R$ 140,00. Sua multa passou para R$ 14,00.'));

-- Vagas (RN06).
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('vagas abaixo dos quatro confirmados',
  $$select editar_jogo(pg_temp.jogo('e1'), p_vagas_total => 3)$$, 'vagas_abaixo_dos_confirmados');
select pg_temp.espera_recusa('vagas zero', $$select editar_jogo(pg_temp.jogo('e1'), p_vagas_total => 0)$$, 'vagas_invalidas');
select pg_temp.espera_ok('vagas iguais aos confirmados', $$select editar_jogo(pg_temp.jogo('e1'), p_vagas_total => 4)$$);
reset role;
select pg_temp.espera_verdade('R$ 140,00 em 4 vagas: R$ 35,00, com o aviso de vagas',
  pg_temp.cobranca('e1', pg_temp.m(2)) = 'pendente:parte:3500'
  and exists (select 1 from notificacao where tipo = 'valor_recalculado' and pessoa_id = pg_temp.m(2)
            and titulo = 'Areia de Sábado mudou as vagas'
            and corpo = 'Agora são 4 vagas. Sua parte passou para R$ 35,00.'));

-- Vagas que aumentam com fila (RN08).
select pg_temp.como_faz(pg_temp.m(n), $$select confirmar_presenca(pg_temp.jogo('e1'))$$) from generate_series(5, 6) n;
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Ana aumenta para 5 vagas e muda o custo para R$ 150,00',
  $$select editar_jogo(pg_temp.jogo('e1'), p_vagas_total => 5, p_custo_total => 15000)$$);
reset role;
select pg_temp.espera_verdade('a fila inteira recebe vaga_liberada, sem a vaga ser dada a ninguém',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'vaga_liberada' and jogo_id = pg_temp.jogo('e1'))
    = array[pg_temp.m(5), pg_temp.m(6)]
  and (select count(*) from participacao where jogo_id = pg_temp.jogo('e1') and status = 'lista_espera') = 2);
select pg_temp.espera_verdade('custo e vagas juntos: o terceiro texto',
  exists (select 1 from notificacao where tipo = 'valor_recalculado' and pessoa_id = pg_temp.m(3)
            and titulo = 'Areia de Sábado mudou o custo e as vagas'
            and corpo = 'Total R$ 150,00 em 5 vagas. Sua parte passou para R$ 30,00.')
  and pg_temp.cobranca('e1', pg_temp.m(4)) = 'pendente:cancelamento_tardio:3000');

-- Remarcação (RN20).
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('remarcar para o horário de outro jogo na mesma quadra',
  $$select editar_jogo(pg_temp.jogo('e1'), p_inicio => pg_temp.proximo(1, '19:00'))$$, 'quadra_ocupada');
select pg_temp.espera_recusa('remarcar para fora da faixa',
  $$select editar_jogo(pg_temp.jogo('e1'), p_inicio => pg_temp.proximo(4, '22:00'))$$, 'fora_do_funcionamento');
select pg_temp.espera_recusa('remarcar para o passado',
  $$select editar_jogo(pg_temp.jogo('e1'), p_inicio => now() - interval '1 hour')$$, 'inicio_no_passado');
select pg_temp.espera_ok('remarcar uma hora depois, sobre o próprio horário antigo',
  $$select editar_jogo(pg_temp.jogo('e1'), p_inicio => pg_temp.proximo(4, '20:00'))$$);
select pg_temp.espera_ok('repetir a remarcação', $$select editar_jogo(pg_temp.jogo('e1'), p_inicio => pg_temp.proximo(4, '20:00'))$$);
reset role;

select pg_temp.espera_verdade('a remarcação grava o novo início em cancelamento_livre_ate e cancela a multa',
  (select cancelamento_livre_ate from jogo where id = pg_temp.jogo('e1')) = pg_temp.proximo(4, '20:00')
  and privado.prazo_sem_multa(pg_temp.jogo('e1')) = pg_temp.proximo(4, '20:00')
  and pg_temp.cobranca('e1', pg_temp.m(4)) = 'cancelada:cancelamento_tardio:3000');
select pg_temp.espera_verdade('jogo_editado a cada confirmado e à multada, uma vez só, e não a quem editou nem à fila',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'jogo_editado' and jogo_id = pg_temp.jogo('e1'))
    = array[pg_temp.m(1), pg_temp.m(2), pg_temp.m(3), pg_temp.m(4), 'a0000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_verdade('os dois textos da remarcação',
  exists (select 1 from notificacao where tipo = 'jogo_editado' and pessoa_id = pg_temp.m(1)
            and titulo = 'Jogo remarcado' and cobranca_id is null
            and corpo = format('Areia de Sábado de %s passou para %s · 20:00, em Arena Beira-Mar · Quadra 1. Cancelar fica sem multa até o início.',
                               privado.data_curta(pg_temp.proximo(4, '19:00')), privado.data_curta(pg_temp.proximo(4, '20:00'))))
  and exists (select 1 from notificacao where tipo = 'jogo_editado' and pessoa_id = pg_temp.m(4)
            and corpo = format('Areia de Sábado de %s passou para %s · 20:00, em Arena Beira-Mar · Quadra 1. Sua multa de R$ 30,00 foi cancelada.',
                               privado.data_curta(pg_temp.proximo(4, '19:00')), privado.data_curta(pg_temp.proximo(4, '20:00')))));

-- Depois da remarcação, cancelar não gera multa até o início: o tempo passa até 1 h antes.
update jogo set inicio = now() + interval '1 hour', cancelamento_livre_ate = now() + interval '1 hour'
where id = pg_temp.jogo('e1');
select pg_temp.como_faz(pg_temp.m(1), $$select cancelar_presenca(pg_temp.jogo('e1'))$$);
select pg_temp.espera_verdade('a 1 h do início, com o prazo de 3 h do grupo vencido, Membro 1 cancela sem multa',
  pg_temp.cobranca('e1', pg_temp.m(1)) = 'cancelada:parte:3000'
  and (select status from participacao where jogo_id = pg_temp.jogo('e1') and pessoa_id = pg_temp.m(1)) = 'cancelou_no_prazo');

-- Janelas: vagas e remarcação até o início; custo até o encerramento.
update jogo set inicio = now() - interval '1 minute' where id = pg_temp.jogo('e1');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('vagas depois do início', $$select editar_jogo(pg_temp.jogo('e1'), p_vagas_total => 8)$$, 'jogo_ja_comecou');
select pg_temp.espera_recusa('remarcar depois do início',
  $$select editar_jogo(pg_temp.jogo('e1'), p_quadra => pg_temp.q2())$$, 'jogo_ja_comecou');
select pg_temp.espera_ok('custo depois do início', $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => 16000)$$);
reset role;
select pg_temp.espera_verdade('o custo mudou depois do início',
  (select preco_por_vaga from jogo where id = pg_temp.jogo('e1')) = 3200 and pg_temp.cobranca('e1', pg_temp.m(2)) = 'pendente:parte:3200');
update jogo set status = 'encerrado' where id = pg_temp.jogo('e1');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('custo depois do encerramento', $$select editar_jogo(pg_temp.jogo('e1'), p_custo_total => 17000)$$, 'jogo_fechado');
reset role;

-- Troca de recebedor (RN20, RN24).
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.jogo('e2'))$$)
from unnest(array['b0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(1), pg_temp.m(2)]) p;
select pg_temp.como_faz(pg_temp.m(2), $$select cancelar_presenca(pg_temp.jogo('e2'))$$);
create temp table avisos_antes as select count(*) as n from notificacao;

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('novo recebedor sem chave', $$select editar_jogo(pg_temp.jogo('e2'), p_recebedor => 'b0000000-0000-0000-0000-000000000001')$$,
  'recebedor_sem_chave');
select pg_temp.espera_recusa('novo recebedor desconhecido', $$select editar_jogo(pg_temp.jogo('e2'), p_recebedor => 'd0000000-0000-0000-0000-000000000001')$$,
  'recebedor_desconhecido');
select pg_temp.espera_ok('Ana passa o recebimento a Bruno, com a chave digitada',
  $$select editar_jogo(pg_temp.jogo('e2'), p_recebedor => 'b0000000-0000-0000-0000-000000000001', p_chave_pix_recebedor => 'bruno-pix')$$);
reset role;

select pg_temp.espera_verdade('o jogo guarda o novo recebedor e a chave digitada',
  (select recebedor_id::text || ':' || chave_pix_recebedor from jogo where id = pg_temp.jogo('e2'))
    = 'b0000000-0000-0000-0000-000000000001:bruno-pix'
  and (select chave_pix from pessoa where id = 'b0000000-0000-0000-0000-000000000001') is null);
select pg_temp.espera_verdade('a cobrança de Bruno, agora recebedor, vira cancelada',
  pg_temp.cobranca('e2', 'b0000000-0000-0000-0000-000000000001') = 'cancelada:parte:1000');
select pg_temp.espera_verdade('Ana, antiga recebedora e confirmada, passa a dever a parte',
  pg_temp.cobranca('e2', 'a0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000');
select pg_temp.espera_verdade('todas as cobranças, inclusive a cancelada de Membro 2, apontam a Bruno; só a dele fica com Ana',
  (select array_agg(p.pessoa_id::text || '>' || c.credor_id order by p.pessoa_id)
   from cobranca c join participacao p on p.id = c.participacao_id where p.jogo_id = pg_temp.jogo('e2'))
  = array['90000000-0000-0000-0000-000000000001>b0000000-0000-0000-0000-000000000001',
          '90000000-0000-0000-0000-000000000002>b0000000-0000-0000-0000-000000000001',
          'a0000000-0000-0000-0000-000000000001>b0000000-0000-0000-0000-000000000001',
          'b0000000-0000-0000-0000-000000000001>a0000000-0000-0000-0000-000000000001']
  and pg_temp.cobranca('e2', pg_temp.m(2)) = 'cancelada:parte:1000');
select pg_temp.espera_verdade('a troca não avisa ninguém', (select count(*) from notificacao) = (select n from avisos_antes));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Ana volta a receber, com a chave do perfil',
  $$select editar_jogo(pg_temp.jogo('e2'), p_recebedor => 'a0000000-0000-0000-0000-000000000001')$$);
reset role;
select pg_temp.espera_verdade('de volta: Bruno deve de novo, na mesma cobrança, e a de Ana é cancelada',
  pg_temp.cobranca('e2', 'b0000000-0000-0000-0000-000000000001') = 'pendente:parte:1000'
  and pg_temp.cobranca('e2', 'a0000000-0000-0000-0000-000000000001') = 'cancelada:parte:1000'
  and (select count(*) from cobranca c join participacao p on p.id = c.participacao_id where p.jogo_id = pg_temp.jogo('e2')) = 4
  and (select chave_pix_recebedor from jogo where id = pg_temp.jogo('e2')) = 'ana-nova'
  and not exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
                  where p.jogo_id = pg_temp.jogo('e2') and c.devedor_id <> 'a0000000-0000-0000-0000-000000000001'
                    and c.credor_id <> 'a0000000-0000-0000-0000-000000000001'));

-- e3: só a criadora recebedora confirmada. Mudar o custo não avisa; trocar de local leva a quadra do local novo.
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('custo de e3 sem outros confirmados', $$select editar_jogo(pg_temp.jogo('e3'), p_custo_total => 12000)$$);
select pg_temp.espera_recusa('Ginásio com a quadra da Arena',
  $$select editar_jogo(pg_temp.jogo('e3'), p_inicio => pg_temp.proximo(5, '10:00'), p_local => pg_temp.ginasio(), p_quadra => pg_temp.q1())$$,
  'quadra_invalida');
select pg_temp.espera_ok('e3 vai para o Ginásio, sem quadra',
  $$select editar_jogo(pg_temp.jogo('e3'), p_inicio => pg_temp.proximo(5, '10:00'), p_local => pg_temp.ginasio())$$);
reset role;
select pg_temp.espera_verdade('sem confirmados além da criadora recebedora, nenhum aviso',
  not exists (select 1 from notificacao where jogo_id = pg_temp.jogo('e3'))
  and not exists (select 1 from notificacao n join cobranca c on c.id = n.cobranca_id
                  join participacao p on p.id = c.participacao_id where p.jogo_id = pg_temp.jogo('e3')));
select pg_temp.espera_verdade('e3 está no Ginásio, sem quadra, com o preço novo',
  exists (select 1 from jogo where id = pg_temp.jogo('e3') and local_id = pg_temp.ginasio() and quadra_id is null
            and preco_por_vaga = 1200 and cancelamento_livre_ate = pg_temp.proximo(5, '10:00')));

-- Cancelar jogo (RF11, RN23).

select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values
  ('k1', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(),
                    pg_temp.proximo(4, '19:00') + interval '14 days', 120, 5, 10000, null)),
  ('k2', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(),
                    pg_temp.proximo(5, '19:00') + interval '14 days', 120, 5, 10000, null));
reset role;

-- k1: Ana recebe; Membros 1 a 4 completam as cinco vagas, e Membro 5 fica na fila. Perto do
-- início, Membro 4 e depois Membro 3 cancelam tarde, e Membro 6 confirma, isentando a multa
-- de Membro 4. De volta ao prazo, Membro 2 cancela sem multa.
select pg_temp.como_faz(pg_temp.m(n), $$select confirmar_presenca(pg_temp.jogo('k1'))$$) from generate_series(1, 5) n;
update jogo set inicio = now() + interval '1 hour' where id = pg_temp.jogo('k1');
select pg_temp.como_faz(pg_temp.m(4), $$select cancelar_presenca(pg_temp.jogo('k1'))$$);
update participacao set cancelado_em = now() - interval '10 minutes'
where jogo_id = pg_temp.jogo('k1') and pessoa_id = pg_temp.m(4);
select pg_temp.como_faz(pg_temp.m(3), $$select cancelar_presenca(pg_temp.jogo('k1'))$$);
select pg_temp.como_faz(pg_temp.m(6), $$select confirmar_presenca(pg_temp.jogo('k1'))$$);
update jogo set inicio = pg_temp.proximo(4, '19:00') + interval '14 days' where id = pg_temp.jogo('k1');
select pg_temp.como_faz(pg_temp.m(2), $$select cancelar_presenca(pg_temp.jogo('k1'))$$);

select pg_temp.espera_verdade('k1 montado: partes, multa pendente, multa isenta, saída no prazo e fila',
  pg_temp.cobranca('k1', pg_temp.m(1)) = 'pendente:parte:2000'
  and pg_temp.cobranca('k1', pg_temp.m(6)) = 'pendente:parte:2000'
  and pg_temp.cobranca('k1', pg_temp.m(3)) = 'pendente:cancelamento_tardio:2000'
  and pg_temp.cobranca('k1', pg_temp.m(4)) = 'isenta:cancelamento_tardio:2000'
  and pg_temp.cobranca('k1', pg_temp.m(2)) = 'cancelada:parte:2000'
  and (select status from participacao where jogo_id = pg_temp.jogo('k1') and pessoa_id = pg_temp.m(5)) = 'lista_espera');

select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('membro comum não cancela o jogo',
  $$select cancelar_jogo(pg_temp.jogo('k1'))$$, 'sem_permissao', '42501');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem é de fora não cancela',
  $$select cancelar_jogo(pg_temp.jogo('k1'))$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('cancelar jogo que não existe',
  $$select cancelar_jogo('40000000-0000-0000-0000-0000000000ff')$$, 'sem_permissao', '42501');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Ana, a criadora, cancela k1', $$select cancelar_jogo(pg_temp.jogo('k1'))$$);
select pg_temp.espera_ok('e repete o pedido', $$select cancelar_jogo(pg_temp.jogo('k1'))$$);
reset role;

select pg_temp.espera_verdade('k1 cancelado: toda cobrança ativa, parte ou multa, vira cancelada, sem autor',
  (select status from jogo where id = pg_temp.jogo('k1')) = 'cancelado'
  and pg_temp.cobranca('k1', pg_temp.m(1)) = 'cancelada:parte:2000'
  and pg_temp.cobranca('k1', pg_temp.m(6)) = 'cancelada:parte:2000'
  and pg_temp.cobranca('k1', pg_temp.m(3)) = 'cancelada:cancelamento_tardio:2000'
  and not exists (select 1 from cobranca c join participacao p on p.id = c.participacao_id
                  where p.jogo_id = pg_temp.jogo('k1')
                    and (c.status in ('pendente', 'comprovante_enviado')
                         or c.confirmado_por is not null or c.confirmado_em is not null)));
select pg_temp.espera_verdade('a multa isenta segue isenta, e as participações ficam como estavam',
  pg_temp.cobranca('k1', pg_temp.m(4)) = 'isenta:cancelamento_tardio:2000'
  and (select array_agg(status::text order by pessoa_id) from participacao where jogo_id = pg_temp.jogo('k1'))
      = array['confirmado', 'cancelou_no_prazo', 'cancelou_fora_do_prazo', 'cancelou_fora_do_prazo',
              'lista_espera', 'confirmado', 'confirmado']);
select pg_temp.espera_verdade('jogo_cancelado uma vez aos confirmados, à fila e à multa ativa; não a Ana, que cancelou, à isenta nem a quem saiu no prazo',
  (select array_agg(pessoa_id order by pessoa_id) from notificacao where tipo = 'jogo_cancelado')
  = array[pg_temp.m(1), pg_temp.m(3), pg_temp.m(5), pg_temp.m(6)]);
select pg_temp.espera_verdade('o texto do cancelamento, levando ao jogo',
  not exists (select 1 from notificacao where tipo = 'jogo_cancelado'
              and (titulo <> 'Jogo cancelado' or jogo_id <> pg_temp.jogo('k1') or cobranca_id is not null
                   or corpo <> format('Areia de Sábado, %s · 19:00, não vai acontecer. Nada a pagar por ele.',
                                      privado.data_curta(pg_temp.proximo(4, '19:00') + interval '14 days')))));

select pg_temp.como(pg_temp.m(2));
select pg_temp.espera_recusa('confirmar em jogo cancelado', $$select confirmar_presenca(pg_temp.jogo('k1'))$$, 'jogo_fechado');
select pg_temp.como(pg_temp.m(5));
select pg_temp.espera_recusa('sair da fila de jogo cancelado', $$select cancelar_presenca(pg_temp.jogo('k1'))$$, 'jogo_fechado');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('editar jogo cancelado', $$select editar_jogo(pg_temp.jogo('k1'), p_custo_total => 12000)$$, 'jogo_fechado');
select pg_temp.espera_recusa('encerrar jogo cancelado', $$select encerrar_jogo(pg_temp.jogo('k1'))$$, 'jogo_fechado');
reset role;

-- k2: depois do início, ninguém cancela; antes dele, um admin que não criou cancela.
update jogo set inicio = now() - interval '1 minute' where id = pg_temp.jogo('k2');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('cancelar depois do início', $$select cancelar_jogo(pg_temp.jogo('k2'))$$, 'jogo_ja_comecou');
reset role;
update jogo set inicio = pg_temp.proximo(5, '19:00') + interval '14 days' where id = pg_temp.jogo('k2');
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Carlos, admin, cancela k2', $$select cancelar_jogo(pg_temp.jogo('k2'))$$);
reset role;
select pg_temp.espera_verdade('k2 cancelado, e Ana, criadora confirmada, é avisada por ser outro quem cancelou',
  (select status from jogo where id = pg_temp.jogo('k2')) = 'cancelado'
  and (select array_agg(pessoa_id) from notificacao where tipo = 'jogo_cancelado' and jogo_id = pg_temp.jogo('k2'))
      = array['a0000000-0000-0000-0000-000000000001'::uuid]);

-- Encerrar jogo (RF33, RN17) e pagamento liberado (RN07).

select pg_temp.como('b0000000-0000-0000-0000-000000000001');
insert into ids values ('k3', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
  pg_temp.proximo(4, '19:00') + interval '14 days', 120, 5, 10000, null, 'a0000000-0000-0000-0000-000000000001'));
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
insert into ids values ('k4', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q2(),
  pg_temp.proximo(5, '19:00') + interval '14 days', 120, 10, 10000, null));
reset role;

-- k3: Bruno cria com Ana recebendo, e deve a parte dele. Ana e Membros 1 a 3 completam as
-- cinco vagas, e Membro 4 fica na fila. Perto do início, Membro 2 e depois Membro 3
-- cancelam tarde, e Membro 5 confirma, isentando a multa de Membro 2.
select pg_temp.como_faz(p, $$select confirmar_presenca(pg_temp.jogo('k3'))$$)
from unnest(array['a0000000-0000-0000-0000-000000000001'::uuid, pg_temp.m(1), pg_temp.m(2), pg_temp.m(3), pg_temp.m(4)]) p;
update jogo set inicio = now() + interval '1 hour' where id = pg_temp.jogo('k3');
select pg_temp.como_faz(pg_temp.m(2), $$select cancelar_presenca(pg_temp.jogo('k3'))$$);
update participacao set cancelado_em = now() - interval '10 minutes'
where jogo_id = pg_temp.jogo('k3') and pessoa_id = pg_temp.m(2);
select pg_temp.como_faz(pg_temp.m(3), $$select cancelar_presenca(pg_temp.jogo('k3'))$$);
select pg_temp.como_faz(pg_temp.m(5), $$select confirmar_presenca(pg_temp.jogo('k3'))$$);

select pg_temp.espera_verdade('k3 montado: Ana sem cobrança, três partes, uma multa pendente, uma isenta e a fila',
  pg_temp.cobranca('k3', 'a0000000-0000-0000-0000-000000000001') is null
  and pg_temp.cobranca('k3', 'b0000000-0000-0000-0000-000000000001') = 'pendente:parte:2000'
  and pg_temp.cobranca('k3', pg_temp.m(1)) = 'pendente:parte:2000'
  and pg_temp.cobranca('k3', pg_temp.m(5)) = 'pendente:parte:2000'
  and pg_temp.cobranca('k3', pg_temp.m(3)) = 'pendente:cancelamento_tardio:2000'
  and pg_temp.cobranca('k3', pg_temp.m(2)) = 'isenta:cancelamento_tardio:2000'
  and (select status || ':' || posicao_espera from participacao
       where jogo_id = pg_temp.jogo('k3') and pessoa_id = pg_temp.m(4)) = 'lista_espera:1');

-- Um minuto antes do fim reservado.
update jogo set inicio = now() - interval '119 minutes' where id = pg_temp.jogo('k3');
select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('encerrar antes do fim reservado', $$select encerrar_jogo(pg_temp.jogo('k3'))$$, 'jogo_nao_terminou');
select pg_temp.como(pg_temp.m(1));
select pg_temp.espera_recusa('membro comum não encerra', $$select encerrar_jogo(pg_temp.jogo('k3'))$$, 'sem_permissao', '42501');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('quem é de fora não encerra', $$select encerrar_jogo(pg_temp.jogo('k3'))$$, 'sem_permissao', '42501');
select pg_temp.espera_recusa('encerrar jogo que não existe',
  $$select encerrar_jogo('40000000-0000-0000-0000-0000000000ff')$$, 'sem_permissao', '42501');
reset role;

-- No fim reservado, em ponto.
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.jogo('k3');
select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Bruno, o criador, encerra k3 no fim reservado', $$select encerrar_jogo(pg_temp.jogo('k3'))$$);
select pg_temp.espera_ok('e repete o pedido', $$select encerrar_jogo(pg_temp.jogo('k3'))$$);
reset role;

select pg_temp.espera_verdade('k3 encerrado, com as cobranças como estavam e a fila mantida',
  (select status from jogo where id = pg_temp.jogo('k3')) = 'encerrado'
  and pg_temp.cobranca('k3', 'b0000000-0000-0000-0000-000000000001') = 'pendente:parte:2000'
  and pg_temp.cobranca('k3', pg_temp.m(3)) = 'pendente:cancelamento_tardio:2000'
  and pg_temp.cobranca('k3', pg_temp.m(2)) = 'isenta:cancelamento_tardio:2000'
  and (select status || ':' || posicao_espera from participacao
       where jogo_id = pg_temp.jogo('k3') and pessoa_id = pg_temp.m(4)) = 'lista_espera:1');
select pg_temp.espera_verdade('pagamento_liberado uma vez às partes e à multa pendentes; não a Ana, recebedora, à isenta, à fila nem a Bruno, que encerrou',
  (select array_agg(n.pessoa_id order by n.pessoa_id)
   from notificacao n join cobranca c on c.id = n.cobranca_id join participacao p on p.id = c.participacao_id
   where n.tipo = 'pagamento_liberado' and p.jogo_id = pg_temp.jogo('k3'))
  = array[pg_temp.m(1), pg_temp.m(3), pg_temp.m(5)]
  and (select count(*) from notificacao where tipo = 'pagamento_liberado') = 3);
select pg_temp.espera_verdade('o aviso leva à cobrança do próprio devedor, com o valor, o credor e o vencimento 24 h depois do encerramento previsto',
  not exists (select 1 from notificacao n join cobranca c on c.id = n.cobranca_id
              where n.tipo = 'pagamento_liberado'
                and (c.devedor_id <> n.pessoa_id or n.jogo_id is not null or n.titulo <> 'Pagamento liberado'
                     or n.corpo <> format('R$ 20,00 para Ana Souza. Vence %s · %s.',
                                          privado.data_curta(now() + interval '25 hours'),
                                          privado.hora(now() + interval '25 hours')))));

-- Depois do encerramento, só a falta (RN17); o custo, até o encerramento (RN20).
select pg_temp.como('b0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('editar o custo depois do encerramento', $$select editar_jogo(pg_temp.jogo('k3'), p_custo_total => 12000)$$, 'jogo_fechado');
select pg_temp.espera_recusa('cancelar jogo encerrado', $$select cancelar_jogo(pg_temp.jogo('k3'))$$, 'jogo_fechado');
select pg_temp.espera_recusa('cancelar a presença em jogo encerrado', $$select cancelar_presenca(pg_temp.jogo('k3'))$$, 'jogo_fechado');
select pg_temp.como(pg_temp.m(4));
select pg_temp.espera_recusa('confirmar da fila em jogo encerrado', $$select confirmar_presenca(pg_temp.jogo('k3'))$$, 'jogo_fechado');
reset role;

-- k4: um admin que não criou encerra; a criadora recebedora não recebe aviso.
select pg_temp.como_faz(pg_temp.m(1), $$select confirmar_presenca(pg_temp.jogo('k4'))$$);
update jogo set inicio = now() - interval '2 hours' where id = pg_temp.jogo('k4');
select pg_temp.como(pg_temp.m(2));
select pg_temp.espera_recusa('membro comum não encerra k4', $$select encerrar_jogo(pg_temp.jogo('k4'))$$, 'sem_permissao', '42501');
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Carlos, admin, encerra k4', $$select encerrar_jogo(pg_temp.jogo('k4'))$$);
reset role;
select pg_temp.espera_verdade('k4 encerrado, com pagamento_liberado só a Membro 1',
  (select status from jogo where id = pg_temp.jogo('k4')) = 'encerrado'
  and (select array_agg(n.pessoa_id)
       from notificacao n join cobranca c on c.id = n.cobranca_id join participacao p on p.id = c.participacao_id
       where n.tipo = 'pagamento_liberado' and p.jogo_id = pg_temp.jogo('k4')) = array[pg_temp.m(1)]);

-- Avulso: só o criador encerra, nem quem joga nem admin de outro grupo.
insert into participacao (jogo_id, pessoa_id, status, confirmado_em)
values (pg_temp.jogo('avulso_b'), 'a0000000-0000-0000-0000-000000000001', 'confirmado', now());
update jogo set inicio = now() - interval '61 minutes' where id = pg_temp.jogo('avulso_b');
select pg_temp.como('a0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('no avulso, quem joga não encerra', $$select encerrar_jogo(pg_temp.jogo('avulso_b'))$$, 'sem_permissao', '42501');
select pg_temp.como('c0000000-0000-0000-0000-000000000001');
select pg_temp.espera_recusa('no avulso, admin de grupo não encerra', $$select encerrar_jogo(pg_temp.jogo('avulso_b'))$$, 'sem_permissao', '42501');
select pg_temp.como('d0000000-0000-0000-0000-000000000001');
select pg_temp.espera_ok('Dani, a criadora, encerra o avulso', $$select encerrar_jogo(pg_temp.jogo('avulso_b'))$$);
reset role;
select pg_temp.espera_verdade('o avulso está encerrado', (select status from jogo where id = pg_temp.jogo('avulso_b')) = 'encerrado');

-- Pela rotina de minuto, sem autor: até o criador que deve recebe o aviso.
select pg_temp.como('b0000000-0000-0000-0000-000000000001');
insert into ids values ('k5', criar_jogo(pg_temp.jogo('sabado'), pg_temp.arena(), pg_temp.q1(),
  pg_temp.proximo(3, '19:00') + interval '14 days', 120, 10, 10000, null, 'a0000000-0000-0000-0000-000000000001'));
reset role;
update jogo set inicio = now() - interval '3 hours' where id = pg_temp.jogo('k5');
select set_config('request.jwt.claims', '', true);
select pg_temp.espera_ok('privado.encerrar sem ninguém autenticado', $$select privado.encerrar(pg_temp.jogo('k5'))$$);
select pg_temp.espera_verdade('k5 encerrado, e Bruno, o criador, recebe pagamento_liberado',
  (select status from jogo where id = pg_temp.jogo('k5')) = 'encerrado'
  and (select array_agg(n.pessoa_id)
       from notificacao n join cobranca c on c.id = n.cobranca_id join participacao p on p.id = c.participacao_id
       where n.tipo = 'pagamento_liberado' and p.jogo_id = pg_temp.jogo('k5'))
      = array['b0000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_recusa('privado.encerrar em jogo cancelado', $$select privado.encerrar(pg_temp.jogo('k1'))$$, 'jogo_fechado');

-- Privilégios.

select pg_temp.espera_verdade('anon não executa cancelar nem encerrar; authenticated executa os dois, mas não privado.encerrar',
  not has_function_privilege('anon', 'public.cancelar_jogo(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.encerrar_jogo(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.cancelar_jogo(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.encerrar_jogo(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.encerrar(uuid)', 'execute')
  and not has_function_privilege('anon', 'privado.encerrar(uuid)', 'execute'));

select pg_temp.espera_verdade('anon não executa criar, duplicar nem editar',
  not has_function_privilege('anon', 'public.criar_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text)', 'execute')
  and not has_function_privilege('anon', 'public.duplicar_jogo(uuid, timestamptz, text)', 'execute')
  and not has_function_privilege('anon', 'public.editar_jogo(uuid, timestamptz, uuid, uuid, integer, integer, uuid, text)', 'execute'));
select pg_temp.espera_verdade('authenticated executa criar, duplicar e editar',
  has_function_privilege('authenticated', 'public.criar_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text)', 'execute')
  and has_function_privilege('authenticated', 'public.duplicar_jogo(uuid, timestamptz, text)', 'execute')
  and has_function_privilege('authenticated', 'public.editar_jogo(uuid, timestamptz, uuid, uuid, integer, integer, uuid, text)', 'execute'));
select pg_temp.espera_verdade('authenticated não executa as auxiliares de privado',
  not has_function_privilege('authenticated', 'privado.prazo_sem_multa(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.checar_rn15(uuid, uuid, timestamptz, integer, uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.nascer_cobranca(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.chave_do_recebedor(uuid, text)', 'execute')
  and not has_function_privilege('authenticated', 'privado.nascer_jogo(uuid, uuid, uuid, timestamptz, integer, integer, integer, integer, uuid, text)', 'execute'));

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_erro('authenticated chamando privado.nascer_cobranca é barrado',
  $$select privado.nascer_cobranca('00000000-0000-0000-0000-000000000000')$$, '42501');
select pg_temp.espera_erro('authenticated chamando privado.encerrar é barrado',
  $$select privado.encerrar(pg_temp.jogo('k4'))$$, '42501');
select pg_temp.espera_erro('authenticated não insere jogo direto',
  $$insert into jogo (criador_id, recebedor_id, local_id, inicio, duracao_minutos, vagas_total, custo_total,
      preco_por_vaga, prazo_cancelamento_horas, status)
    values ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', pg_temp.ginasio(),
      now() + interval '1 day', 60, 10, 0, 0, 2, 'aberto')$$, '42501');

select pg_temp.como(null);

select pg_temp.espera_erro('anon chamando criar_jogo é barrado',
  $$select criar_jogo(null, '10000000-0000-0000-0000-000000000002', null, now() + interval '1 day', 60, 10, 0, 2)$$, '42501');

reset role;

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
