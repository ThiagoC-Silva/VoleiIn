# T09.4 — Celular: cadastro, entrada e redefinição

**Estado:** feito · **Depende de:** T09.3

## Objetivo

Os cenários 1, 2, 3, 5 e 9 da T07 no celular, com o **Gmail 1** e e-mail real: criar conta, entrar com senha e redefinir a senha.

## O que já existe

- O roteiro e o resultado local de cada cenário em [`07-e2e-local.md`](../passo-3/07-e2e-local.md).
- O app ainda não registra aparelho de push (passo 7), então o 9 não tem linhas de `dispositivo_push` para ver sumir: isso fica com o local.

## O que falta

Para cada e-mail recebido, o Thiago anota a hora do pedido e da chegada, a pasta (entrada ou spam) e se o remetente aparece como "VoleiIn".

- [x] **1.** **[Thiago]** A2 com o Gmail 1, nome e a senha descartável. Chega "Confirme seu cadastro no VoleiIn"; A3 com o código; o início abre com "Olá, <nome>". Pelo MCP: antes do código, nenhuma `pessoa`; depois, a linha com o id de `auth.users` e o nome.
- [x] **2.** **[Thiago]** "Sair" e entrar com e-mail e senha. Nenhum e-mail novo.
- [x] **3.** **[Thiago]** Senha errada: "E-mail ou senha incorretos.", e a A1 continua com os campos.
- [x] **5.** **[Thiago]** A2 de novo com o Gmail 1: "Esse e-mail já tem conta. Entre com a senha ou pelo Google.", sem e-mail. Pelo `curl` do mesmo `/signup`, anotar se o remoto responde 422 `user_already_exists`, como o local, ou 200 com usuário sem `identities`. Se for o segundo, conferir que a A2 mostra a mesma mensagem.
- [x] **9.** Segunda sessão por `curl` (`/token?grant_type=password` com o Gmail 1), guardando o `refresh_token`. **[Thiago]** Na A1, "Esqueci a senha" → A4, com código e senha nova. Esperado:
  - o snackbar "Senha trocada. Os outros aparelhos foram desconectados." e o início;
  - chega "A senha da sua conta no VoleiIn foi trocada";
  - a renovação da segunda sessão é recusada (`refresh_token_not_found`);
  - a senha antiga dá `invalid_credentials`, e a nova entra.

  A senha nova também é descartável e dita na conversa.

## Resultado

Feito em 2026-10-27, de 22:56 a 23:05 UTC, no APK release da T09.3. Os cinco cenários batem com o local.

- **Quem operou o celular:** o Claude, pelo `adb` (`input tap`/`text`, `uiautomator dump`, `screencap`), a pedido do Thiago, e não o Thiago com o dedo, como previa o README. Os códigos foram lidos das notificações do Gmail no aparelho (`dumpsys notification --noredact`), que trazem o corpo do e-mail, sem abrir a caixa de entrada.
- **Senhas:** a descartável da T09.1 no cadastro; a nova do 9, também descartável, dita na conversa. É ela que vale para a T09.5.

| # | Observado | Contra o local | `error_code` |
| --- | --- | --- | --- |
| 1 | `/signup` às 22:58:57. Antes do código, `auth.users` com `email_confirmed_at` nulo, uma identidade e o nome nos metadados, e nenhuma `pessoa`. Depois, A3 → "Olá, Thiago", e `pessoa` com o id de `auth.users`, nome "Thiago" e `avatar_url` nulo | igual | — |
| 2 | "Sair", entrada com e-mail e senha, o início. Nenhum e-mail novo em 15 s | igual | — |
| 3 | "E-mail ou senha incorretos." acima do "Entrar", a A1 com os dois campos preenchidos | igual | `invalid_credentials` |
| 5 | A2: "Esse e-mail já tem conta. Entre com a senha ou pelo Google.", sem e-mail. O `curl` do `/signup`: 422. O remoto **não** esconde a conta com usuário sem `identities` | igual | `user_already_exists` |
| 9 | Segunda sessão por `curl`, renovada uma vez antes. A4 com o código e a senha nova: o início logado. Depois, a renovação da segunda sessão dá 400, a senha antiga dá 400, e a nova entra com 200. Nos logs do Auth, `PUT /user` 200 e `/logout` 204 às 23:03:55 | igual | `refresh_token_not_found`, `invalid_credentials` |

**E-mails**, os três na caixa de entrada principal do Gmail, com o remetente "VoleiIn" `<nao-responda@mail.voleiin.com.br>`:

| E-mail | Pedido (UTC) | Chegada (UTC) | Pasta |
| --- | --- | --- | --- |
| "Confirme seu cadastro no VoleiIn" | 22:58:57 | 22:59:03 (6 s) | entrada |
| "Seu código para redefinir a senha do VoleiIn" | 23:03:05 | 23:03:08 (3 s) | entrada |
| "A senha da sua conta no VoleiIn foi trocada" | 23:03:55 | 23:03 (sem segundos) | entrada |

- **O aviso de senha trocada não gerou notificação no celular**, e os dois códigos geraram (`GMAIL_IMPORTANT_EMAIL`). O Thiago o achou na caixa de entrada principal, com a hora 20:03 de Brasília. Fica anotado como critério do Gmail sobre o que notifica, não como problema de entrega.
- **Snackbar do 9 não visto.** A folha "Salvar senha em Gerenciador de Senhas do Google?" do Android cobriu a tela logo depois do toque em "Salvar nova senha", e o snackbar acabou antes de ela ser fechada. A A4 só mostra o snackbar e volta ao início quando a gravação dá certo (`redefinir_senha_tela.dart`), e os logs mostram o `PUT /user` com 200 seguido do `/logout` das outras sessões com 204. O texto não mudou desde a T07, que o viu. Não repetido, para não gastar mais dois e-mails.
- **`same_password` às 22:59:55**, logo depois do `/verify` do cadastro: é a A3 aberta pela A2 gravando a senha digitada (T13), que é a mesma da conta. O app o ignora, como previsto.
- **Folha "Salvar senha" do Google** a cada entrada com senha bem-sucedida. Ao operar pelo `adb`, fechar com "voltar" ou "Agora não", nunca com "Nunca", que marcaria o app para sempre no gerenciador do Thiago.
- **Sessões que ficam no remoto:** a do app e a do `curl` da senha nova. Saem com a conta na T09.9.

## Pronto quando

Os cinco cenários batem com o local, ou a divergência está anotada com o `error_code`, e cada e-mail tem tempo, pasta e remetente.

## Commit

`Registra o cadastro, a entrada e a redefinição no remoto`
