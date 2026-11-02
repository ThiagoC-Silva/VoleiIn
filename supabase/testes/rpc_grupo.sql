-- Cenários das funções de grupo (migração rpc_grupo): criar, editar, promover, remover e
-- sair, com os avisos que gravam e os privilégios de execução. Roda numa transação
-- desfeita, a partir do banco recém-resetado com o seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_grupo.sql
--
-- O aviso de editar_grupo sobre o prazo depende de confirmados em jogo e é conferido em
-- rpc_presenca.sql (T05).

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

-- Ids dos grupos criados pelas funções, guardados para os cenários seguintes.
create temp table ids (nome text primary key, id uuid not null);
grant select, insert on ids to authenticated;

-- Elenco, inserido como postgres. Membros comuns entram direto em membro_grupo, porque o
-- convite de grupo só chega no passo 9; grupos nascem pela criar_grupo.
--   Ana    a0…  cria Sábado
--   Bruno  b0…  membro de Sábado, promovido por Ana
--   Carlos c0…  cria Quinta
--   Dani   d0…  sem grupo; depois membro de Quinta
--   Eva    e0…  membro de Sábado, removida por Ana
insert into pessoa (id, nome) values
  ('a0000000-0000-0000-0000-000000000001', 'Ana Souza'),
  ('b0000000-0000-0000-0000-000000000001', 'Bruno Lima'),
  ('c0000000-0000-0000-0000-000000000001', 'Carlos'),
  ('d0000000-0000-0000-0000-000000000001', 'Dani'),
  ('e0000000-0000-0000-0000-000000000001', 'Eva');

-- Formatação dos textos, em horário de Brasília.

select pg_temp.espera_verdade('data curta em Brasília: 23:00 UTC de 24/10 é sáb, 24 out',
  privado.data_curta('2026-10-24 23:00:00+00') = 'sáb, 24 out');
select pg_temp.espera_verdade('hora em Brasília: 23:00 UTC é 20:00',
  privado.hora('2026-10-24 23:00:00+00') = '20:00');
select pg_temp.espera_verdade('dia de um algarismo sai sem zero: qui, 5 nov',
  privado.data_curta('2026-11-05 12:00:00+00') = 'qui, 5 nov');
select pg_temp.espera_verdade('a virada do dia segue Brasília: 02:00 UTC de 1/11 é sáb, 31 out · 23:00',
  privado.data_curta('2026-11-01 02:00:00+00') = 'sáb, 31 out'
  and privado.hora('2026-11-01 02:00:00+00') = '23:00');

-- Criar (RF03, RN12, RN13).

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Ana cria Sábado',
  $$insert into ids values ('sabado', criar_grupo('  Areia de Sábado ', '#3b6fe0', 3,
      '10000000-0000-0000-0000-000000000001', 14, 30000))$$);
select pg_temp.espera_recusa('cor fora das seis recusada',
  $$select criar_grupo('Outro', '#123456', 3)$$, 'cor_invalida');
select pg_temp.espera_recusa('cor vazia recusada',
  $$select criar_grupo('Outro', null, 3)$$, 'cor_invalida');
select pg_temp.espera_recusa('prazo negativo recusado',
  $$select criar_grupo('Outro', '#3B6FE0', -1)$$, 'prazo_invalido');
select pg_temp.espera_recusa('prazo vazio recusado',
  $$select criar_grupo('Outro', '#3B6FE0', null)$$, 'prazo_invalido');
select pg_temp.espera_recusa('nome só de espaços recusado',
  $$select criar_grupo('   ', '#3B6FE0', 3)$$, 'nome_vazio');
select pg_temp.espera_ok('prazo zero é aceito',
  $$insert into ids values ('zero', criar_grupo('Prazo zero', '#5A6B8C', 0))$$);

reset role;

select pg_temp.espera_verdade('o grupo nasce com os campos dados, nome aparado e cor em maiúsculas',
  exists (select 1 from grupo g join ids on ids.id = g.id and ids.nome = 'sabado'
          where g.nome = 'Areia de Sábado' and g.cor = '#3B6FE0' and g.prazo_cancelamento_horas = 3
            and g.criado_por = 'a0000000-0000-0000-0000-000000000001'
            and g.local_padrao_id = '10000000-0000-0000-0000-000000000001'
            and g.vagas_padrao = 14 and g.custo_total_padrao = 30000));
select pg_temp.espera_verdade('quem cria é admin e único membro',
  (select array_agg(m.pessoa_id::text || ':' || m.papel)
   from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'sabado')
  = array['a0000000-0000-0000-0000-000000000001:admin']);
select pg_temp.espera_verdade('as recusas não deixaram grupo pela metade',
  (select count(*) from grupo) = 2 and (select count(*) from membro_grupo) = 2);

insert into membro_grupo (grupo_id, pessoa_id, papel)
select id, p, 'membro' from ids, unnest(array['b0000000-0000-0000-0000-000000000001',
                                              'e0000000-0000-0000-0000-000000000001']::uuid[]) p
where nome = 'sabado';

-- Editar (RF06, RN11, RN13).

select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('membro comum não edita',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Outro', '#3B6FE0', 3)$$,
  'sem_permissao', '42501');

select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('quem não é membro não edita',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Outro', '#3B6FE0', 3)$$,
  'sem_permissao', '42501');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('editar valida a cor',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Areia de Sábado', '#FFFFFF', 3)$$,
  'cor_invalida');
select pg_temp.espera_recusa('editar valida o prazo',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Areia de Sábado', '#3B6FE0', -2)$$,
  'prazo_invalido');
select pg_temp.espera_recusa('editar valida o nome',
  $$select editar_grupo((select id from ids where nome = 'sabado'), '', '#3B6FE0', 3)$$,
  'nome_vazio');
select pg_temp.espera_ok('admin troca a cor e as vagas',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Areia de Sábado', '#E0559B', 3,
      '10000000-0000-0000-0000-000000000001', 12, 30000)$$);
select pg_temp.espera_ok('admin muda o prazo de um grupo sem jogos',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Areia de Sábado', '#E0559B', 5,
      '10000000-0000-0000-0000-000000000001', 12, 30000)$$);

reset role;

select pg_temp.espera_verdade('a edição gravou cor, vagas e prazo',
  exists (select 1 from grupo g join ids on ids.id = g.id and ids.nome = 'sabado'
          where g.cor = '#E0559B' and g.vagas_padrao = 12 and g.prazo_cancelamento_horas = 5));
select pg_temp.espera_verdade('mudança de cor e de prazo sem jogos não grava aviso',
  not exists (select 1 from notificacao));

-- Promover (RF31, RN13).

select pg_temp.como('e0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('membro comum não promove',
  $$select promover_admin((select id from ids where nome = 'sabado'), 'e0000000-0000-0000-0000-000000000001')$$,
  'sem_permissao', '42501');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('quem não é membro não é promovido',
  $$select promover_admin((select id from ids where nome = 'sabado'), 'd0000000-0000-0000-0000-000000000001')$$,
  'nao_e_membro');
select pg_temp.espera_ok('Ana promove Bruno',
  $$select promover_admin((select id from ids where nome = 'sabado'), 'b0000000-0000-0000-0000-000000000001')$$);
select pg_temp.espera_ok('promover de novo não é erro',
  $$select promover_admin((select id from ids where nome = 'sabado'), 'b0000000-0000-0000-0000-000000000001')$$);
select pg_temp.espera_ok('promover quem já é admin, a si mesma, não é erro',
  $$select promover_admin((select id from ids where nome = 'sabado'), 'a0000000-0000-0000-0000-000000000001')$$);

reset role;

select pg_temp.espera_verdade('Bruno virou admin',
  exists (select 1 from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'sabado'
          where m.pessoa_id = 'b0000000-0000-0000-0000-000000000001' and m.papel = 'admin'));
select pg_temp.espera_verdade('o aviso nasce para o promovido, uma vez só, com o texto aprovado',
  (select count(*) from notificacao) = 1
  and exists (select 1 from notificacao
              where pessoa_id = 'b0000000-0000-0000-0000-000000000001'
                and tipo = 'promovido_a_admin'
                and titulo = 'Você agora é admin de Areia de Sábado'
                and corpo = 'Ana Souza promoveu você. Agora você edita as regras, convida e remove membros.'
                and jogo_id is null and cobranca_id is null and lida_em is null));

select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('o promovido lê o próprio aviso',
  (select count(*) from notificacao) = 1);
select pg_temp.espera_ok('o admin promovido edita as regras',
  $$select editar_grupo((select id from ids where nome = 'sabado'), 'Areia de Sábado', '#E0559B', 5,
      '10000000-0000-0000-0000-000000000001', 14, 30000)$$);

-- Remover (RF30, RN13, RN30).

select pg_temp.como('e0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('membro comum não remove',
  $$select remover_membro((select id from ids where nome = 'sabado'), 'b0000000-0000-0000-0000-000000000001')$$,
  'sem_permissao', '42501');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('admin não remove a si mesmo',
  $$select remover_membro((select id from ids where nome = 'sabado'), 'a0000000-0000-0000-0000-000000000001')$$,
  'saia_do_grupo');
select pg_temp.espera_ok('Ana remove Eva',
  $$select remover_membro((select id from ids where nome = 'sabado'), 'e0000000-0000-0000-0000-000000000001')$$);
select pg_temp.espera_ok('remover de novo não é erro',
  $$select remover_membro((select id from ids where nome = 'sabado'), 'e0000000-0000-0000-0000-000000000001')$$);

reset role;

select pg_temp.espera_verdade('Eva saiu do grupo',
  not exists (select 1 from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'sabado'
              where m.pessoa_id = 'e0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('a removida recebe um aviso só, com o texto aprovado',
  (select count(*) from notificacao where pessoa_id = 'e0000000-0000-0000-0000-000000000001') = 1
  and exists (select 1 from notificacao
              where pessoa_id = 'e0000000-0000-0000-0000-000000000001'
                and tipo = 'removido_do_grupo'
                and titulo = 'Você não está mais em Areia de Sábado'
                and corpo = 'Um admin removeu você do grupo. Suas presenças e cobranças continuam valendo.'
                and jogo_id is null and cobranca_id is null));

select pg_temp.como('e0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('a removida perdeu o papel no grupo',
  $$select promover_admin((select id from ids where nome = 'sabado'), 'e0000000-0000-0000-0000-000000000001')$$,
  'sem_permissao', '42501');

select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('um admin remove outro admin',
  $$select remover_membro((select id from ids where nome = 'sabado'), 'a0000000-0000-0000-0000-000000000001')$$);

reset role;

select pg_temp.espera_verdade('Ana removida por Bruno, que segue admin único',
  (select array_agg(m.pessoa_id::text || ':' || m.papel)
   from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'sabado')
  = array['b0000000-0000-0000-0000-000000000001:admin']);

-- Sair (RF29, RN30).

select pg_temp.como('c0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Carlos cria Quinta',
  $$insert into ids values ('quinta', criar_grupo('Quinta', '#0FA3A0', 6))$$);

reset role;

insert into membro_grupo (grupo_id, pessoa_id, papel)
select id, 'd0000000-0000-0000-0000-000000000001', 'membro' from ids where nome = 'quinta';

select pg_temp.como('c0000000-0000-0000-0000-000000000001');

select pg_temp.espera_recusa('admin único com outro membro não sai',
  $$select sair_grupo((select id from ids where nome = 'quinta'))$$, 'promova_outro_admin');
select pg_temp.espera_ok('Carlos promove Dani',
  $$select promover_admin((select id from ids where nome = 'quinta'), 'd0000000-0000-0000-0000-000000000001')$$);
select pg_temp.espera_ok('com outro admin, Carlos sai',
  $$select sair_grupo((select id from ids where nome = 'quinta'))$$);
select pg_temp.espera_ok('sair de novo não é erro',
  $$select sair_grupo((select id from ids where nome = 'quinta'))$$);

select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('a última membro sai livre',
  $$select sair_grupo((select id from ids where nome = 'quinta'))$$);

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('admin único e último membro de Prazo zero sai livre',
  $$select sair_grupo((select id from ids where nome = 'zero'))$$);

reset role;

select pg_temp.espera_verdade('Quinta ficou sem membros, e o grupo continua existindo',
  not exists (select 1 from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'quinta')
  and exists (select 1 from grupo g join ids on ids.id = g.id and ids.nome = 'quinta'));
select pg_temp.espera_verdade('Prazo zero ficou sem membros',
  not exists (select 1 from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'zero'));
select pg_temp.espera_verdade('sair não avisa ninguém: além da remoção de Ana, só a promoção de Dani foi gravada',
  (select count(*) from notificacao) = 4
  and exists (select 1 from notificacao where pessoa_id = 'a0000000-0000-0000-0000-000000000001'
              and tipo = 'removido_do_grupo')
  and exists (select 1 from notificacao where pessoa_id = 'd0000000-0000-0000-0000-000000000001'
              and tipo = 'promovido_a_admin' and corpo like 'Carlos promoveu você.%'));

-- Membro comum sai sem precisar de nada; o admin restante segue.
insert into membro_grupo (grupo_id, pessoa_id, papel)
select id, 'e0000000-0000-0000-0000-000000000001', 'membro' from ids where nome = 'sabado';

select pg_temp.como('e0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('membro comum sai', $$select sair_grupo((select id from ids where nome = 'sabado'))$$);

reset role;

select pg_temp.espera_verdade('Bruno segue admin de Sábado',
  (select array_agg(m.pessoa_id::text) from membro_grupo m join ids on ids.id = m.grupo_id and ids.nome = 'sabado')
  = array['b0000000-0000-0000-0000-000000000001']);

-- Privilégios.

select pg_temp.espera_verdade('anon não executa nenhuma das cinco',
  not has_function_privilege('anon', 'public.criar_grupo(text, text, integer, uuid, integer, integer)', 'execute')
  and not has_function_privilege('anon', 'public.editar_grupo(uuid, text, text, integer, uuid, integer, integer)', 'execute')
  and not has_function_privilege('anon', 'public.promover_admin(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.remover_membro(uuid, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.sair_grupo(uuid)', 'execute'));
select pg_temp.espera_verdade('authenticated executa as cinco',
  has_function_privilege('authenticated', 'public.criar_grupo(text, text, integer, uuid, integer, integer)', 'execute')
  and has_function_privilege('authenticated', 'public.editar_grupo(uuid, text, text, integer, uuid, integer, integer)', 'execute')
  and has_function_privilege('authenticated', 'public.promover_admin(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.remover_membro(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.sair_grupo(uuid)', 'execute'));
select pg_temp.espera_verdade('authenticated não executa as auxiliares de privado',
  not has_function_privilege('authenticated', 'privado.avisar(uuid, notificacao_tipo, text, text, uuid, uuid)', 'execute')
  and not has_function_privilege('authenticated', 'privado.data_curta(timestamptz)', 'execute')
  and not has_function_privilege('authenticated', 'privado.hora(timestamptz)', 'execute')
  and not has_function_privilege('authenticated', 'privado.validar_grupo(text, text, integer)', 'execute'));

select pg_temp.como(null);

select pg_temp.espera_erro('anon chamando criar_grupo é barrado', $$select criar_grupo('X', '#3B6FE0', 3)$$, '42501');
select pg_temp.espera_erro('anon chamando sair_grupo é barrado',
  $$select sair_grupo('00000000-0000-0000-0000-000000000000')$$, '42501');

select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_erro('authenticated chamando privado.avisar é barrado',
  $$select privado.avisar('a0000000-0000-0000-0000-000000000001', 'removido_do_grupo', 'x', 'y')$$, '42501');
select pg_temp.espera_erro('authenticated não insere aviso direto',
  $$insert into notificacao (pessoa_id, tipo, titulo) values ('a0000000-0000-0000-0000-000000000001', 'removido_do_grupo', 'x')$$,
  '42501');

reset role;

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
