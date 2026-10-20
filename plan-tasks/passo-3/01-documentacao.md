# T01 — Fechar a documentação de autenticação

**Estado:** feito · **Depende de:** —

## Objetivo

Deixar os documentos normativos coerentes com o que o passo 3 entrega, antes de commitar código: acesso por e-mail e senha ou Google (RF01, RF41, RN21), troca de e-mail confirmada só no endereço novo, com aviso ao antigo (RN21, RNF07), e `minSdk` 24.

## Reaberta em 2026-10-20 — senha e Google

O acesso deixou de ser por código a cada entrada (ver as decisões no [README](README.md)). Fechada no mesmo dia, antes de qualquer código, em `84f20aa`:

- [x] `docs/prd.md`:
  - escopo;
  - RF01 reescrito e RF41 novo, com a contagem de requisitos;
  - RN21, RNF01, RNF06 e RNF07;
  - parágrafo de DispositivoPush (três casos de revogação);
  - decisões Código por e-mail, Credencial, Cadastro com senha e Troca de senha;
  - WhatsApp em Fora do MVP.
- [x] `docs/modelo-de-dados.md`: convenção da credencial e invariante de DispositivoPush com a troca de senha.
- [x] `docs/stack.md`:
  - Escolhas (Autenticação, Login Google) e o `google_sign_in` nos pacotes;
  - seção Autenticação reescrita;
  - passo 3 na ordem de implementação;
  - riscos do SHA-1 e da tela de consentimento.
- [x] `grep -rn "otp_disabled\|codigo_acesso\|código de acesso\|dois casos de revogação" docs/` não acha nada. O único `signInWithOtp` é o parágrafo que registra a entrada por código como aberta e sem uso.

`CLAUDE.md` da raiz e `supabase/CLAUDE.md` mudam junto com o código que os torna verdade: T03, T04 e T11.

## O que já existe

Commitado em `9814aa7` (troca de e-mail) e `c550444` (minSdk):
- `docs/prd.md` — RN21 e RNF07 reescritas para "código ao endereço novo, aviso ao antigo"; nova linha "Troca de e-mail" na tabela de decisões.
- `docs/stack.md`, seção Autenticação — `double_confirm_changes = false`, `notification.email_changed`, explicação de por que a confirmação dupla não adiantaria no fluxo por código.

## O que falta

- [x] Revisar o diff de `docs/prd.md` e `docs/stack.md` (`git diff docs/`).
- [x] `docs/stack.md`, tabela Escolhas: `minSdk` 23 → 24.
- [x] `app/CLAUDE.md`: `minSdk` 23 → 24.
- [x] Conferir que `docs/modelo-de-dados.md` não cita confirmação nos dois endereços (`grep -n "dois endereços" docs/`).

## Pronto quando

- `grep -rn "minSdk" docs/ app/CLAUDE.md` mostra só 24.
- `grep -rn "dois endereços\|confirmação dupla" docs/` não acha regra contrária ao fluxo de código só no endereço novo.

## Commit

Feito em `9814aa7` e `c550444`; a reabertura, em `84f20aa`.
