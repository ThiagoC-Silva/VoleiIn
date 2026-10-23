# T07.4 — Script: redefinição e troca de senha (cenários 9 a 12)

**Estado:** a fazer · **Depende de:** T07.3

## Objetivo

Provar a cadeia que o `redefinirSenha` do app faz (`verifyOTP(recovery)` → `updateUser(password)` → `signOut(others)`): outras sessões caem, aparelhos somem pelo gatilho, chega o aviso de senha trocada (RF41, RNF07).

## O que já existe

- O gatilho `privado.apagar_dispositivos_na_troca`, que dispara na mudança de `encrypted_password`.
- `secure_password_change = true` no `config.toml`.

## O que falta

- [ ] **Cenário 9** — Bruno, confirmado como no cenário 1:
  - duas entradas por senha, que viram as sessões B e C, e o `refresh_token` de cada uma guardado;
  - duas linhas em `dispositivo_push` pelo `PSQL` (`pessoa_id`, `token_fcm` inventado);
  - `/recover` → "Seu código para redefinir a senha do VoleiIn" → `/verify` (`type: recovery`) dá a sessão A → `PUT /user` com a senha nova → `/logout?scope=others`, tudo com o token de A;
  - esperado: o refresh de B e de C é recusado (anotar o `error_code`), o de A segue; as linhas de `dispositivo_push` sumiram; chega "A senha da sua conta no VoleiIn foi trocada"; a senha antiga dá `invalid_credentials`; a nova entra.
- [ ] **Cenário 10** — `/recover` para um e-mail sem conta: mesmo status e corpo do cenário 9, e nenhum e-mail.
- [ ] **Cenário 11** — Gil: código de redefinição, depois `PUT /user` com a senha atual dá `same_password`. **Anotar** se a sessão criada no `/verify` continua de pé (`GET /user` com o token dela).
- [ ] **Cenário 12** — Carla do cenário 1:
  - envelhecer a sessão (`update auth.sessions set created_at = now() - interval '25 hours' where user_id = …`) e `PUT /user` com senha nova: `reauthentication_needed`;
  - confirmar que pelo caminho do app passa: código de redefinição, sessão nova, `PUT /user` aceito. É o que justifica o app não ter tela de reautenticação.
- [ ] Anotar se o `/recover` logo depois do cadastro esbarra nos 60 s (o limite é por tipo de e-mail ou por usuário?). O roteiro se ajusta a isso.

## Resultado

_Preenchido na execução: `error_code` do refresh recusado, comportamento do 11 e o limite de 60 s entre tipos._

## Pronto quando

`autenticacao_api.sh --so 9,10,11,12` passa.

## Commit

`Cobre a redefinição de senha no roteiro da API`
