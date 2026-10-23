# T07.2 — Base do script e cenários 1 a 5

**Estado:** a fazer · **Depende de:** T07.1

## Objetivo

Criar `supabase/testes/autenticacao_api.sh` com as funções de apoio e os primeiros cenários, que exercitam todas elas: cadastro, confirmação, entrada com senha e recusas.

## O que já existe

- As suítes SQL, cujo formato de saída o script imita (`FALHOU: …` e saída ≠ 0, ou `SUCESSO: N`).
- `curl` e `jq` instalados.
- O Mailpit guarda todo e-mail do Auth local. A busca é `/api/v1/search?query=to:"…" subject:"…"`, e a mensagem completa sai de `/api/v1/message/{ID}`. O código está no corpo como seis dígitos (`{{ .Token }}` dos modelos).

## O que falta

- [ ] **Parâmetros por ambiente**, com padrão para o local:
  - `AUTH_URL` (`http://127.0.0.1:54321/auth/v1`);
  - `CHAVE` (sem padrão: a chave pública de `supabase status`; sem ela, o script para com a mensagem);
  - `MAILPIT_URL` (`http://127.0.0.1:54324`; vazio pede o código no terminal, para a T09);
  - `PSQL` (`docker exec -i supabase_db_VoleiIn psql -U postgres -tA -v ON_ERROR_STOP=1`; vazio pula as conferências de banco e avisa quantas pulou);
  - `EMAIL_BASE` (`exemplo.com`).
- [ ] **Opções**: `--so <n,…>` roda só os cenários dados; `--com-expiracao` liga o de cinco minutos (T07.3); `--impostor <gmail>` (T07.5).
- [ ] **Funções de apoio**:
  - `chamar <método> <caminho> [corpo] [token]` — guarda status e JSON da resposta, com `apikey` e, quando dado, `Authorization: Bearer`;
  - `espera_status <descrição> <status>` e `espera_erro <descrição> <error_code>` — conferem a última resposta e imprimem o `error_code` real quando diverge;
  - `codigo_de <email> <assunto>` — tenta por até 10 s a mensagem mais nova que ainda não foi lida, devolve as seis casas;
  - `sem_email <email> <assunto>` — espera 5 s e confere que nada chegou;
  - `banco <sql>` — devolve o valor;
  - `email_unico <nome>` — `<nome>.<epoch>@<EMAIL_BASE>`;
  - `anota <cenário> <texto>` — o que é para anotar, não conferir (cenários 6, 11, 20), impresso num bloco no fim.
- [ ] **Uma pessoa por cenário**, para nenhum esperar os 60 s de envio de outro.
- [ ] **Cenários**:
  - **1** — Carla faz `POST /signup` com nome nos metadados; chega "Confirme seu cadastro no VoleiIn"; `pessoa` sem a linha; `POST /verify` (`type: email`) devolve sessão; `pessoa` com o id de `auth.users` e o nome "Carla".
  - **2** — `POST /token?grant_type=password` entra, e nenhum e-mail novo chega.
  - **3** — senha errada: `invalid_credentials`.
  - **4** — `/signup` com 7 caracteres: `weak_password`, e `auth.users` sem a linha.
  - **5** — `/signup` com o e-mail da Carla: `user_already_exists`, ou usuário sem `identities` (anotar qual); nenhum e-mail.
  - **e-mail inválido** — `/signup` com `carla@`: `email_address_invalid` ou `validation_failed` (anotar qual).
- [ ] Linha de comando na tabela de `supabase/CLAUDE.md`:
  `CHAVE=<chave pública> supabase/testes/autenticacao_api.sh [--so 1,2] [--com-expiracao]`.

## Resultado

_Preenchido na execução: `error_code` e status observados em cada cenário._

## Pronto quando

`supabase/testes/autenticacao_api.sh` roda contra o local e termina com `SUCESSO: 6 cenários`, e `--so 3` roda só o cenário 3. Uma conferência quebrada de propósito (status esperado errado) imprime `FALHOU` e sai com código ≠ 0.

## Commit

`Cria a base do roteiro de autenticação pela API do Auth`
