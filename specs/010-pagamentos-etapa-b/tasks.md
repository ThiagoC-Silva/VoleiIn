# Tasks: Pagamentos, etapa B (fatia 6)

**Input**: `specs/010-pagamentos-etapa-b/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 8 e 14, linha B, e da seção 7 do `docs/comprovantes-ia.md`.

## Sessão 2 — Servidor

- [ ] T001 [P] B03, B04, B06 e B10 com as linhas da etapa B
- [ ] T002 [P] [US1] CP01 a CP24 em `receipt_rules.test.sql`
- [ ] T003 [P] [US2] RV01 a RV06 em `receipt_rules.test.sql`
- [ ] T004 [P] [US3] RS01 a RS05 e RS09 em `receipt_security.test.sql`; RS06 a RS08 em `_tests/receipts_test.ts`
- [ ] T005 [P] [US1] NM01 a NM05 em `process-receipt/normalize_test.ts`
- [ ] T006 [US1] `scripts/receipt-fixtures.py` e os arquivos de CF01 a CF26 (research R10)
- [ ] T007 [US1] PR01 a PR10 e CF01 a CF26 em `process-receipt/index_test.ts`, com o dublê da Claude API
- [ ] T008 [P] [US1, US2] C10 a C12 e C18 em `concurrency/payments_test.ts`
- [ ] T009 Saída da falha e *commit* só de testes
- [ ] T010 Migração `receipts_rls` (research R6)
- [ ] T011 Migração `create_receipt_functions` (research R1 a R5)
- [ ] T012 `process-receipt`: prompt, schema, normalização, handler e `index.ts` (research R7 a R9)
- [ ] T013 Seed com o jogo de comprovantes (research R12)
- [ ] T014 `deno task receipts:live` e a medição dos três modelos, com o OK do responsável para o gasto (research R11)
- [ ] T015 Comandos verdes, documentos e PR

## Sessão 3 — App

Precisa dos PNGs de comprovante em `docs/ui/referencias/fatia-6/`.

- [ ] T016 Testes antes: U14, S77 a S83, S84 (**Conferir comprovante**), S85 (**Para conferir**), S88, S89, E15, L24, L25
- [ ] T017 Telas de comprovante (`docs/ui/telas.md`, seção 9)
- [ ] T018 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T019 L24 e L25 nas APIs 29 e 36
- [ ] T020 M09 com a API real e o build da produção
- [ ] T021 Chave `voleiin-prod`, `RECEIPT_MODEL` na produção, ensaio, `supabase db push`, deploy da `process-receipt`; advisors
