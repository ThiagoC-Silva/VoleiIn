# T11 — Projeto no Google Cloud e provedor Google local

**Estado:** parcial ·  **Depende de:** T01

## Objetivo

Ter o cliente OAuth do Google que o app (T04) e o Supabase Auth local (T07) usam para a entrada pelo Google (RF01, RN21), sem custo. O desenho está em `docs/stack.md`, Autenticação.

Os itens marcados **[Thiago]** exigem conta e painel e são feitos à mão.

## O que falta

### Google Cloud

- [x] **[Thiago]** Projeto no Google Cloud. De preferência, já o projeto do Firebase que o passo 7 vai usar para a FCM: todo projeto Firebase é um projeto do Google Cloud, e assim login e push não ficam em dois projetos.
- [x] **[Thiago]** Tela de consentimento:
  - tipo externo;
  - nome "VoleiIn" e e-mail de suporte;
  - escopos `openid`, `email` e `profile`;
  - [ ] **em teste**, com o Gmail do Thiago e o Gmail de teste da T07 em "Usuários de teste". Publicar exige página inicial e Política de Privacidade, que ficam para o passo 10 (decisão de 2026-10-20 no [README](README.md)).
- [x] **[Thiago]** Cliente OAuth **web**. Guardar:
  - o ID, que vai no `config.toml` abaixo e no `--dart-define` da T04;
  - o segredo, que vai só em `supabase/.env` e, na T08, no painel do Supabase.
- [x] **[Thiago]** Cliente OAuth **Android**:
  - pacote `br.com.voleiin`;
  - SHA-1 da chave de debug desta máquina: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`;
  - repetir na outra máquina, com o SHA-1 dela: um cliente Android por SHA-1, todos no mesmo projeto do cliente web.

### Supabase local

- [x] `supabase/config.toml`:

  ```toml
  # Entrada pelo Google, por ID token (RN21). O segredo fica em supabase/.env, fora do git.
  [auth.external.google]
  enabled = true
  client_id = "<id do cliente web>"
  secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"
  skip_nonce_check = true
  ```

  `skip_nonce_check` é o que o CLI pede para o Google no local; para o remoto, decide-se na T08.
- [x] `supabase/.env` com `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...`, fora do git. O `.env` do `.gitignore` da raiz já cobre; conferir com `git check-ignore supabase/.env`.
- [x] `supabase/CLAUDE.md`: o segredo do Google mora em `supabase/.env`, que o CLI lê no `supabase start`. Quem clona o repositório cria o seu.
- [x] `supabase stop && supabase start` e conferir no `docker inspect supabase_auth_VoleiIn` o provedor Google ligado, com o `client_id` certo.

## Conferido em 2026-10-20

- O Google recusou publicar a tela de consentimento sem página inicial e Política de Privacidade; ela fica em teste até o passo 10 (ver o [README](README.md)).
- Depois de `supabase stop && supabase start`, o `docker inspect supabase_auth_VoleiIn` mostra `GOTRUE_EXTERNAL_GOOGLE_ENABLED=true`, o `client_id` do cliente web, o segredo preenchido e `SKIP_NONCE_CHECK=true`. O `/auth/v1/settings` responde `google: true`.
- `git check-ignore supabase/.env` confirma o arquivo fora do git.
- As três suítes seguem passando: schema 61, rls 69, autenticacao 36.

Faltam só as confirmações do Thiago: as duas contas em "Usuários de teste". O cliente Android desta máquina foi criado. Elas não travam a T04 nem a T05; travam o primeiro login real pelo Google, na T07.

## Pronto quando

- O Auth local sobe com o provedor Google ligado.
- `git status` não mostra `supabase/.env`.

## Commit

`Liga o provedor Google no Supabase local`
