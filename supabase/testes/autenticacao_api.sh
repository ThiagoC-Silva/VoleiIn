#!/usr/bin/env bash
# Roteiro de autenticação pela API do Auth (T07): o caminho real do Supabase Auth até os
# gatilhos, os códigos de erro reais e os e-mails. Os cenários estão descritos em
# plan-tasks/passo-3/07-e2e-local.md; este script cobre a parte de servidor deles.
#
# Uso: CHAVE=<chave pública> supabase/testes/autenticacao_api.sh [--so 1,2] [--com-expiracao]
#      CHAVE=<chave pública> supabase/testes/autenticacao_api.sh --impostor <gmail>
#
# --impostor só cria o cadastro pendente do cenário 19, com senha e nome "Impostor", e
# imprime o id; o resto do cenário é no celular (T07.9).
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
IMPOSTOR=
while (($#)); do
  case $1 in
    --so) SO=",${2:?--so pede a lista de cenários, como 1,2},"; shift 2 ;;
    --com-expiracao) COM_EXPIRACAO=1; shift ;;
    --impostor) IMPOSTOR=${2:?--impostor pede o Gmail}; shift 2 ;;
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

# A API de dados mora ao lado da de autenticação. Só o cenário do cadastro refeito a usa,
# para gravar e ler o nome como o app.
REST_URL=${AUTH_URL%/auth/v1}/rest/v1

dados() {  # <método> <caminho> <token> [corpo]; como `chamar`, na API de dados
  local args=(-s -o "$TMP/resposta" -w '%{http_code}' -X "$1" -H "apikey: $CHAVE"
    -H "Authorization: Bearer $3")
  [[ -n ${4:-} ]] && args+=(-H 'Content-Type: application/json' -d "$4")
  STATUS=$(curl "${args[@]}" "$REST_URL$2") || falha "$1 $2: sem resposta de $REST_URL"
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

# Espera por até 10 s o e-mail mais novo ainda não lido, marca-o como lido e devolve o id.
# Use como `id=$(chegou …) || exit 1`.
chegou() {  # <email> <assunto>
  local ids i
  for ((i = 0; i < 20; i++)); do
    ids=$(novas "$1" "$2")
    if [[ -n $ids ]]; then
      echo "$ids" >>"$LIDAS"
      head -n1 <<<"$ids"
      return
    fi
    sleep 0.5
  done
  falha "\"$2\" não chegou a $1 em 10 s"
}

# Seis casas do e-mail mais novo ainda não lido. Use como `c=$(codigo_de …) || exit 1`.
codigo_de() {  # <email> <assunto>
  local codigo id
  if [[ -z $MAILPIT_URL ]]; then
    read -rp "Código de \"$2\" enviado a $1: " codigo </dev/tty
    echo "$codigo"
    return
  fi
  id=$(chegou "$1" "$2") || exit 1
  codigo=$(curl -sf "$MAILPIT_URL/api/v1/message/$id" |
    jq -r .Text | grep -oE '\b[0-9]{6}\b' | head -n1)
  [[ -n $codigo ]] || falha "\"$2\" para $1 chegou sem código de seis casas"
  echo "$codigo"
}

# Confere que o aviso chegou; sem MAILPIT_URL, conta como pulada.
espera_aviso() {  # <email> <assunto>
  if [[ -z $MAILPIT_URL ]]; then
    PULADAS=$((PULADAS + 1))
    return
  fi
  chegou "$1" "$2" >/dev/null || exit 1
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
# Os assuntos de `config.toml`, com o modelo de que cada um sai e se leva código.

ASSUNTO_CADASTRO='Confirme seu cadastro no VoleiIn'
ASSUNTO_REDEFINICAO='Seu código para redefinir a senha do VoleiIn'
ASSUNTO_TROCA_EMAIL='Confirme a troca de e-mail no VoleiIn'
ASSUNTO_EMAIL_TROCADO='O e-mail da sua conta no VoleiIn foi trocado'
ASSUNTO_SENHA_TROCADA='A senha da sua conta no VoleiIn foi trocada'

MODELOS=(
  "$ASSUNTO_CADASTRO|confirmacao.html|código"
  "$ASSUNTO_REDEFINICAO|redefinicao_senha.html|código"
  "$ASSUNTO_TROCA_EMAIL|troca_email.html|código"
  "$ASSUNTO_EMAIL_TROCADO|aviso_troca_email.html|aviso"
  "$ASSUNTO_SENHA_TROCADA|aviso_troca_senha.html|aviso"
)
TEMPLATES=$(dirname "${BASH_SOURCE[0]}")/../templates

# Cada cenário que envia e-mail tem a sua pessoa, para nenhum esperar os 60 s de envio de
# outro. A Carla do cenário 1 serve a 2, 3 e 5, que não enviam nada, e a 12, 13 a 15 e 16;
# se o 1 não foi pedido, ela é criada do mesmo jeito. O Fábio, pendente, serve a 8 e 7 do
# mesmo modo.

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
  codigo=$(codigo_de "$CARLA" "$ASSUNTO_CADASTRO") || exit 1
  chamar POST /verify "$(json_codigo email "$CARLA" "$codigo")"
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

json_codigo() {  # <tipo> <email> <código>
  jq -n --arg y "$1" --arg e "$2" --arg t "$3" '{type: $y, email: $e, token: $t}'
}

json_reenvio() {  # <email>
  jq -n --arg e "$1" '{type: "signup", email: $e}'
}

ate_passar() {  # <segundos> <epoch em s>; dorme até <segundos> depois do instante dado
  local falta=$(($2 + $1 - $(date +%s)))
  ((falta > 0)) && sleep "$falta"
}

cenario_6() {  # Eva cadastra e não confirma; depois entra com a senha
  local eva eva_id senha=senha-da-eva enviado codigo
  eva=$(email_unico eva)
  chamar POST /signup "$(json_cadastro "$eva" "$senha" Eva)"
  espera_status '6: cadastro' 200
  enviado=$(date +%s)
  eva_id=$(campo '.id // .user.id')
  # Consome o primeiro código, para o reenvio não ser confundido com ele.
  codigo_de "$eva" "$ASSUNTO_CADASTRO" >/dev/null || exit 1

  chamar POST '/token?grant_type=password' "$(json_entrada "$eva" "$senha")"
  espera_status '6: entrada sem confirmar' 400
  espera_erro '6: entrada sem confirmar' email_not_confirmed

  # É o reenvio que o `entrar` do app engole: o código de menos de um minuto vale.
  chamar POST /resend "$(json_reenvio "$eva")"
  espera_status '6: reenvio logo depois' 429
  espera_erro '6: reenvio logo depois' over_email_send_rate_limit

  # Os 61 s correm junto com os da eva2, que se cadastra de novo antes e depois deles.
  cadastro_duplo_antes

  ate_passar 61 "$enviado"
  chamar POST /resend "$(json_reenvio "$eva")"
  espera_status '6: reenvio depois de 61 s' 200
  codigo=$(codigo_de "$eva" "$ASSUNTO_CADASTRO") || exit 1
  chamar POST /verify "$(json_codigo email "$eva" "$codigo")"
  espera_status '6: confirmação do código reenviado' 200
  espera_igual '6: usuário da sessão' "$(campo .user.id)" "$eva_id"

  cadastro_duplo_depois
}

# A eva2 repete o /signup com outra senha antes de confirmar, uma vez antes de 60 s e
# outra depois, cada vez com outro nome. Só anota: a resposta, se veio código novo e qual
# senha e qual nome valem no fim.
EVA2=
EVA2_CODIGO=
EVA2_SENHAS=(senha-primeira senha-segunda senha-terceira)

cadastro_de_novo() {  # <senha> <nome> <quando>
  local resposta
  chamar POST /signup "$(json_cadastro "$EVA2" "$1" "$2")"
  resposta="$STATUS $(campo .error_code)"
  [[ $STATUS == 200 ]] && resposta+=" (mesmo id: $([[ $(campo '.id // .user.id') == "$EVA2_ID" ]] && echo sim || echo não))"
  sleep 5
  if [[ -n $(novas "$EVA2" || true) ]]; then
    EVA2_CODIGO=$(codigo_de "$EVA2" "$ASSUNTO_CADASTRO") || exit 1
    anota 6 "segundo cadastro $3: $resposta; enviou código novo"
  else
    anota 6 "segundo cadastro $3: $resposta; nenhum código novo"
  fi
}

cadastro_duplo_antes() {
  EVA2=$(email_unico eva2)
  chamar POST /signup "$(json_cadastro "$EVA2" "${EVA2_SENHAS[0]}" 'Eva Primeira')"
  espera_status '6: cadastro da eva2' 200
  EVA2_ID=$(campo '.id // .user.id')
  EVA2_ENVIADO=$(date +%s)
  EVA2_CODIGO=$(codigo_de "$EVA2" "$ASSUNTO_CADASTRO") || exit 1
  cadastro_de_novo "${EVA2_SENHAS[1]}" 'Eva Segunda' 'antes de 60 s'
}

cadastro_duplo_depois() {
  local senha
  ate_passar 61 "$EVA2_ENVIADO"
  cadastro_de_novo "${EVA2_SENHAS[2]}" 'Eva Terceira' 'depois de 60 s'
  chamar POST /verify "$(json_codigo email "$EVA2" "$EVA2_CODIGO")"
  anota 6 "confirmação da eva2 com o código mais novo: $STATUS $(campo .error_code)"
  for senha in "${EVA2_SENHAS[@]}"; do
    chamar POST '/token?grant_type=password' "$(json_entrada "$EVA2" "$senha")"
    anota 6 "depois de confirmar, $senha: $STATUS $(campo .error_code)"
  done
  [[ -n $PSQL ]] &&
    anota 6 "pessoa.nome da eva2: $(banco "select nome from public.pessoa where id = '$EVA2_ID'")"
}

# A Helena refaz pela A2 o cadastro que um impostor deixou pendente no e-mail dela (T13).
# O serviço fica com a senha e o nome do primeiro pedido; o app grava os da A2 com a sessão
# do código, o nome antes da senha. Sem o app, o cenário 6 mostra o que o serviço faz.
cenario_refeito() {
  local helena id enviado codigo token
  helena=$(email_unico helena)
  chamar POST /signup "$(json_cadastro "$helena" senha-do-impostor Impostor)"
  espera_status 'refeito: cadastro do impostor' 200
  id=$(campo '.id // .user.id')
  enviado=$(date +%s)
  # O código do impostor chega à caixa da Helena, que não o usa.
  codigo_de "$helena" "$ASSUNTO_CADASTRO" >/dev/null || exit 1

  ate_passar 61 "$enviado"
  chamar POST /signup "$(json_cadastro "$helena" senha-da-helena Helena)"
  espera_status 'refeito: cadastro da Helena' 200
  espera_igual 'refeito: mesmo usuário' "$(campo '.id // .user.id')" "$id"
  codigo=$(codigo_de "$helena" "$ASSUNTO_CADASTRO") || exit 1
  chamar POST /verify "$(json_codigo email "$helena" "$codigo")"
  espera_status 'refeito: confirmação' 200
  token=$(campo .access_token)

  dados PATCH "/pessoa?id=eq.$id" "$token" '{"nome": "Helena"}'
  espera_status 'refeito: nome da A2' 204
  chamar PUT /user '{"password": "senha-da-helena"}' "$token"
  espera_status 'refeito: senha da A2' 200
  espera_aviso "$helena" "$ASSUNTO_SENHA_TROCADA"

  chamar POST '/token?grant_type=password' "$(json_entrada "$helena" senha-do-impostor)"
  espera_erro 'refeito: senha do impostor' invalid_credentials
  chamar POST '/token?grant_type=password' "$(json_entrada "$helena" senha-da-helena)"
  espera_status 'refeito: senha da Helena' 200
  dados GET "/pessoa?select=nome&id=eq.$id" "$(campo .access_token)"
  espera_igual 'refeito: nome do perfil' "$(campo '.[0].nome')" Helena
}

FABIO=
FABIO_CODIGO=

fabio_pendente() {  # Fábio cadastrado, com o código recebido e sem confirmar
  [[ -z $FABIO ]] || return 0
  FABIO=$(email_unico fabio)
  chamar POST /signup "$(json_cadastro "$FABIO" senha-do-fabio Fábio)"
  espera_status 'Fábio: cadastro' 200
  FABIO_CODIGO=$(codigo_de "$FABIO" "$ASSUNTO_CADASTRO") || exit 1
}

cenario_8() {  # Reenvio antes de 60 s do cadastro
  fabio_pendente
  chamar POST /resend "$(json_reenvio "$FABIO")"
  espera_status '8: reenvio antes de 60 s' 429
  espera_erro '8: reenvio antes de 60 s' over_email_send_rate_limit
}

cenario_7() {  # Código errado, código certo, o mesmo código de novo e, opcional, vencido
  fabio_pendente
  local errado=000000
  [[ $FABIO_CODIGO == "$errado" ]] && errado=111111
  chamar POST /verify "$(json_codigo email "$FABIO" "$errado")"
  [[ $STATUS == 2* ]] && falha "7: código errado aceito — $RESPOSTA"
  anota 7 "código errado: $STATUS $(campo .error_code)"

  chamar POST /verify "$(json_codigo email "$FABIO" "$FABIO_CODIGO")"
  espera_status '7: código certo' 200
  [[ -n $(campo .access_token) ]] || falha "7: confirmação sem sessão — $RESPOSTA"

  chamar POST /verify "$(json_codigo email "$FABIO" "$FABIO_CODIGO")"
  [[ $STATUS == 2* ]] && falha "7: código usado aceito de novo — $RESPOSTA"
  anota 7 "código usado de novo: $STATUS $(campo .error_code)"

  ((COM_EXPIRACAO)) || return 0
  local heitor enviado codigo
  heitor=$(email_unico heitor)
  chamar POST /signup "$(json_cadastro "$heitor" senha-do-heitor Heitor)"
  espera_status '7: cadastro do Heitor' 200
  enviado=$(date +%s)
  codigo=$(codigo_de "$heitor" "$ASSUNTO_CADASTRO") || exit 1
  echo "7: esperando o código do Heitor vencer (301 s)…"
  ate_passar 301 "$enviado"
  chamar POST /verify "$(json_codigo email "$heitor" "$codigo")"
  [[ $STATUS == 2* ]] && falha "7: código de mais de 5 min aceito — $RESPOSTA"
  anota 7 "código depois de 301 s: $STATUS $(campo .error_code)"
}

json_email() {  # <email>
  jq -n --arg e "$1" '{email: $e}'
}

json_senha() {  # <senha>
  jq -n --arg s "$1" '{password: $s}'
}

json_renovacao() {  # <refresh_token>
  jq -n --arg r "$1" '{refresh_token: $r}'
}

# Cadastro e confirmação, sem as conferências do cenário 1. Deixa o id em CONFIRMADO_ID.
cadastro_confirmado() {  # <email> <senha> <nome> <cenário>
  local codigo
  chamar POST /signup "$(json_cadastro "$1" "$2" "$3")"
  espera_status "$4: cadastro de $3" 200
  CONFIRMADO_ID=$(campo '.id // .user.id')
  codigo=$(codigo_de "$1" "$ASSUNTO_CADASTRO") || exit 1
  chamar POST /verify "$(json_codigo email "$1" "$codigo")"
  espera_status "$4: confirmação de $3" 200
}

# O começo do `redefinirSenha` do app: pede o código e o confere, o que cria a sessão A.
# Deixa SESSAO_TOKEN e SESSAO_RENOVACAO, e o corpo do /recover em RESPOSTA_RECUPERACAO,
# que o cenário 10 compara. O /recover logo depois do cadastro passa: os 60 s entre
# envios contam por tipo de e-mail, não por usuário.
redefinicao() {  # <email> <cenário>
  local codigo
  chamar POST /recover "$(json_email "$1")"
  espera_status "$2: pedido de redefinição" 200
  RESPOSTA_RECUPERACAO=$RESPOSTA
  codigo=$(codigo_de "$1" "$ASSUNTO_REDEFINICAO") || exit 1
  chamar POST /verify "$(json_codigo recovery "$1" "$codigo")"
  espera_status "$2: conferência do código de redefinição" 200
  SESSAO_TOKEN=$(campo .access_token)
  SESSAO_RENOVACAO=$(campo .refresh_token)
  [[ -n $SESSAO_TOKEN ]] || falha "$2: código de redefinição sem sessão — $RESPOSTA"
}

renovacao_recusada() {  # <descrição> <refresh_token> <cenário>
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$2")"
  [[ $STATUS == 2* ]] && falha "$3: $1 renovou o token — $RESPOSTA"
  anota "$3" "$1: $STATUS $(campo .error_code)"
}

# Duas linhas em `dispositivo_push` com token inventado, como de dois aparelhos.
aparelhos_inventados() {  # <pessoa_id> <cenário>
  if [[ -n $PSQL ]]; then
    banco "insert into public.dispositivo_push (pessoa_id, token_fcm)
           values ('$1', 'fcm-inventado-1-$1'), ('$1', 'fcm-inventado-2-$1')" >/dev/null || exit 1
  fi
  confere_banco "$2: aparelhos antes da troca" \
    "select count(*) from public.dispositivo_push where pessoa_id = '$1'" 2
}

# O Bruno do cenário 9 serve ao 16; se o 9 não foi pedido, ele é criado sem as conferências.
BRUNO=

bruno_confirmado() {
  [[ -n $BRUNO ]] && return 0
  BRUNO=$(email_unico bruno)
  cadastro_confirmado "$BRUNO" senha-do-bruno Bruno 16
}

cenario_9() {  # Bruno redefine a senha com outras duas sessões abertas e aparelhos de push
  local bruno_id senha=senha-do-bruno nova=senha-nova-do-bruno b c
  BRUNO=$(email_unico bruno)
  cadastro_confirmado "$BRUNO" "$senha" Bruno 9
  bruno_id=$CONFIRMADO_ID

  # B e C: entradas por senha, como em outros dois aparelhos.
  chamar POST '/token?grant_type=password' "$(json_entrada "$BRUNO" "$senha")"
  espera_status '9: entrada da sessão B' 200
  b=$(campo .refresh_token)
  chamar POST '/token?grant_type=password' "$(json_entrada "$BRUNO" "$senha")"
  espera_status '9: entrada da sessão C' 200
  c=$(campo .refresh_token)
  aparelhos_inventados "$bruno_id" 9

  redefinicao "$BRUNO" 9
  chamar PUT /user "$(json_senha "$nova")" "$SESSAO_TOKEN"
  espera_status '9: troca da senha' 200
  # Só anota: diz se a troca sozinha já derruba as outras sessões, antes do logout do app.
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$c")"
  anota 9 "renovação de C depois da troca e antes do logout: $STATUS $(campo .error_code)"
  [[ $STATUS == 200 ]] && c=$(campo .refresh_token)
  chamar POST '/logout?scope=others' '' "$SESSAO_TOKEN"
  espera_status '9: saída das outras sessões' 204

  renovacao_recusada 'renovação de B depois do logout' "$b" 9
  renovacao_recusada 'renovação de C depois do logout' "$c" 9
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$SESSAO_RENOVACAO")"
  espera_status '9: renovação da sessão A' 200
  confere_banco '9: aparelhos depois da troca' \
    "select count(*) from public.dispositivo_push where pessoa_id = '$bruno_id'" 0
  espera_aviso "$BRUNO" "$ASSUNTO_SENHA_TROCADA"

  chamar POST '/token?grant_type=password' "$(json_entrada "$BRUNO" "$senha")"
  espera_status '9: senha antiga' 400
  espera_erro '9: senha antiga' invalid_credentials
  chamar POST '/token?grant_type=password' "$(json_entrada "$BRUNO" "$nova")"
  espera_status '9: senha nova' 200
}

cenario_10() {  # Redefinição para e-mail sem conta
  # Compara com o /recover mais recente da rodada; sozinho, pede um para a Carla.
  if [[ -z ${RESPOSTA_RECUPERACAO:-} ]]; then
    carla_confirmada
    chamar POST /recover "$(json_email "$CARLA")"
    espera_status '10: pedido de redefinição da Carla' 200
    RESPOSTA_RECUPERACAO=$RESPOSTA
  fi
  local ninguem
  ninguem=$(email_unico ninguem)
  chamar POST /recover "$(json_email "$ninguem")"
  espera_status '10: pedido para e-mail sem conta' 200
  espera_igual '10: corpo igual ao de e-mail com conta' "$RESPOSTA" "$RESPOSTA_RECUPERACAO"
  sem_email "$ninguem"
}

cenario_11() {  # Senha nova igual à atual
  local gil senha=senha-do-gil
  gil=$(email_unico gil)
  cadastro_confirmado "$gil" "$senha" Gil 11
  redefinicao "$gil" 11
  chamar PUT /user "$(json_senha "$senha")" "$SESSAO_TOKEN"
  espera_status '11: senha igual à atual' 422
  espera_erro '11: senha igual à atual' same_password
  chamar GET /user '' "$SESSAO_TOKEN"
  anota 11 "sessão do código depois do same_password, GET /user: $STATUS $(campo .error_code)"
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$SESSAO_RENOVACAO")"
  anota 11 "sessão do código depois do same_password, renovação: $STATUS $(campo .error_code)"
  sem_email "$gil" "$ASSUNTO_SENHA_TROCADA"
}

cenario_12() {  # Troca de senha sem código, por sessão com mais de 24 h
  local nova=senha-nova-da-carla
  carla_confirmada
  if [[ -n $PSQL ]]; then
    chamar POST '/token?grant_type=password' "$(json_entrada "$CARLA" "$CARLA_SENHA")"
    espera_status '12: entrada da Carla' 200
    local token
    token=$(campo .access_token)
    banco "update auth.sessions set created_at = now() - interval '25 hours'
           where user_id = '$CARLA_ID'" >/dev/null || exit 1
    chamar PUT /user "$(json_senha "$nova")" "$token"
    espera_status '12: troca por sessão de 25 h' 400
    espera_erro '12: troca por sessão de 25 h' reauthentication_needed
  else
    PULADAS=$((PULADAS + 1))
  fi

  # O caminho do app: o código de redefinição cria sessão nova, e a troca passa sem
  # reautenticação. Por isso o app não tem tela de reautenticação.
  redefinicao "$CARLA" 12
  chamar PUT /user "$(json_senha "$nova")" "$SESSAO_TOKEN"
  espera_status '12: troca pela sessão do código' 200
  CARLA_SENHA=$nova
  espera_aviso "$CARLA" "$ASSUNTO_SENHA_TROCADA"
}

# A troca de e-mail da Carla serve aos três cenários e roda uma vez só, pedida por qualquer
# um deles: sessões A e B abertas e dois aparelhos; A pede a troca para carla2.
TROCA_FEITA=0

troca_de_email() {
  ((TROCA_FEITA)) && return 0
  TROCA_FEITA=1
  local novo a renovacao_a b codigo token renovacao
  carla_confirmada
  novo=$(email_unico carla2)

  chamar POST '/token?grant_type=password' "$(json_entrada "$CARLA" "$CARLA_SENHA")"
  espera_status '13: entrada da sessão A' 200
  a=$(campo .access_token)
  renovacao_a=$(campo .refresh_token)
  chamar POST '/token?grant_type=password' "$(json_entrada "$CARLA" "$CARLA_SENHA")"
  espera_status '14: entrada da sessão B' 200
  b=$(campo .refresh_token)
  aparelhos_inventados "$CARLA_ID" 15

  chamar PUT /user "$(json_email "$novo")" "$a"
  espera_status '13: pedido da troca' 200
  espera_igual '13: e-mail da conta antes de confirmar' "$(campo .email)" "$CARLA"
  codigo=$(codigo_de "$novo" "$ASSUNTO_TROCA_EMAIL") || exit 1
  sem_email "$CARLA"
  confere_banco '15: aparelhos depois do pedido' \
    "select count(*) from public.dispositivo_push where pessoa_id = '$CARLA_ID'" 2

  # Como o `confirmarTrocaEmail` do app: o /verify devolve uma sessão nova, que o verifyOTP
  # põe no lugar da A, e é dela que sai o signOut(others).
  chamar POST /verify "$(json_codigo email_change "$novo" "$codigo")"
  espera_status '13: confirmação da troca' 200
  token=$(campo .access_token)
  renovacao=$(campo .refresh_token)
  [[ -n $token ]] || falha "13: confirmação da troca sem sessão — $RESPOSTA"
  # Só anota: diz se a troca sozinha já derruba as outras sessões, antes do logout do app.
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$b")"
  anota 14 "renovação de B depois da troca e antes do logout: $STATUS $(campo .error_code)"
  [[ $STATUS == 200 ]] && b=$(campo .refresh_token)
  chamar POST '/logout?scope=others' '' "$token"
  espera_status '13: saída das outras sessões' 204

  chamar GET /user '' "$token"
  espera_status '13: usuário da sessão do aparelho' 200
  espera_igual '13: e-mail da sessão do aparelho' "$(campo .email)" "$novo"
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$renovacao")"
  espera_status '13: renovação da sessão do aparelho' 200
  chamar POST '/token?grant_type=refresh_token' "$(json_renovacao "$renovacao_a")"
  anota 13 "renovação da sessão A, substituída no aparelho pela do código: $STATUS $(campo .error_code)"
  renovacao_recusada 'renovação de B depois do logout' "$b" 14
  confere_banco '15: aparelhos depois da confirmação' \
    "select count(*) from public.dispositivo_push where pessoa_id = '$CARLA_ID'" 0
  espera_aviso "$CARLA" "$ASSUNTO_EMAIL_TROCADO"
  CARLA=$novo
}

cenario_13() {  # Carla troca para carla2: código só no novo, aviso no antigo, logada no novo
  troca_de_email
}

cenario_14() {  # Carla com segunda sessão aberta ao trocar o e-mail
  troca_de_email
}

cenario_15() {  # Carla com aparelhos de push ao trocar o e-mail
  troca_de_email
}

cenario_16() {  # Troca para o e-mail do Bruno, que já tem conta
  carla_confirmada
  bruno_confirmado
  chamar POST '/token?grant_type=password' "$(json_entrada "$CARLA" "$CARLA_SENHA")"
  espera_status '16: entrada da Carla' 200
  chamar PUT /user "$(json_email "$BRUNO")" "$(campo .access_token)"
  espera_status '16: troca para e-mail com conta' 422
  espera_erro '16: troca para e-mail com conta' email_exists
  sem_email "$BRUNO"
  sem_email "$CARLA"
}

# Para cada modelo, a mensagem lida na rodada com o assunto exato: o título do modelo no
# corpo, que é o que prova o texto em português no lugar do padrão do Supabase, nenhuma
# variável sem preencher e, nos de código, as seis casas. Sem MAILPIT_URL, pulada.
confere_modelos() {
  if [[ -z $MAILPIT_URL ]]; then
    PULADAS=$((PULADAS + 1))
    return
  fi
  local id modelo assunto arquivo tipo titulo texto vistos=0 faltam=()
  mkdir -p "$TMP/mensagens"
  while read -r id; do
    curl -sf "$MAILPIT_URL/api/v1/message/$id" >"$TMP/mensagens/$id.json" ||
      falha "modelos: mensagem $id sumiu do Mailpit"
  done < <(sort -u "$LIDAS")

  for modelo in "${MODELOS[@]}"; do
    IFS='|' read -r assunto arquivo tipo <<<"$modelo"
    texto=$(jq -rs --arg a "$assunto" 'map(select(.Subject == $a))[0].Text // empty' \
      "$TMP/mensagens"/*.json 2>/dev/null)
    if [[ -z $texto ]]; then
      faltam+=("$assunto")
      continue
    fi
    titulo=$(sed -n 's:.*<h2>\(.*\)</h2>.*:\1:p' "$TEMPLATES/$arquivo")
    [[ -n $titulo ]] || falha "modelos: $arquivo sem <h2>"
    [[ $texto == *"$titulo"* ]] || falha "modelos: \"$assunto\" sem o título \"$titulo\" — $texto"
    [[ $texto != *'{{'* ]] || falha "modelos: \"$assunto\" com variável sem preencher — $texto"
    if [[ $tipo == código ]]; then
      grep -qE '\b[0-9]{6}\b' <<<"$texto" || falha "modelos: \"$assunto\" sem código de seis casas"
    fi
    vistos=$((vistos + 1))
  done

  # A rodada inteira passa pelos cinco; com --so, falta o que os cenários pedidos não enviam.
  if ((${#faltam[@]})); then
    [[ -n $SO ]] || falha "modelos: nenhuma mensagem lida com o assunto \"${faltam[0]}\""
    for assunto in "${faltam[@]}"; do
      anota modelos "sem mensagem nesta rodada: \"$assunto\""
    done
  fi
  echo "ok: modelos ($vistos de ${#MODELOS[@]})"
}

# Cadastro pendente do cenário 19, fora da contagem: o dono do Gmail entra pelo Google
# depois, no celular, e a senha daqui tem de deixar de valer.
impostor() {  # <gmail>
  local senha=senha-do-impostor id
  chamar POST /signup "$(json_cadastro "$1" "$senha" Impostor)"
  if [[ $STATUS == 422 && $(campo .error_code) == user_already_exists ]] ||
    [[ $STATUS == 200 && $(campo '(.identities // .user.identities) | length') == 0 ]]; then
    falha "impostor: $1 já tem conta confirmada; apague-a pelo SQL de plan-tasks/passo-3/07-e2e-local.md"
  fi
  espera_status 'impostor: cadastro' 200
  id=$(campo '.id // .user.id')
  [[ -n $id ]] || falha "impostor: cadastro sem id de usuário — $RESPOSTA"
  confere_banco 'impostor: pessoa sem a linha' \
    "select count(*) from public.pessoa where id = '$id'" 0
  echo "Impostor pendente: id $id, senha $senha"
  ((PULADAS)) && echo "Conferências puladas por falta de PSQL: $PULADAS"
  exit 0
}

[[ -n $IMPOSTOR ]] && impostor "$IMPOSTOR"

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
roda 6
roda refeito
# O 8 reenvia ao Fábio antes da confirmação que o 7 faz.
roda 8
roda 7
roda 9
roda 11
roda 12
# O 13 troca o e-mail da Carla depois de o 12 trocar a senha; o 16 usa o Bruno do 9.
roda 13
roda 14
roda 15
roda 16
# O 10 compara com o /recover de 9, 11 ou 12, e vem por último: sozinho, ele pede um
# para a Carla, que ninguém lê e que o "nada no antigo" do 13 acusaria.
roda 10

((CENARIOS)) || falha "nenhum cenário com --so ${SO:1:-1}"
confere_modelos
if [[ -s $ANOTACOES ]]; then
  echo
  echo 'Para anotar:'
  cat "$ANOTACOES"
fi
((PULADAS)) && echo "Conferências puladas por falta de PSQL ou MAILPIT_URL: $PULADAS"
echo "SUCESSO: $CENARIOS cenários"
