-- Asserções de acesso do passo 2: quem lê cada tabela, que escrita o app consegue
-- fazer e o que a listar_participantes devolve (RN26). Matriz em docs/stack.md,
-- seção Política de linha. Roda numa transação desfeita, a partir do banco
-- recém-resetado com o seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rls.sql

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

-- Elenco, inserido como postgres, que contorna a política.
--   Ana    a0…  admin do grupo de sábado; cria e recebe J1, J2, J5, J6
--   Bruno  b0…  membro de sábado e de quinta; deve vencido em J1 (sábado) e J4 (quinta)
--   Carlos c0…  admin de quinta; cria e recebe J4; não conhece a turma de sábado
--   Dani   d0…  convidada, sem grupo; joga J1, J3, J5, J6
--   Eva    e0…  membro de sábado; cria e recebe J3; deve ainda no prazo em J2
--
--   J1 sábado, encerrado há dez dias   J4 quinta, encerrado há dez dias
--   J2 sábado, encerrado há duas horas J5 avulso, encerrado há dez dias
--   J3 sábado, aberto                  J6 avulso, aberto
insert into pessoa (id, nome) values
  ('a0000000-0000-0000-0000-000000000001', 'Ana'),
  ('b0000000-0000-0000-0000-000000000001', 'Bruno'),
  ('c0000000-0000-0000-0000-000000000001', 'Carlos'),
  ('d0000000-0000-0000-0000-000000000001', 'Dani'),
  ('e0000000-0000-0000-0000-000000000001', 'Eva');

insert into grupo (id, nome, cor, criado_por, prazo_cancelamento_horas) values
  ('31000000-0000-0000-0000-000000000001', 'Sábado', '#1e88e5', 'a0000000-0000-0000-0000-000000000001', 6),
  ('32000000-0000-0000-0000-000000000001', 'Quinta', '#43a047', 'c0000000-0000-0000-0000-000000000001', 6);

insert into membro_grupo (grupo_id, pessoa_id, papel) values
  ('31000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'admin'),
  ('31000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'membro'),
  ('31000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'membro'),
  ('32000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'admin'),
  ('32000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'membro');

insert into jogo (id, grupo_id, criador_id, recebedor_id, chave_pix_recebedor, local_id, quadra_id,
                  inicio, duracao_minutos, vagas_total, custo_total, preco_por_vaga, prazo_cancelamento_horas, status)
values
  ('41000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'pix-ana',
   '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   now() - interval '10 days', 120, 10, 10000, 1000, null, 'encerrado'),
  -- Fim reservado há uma hora: encerramento previsto agora, vencimento daqui a 24 horas.
  ('42000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001',
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'pix-ana',
   '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   now() - interval '2 hours', 60, 10, 10000, 1000, null, 'encerrado'),
  ('43000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001',
   'e0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'pix-eva',
   '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   now() + interval '2 days', 120, 10, 10000, 1000, null, 'aberto'),
  ('44000000-0000-0000-0000-000000000001', '32000000-0000-0000-0000-000000000001',
   'c0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'pix-carlos',
   '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   now() - interval '10 days', 120, 10, 10000, 1000, null, 'encerrado'),
  ('45000000-0000-0000-0000-000000000001', null,
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'pix-ana',
   '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   now() - interval '10 days' + interval '3 hours', 120, 10, 10000, 1000, 6, 'encerrado'),
  ('46000000-0000-0000-0000-000000000001', null,
   'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'pix-ana',
   '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000002',
   now() + interval '3 days', 120, 10, 10000, 1000, 6, 'aberto');

insert into participacao (id, jogo_id, pessoa_id, status, confirmado_em) values
  ('51000000-0000-0000-0000-0000000000b1', '41000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '12 days'),
  ('51000000-0000-0000-0000-0000000000d1', '41000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '12 days'),
  ('52000000-0000-0000-0000-0000000000e1', '42000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '1 day'),
  ('53000000-0000-0000-0000-0000000000b1', '43000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '2 hours'),
  ('53000000-0000-0000-0000-0000000000d1', '43000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '1 hour'),
  ('54000000-0000-0000-0000-0000000000b1', '44000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '12 days'),
  ('55000000-0000-0000-0000-0000000000d1', '45000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '12 days'),
  ('56000000-0000-0000-0000-0000000000d1', '46000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'confirmado', now() - interval '1 hour');

-- Eva entra na fila de J3 para conferir a ordem da listagem.
insert into participacao (id, jogo_id, pessoa_id, status, posicao_espera) values
  ('53000000-0000-0000-0000-0000000000e1', '43000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'lista_espera', 1);

insert into cobranca (id, participacao_id, devedor_id, credor_id, valor, origem, status) values
  -- Vencida, sábado: marca Bruno em J3.
  ('61000000-0000-0000-0000-0000000000b1', '51000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente'),
  -- Comprovante enviado: não marca Dani.
  ('61000000-0000-0000-0000-0000000000d1', '51000000-0000-0000-0000-0000000000d1', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1000, 'parte', 'comprovante_enviado'),
  -- Ainda no prazo: não marca Eva.
  ('62000000-0000-0000-0000-0000000000e1', '52000000-0000-0000-0000-0000000000e1', 'e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente'),
  ('63000000-0000-0000-0000-0000000000b1', '53000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente'),
  ('63000000-0000-0000-0000-0000000000d1', '53000000-0000-0000-0000-0000000000d1', 'd0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente'),
  -- Vencida, mas de quinta: não aparece no sábado.
  ('64000000-0000-0000-0000-0000000000b1', '54000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente'),
  -- Vencida, avulso da Ana: marca Dani em J6, não em J3.
  ('65000000-0000-0000-0000-0000000000d1', '55000000-0000-0000-0000-0000000000d1', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente'),
  ('66000000-0000-0000-0000-0000000000d1', '56000000-0000-0000-0000-0000000000d1', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1000, 'parte', 'pendente');

insert into comprovante (cobranca_id, resultado, arquivo_url) values
  ('61000000-0000-0000-0000-0000000000d1', 'ilegivel', 'comprovantes/dani-j1.jpg');

insert into convite (token, tipo, grupo_id, jogo_id, criado_por, expira_em) values
  ('tok-sabado', 'grupo', '31000000-0000-0000-0000-000000000001', null, 'a0000000-0000-0000-0000-000000000001', null),
  ('tok-j3', 'jogo', null, '43000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', now() + interval '2 days');

insert into notificacao (id, pessoa_id, tipo, titulo) values
  ('70000000-0000-0000-0000-0000000000b1', 'b0000000-0000-0000-0000-000000000001', 'pagamento_liberado', 'Pagamento liberado'),
  ('70000000-0000-0000-0000-0000000000d1', 'd0000000-0000-0000-0000-000000000001', 'pagamento_liberado', 'Pagamento liberado');

insert into dispositivo_push (pessoa_id, token_fcm) values
  ('b0000000-0000-0000-0000-000000000001', 'fcm-bruno');

-- Leitura: Carlos, de outra turma
select pg_temp.como('c0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Carlos vê só o jogo de quinta',
  (select array_agg(id) from jogo) = array['44000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_verdade('Carlos vê só o grupo de quinta',
  (select array_agg(id) from grupo) = array['32000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_verdade('Carlos vê os dois membros de quinta',
  (select count(*) from membro_grupo) = 2);
select pg_temp.espera_verdade('Carlos conhece só a si e ao Bruno, não a Ana',
  (select array_agg(nome order by nome) from pessoa) = array['Bruno', 'Carlos']);
select pg_temp.espera_verdade('Carlos vê só a participação de J4',
  (select count(*) from participacao) = 1);
select pg_temp.espera_verdade('Carlos, credor, vê só a cobrança de J4',
  (select array_agg(id) from cobranca) = array['64000000-0000-0000-0000-0000000000b1'::uuid]);
select pg_temp.espera_verdade('Carlos não vê comprovante alheio',
  (select count(*) from comprovante) = 0);
select pg_temp.espera_verdade('Carlos não vê convite de sábado',
  (select count(*) from convite) = 0);
select pg_temp.espera_verdade('Carlos lê local, quadra e horário (RN18)',
  (select count(*) from local) > 0 and (select count(*) from quadra) > 0
  and (select count(*) from horario_funcionamento) > 0);

-- Leitura: Dani, convidada sem grupo
select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Dani vê os quatro jogos em que tem participação',
  (select count(*) from jogo) = 4
  and not exists (select 1 from jogo where id in ('42000000-0000-0000-0000-000000000001', '44000000-0000-0000-0000-000000000001')));
select pg_temp.espera_verdade('Dani vê o grupo de sábado pelo selo do feed (RF12)',
  (select array_agg(id) from grupo) = array['31000000-0000-0000-0000-000000000001'::uuid]);
select pg_temp.espera_verdade('Dani não vê a lista de membros',
  (select count(*) from membro_grupo) = 0);
select pg_temp.espera_verdade('Dani conhece quem está nos jogos dela, não o Carlos',
  (select array_agg(nome order by nome) from pessoa) = array['Ana', 'Bruno', 'Dani', 'Eva']);
select pg_temp.espera_verdade('Dani vê as três participações de J3, inclusive a fila',
  (select count(*) from participacao where jogo_id = '43000000-0000-0000-0000-000000000001') = 3);
select pg_temp.espera_verdade('Dani vê só as próprias cobranças',
  (select count(*) from cobranca) = 4
  and not exists (select 1 from cobranca where devedor_id <> 'd0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('Dani, devedora, vê o próprio comprovante',
  (select count(*) from comprovante) = 1);
select pg_temp.espera_verdade('Dani vê o convite de jogo que criou',
  (select array_agg(token) from convite) = array['tok-j3']);
select pg_temp.espera_verdade('Dani vê só o próprio aviso',
  (select array_agg(id) from notificacao) = array['70000000-0000-0000-0000-0000000000d1'::uuid]);
select pg_temp.espera_verdade('Dani não vê dispositivo alheio',
  (select count(*) from dispositivo_push) = 0);

-- Leitura: Bruno, membro de duas turmas
select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Bruno vê os jogos das duas turmas, não os avulsos',
  (select count(*) from jogo) = 4 and (select count(*) from jogo where grupo_id is null) = 0);
select pg_temp.espera_verdade('Bruno conhece as duas turmas e quem joga com ele',
  (select array_agg(nome order by nome) from pessoa) = array['Ana', 'Bruno', 'Carlos', 'Dani', 'Eva']);
select pg_temp.espera_verdade('Bruno não vê a cobrança da Dani',
  (select count(*) from cobranca) = 3
  and not exists (select 1 from cobranca where devedor_id <> 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('Bruno não vê o comprovante da Dani',
  (select count(*) from comprovante) = 0);
select pg_temp.espera_verdade('Bruno, membro, não vê convite de grupo',
  (select count(*) from convite) = 0);
select pg_temp.espera_verdade('Bruno vê o próprio dispositivo',
  (select count(*) from dispositivo_push) = 1);

-- Leitura: Ana, admin e credora
select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Ana, credora, vê as cobranças que recebe',
  (select count(*) from cobranca) = 5);
select pg_temp.espera_verdade('Ana, credora, vê o comprovante da Dani',
  (select count(*) from comprovante) = 1);
select pg_temp.espera_verdade('Ana, admin, vê o convite do grupo e não o de jogo da Dani (RF32)',
  (select array_agg(token) from convite) = array['tok-sabado']);
select pg_temp.espera_verdade('Ana não conhece o Carlos',
  not exists (select 1 from pessoa where nome = 'Carlos'));

-- Escrita negada no rateio e na base de locais
select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_erro('app cria jogo direto', $c$
  insert into jogo (criador_id, recebedor_id, chave_pix_recebedor, local_id, inicio, duracao_minutos,
                    vagas_total, custo_total, preco_por_vaga, prazo_cancelamento_horas, status)
  values ('b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'pix',
          '10000000-0000-0000-0000-000000000001', now() + interval '1 day', 60, 10, 1000, 100, 6, 'aberto')
$c$, '42501');

select pg_temp.espera_erro('devedor dá baixa na própria cobrança', $c$
  update cobranca set status = 'confirmado' where id = '61000000-0000-0000-0000-0000000000b1'
$c$, '42501');

select pg_temp.espera_erro('app apaga participação', $c$
  delete from participacao where id = '53000000-0000-0000-0000-0000000000b1'
$c$, '42501');

select pg_temp.espera_erro('app envia comprovante direto', $c$
  insert into comprovante (cobranca_id, resultado) values ('61000000-0000-0000-0000-0000000000b1', 'consistente')
$c$, '42501');

select pg_temp.espera_erro('app entra no grupo direto', $c$
  insert into membro_grupo (grupo_id, pessoa_id, papel)
  values ('32000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'admin')
$c$, '42501');

select pg_temp.espera_erro('app cadastra local (RN18)', $c$
  insert into local (nome, criado_por, modo_reserva)
  values ('Quadra pirata', 'b0000000-0000-0000-0000-000000000001', 'por_horario')
$c$, '42501');

select pg_temp.espera_erro('app altera preço da quadra (RN18)', $c$
  update quadra set preco_hora = 1 where id = '20000000-0000-0000-0000-000000000001'
$c$, '42501');

select pg_temp.espera_erro('app apaga horário de funcionamento (RN18)', $c$
  delete from horario_funcionamento
$c$, '42501');

select pg_temp.espera_erro('perfil não troca de id', $c$
  update pessoa set id = gen_random_uuid() where id = 'b0000000-0000-0000-0000-000000000001'
$c$, '42501');

select pg_temp.espera_erro('aviso não troca de título', $c$
  update notificacao set titulo = 'Outro' where id = '70000000-0000-0000-0000-0000000000b1'
$c$, '42501');

select pg_temp.espera_erro('app cria aviso', $c$
  insert into notificacao (pessoa_id, tipo, titulo)
  values ('b0000000-0000-0000-0000-000000000001', 'vaga_liberada', 'Falso')
$c$, '42501');

-- As três escritas diretas fora do rateio (RF02, RF38, RF40)
select pg_temp.espera_ok('Bruno edita o próprio perfil', $c$
  update pessoa set nome = 'Bruno S.', telefone = '85999990000', chave_pix = 'pix-bruno'
  where id = 'b0000000-0000-0000-0000-000000000001'
$c$);
select pg_temp.espera_verdade('o perfil do Bruno mudou',
  (select nome = 'Bruno S.' and chave_pix = 'pix-bruno' from pessoa where id = 'b0000000-0000-0000-0000-000000000001'));

select pg_temp.espera_ok('Bruno tenta editar o perfil da Ana', $c$
  update pessoa set nome = 'Invadida' where id = 'a0000000-0000-0000-0000-000000000001'
$c$);
select pg_temp.espera_verdade('o perfil da Ana não mudou',
  (select nome = 'Ana' from pessoa where id = 'a0000000-0000-0000-0000-000000000001'));

select pg_temp.espera_ok('Bruno marca o próprio aviso como lido', $c$
  update notificacao set lida_em = now() where id = '70000000-0000-0000-0000-0000000000b1'
$c$);
select pg_temp.espera_verdade('o aviso do Bruno está lido',
  (select lida_em is not null from notificacao where id = '70000000-0000-0000-0000-0000000000b1'));

select pg_temp.espera_ok('Bruno registra outro aparelho', $c$
  insert into dispositivo_push (pessoa_id, token_fcm, modelo_aparelho)
  values ('b0000000-0000-0000-0000-000000000001', 'fcm-bruno-2', 'Moto G')
$c$);

select pg_temp.espera_erro('Bruno registra aparelho em nome da Dani', $c$
  insert into dispositivo_push (pessoa_id, token_fcm)
  values ('d0000000-0000-0000-0000-000000000001', 'fcm-falso')
$c$, '42501');

select pg_temp.espera_erro('aparelho não marca o próprio erro', $c$
  update dispositivo_push set ultimo_erro_em = now() where token_fcm = 'fcm-bruno'
$c$, '42501');

select pg_temp.espera_ok('Bruno remove um aparelho', $c$
  delete from dispositivo_push where token_fcm = 'fcm-bruno-2'
$c$);
select pg_temp.espera_verdade('sobrou um aparelho do Bruno',
  (select count(*) from dispositivo_push) = 1);

select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_ok('Dani tenta ler o aviso do Bruno e apagar o aparelho dele', $c$
  update notificacao set lida_em = null where id = '70000000-0000-0000-0000-0000000000b1';
  delete from dispositivo_push where token_fcm = 'fcm-bruno'
$c$);

reset role;

select pg_temp.espera_verdade('o aviso e o aparelho do Bruno seguem intactos',
  (select lida_em is not null from notificacao where id = '70000000-0000-0000-0000-0000000000b1')
  and exists (select 1 from dispositivo_push where token_fcm = 'fcm-bruno'));

-- Sem autenticação, nada
select pg_temp.como(null);

select pg_temp.espera_erro('anon lê jogo', $c$ select count(*) from jogo $c$, '42501');
select pg_temp.espera_erro('anon lê pessoa', $c$ select count(*) from pessoa $c$, '42501');
select pg_temp.espera_erro('anon lê local', $c$ select count(*) from local $c$, '42501');
select pg_temp.espera_erro('anon lista participantes', $c$
  select * from listar_participantes('43000000-0000-0000-0000-000000000001')
$c$, '42501');

reset role;

-- As auxiliares e o gatilho não viram RPC
select pg_temp.espera_verdade('authenticated não executa auxiliar de cálculo nem gatilho',
  not has_function_privilege('authenticated', 'privado.encerramento_previsto(timestamptz, integer)', 'execute')
  and not has_function_privilege('authenticated', 'public.tocar_atualizado_em()', 'execute')
  and not has_function_privilege('anon', 'privado.pode_ver_jogo(uuid)', 'execute'));

select pg_temp.espera_verdade('política de linha ligada nas treze tabelas',
  (select count(*) = 13 from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity));

-- listar_participantes (RN26)
select pg_temp.como('a0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Ana, admin, vê Bruno marcado em J3 pela dívida de sábado',
  (select debito_vencido from listar_participantes('43000000-0000-0000-0000-000000000001')
   where pessoa_id = 'b0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('Dani não é marcada em J3: comprovante enviado e dívida avulsa ficam de fora',
  (select debito_vencido = false from listar_participantes('43000000-0000-0000-0000-000000000001')
   where pessoa_id = 'd0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('Eva não é marcada: a cobrança de J2 ainda está no prazo',
  (select debito_vencido = false from listar_participantes('43000000-0000-0000-0000-000000000001')
   where pessoa_id = 'e0000000-0000-0000-0000-000000000001'));
select pg_temp.espera_verdade('J3 lista confirmados por ordem de confirmação e depois a fila',
  (select array_agg(l.pessoa_id order by l.ordinality)
   from listar_participantes('43000000-0000-0000-0000-000000000001') with ordinality as l)
  = array['b0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001',
          'e0000000-0000-0000-0000-000000000001']::uuid[]);
select pg_temp.espera_verdade('no avulso J6, Dani é marcada pela dívida com a mesma recebedora',
  (select debito_vencido from listar_participantes('46000000-0000-0000-0000-000000000001')
   where pessoa_id = 'd0000000-0000-0000-0000-000000000001'));

select pg_temp.como('e0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Eva, criadora de J3, também vê a marca',
  (select debito_vencido from listar_participantes('43000000-0000-0000-0000-000000000001')
   where pessoa_id = 'b0000000-0000-0000-0000-000000000001'));

select pg_temp.como('d0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Dani, participante, vê a lista sem a marca',
  (select count(*) = 3 and bool_and(debito_vencido is null)
   from listar_participantes('43000000-0000-0000-0000-000000000001')));

select pg_temp.como('b0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Bruno, membro, vê a lista sem a marca',
  (select count(*) = 3 and bool_and(debito_vencido is null)
   from listar_participantes('43000000-0000-0000-0000-000000000001')));

select pg_temp.como('c0000000-0000-0000-0000-000000000001');

select pg_temp.espera_verdade('Carlos não vê J3 e recebe lista vazia',
  not exists (select 1 from listar_participantes('43000000-0000-0000-0000-000000000001')));
select pg_temp.espera_verdade('Carlos, admin de quinta, vê Bruno marcado em J4 só pela dívida de quinta',
  (select debito_vencido from listar_participantes('44000000-0000-0000-0000-000000000001')
   where pessoa_id = 'b0000000-0000-0000-0000-000000000001'));

reset role;

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
