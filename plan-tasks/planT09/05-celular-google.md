# T09.5 — Celular: Google

**Estado:** feito · **Depende de:** T09.4

## Objetivo

Os cenários 17 e 18 da T07 no remoto: Google no primeiro acesso e Google numa conta que já tem senha. Confere também o `skip_nonce_check = true` do remoto (T08.6) e o SHA-1 desta máquina com o APK release.

## O que já existe

- A conta com senha do Gmail 1, da T09.4.
- O Gmail 2 sem conta no remoto (T09.1).
- No local, o primeiro login de cada Gmail mostrou a tela de consentimento do Google (T07, cenário 17). No remoto ela deve aparecer de novo para o Gmail 2, porque o cliente é o mesmo, mas o consentimento pode já estar dado: anotar o que aparecer.

## O que falta

- [x] **17.** **[Thiago]** Na A1, "Entrar com Google" → Gmail 2. Entra direto no início, com o nome da conta Google. Pelo MCP: `pessoa.nome` é o do Google, `avatar_url` nulo, `encrypted_password` nulo em `auth.users`. Nenhum e-mail.
- [x] **18.** **[Thiago]** "Sair", e "Entrar com Google" → Gmail 1. Pelo MCP: o mesmo `pessoa.id` da T09.4, e o nome continua o do cadastro. Depois de "Sair", a senha da T09.4 continua entrando.
- [x] Se o serviço recusar o token, **parar**: anotar o `error_code` e a `description`, e decidir com o Thiago (o nonce, o cliente ou a redução de código do release; ver T09.3).

## Resultado

Feito em 2026-10-27, de 23:23 a 23:28 UTC, no APK release da T09.3, com o Claude operando o celular pelo `adb`. Os dois cenários batem com o local, e o serviço aceitou o token do Google nas duas vezes: o `skip_nonce_check = true` do remoto, o SHA-1 desta máquina no APK release e a redução de código do release não atrapalharam o `google_sign_in`. A suspeita do R8 levantada na T09.3 cai.

- **Papéis dos Gmails trocados em relação à T09.1.** A conta com senha da T09.4 está no Gmail secundário, a base do `+t087`, e não no principal, como a T09.1 previa. O 17 foi feito com o Gmail que estava sem conta (o principal) e o 18 com o que tinha senha. Daqui em diante, o plano segue pelos papéis, não pela caixa: **Gmail 1** é a conta com senha e Google, e **Gmail 2** é a que só entra pelo Google, alvo do 16 na T09.6 e caixa dos endereços com `+` na T09.7 e na T09.8.
- **Sem tela de consentimento.** O seletor "Escolha uma conta / para continuar no app VoleiIn" mostrou os dois Gmails, e a escolha levou direto ao início. O consentimento já tinha sido dado aos dois Gmails no local (T07, cenário 17), e o cliente do Google é o mesmo.

| # | Observado | Contra o local | `error_code` |
| --- | --- | --- | --- |
| 17 | "Entrar com Google" → Gmail 2: "Olá, thiago silva", sem tela intermediária. `/token` com `grant_type=id_token` 200 às 23:24:21 e `user_signedup` com `provider` `google`. Pelo MCP: `pessoa` com o id de `auth.users` e o nome da conta Google, `avatar_url` nulo (os metadados trazem `avatar_url`, o gatilho não o copia), `encrypted_password` nulo, uma identidade, a `google`, e `email_confirmed_at` preenchido no mesmo instante | igual | — |
| 18 | "Sair", "Entrar com Google" → Gmail 1: "Olá, Thiago". `/token` com `id_token` 200 às 23:25:03, `login` com `provider` `google`. Pelo MCP: o mesmo `pessoa.id` da T09.4 (`f15bb82d…`), o nome continua "Thiago", e não "Thiago Carvalho da Silva" do Google, que só foi para os metadados de `auth.users`. A identidade `google` se juntou à `email`, e a senha continua gravada. Depois de "Sair", a senha nova da T09.4 entrou: `/token` com `grant_type=password` 200 às 23:28:12 | igual | — |

- **Nenhum e-mail.** As notificações do Gmail no aparelho continuam só com os três da T09.4, e os logs do Auth no intervalo só têm `/token` e `/logout`.
- **Folha "Salvar senha"** de novo na entrada com senha, fechada com voltar.
- **Sessões que ficam no remoto:** a do app no Gmail 1, além das da T09.4. O Gmail 2 saiu com "Sair" e está sem sessão. Saem com as contas na T09.9.

## Pronto quando

Os dois cenários batem com o local no APK release, sem nenhum e-mail enviado.

## Commit

`Registra a entrada pelo Google no remoto`
