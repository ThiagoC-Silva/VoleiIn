# T07.11 — Registro dos resultados e fechamento da T07

**Estado:** feito · **Depende de:** T07.10

## Objetivo

Consolidar em `plan-tasks/passo-3/` o que as tasks T07.2 a T07.10 anotaram, fechar a T07 e deixar a T08 pronta para começar.

## O que já existe

O "Resultado" preenchido em cada task desta pasta.

## O que falta

- [x] `plan-tasks/passo-3/07-e2e-local.md`:
  - uma seção "Resultado" com os 22 cenários, trilho, esperado e observado, e o `error_code` real de cada recusa;
  - estado "feito".
- [x] "Anotar para a T10" em `07-e2e-local.md`, pronto para a `10-fechamento.md` usar:
  - os códigos reais e as correções do `_traduzir` (T07.6);
  - o comportamento dos cenários 6, 11 e 20, que vai para "Decisões de implementação" do `progresso.md`;
  - o segundo cadastro pendente do cenário 6 (vale o nome e a senha do primeiro, sem aviso; ver [T07.8](08-celular-senha.md)) é **decisão de produto aberta**: levar ao Thiago com as opções e registrar o que ele decidir, não só o comportamento;
  - o teclado e o colar (T07.7);
  - o cenário 22 (T07.10);
  - que o local não tem limite de e-mails (`GOTRUE_RATE_LIMIT_EMAIL_SENT=360000` sem SMTP próprio, T07.6).
- [x] `plan-tasks/passo-3/09-e2e-remoto.md`: levar o que o local não respondeu e o remoto pode responder diferente (usuário sem `identities` no cadastro repetido, `email_address_invalid`, o teto de 30 e-mails por hora, tempo e destino dos e-mails).
- [x] `plan-tasks/passo-3/README.md`: T07 "feito".
- [x] Esta pasta: todas as tasks "feito" no [README](README.md).
- [x] Se o Gboard do celular ficou em modo de teclado físico, avisar o Thiago de como voltar (T07.7).
- [x] As três suítes SQL, `flutter test` e `dart analyze` passam; `git status` limpo depois do commit.

## Resultado

Executado em 2026-10-26.

- `07-e2e-local.md` ficou "feito", com a seção "Resultado" (os 22 cenários e o e-mail inválido, cada um com trilho, observado, comparação com o esperado e `error_code`) e "Anotar para a T10" reescrita com o que a T10 leva ao `progresso.md`.
- **Cadastro refeito (cenário 6), levado ao Thiago.** Antes de perguntar, uma sonda pela API local (fora do commit) mostrou que o caso não é só confusão de quem recadastra:
  - o "impostor" cadastra um e-mail e não confirma; depois de 60 s, a dona cadastra o mesmo e-mail com outra senha e confirma pelo código;
  - a conta nasce com o nome "Impostor", a senha do impostor entra e a da dona dá `invalid_credentials`;
  - gravar a senha da dona por `PUT /user` com a sessão do `/verify` resolve: a do impostor passa a ser recusada, e chega o aviso de senha trocada;
  - com a senha que já vale, a resposta é 422 `same_password`;
  - pela A1 o buraco não existe, porque com a senha errada um cadastro pendente responde `invalid_credentials`, não `email_not_confirmed`.
- **Decisão do Thiago:** depois do código de um cadastro vindo da A2, o app grava a senha e o nome digitados. As alternativas eram só registrar o risco ou apagar os pendentes antigos por `pg_cron`, que não fecha o buraco. A decisão está registrada em `docs/prd.md` (RN21 e "Cadastro com senha"), em `docs/stack.md` (Autenticação) e no README do passo 3. A implementação virou a [T13](../passo-3/13-cadastro-refeito.md), antes da T08, e a T09 passou a depender dela.
- `09-e2e-remoto.md` ganhou o que o local não respondeu: o usuário sem `identities`, o `email_address_invalid`, o teto de 30 e-mails por hora (com o gasto de 16 da rodada inteira) e o script sem `MAILPIT_URL`. Também ganhou o cadastro refeito entre os cenários a repetir.
- **Gboard:** `show_ime_with_hard_keyboard` continua `0`, o mesmo valor de antes das teclas injetadas (T07.7), e a T07.8 viu o teclado na tela até o fim. Não ficou em modo de teclado físico, e não há o que avisar.
- Suítes SQL: schema 61, rls 69, autenticacao 36. `dart analyze` sem problemas; `flutter test` com 31 testes.

## Pronto quando

A T07 está "feito" no README do passo 3, cada cenário tem resultado anotado, e a T08 pode começar sem reler esta pasta.

## Commit

`Registra a validação local da autenticação`
