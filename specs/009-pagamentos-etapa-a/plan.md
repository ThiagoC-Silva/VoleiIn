# Implementation Plan: Pagamentos, etapa A (fatia 6)

**Branch**: `fatia-6/servidor-a` e `fatia-6/app-a` | **Date**: 2026-11-24 | **Spec**: [spec.md](./spec.md)

## Summary

Uma migração, `create_manual_payment`, com `private.lock_charge`, `public.mark_charge_paid` e `public.revert_charge` (research R1 a R5). Nenhuma política muda: `charges` e `charge_events` já têm as da fatia 5. O seed ganha um valor Pago (R6). No app (sessão 3): valor a pagar e ações no Rateio (`docs/ui/telas.md`, seção 9).

## Technical Context

Igual ao das etapas da fatia 5. Testes: PG01 a PG07 em `payment_functions.test.sql`; B06 em `base_security.test.sql`; C09 em `concurrency/payments_test.ts`.

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa: a lacuna da RN85 foi decidida pelo responsável (R4) e escrita nos documentos, sem mudar resultado esperado |
| II. Uma fatia por vez | Passa: comprovantes e conta excluída ficam nas etapas B e C |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa: o app chama as funções e relê |
| V. Produção | Passa: com o ensaio, na sessão 4 |

## Complexity Tracking

Sem violações.
