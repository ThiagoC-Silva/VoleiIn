# T09.5 — Celular: Google

**Estado:** a fazer · **Depende de:** T09.4

## Objetivo

Os cenários 17 e 18 da T07 no remoto: Google no primeiro acesso e Google numa conta que já tem senha. Confere também o `skip_nonce_check = true` do remoto (T08.6) e o SHA-1 desta máquina com o APK release.

## O que já existe

- A conta com senha do Gmail 1, da T09.4.
- O Gmail 2 sem conta no remoto (T09.1).
- No local, o primeiro login de cada Gmail mostrou a tela de consentimento do Google (T07, cenário 17). No remoto ela deve aparecer de novo para o Gmail 2, porque o cliente é o mesmo, mas o consentimento pode já estar dado: anotar o que aparecer.

## O que falta

- [ ] **17.** **[Thiago]** Na A1, "Entrar com Google" → Gmail 2. Entra direto no início, com o nome da conta Google. Pelo MCP: `pessoa.nome` é o do Google, `avatar_url` nulo, `encrypted_password` nulo em `auth.users`. Nenhum e-mail.
- [ ] **18.** **[Thiago]** "Sair", e "Entrar com Google" → Gmail 1. Pelo MCP: o mesmo `pessoa.id` da T09.4, e o nome continua o do cadastro. Depois de "Sair", a senha da T09.4 continua entrando.
- [ ] Se o serviço recusar o token, **parar**: anotar o `error_code` e a `description`, e decidir com o Thiago (o nonce, o cliente ou a redução de código do release; ver T09.3).

## Resultado

## Pronto quando

Os dois cenários batem com o local no APK release, sem nenhum e-mail enviado.

## Commit

`Registra a entrada pelo Google no remoto`
