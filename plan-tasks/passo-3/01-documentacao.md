# T01 — Fechar a documentação de autenticação

**Estado:** feito · **Depende de:** —

## Objetivo

Deixar os documentos normativos coerentes com o que o passo 3 entrega, antes de commitar código: troca de e-mail confirmada só no endereço novo, com aviso ao antigo (RN21, RNF07), e `minSdk` 24.

## O que já existe

Alterações não commitadas:
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

`Fecha a troca de e-mail por código no endereço novo e o minSdk 24`
