#!/usr/bin/env bash
# Roteiro de autenticação pela API do Auth (T07): o caminho real do Supabase Auth até os
# gatilhos, os códigos de erro reais e os e-mails. Os cenários estão descritos em
# plan-tasks/passo-3/07-e2e-local.md; este script cobre a parte de servidor deles.
#
# Uso: CHAVE=<chave pública> supabase/testes/autenticacao_api.sh [--so 1,2] [--com-expiracao]
#
# Parâmetros por ambiente, com padrão para o local:
#   AUTH_URL     http://127.0.0.1:54321/auth/v1
#   CHAVE        sem padrão: a chave pública de `supabase status`
#   MAILPIT_URL  http://127.0.0.1:54324; vazio pede o código no terminal
#   PSQL         psql do contêiner do banco; vazio pula as conferências de banco
#   EMAIL_BASE   exemplo.com
#
# Saída como a das suítes SQL: `FALHOU: …` e saída 1 na primeira divergência, ou
# `SUCESSO: N cenários`.

set -uo pipefail

AUTH_URL=${AUTH_URL:-http://127.0.0.1:54321/auth/v1}
CHAVE=${CHAVE:-}
MAILPIT_URL=${MAILPIT_URL-http://127.0.0.1:54324}
PSQL=${PSQL-docker exec -i supabase_db_VoleiIn psql -U postgres -tA -v ON_ERROR_STOP=1}
EMAIL_BASE=${EMAIL_BASE:-exemplo.com}

if [[ -z $CHAVE ]]; then
  echo 'Falta CHAVE: a chave pública que `supabase status` mostra.' >&2
  exit 2
fi

SO=
COM_EXPIRACAO=0
while (($#)); do
  case $1 in
    --so) SO=",${2:?--so pede a lista de cenários, como 1,2},"; shift 2 ;;
    --com-expiracao) COM_EXPIRACAO=1; shift ;;
    --impostor) echo '--impostor chega na T07.5.' >&2; exit 2 ;;
    *) echo "Opção desconhecida: $1" >&2; exit 2 ;;
  esac
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
LIDAS=$TMP/lidas          # ids do Mailpit já consumidos nesta rodada
ANOTACOES=$TMP/anotacoes  # o que é para anotar, não conferir
: >"$LIDAS"
: >"$ANOTACOES"

# Em milissegundos: duas rodadas seguidas podem cair no mesmo segundo.
EPOCA=$(date +%s%3N)
CENARIOS=0
PULADAS=0

# --- Apoio ------------------------------------------------------------------------------

falha() {
  echo "FALHOU: $*" >&2
  exit 1
}

# Guarda STATUS e RESPOSTA da chamada. Roda no shell principal, nunca dentro de $(…).
chamar() {  # <método> <caminho> [corpo] [token]
  local args=(-s -o "$TMP/resposta" -w '%{http_code}' -X "$1" -H "apikey: $CHAVE")
  [[ -n ${4:-} ]] && args+=(-H "Authorization: Bearer $4")
  [[ -n ${3:-} ]] && args+=(-H 'Content-Type: application/json' -d "$3")
  STATUS=$(curl "${args[@]}" "$AUTH_URL$2") || falha "$1 $2: sem resposta de $AUTH_URL"
  RESPOSTA=$(cat "$TMP/resposta")
}

campo() {  # <filtro jq> sobre a última resposta
  jq -r "$1 // empty" <<<"$RESPOSTA" 2>/dev/null
}

espera_status() {  # <descrição> <status>
  [[ $STATUS == "$2" ]] ||
    falha "$1: status $STATUS, esperado $2 (error_code: $(campo .error_code)) — $RESPOSTA"
}

espera_erro() {  # <descrição> <error_code>
  local real
  real=$(campo .error_code)
  [[ $real == "$2" ]] ||
    falha "$1: error_code ${real:-nenhum}, esperado $2 (status $STATUS) — $RESPOSTA"
}

espera_igual() {  # <descrição> <valor> <esperado>
  [[ $2 == "$3" ]] || falha "$1: veio '$2', esperado '$3'"
}

# Mensagens do Mailpit para o endereço exato, mais novas primeiro, ainda não consumidas.
novas() {  # <email> [assunto]
  local consulta="to:\"$1\""
  [[ -n ${2:-} ]] && consulta+=" subject:\"$2\""
  curl -sf "$MAILPIT_URL/api/v1/search?query=$(jq -rn --arg q "$consulta" '$q | @uri')" |
    jq -r --arg e "$1" '.messages[] | select(any(.To[]; .Address == $e)) | .ID' |
    grep -vxF -f "$LIDAS"
}

# Seis casas do e-mail mais novo ainda não lido. Use como `c=$(codigo_de …) || exit 1`.
codigo_de() {  # <email> <assunto>
  local codigo
  if [[ -z $MAILPIT_URL ]]; then
    read -rp "Código de \"$2\" enviado a $1: " codigo </dev/tty
    echo "$codigo"
    return
  fi
  local ids i
  for ((i = 0; i < 20; i++)); do
    ids=$(novas "$1" "$2")
    if [[ -n $ids ]]; then
      echo "$ids" >>"$LIDAS"
      codigo=$(curl -sf "$MAILPIT_URL/api/v1/message/$(head -n1 <<<"$ids")" |
        jq -r .Text | grep -oE '\b[0-9]{6}\b' | head -n1)
      [[ -n $codigo ]] || falha "\"$2\" para $1 chegou sem código de seis casas"
      echo "$codigo"
      return
    fi
    sleep 0.5
  done
  falha "\"$2\" não chegou a $1 em 10 s"
}

sem_email() {  # <email> [assunto]; assunto vazio vale para qualquer e-mail
  if [[ -z $MAILPIT_URL ]]; then
    PULADAS=$((PULADAS + 1))
    return
  fi
  sleep 5
  local ids
  ids=$(novas "$1" "${2:-}")
  [[ -z $ids ]] || falha "chegou e-mail inesperado a $1 ($(wc -l <<<"$ids") mensagem)"
}

banco() {  # <sql>; devolve o valor. Use como `v=$(banco …) || exit 1`.
  printf '%s\n' "$1" | eval "$PSQL" || falha "banco: $1"
}

confere_banco() {  # <descrição> <sql> <esperado>
  if [[ -z $PSQL ]]; then
    PULADAS=$((PULADAS + 1))
    return
  fi
  local valor
  valor=$(banco "$2") || exit 1
  espera_igual "$1" "$valor" "$3"
}

email_unico() {  # <nome>
  echo "$1.$EPOCA@$EMAIL_BASE"
}

anota() {  # <cenário> <texto>
  printf '%s — %s\n' "$1" "$2" >>"$ANOTACOES"
}

json_cadastro() {  # <email> <senha> <nome>
  jq -n --arg e "$1" --arg s "$2" --arg n "$3" '{email: $e, password: $s, data: {nome: $n}}'
}

json_entrada() {  # <email> <senha>
  jq -n --arg e "$1" --arg s "$2" '{email: $e, password: $s}'
}

# --- Cenários ---------------------------------------------------------------------------
# Cada cenário que envia e-mail tem a sua pessoa, para nenhum esperar os 60 s de envio de
# outro. A Carla do cenário 1 serve a 2, 3 e 5, que não enviam nada; se o 1 não foi pedido,
# ela é criada do mesmo jeito.

CARLA=
CARLA_ID=
CARLA_SENHA=senha-da-carla

carla_confirmada() {
  [[ -n $CARLA_ID ]] || cenario_1
}

cenario_1() {  # Carla cria conta com senha
  CARLA=$(email_unico carla)
  chamar POST /signup "$(json_cadastro "$CARLA" "$CARLA_SENHA" Carla)"
  espera_status '1: cadastro' 200
  CARLA_ID=$(campo '.id // .user.id')
  [[ -n $CARLA_ID ]] || falha "1: cadastro sem id de usuário — $RESPOSTA"
  confere_banco '1: pessoa antes da confirmação' \
    "select count(*) from public.pessoa where id = '$CARLA_ID'" 0

  local codigo
  codigo=$(codigo_de "$CARLA" 'Confirme seu cadastro no VoleiIn') || exit 1
  chamar POST /verify "$(jq -n --arg e "$CARLA" --arg t "$codigo" '{type: "email", email: $e, token: $t}')"
  espera_status '1: confirmação do código' 200
  [[ -n $(campo .access_token) ]] || falha "1: confirmação sem sessão — $RESPOSTA"
  espera_igual '1: usuário da sessão' "$(campo .user.id)" "$CARLA_ID"
  confere_banco '1: pessoa depois da confirmação, com o id de auth.users' \
    "select p.nome from public.pessoa p join auth.users u using (id) where u.email = '$CARLA'" Carla
}

cenario_2() {  # Carla sai e entra com e-mail e senha
  carla_confirmada
  chamar POST '/token?grant_type=password' "$(json_entrada "$CARLA" "$CARLA_SENHA")"
  espera_status '2: entrada com senha' 200
  [[ -n $(campo .access_token) ]] || falha "2: entrada sem sessão — $RESPOSTA"
  espera_igual '2: usuário da sessão' "$(campo .user.id)" "$CARLA_ID"
  sem_email "$CARLA"
}

cenario_3() {  # Senha errada
  carla_confirmada
  chamar POST '/token?grant_type=password' "$(json_entrada "$CARLA" senha-errada)"
  espera_status '3: senha errada' 400
  espera_erro '3: senha errada' invalid_credentials
}

cenario_4() {  # Cadastro com senha de 7 caracteres
  local email
  email=$(email_unico fraca)
  chamar POST /signup "$(json_cadastro "$email" 1234567 Fraca)"
  espera_status '4: senha de 7 caracteres' 422
  espera_erro '4: senha de 7 caracteres' weak_password
  confere_banco '4: auth.users sem a linha' \
    "select count(*) from auth.users where email = '$email'" 0
}

cenario_5() {  # Cadastro com e-mail que já tem conta
  carla_confirmada
  chamar POST /signup "$(json_cadastro "$CARLA" outra-senha-qualquer Outra)"
  if [[ $STATUS == 422 && $(campo .error_code) == user_already_exists ]]; then
    anota 5 "cadastro com e-mail existente: 422 user_already_exists"
  elif [[ $STATUS == 200 && $(campo '(.identities // .user.identities) | length') == 0 ]]; then
    anota 5 "cadastro com e-mail existente: 200 com usuário sem identities"
  else
    falha "5: e-mail que já tem conta: status $STATUS — $RESPOSTA"
  fi
  sem_email "$CARLA"
}

cenario_invalido() {  # Cadastro com e-mail inválido
  chamar POST /signup "$(json_cadastro carla@ "$CARLA_SENHA" Carla)"
  local codigo
  codigo=$(campo .error_code)
  case $codigo in
    email_address_invalid | validation_failed)
      anota invalido "cadastro com 'carla@': $STATUS $codigo" ;;
    *) falha "invalido: cadastro com 'carla@': status $STATUS — $RESPOSTA" ;;
  esac
}

roda() {  # <cenário>
  [[ -z $SO || $SO == *",$1,"* ]] || return 0
  "cenario_$1"
  CENARIOS=$((CENARIOS + 1))
  echo "ok: cenário $1"
}

roda 1
roda 2
roda 3
roda 4
roda 5
roda invalido

((CENARIOS)) || falha "nenhum cenário com --so ${SO:1:-1}"
if [[ -s $ANOTACOES ]]; then
  echo
  echo 'Para anotar:'
  cat "$ANOTACOES"
fi
((PULADAS)) && echo "Conferências puladas por falta de PSQL ou MAILPIT_URL: $PULADAS"
echo "SUCESSO: $CENARIOS cenários"
