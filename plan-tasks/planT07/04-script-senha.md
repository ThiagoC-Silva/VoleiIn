# T07.4 — Script: redefinição e troca de senha (cenários 9 a 12)

**Estado:** feito · **Depende de:** T07.3

## Objetivo

Provar a cadeia que o `redefinirSenha` do app faz (`verifyOTP(recovery)` → `updateUser(password)` → `signOut(others)`): outras sessões caem, aparelhos somem pelo gatilho, chega o aviso de senha trocada (RF41, RNF07).

## O que já existe

- O gatilho `privado.apagar_dispositivos_na_troca`, que dispara na mudança de `encrypted_password`.
- `secure_password_change = true` no `config.toml`.

## O que falta

- [x] **Cenário 9** — Bruno, confirmado como no cenário 1:
  - duas entradas por senha, que viram as sessões B e C, e o `refresh_token` de cada uma guardado;
  - duas linhas em `dispositivo_push` pelo `PSQL` (`pessoa_id`, `token_fcm` inventado);
  - `/recover` → "Seu código para redefinir a senha do VoleiIn" → `/verify` (`type: recovery`) dá a sessão A → `PUT /user` com a senha nova → `/logout?scope=others`, tudo com o token de A;
  - esperado: o refresh de B e de C é recusado (anotar o `error_code`), o de A segue; as linhas de `dispositivo_push` sumiram; chega "A senha da sua conta no VoleiIn foi trocada"; a senha antiga dá `invalid_credentials`; a nova entra.
- [x] **Cenário 10** — `/recover` para um e-mail sem conta: mesmo status e corpo do cenário 9, e nenhum e-mail.
- [x] **Cenário 11** — Gil: código de redefinição, depois `PUT /user` com a senha atual dá `same_password`. **Anotar** se a sessão criada no `/verify` continua de pé (`GET /user` com o token dela).
- [x] **Cenário 12** — Carla do cenário 1:
  - envelhecer a sessão (`update auth.sessions set created_at = now() - interval '25 hours' where user_id = …`) e `PUT /user` com senha nova: `reauthentication_needed`;
  - confirmar que pelo caminho do app passa: código de redefinição, sessão nova, `PUT /user` aceito. É o que justifica o app não ter tela de reautenticação.
- [x] Anotar se o `/recover` logo depois do cadastro esbarra nos 60 s (o limite é por tipo de e-mail ou por usuário?). O roteiro se ajusta a isso.

## Resultado

Rodada contra o local em 2026-10-23, Auth v2.197.0:

| Cenário | Observado |
| --- | --- |
| 9 | "Seu código para redefinir a senha do VoleiIn" chega; `/verify` (`type: recovery`) 200 com a sessão A; `PUT /user` 200; `/logout?scope=others` 204. Renovação de B e de C: 400 `refresh_token_not_found`; a de A, 200. As duas linhas de `dispositivo_push` somem. Chega "A senha da sua conta no VoleiIn foi trocada". Senha antiga: 400 `invalid_credentials`; a nova entra |
| 10 | `/recover` para e-mail sem conta: 200 `{}`, igual ao de e-mail com conta; nenhum e-mail em 5 s |
| 11 | `PUT /user` com a senha atual: 422 `same_password`. A sessão criada no `/verify` **continua de pé**: `GET /user` 200 e a renovação 200. Nenhum aviso de senha trocada |
| 12 | Com `auth.sessions.created_at` 25 h atrás, `PUT /user`: 400 `reauthentication_needed`. Pelo caminho do app (código de redefinição, sessão nova, `PUT /user`): 200, e chega o aviso |
| limite de 60 s | É **por tipo de e-mail**, não por usuário: o `/recover` logo depois da confirmação do cadastro dá 200 e o e-mail chega; um segundo `/recover` logo em seguida dá 429 `over_email_send_rate_limit`. O roteiro não precisa esperar entre o cadastro e a redefinição |

- **A troca da senha sozinha já derruba as outras sessões**: a renovação de C, feita entre o `PUT /user` e o `/logout?scope=others`, já deu 400 `refresh_token_not_found`. O `signOut(others)` do `redefinirSenha` fica redundante, sem prejuízo; não mexi no app.
- **Para a T07.6 e a T07.8**, efeito do 11 no app: a sessão nasce no `verifyOTP`, antes do `updateUser`, e `app/lib/core/rotas.dart:17` troca a A1 pelo início assim que há sessão. Quem digita na redefinição a mesma senha que já tem provavelmente entra no app sem ver "A senha nova precisa ser diferente da atual." — e entra com a senha que digitou, que continua valendo. Não é decisão desta task; conferir no celular.
- `cadastro_confirmado`, `redefinicao` e `renovacao_recusada` são novas funções de apoio; `codigo_de` passou a usar `chegou`, que também serve a `espera_aviso` (aviso sem código).
- Ordem: 9, 11, 12 e por último o 10, que compara com o `/recover` mais recente da rodada; com `--so 10` sozinho, pede um para a Carla (conferido: `SUCESSO: 1 cenários`).
- O 12 troca a senha da Carla e atualiza `CARLA_SENHA`; quem usar a Carla depois dele na rodada (T07.5) entra com a nova. Sem `PSQL`, a parte da sessão envelhecida conta como pulada.
- E-mails: `--so 9,10,11,12` gasta 8 (Carla 1 + 2, Bruno 3, Gil 2) e leva cerca de 15 s. A rodada inteira até aqui gasta 14 (7 da T07.3 mais 7, com o cadastro da Carla contado uma vez), já no teto da estimativa de 13 a 15; a T07.5 vai passar dela, e a T07.6 precisa refazer a conta contra os 30 por hora. Esta task gastou 12 na hora, com a sonda.

## Pronto quando

`autenticacao_api.sh --so 9,10,11,12` passa.

## Commit

`Cobre a redefinição de senha no roteiro da API`
