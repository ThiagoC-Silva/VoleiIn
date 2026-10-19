-- Asserções de schema do passo 1. Tenta violar cada restrição e espera o erro certo;
-- confere os casos que devem passar. Roda dentro de uma transação desfeita ao fim,
-- então não deixa rastro. Parte do banco recém-resetado, com o seed.sql aplicado.
--
-- docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/schema.sql

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

-- Jogo válido ponta a ponta, do local à cobrança. Usa a pessoa, o local e a quadra do seed.
--   pessoa 01 (seed) cria e recebe; pessoa 02 joga e deve
--   local 10…01 por_quadra, quadra 20…01
select pg_temp.espera_ok('pessoa sem conta', $c$
  insert into pessoa (id, nome) values ('00000000-0000-0000-0000-000000000002', 'Jogadora')
$c$);

select pg_temp.espera_ok('grupo com padrões', $c$
  insert into grupo (id, nome, cor, criado_por, local_padrao_id, vagas_padrao, custo_total_padrao, prazo_cancelamento_horas)
  values ('30000000-0000-0000-0000-000000000001', 'Vôlei de sábado', '#1e88e5',
          '00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 12, 24000, 6)
$c$);

select pg_temp.espera_ok('membro do grupo', $c$
  insert into membro_grupo (grupo_id, pessoa_id, papel)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'admin')
$c$);

select pg_temp.espera_ok('jogo de grupo, sem prazo próprio, 10000 / 7 = 1429', $c$
  insert into jogo (id, grupo_id, criador_id, recebedor_id, chave_pix_recebedor, local_id, quadra_id,
                    inicio, duracao_minutos, vagas_total, custo_total, preco_por_vaga, status)
  values ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'pix@exemplo.com',
          '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
          '2026-10-25 00:00+00', 120, 7, 10000, 1429, 'encerrado')
$c$);

select pg_temp.espera_ok('participação confirmada', $c$
  insert into participacao (id, jogo_id, pessoa_id, status, confirmado_em)
  values ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000002', 'confirmado', now())
$c$);

select pg_temp.espera_ok('cobrança pendente', $c$
  insert into cobranca (id, participacao_id, devedor_id, credor_id, valor, origem, status)
  values ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 1429, 'parte', 'pendente')
$c$);

select pg_temp.espera_ok('dois comprovantes ilegíveis na mesma cobrança (RN10)', $c$
  insert into comprovante (cobranca_id, resultado) values
    ('60000000-0000-0000-0000-000000000001', 'ilegivel'),
    ('60000000-0000-0000-0000-000000000001', 'ilegivel')
$c$);

select pg_temp.espera_ok('comprovante com identificador', $c$
  insert into comprovante (cobranca_id, resultado, valor_lido, id_transacao)
  values ('60000000-0000-0000-0000-000000000001', 'consistente', 1429, 'E2E-1')
$c$);

select pg_temp.espera_ok('cobrança confirmada com o par preenchido (RN07)', $c$
  update cobranca set status = 'confirmado',
    confirmado_por = '00000000-0000-0000-0000-000000000001', confirmado_em = now()
  where id = '60000000-0000-0000-0000-000000000001'
$c$);

select pg_temp.espera_ok('convite de grupo', $c$
  insert into convite (token, tipo, grupo_id, criado_por)
  values ('tok-grupo', 'grupo', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001')
$c$);

select pg_temp.espera_ok('convite de jogo', $c$
  insert into convite (token, tipo, jogo_id, criado_por, expira_em)
  values ('tok-jogo', 'jogo', '40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001',
          '2026-10-25 00:00+00')
$c$);

select pg_temp.espera_ok('aviso', $c$
  insert into notificacao (pessoa_id, tipo, titulo, jogo_id, cobranca_id)
  values ('00000000-0000-0000-0000-000000000002', 'cobranca_confirmada', 'Pagamento confirmado',
          '40000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001')
$c$);

select pg_temp.espera_ok('dispositivo de push', $c$
  insert into dispositivo_push (pessoa_id, token_fcm)
  values ('00000000-0000-0000-0000-000000000002', 'fcm-1')
$c$);

-- Unicidades
select pg_temp.espera_erro('membro duas vezes no grupo', $c$
  insert into membro_grupo (grupo_id, pessoa_id, papel)
  values ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'membro')
$c$, '23505', 'membro_grupo_grupo_pessoa_unico');

select pg_temp.espera_erro('duas vagas da mesma pessoa no jogo', $c$
  insert into participacao (jogo_id, pessoa_id, status)
  values ('40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'confirmado')
$c$, '23505', 'participacao_jogo_pessoa_unico');

select pg_temp.espera_erro('duas cobranças da mesma participação', $c$
  insert into cobranca (participacao_id, devedor_id, credor_id, valor, origem, status)
  values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002',
          '00000000-0000-0000-0000-000000000001', 1429, 'parte', 'pendente')
$c$, '23505', 'cobranca_participacao_unico');

select pg_temp.espera_erro('token de convite repetido', $c$
  insert into convite (token, tipo, grupo_id, criado_por)
  values ('tok-grupo', 'grupo', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001')
$c$, '23505', 'convite_token_unico');

select pg_temp.espera_erro('token FCM repetido', $c$
  insert into dispositivo_push (pessoa_id, token_fcm)
  values ('00000000-0000-0000-0000-000000000001', 'fcm-1')
$c$, '23505', 'dispositivo_push_token_fcm_unico');

select pg_temp.espera_erro('id_transacao repetido, mesmo em outra linha (RN10)', $c$
  insert into comprovante (cobranca_id, resultado, id_transacao)
  values ('60000000-0000-0000-0000-000000000001', 'consistente', 'E2E-1')
$c$, '23505', 'comprovante_id_transacao_unico');

-- jogo: valores no limite
select pg_temp.espera_erro('vagas_total zero', $c$
  update jogo set vagas_total = 0 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_vagas_total_positivo');

select pg_temp.espera_erro('duracao_minutos zero', $c$
  update jogo set duracao_minutos = 0 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_duracao_minutos_positiva');

select pg_temp.espera_erro('custo_total negativo', $c$
  update jogo set custo_total = -1, preco_por_vaga = 0 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_custo_total_nao_negativo');

select pg_temp.espera_erro('preço por vaga arredondado para baixo (RN16)', $c$
  update jogo set preco_por_vaga = 1428 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_preco_por_vaga_arredondado');

select pg_temp.espera_erro('preço por vaga um centavo acima do teto (RN16)', $c$
  update jogo set preco_por_vaga = 1430 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_preco_por_vaga_arredondado');

select pg_temp.espera_erro('custo alterado sem recalcular o preço (RN01)', $c$
  update jogo set custo_total = 12000 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_preco_por_vaga_arredondado');

select pg_temp.espera_ok('divisão exata: 7000 / 7 = 1000', $c$
  update jogo set custo_total = 7000, preco_por_vaga = 1000 where id = '40000000-0000-0000-0000-000000000001'
$c$);

select pg_temp.espera_erro('divisão exata não arredonda para cima', $c$
  update jogo set preco_por_vaga = 1001 where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_preco_por_vaga_arredondado');

select pg_temp.espera_ok('custo zero e uma vaga', $c$
  update jogo set vagas_total = 1, custo_total = 0, preco_por_vaga = 0 where id = '40000000-0000-0000-0000-000000000001'
$c$);

select pg_temp.espera_ok('volta a 10000 / 7 = 1429', $c$
  update jogo set vagas_total = 7, custo_total = 10000, preco_por_vaga = 1429 where id = '40000000-0000-0000-0000-000000000001'
$c$);

select pg_temp.espera_erro('jogo avulso sem prazo (RN12)', $c$
  update jogo set grupo_id = null where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_avulso_tem_prazo');

select pg_temp.espera_ok('jogo avulso com prazo', $c$
  update jogo set grupo_id = null, prazo_cancelamento_horas = 0 where id = '40000000-0000-0000-0000-000000000001'
$c$);

select pg_temp.espera_erro('chave Pix do recebedor vazia (RN24)', $c$
  update jogo set chave_pix_recebedor = '' where id = '40000000-0000-0000-0000-000000000001'
$c$, '23514', 'jogo_chave_pix_recebedor_nao_vazia');

select pg_temp.espera_ok('chave Pix do recebedor esvaziada na anonimização (RN27)', $c$
  update jogo set chave_pix_recebedor = null where id = '40000000-0000-0000-0000-000000000001'
$c$);

-- participacao (RN08)
select pg_temp.espera_erro('lista de espera sem posição', $c$
  update participacao set status = 'lista_espera' where id = '50000000-0000-0000-0000-000000000001'
$c$, '23514', 'participacao_posicao_so_na_espera');

select pg_temp.espera_erro('confirmado com posição', $c$
  update participacao set posicao_espera = 1 where id = '50000000-0000-0000-0000-000000000001'
$c$, '23514', 'participacao_posicao_so_na_espera');

select pg_temp.espera_erro('posição zero na lista de espera', $c$
  update participacao set status = 'lista_espera', posicao_espera = 0 where id = '50000000-0000-0000-0000-000000000001'
$c$, '23514', 'participacao_posicao_espera_positiva');

select pg_temp.espera_ok('lista de espera na posição 1', $c$
  update participacao set status = 'lista_espera', posicao_espera = 1 where id = '50000000-0000-0000-0000-000000000001'
$c$);

-- convite (RN22)
select pg_temp.espera_erro('convite de grupo apontando para jogo', $c$
  insert into convite (token, tipo, jogo_id, criado_por)
  values ('t1', 'grupo', '40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001')
$c$, '23514', 'convite_alvo_conforme_tipo');

select pg_temp.espera_erro('convite de jogo apontando para grupo', $c$
  insert into convite (token, tipo, grupo_id, criado_por)
  values ('t2', 'jogo', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001')
$c$, '23514', 'convite_alvo_conforme_tipo');

select pg_temp.espera_erro('convite com os dois alvos', $c$
  insert into convite (token, tipo, grupo_id, jogo_id, criado_por)
  values ('t3', 'grupo', '30000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-000000000001')
$c$, '23514', 'convite_alvo_conforme_tipo');

select pg_temp.espera_erro('convite sem alvo', $c$
  insert into convite (token, tipo, criado_por)
  values ('t4', 'grupo', '00000000-0000-0000-0000-000000000001')
$c$, '23514', 'convite_alvo_conforme_tipo');

-- horario_funcionamento
select pg_temp.espera_erro('dia_semana -1', $c$
  insert into horario_funcionamento (local_id, dia_semana, abre, fecha)
  values ('10000000-0000-0000-0000-000000000001', -1, '08:00', '12:00')
$c$, '23514', 'horario_funcionamento_dia_semana_valido');

select pg_temp.espera_erro('dia_semana 7', $c$
  insert into horario_funcionamento (local_id, dia_semana, abre, fecha)
  values ('10000000-0000-0000-0000-000000000001', 7, '08:00', '12:00')
$c$, '23514', 'horario_funcionamento_dia_semana_valido');

select pg_temp.espera_ok('dia_semana 0 e 6', $c$
  insert into horario_funcionamento (local_id, dia_semana, abre, fecha)
  values ('10000000-0000-0000-0000-000000000001', 0, '08:00', '12:00'),
         ('10000000-0000-0000-0000-000000000001', 6, '08:00', '12:00')
$c$);

-- local e quadra (RN14, RN15)
select pg_temp.espera_erro('preço por hora do local negativo', $c$
  update local set preco_hora = -1 where id = '10000000-0000-0000-0000-000000000001'
$c$, '23514', 'local_preco_hora_nao_negativo');

select pg_temp.espera_erro('capacidade zero', $c$
  update local set capacidade = 0 where id = '10000000-0000-0000-0000-000000000002'
$c$, '23514', 'local_capacidade_positiva');

select pg_temp.espera_ok('preço zero e capacidade 1', $c$
  update local set preco_hora = 0, capacidade = 1 where id = '10000000-0000-0000-0000-000000000002'
$c$);

select pg_temp.espera_erro('preço por hora da quadra negativo', $c$
  update quadra set preco_hora = -1 where id = '20000000-0000-0000-0000-000000000001'
$c$, '23514', 'quadra_preco_hora_nao_negativo');

-- grupo (RN12)
select pg_temp.espera_erro('vagas_padrao zero', $c$
  update grupo set vagas_padrao = 0 where id = '30000000-0000-0000-0000-000000000001'
$c$, '23514', 'grupo_vagas_padrao_positivo');

select pg_temp.espera_erro('custo_total_padrao negativo', $c$
  update grupo set custo_total_padrao = -1 where id = '30000000-0000-0000-0000-000000000001'
$c$, '23514', 'grupo_custo_total_padrao_nao_negativo');

select pg_temp.espera_ok('padrões vazios', $c$
  update grupo set vagas_padrao = null, custo_total_padrao = null where id = '30000000-0000-0000-0000-000000000001'
$c$);

-- cobranca (RN07)
select pg_temp.espera_erro('valor negativo', $c$
  update cobranca set valor = -1 where id = '60000000-0000-0000-0000-000000000001'
$c$, '23514', 'cobranca_valor_nao_negativo');

select pg_temp.espera_erro('confirmado_por sem confirmado_em', $c$
  update cobranca set confirmado_em = null where id = '60000000-0000-0000-0000-000000000001'
$c$, '23514', 'cobranca_confirmacao_em_par');

select pg_temp.espera_erro('confirmado_em sem confirmado_por', $c$
  update cobranca set confirmado_por = null where id = '60000000-0000-0000-0000-000000000001'
$c$, '23514', 'cobranca_confirmacao_em_par');

select pg_temp.espera_ok('valor zero e par vazio', $c$
  update cobranca set valor = 0, status = 'pendente', confirmado_por = null, confirmado_em = null
  where id = '60000000-0000-0000-0000-000000000001'
$c$);

-- comprovante (RN10)
select pg_temp.espera_erro('id_transacao vazio', $c$
  insert into comprovante (cobranca_id, resultado, id_transacao)
  values ('60000000-0000-0000-0000-000000000001', 'ilegivel', '')
$c$, '23514', 'comprovante_id_transacao_nao_vazio');

-- Enum recusa valor fora do catálogo
select pg_temp.espera_erro('status de jogo fora do catálogo', $c$
  update jogo set status = 'finalizado' where id = '40000000-0000-0000-0000-000000000001'
$c$, '22P02');

select pg_temp.espera_erro('tipo de quadra fora do catálogo', $c$
  update quadra set tipo = 'grama' where id = '20000000-0000-0000-0000-000000000001'
$c$, '22P02');

-- pessoa.id sem default: insert sem id falha em vez de criar perfil órfão
select pg_temp.espera_erro('pessoa sem id', $c$
  insert into pessoa (nome) values ('Sem id')
$c$, '23502');

-- Gatilho: dentro de uma transação now() é fixo, então parte de um atualizado_em antigo.
update pessoa set atualizado_em = '2000-01-01' where id = '00000000-0000-0000-0000-000000000002';
update pessoa set nome = 'Jogadora renomeada' where id = '00000000-0000-0000-0000-000000000002';

select pg_temp.espera_verdade('update move atualizado_em para now()',
  (select atualizado_em = now() from pessoa where id = '00000000-0000-0000-0000-000000000002'));

select pg_temp.espera_verdade('o gatilho existe nas treze tabelas',
  (select count(*) = 13
   from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and t.tgname = 'tocar_atualizado_em'));

do $$
begin
  raise notice 'SUCESSO: % asserções', currval('assercoes');
end;
$$;

rollback;
