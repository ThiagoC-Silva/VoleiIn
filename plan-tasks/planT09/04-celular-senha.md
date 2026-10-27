# T09.4 — Celular: cadastro, entrada e redefinição

**Estado:** a fazer · **Depende de:** T09.3

## Objetivo

Os cenários 1, 2, 3, 5 e 9 da T07 no celular, com o **Gmail 1** e e-mail real: criar conta, entrar com senha e redefinir a senha.

## O que já existe

- O roteiro e o resultado local de cada cenário em [`07-e2e-local.md`](../passo-3/07-e2e-local.md).
- O app ainda não registra aparelho de push (passo 7), então o 9 não tem linhas de `dispositivo_push` para ver sumir: isso fica com o local.

## O que falta

Para cada e-mail recebido, o Thiago anota a hora do pedido e da chegada, a pasta (entrada ou spam) e se o remetente aparece como "VoleiIn".

- [ ] **1.** **[Thiago]** A2 com o Gmail 1, nome e a senha descartável. Chega "Confirme seu cadastro no VoleiIn"; A3 com o código; o início abre com "Olá, <nome>". Pelo MCP: antes do código, nenhuma `pessoa`; depois, a linha com o id de `auth.users` e o nome.
- [ ] **2.** **[Thiago]** "Sair" e entrar com e-mail e senha. Nenhum e-mail novo.
- [ ] **3.** **[Thiago]** Senha errada: "E-mail ou senha incorretos.", e a A1 continua com os campos.
- [ ] **5.** **[Thiago]** A2 de novo com o Gmail 1: "Esse e-mail já tem conta. Entre com a senha ou pelo Google.", sem e-mail. Pelo `curl` do mesmo `/signup`, anotar se o remoto responde 422 `user_already_exists`, como o local, ou 200 com usuário sem `identities`. Se for o segundo, conferir que a A2 mostra a mesma mensagem.
- [ ] **9.** Segunda sessão por `curl` (`/token?grant_type=password` com o Gmail 1), guardando o `refresh_token`. **[Thiago]** Na A1, "Esqueci a senha" → A4, com código e senha nova. Esperado:
  - o snackbar "Senha trocada. Os outros aparelhos foram desconectados." e o início;
  - chega "A senha da sua conta no VoleiIn foi trocada";
  - a renovação da segunda sessão é recusada (`refresh_token_not_found`);
  - a senha antiga dá `invalid_credentials`, e a nova entra.

  A senha nova também é descartável e dita na conversa.

## Resultado

## Pronto quando

Os cinco cenários batem com o local, ou a divergência está anotada com o `error_code`, e cada e-mail tem tempo, pasta e remetente.

## Commit

`Registra o cadastro, a entrada e a redefinição no remoto`
