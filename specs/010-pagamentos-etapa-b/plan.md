# Implementation Plan: Pagamentos, etapa B (fatia 6)

**Branch**: `fatia-6/servidor-b` e `fatia-6/app-b` | **Date**: 2026-11-25 | **Spec**: [spec.md](./spec.md)

## Summary

Duas migrações: `receipts_rls` (auxiliares, leitura de `receipts`, bucket e índice de `storage_path`, research R6) e `create_receipt_functions` (`record_receipt` e `review_receipt`, research R1 a R5). A Edge Function `process-receipt`, com o prompt, o schema, a normalização e o dublê da Claude API (R7 a R9). O conjunto fixo CF01 a CF26 e a `deno task receipts:live` (R10), a medição dos três modelos (R11) e o seed (R12). No app (sessão 3): as telas da seção 9 do `docs/ui/telas.md` que envolvem comprovante.

## Technical Context

Igual ao das etapas anteriores, mais o `npm:@anthropic-ai/sdk` com versão exata no `deno.json` e o Pillow no `scripts/receipt-fixtures.py`. Testes:
- pgTAP: CP01 a CP24 e RV01 a RV06 em `receipt_rules.test.sql`; RS01 a RS05 e RS09 em `receipt_security.test.sql`; B03, B04, B06 e B10 em `base_security.test.sql`.
- Deno: PR01 a PR10 e CF01 a CF26 em `process-receipt/index_test.ts`; NM01 a NM05 em `process-receipt/normalize_test.ts`; RS06 a RS08 em `_tests/receipts_test.ts`; C10 a C12 e C18 em `_tests/concurrency/payments_test.ts`.

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa: as escolhas de R1 a R12 só interpretam os documentos, sem mudar resultado esperado |
| II. Uma fatia por vez | Passa: retenção e exclusão de conta ficam na etapa C |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa: a RN88 roda no SQL, e o modelo só extrai (ADR 0019) |
| V. Produção | Passa: com o ensaio, na sessão 4 |

## Complexity Tracking

Sem violações.
