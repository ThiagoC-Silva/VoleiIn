# 0017. Código de 6 dígitos por e-mail no lugar de link

- **Status:** Aceito
- **Data:** 2026-11-12

## Contexto
Três fluxos de conta dependem de um e-mail: a confirmação do cadastro (RF02), a recuperação de senha (RF06) e a troca de e-mail (RF106). Os requisitos diziam "por link", mas nenhum documento dizia para onde o link leva. Um link do Supabase Auth precisa de um destino que conclua o fluxo: ou um App Link que abra o app, que só existe na fatia 8 (ADR 0008), ou uma página web, que o projeto não tem. Na recuperação de senha, a página web teria também de receber a senha nova, porque o fluxo terminaria no navegador, e não no app. O v0 usava código nos três fluxos.

## Decisão
Os três e-mails trazem um **código de 6 dígitos**, que a pessoa digita no app. O app confirma com `verifyOTP` do Supabase Auth, nos tipos `email` (cadastro), `recovery` (senha) e `email_change` (troca de e-mail). O código vale por 1 hora (`otp_expiry = 3600`). Os modelos dos e-mails usam `{{ .Token }}` no lugar de `{{ .ConfirmationURL }}`. Decisão do responsável em 12/11/2026.

## Alternativas descartadas
- **Link com App Link:** antecipa da fatia 8 a página no Cloudflare Pages e o `assetlinks.json`. Também não funciona quando o e-mail é aberto no computador.
- **Link com página web:** exige uma página nova, e a troca de senha passaria a acontecer no navegador.

## Consequências
- RF02, RF06 e RF106 passam a dizer "por código".
- Não há *deep link* de autenticação. O único *deep link* do app continua sendo o convite (fatia 8).
- O app precisa guardar, em memória, o e-mail do código pendente (`arquitetura-app.md`, seção 9), porque a rota leva só ID ou código.
- O limite de envio de e-mails do Supabase Auth vale também para o "Reenviar código".
