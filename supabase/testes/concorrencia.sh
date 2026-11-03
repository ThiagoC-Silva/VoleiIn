#!/usr/bin/env bash
# Concorrência (T12 do passo 4): duas sessões de verdade, cada uma na sua conexão, disputando
# a última vaga (RNF09) e a mesma quadra ou a capacidade do local (RN15, fila por local). As
# suítes SQL rodam numa transação só e não enxergam essa disputa.
#
# Uso: supabase/testes/concorrencia.sh
#
# Grava dados de verdade no banco local — três pessoas e um grupo com ids próprios (cc…) e os
# jogos criados nele — e apaga tudo no fim, mesmo quando uma conferência falha. Os jogos
# ficam dez semanas à frente, para não esbarrar em nada do seed nem do uso do app.
#
# Em cada cenário, a sessão A faz a operação e segura a transação aberta por 3 s; a sessão B
# começa 1 s depois e faz a mesma operação. A trava (for update na linha do jogo, ou
# pg_advisory_xact_lock no local) obriga B a esperar o commit de A; o tempo de B confere que
# a espera aconteceu, e o resultado, que B viu o que A gravou.
#
# Parâmetro, com padrão para o local:
#   PSQL  psql do contêiner do banco
#
# Saída como a das suítes SQL: `FALHOU: …` e saída 1 na primeira divergência, ou
# `SUCESSO: N cenários`.

set -uo pipefail

PSQL=${PSQL:-docker exec -i supabase_db_VoleiIn psql -U postgres -tA -q -v ON_ERROR_STOP=1}

ANA=cc000000-0000-0000-0000-000000000001
BRUNO=cc000000-0000-0000-0000-000000000002
CARLA=cc000000-0000-0000-0000-000000000003
GRUPO=cc000000-0000-0000-0000-0000000000aa
ARENA=10000000-0000-0000-0000-000000000001
QUADRA1=20000000-0000-0000-0000-000000000001
QUADRA2=20000000-0000-0000-0000-000000000002
GINASIO=10000000-0000-0000-0000-000000000002

# Segunda-feira dez semanas à frente, à hora dada em Brasília.
segunda() {  # <hora, como 19:00>
  echo "((date_trunc('week', now() at time zone 'America/Sao_Paulo') + interval '10 weeks' + time '$1') at time zone 'America/Sao_Paulo')"
}

TMP=$(mktemp -d)
CENARIOS=0

# Apaga o que o script grava, na ordem das chaves estrangeiras. Roda no começo também, para
# o resto de uma rodada interrompida não atrapalhar a seguinte.
apagar_dados() {
  $PSQL >/dev/null <<SQL || echo "AVISO: a limpeza falhou; rode o script de novo, que ele limpa antes de começar" >&2
begin;
delete from notificacao where pessoa_id in ('$ANA', '$BRUNO', '$CARLA');
delete from cobranca where participacao_id in (
  select p.id from participacao p join jogo j on j.id = p.jogo_id where j.grupo_id = '$GRUPO');
delete from participacao where jogo_id in (select id from jogo where grupo_id = '$GRUPO');
delete from jogo where grupo_id = '$GRUPO';
delete from membro_grupo where grupo_id = '$GRUPO';
delete from grupo where id = '$GRUPO';
delete from pessoa where id in ('$ANA', '$BRUNO', '$CARLA');
commit;
SQL
}

limpar() {
  apagar_dados
  rm -rf "$TMP"
}
trap limpar EXIT

falha() {
  echo "FALHOU: $*" >&2
  exit 1
}

# SQL que, dentro de uma transação, passa a agir como a pessoa, do jeito que a API faz.
como() {  # <pessoa>
  echo "select set_config('role', 'authenticated', true),
               set_config('request.jwt.claims', '{\"sub\": \"$1\", \"role\": \"authenticated\"}', true);"
}

# Roda A em segundo plano e B em primeiro, cada um com o seu SQL, e guarda a saída de cada
# um e o tempo de B em milissegundos.
disputa() {  # <sql de A> <sql de B>
  $PSQL <<<"$1" >"$TMP/a" 2>&1 &
  local pid_a=$!
  local t0
  t0=$(date +%s%N)
  $PSQL <<<"$2" >"$TMP/b" 2>&1
  TEMPO_B=$((($(date +%s%N) - t0) / 1000000))
  wait "$pid_a" || falha "a sessão A não terminou bem: $(cat "$TMP/a")"
  SAIDA_A=$(cat "$TMP/a")
  SAIDA_B=$(cat "$TMP/b")
}

consulta() {  # <sql>
  $PSQL <<<"$1" || falha "consulta: $1"
}

# --- Dados ------------------------------------------------------------------------------

apagar_dados

$PSQL >/dev/null <<SQL || falha "preparar os dados"
begin;
insert into pessoa (id, nome, chave_pix) values
  ('$ANA', 'Ana Concorrência', 'ana@pix'),
  ('$BRUNO', 'Bruno Concorrência', 'bruno@pix'),
  ('$CARLA', 'Carla Concorrência', 'carla@pix');
insert into grupo (id, nome, cor, criado_por, prazo_cancelamento_horas)
values ('$GRUPO', 'Concorrência', '#3B6FE0', '$ANA', 3);
insert into membro_grupo (grupo_id, pessoa_id, papel) values
  ('$GRUPO', '$ANA', 'admin'), ('$GRUPO', '$BRUNO', 'membro'), ('$GRUPO', '$CARLA', 'membro');
commit;
SQL

# --- 1. A última vaga (RNF09) -------------------------------------------------------------

# Duas vagas, e Ana, a criadora, já ocupa uma.
JOGO=$(consulta "begin; $(como "$ANA") select 'jogo:' || criar_jogo('$GRUPO', '$ARENA', '$QUADRA2', $(segunda 19:00), 120, 2, 2000, null); commit;" \
       | sed -n 's/^jogo://p')
[[ -n $JOGO ]] || falha "última vaga: o jogo não foi criado"

disputa \
  "begin; $(como "$BRUNO") select 'resultado:' || confirmar_presenca('$JOGO'); select pg_sleep(3); commit;" \
  "select pg_sleep(1); begin; $(como "$CARLA") select 'resultado:' || confirmar_presenca('$JOGO'); commit;"

grep -qx 'resultado:confirmado' <<<"$SAIDA_A" || falha "última vaga: Bruno devia ficar com a vaga; veio: $SAIDA_A"
grep -qx 'resultado:lista_espera' <<<"$SAIDA_B" || falha "última vaga: Carla devia cair na lista; veio: $SAIDA_B"
((TEMPO_B >= 2000)) || falha "última vaga: Carla não esperou a trava do jogo (${TEMPO_B} ms)"
SITUACAO=$(consulta "select string_agg(p.status || coalesce(':' || p.posicao_espera, '') || ':' || coalesce(c.status::text, '-'), ',' order by p.pessoa_id)
                     from participacao p left join cobranca c on c.participacao_id = p.id where p.jogo_id = '$JOGO';")
[[ $SITUACAO == 'confirmado:-,confirmado:pendente,lista_espera:1:-' ]] \
  || falha "última vaga: esperava Ana e Bruno confirmados, só Bruno com cobrança, e Carla na lista; veio $SITUACAO"
echo "ok: última vaga — um confirmado e um na lista, depois de ${TEMPO_B} ms de espera"
CENARIOS=$((CENARIOS + 1))

# --- 2. A mesma quadra (RN15) -------------------------------------------------------------

CRIAR_Q1="select 'jogo:' || criar_jogo('$GRUPO', '$ARENA', '$QUADRA1', $(segunda 19:00), 120, 10, 10000, null);"
disputa \
  "begin; $(como "$ANA") $CRIAR_Q1 select pg_sleep(3); commit;" \
  "select pg_sleep(1); begin; $(como "$BRUNO") $CRIAR_Q1 commit;"

grep -q '^jogo:' <<<"$SAIDA_A" || falha "mesma quadra: o jogo de Ana devia nascer; veio: $SAIDA_A"
grep -q 'ERROR:  quadra_ocupada' <<<"$SAIDA_B" || falha "mesma quadra: Bruno devia receber quadra_ocupada; veio: $SAIDA_B"
((TEMPO_B >= 2000)) || falha "mesma quadra: Bruno não esperou a fila do local (${TEMPO_B} ms)"
N=$(consulta "select count(*) from jogo where grupo_id = '$GRUPO' and quadra_id = '$QUADRA1';")
[[ $N == 1 ]] || falha "mesma quadra: esperava um jogo na Quadra 1; há $N"
echo "ok: mesma quadra — um jogo e uma recusa quadra_ocupada, depois de ${TEMPO_B} ms de espera"
CENARIOS=$((CENARIOS + 1))

# --- 3. A capacidade do local (RN15) ------------------------------------------------------

# O Ginásio comporta dois jogos simultâneos, e Carla já tem um gravado no horário.
CRIAR_GIN="select 'jogo:' || criar_jogo('$GRUPO', '$GINASIO', null, $(segunda 08:00), 60, 10, 10000, null);"
consulta "begin; $(como "$CARLA") $CRIAR_GIN commit;" | grep -q '^jogo:' || falha "capacidade: o primeiro jogo não foi criado"

disputa \
  "begin; $(como "$ANA") $CRIAR_GIN select pg_sleep(3); commit;" \
  "select pg_sleep(1); begin; $(como "$BRUNO") $CRIAR_GIN commit;"

grep -q '^jogo:' <<<"$SAIDA_A" || falha "capacidade: o jogo de Ana devia nascer; veio: $SAIDA_A"
grep -q 'ERROR:  local_lotado' <<<"$SAIDA_B" || falha "capacidade: Bruno devia receber local_lotado; veio: $SAIDA_B"
((TEMPO_B >= 2000)) || falha "capacidade: Bruno não esperou a fila do local (${TEMPO_B} ms)"
N=$(consulta "select count(*) from jogo where grupo_id = '$GRUPO' and local_id = '$GINASIO';")
[[ $N == 2 ]] || falha "capacidade: esperava dois jogos no Ginásio; há $N"
echo "ok: capacidade — o segundo jogo nasce e o terceiro recebe local_lotado, depois de ${TEMPO_B} ms de espera"
CENARIOS=$((CENARIOS + 1))

echo "SUCESSO: $CENARIOS cenários"
