# T05 — Tela de entrar (RF01)

**Estado:** feito · **Depende de:** T04

## Objetivo

Entrar e criar conta numa tela só (RF01, RN21, RNF06): e-mail; nome só quando o e-mail não tem conta; código de seis dígitos com reenvio depois de 60 s. Sem especificação de tela: o design será refeito depois.

## O que já existe

- `app/lib/dados/auth_repositorio.dart` — `pedirCodigo` (`signInWithOtp(shouldCreateUser: false)`, devolve `false` em `otp_disabled`), `criarConta` (`shouldCreateUser: true`, `data: {'nome': ...}`), `confirmarCodigo` (`verifyOTP(type: email)`), `sair`, e `_traduzir`, que converte o código de erro do Auth em mensagem em português.
- `app/lib/features/auth/entrar_tela.dart` — etapas `email → nome → codigo`, voltar para trocar o e-mail.
- `app/lib/features/auth/etapa_codigo.dart` — campo de código e contagem de 60 s para o reenvio, reaproveitado na T06.
- `app/test/features/auth/entrar_tela_test.dart` — 4 testes, passando.

Tudo commitado em `a9a99cf`.

## O que falta

- [x] Teste de widget para o botão de voltar (da etapa de código para a de e-mail).
- [x] Teste de widget para conta nova: o reenvio chama `criarConta` de novo, não `pedirCodigo`.
- [ ] Conferir em `_traduzir` os códigos de erro que o Auth local devolve de fato: `otp_disabled`, `otp_expired`, `over_email_send_rate_limit`, `over_request_rate_limit`, `email_address_invalid`/`validation_failed`. Ajustar o que vier diferente. Fica para a T07, que já carrega esse roteiro — não bloqueia o fechamento desta task.

## Pronto quando

`cd app && flutter test` passa, com os testes novos. **Feito.**

## Commit

A tela já entrou em `a9a99cf`. O resto, em `Cobre o voltar e o reenvio de conta nova na tela de entrar` — inclui a extração do fake de autenticação para `app/test/auth_falso.dart`, reaproveitado pela T06.
