# Tasks: Pagamentos, etapa A (fatia 6)

**Input**: `specs/009-pagamentos-etapa-a/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 8 e 14, linha A.

## Sessão 2 — Servidor

- [ ] T001 [P] B06 com `mark_charge_paid(uuid)` e `revert_charge(uuid)`
- [ ] T002 [P] [US1] PG01 a PG03 em `payment_functions.test.sql`
- [ ] T003 [P] [US2] PG04 a PG07 em `payment_functions.test.sql`
- [ ] T004 [P] [US1] C09 em `concurrency/payments_test.ts`
- [ ] T005 Saída da falha e *commit* só de testes
- [ ] T006 Migração `create_manual_payment` (research R1 a R5)
- [ ] T007 Seed com o valor Pago da Carla (R6)
- [ ] T008 Comandos verdes, documentos e PR

## Sessão 3 — App

Precisa do `charge.png` em `docs/ui/referencias/fatia-6/`.

- [ ] T009 Testes antes: S77 (sem comprovantes), S84, S85 (sem **Para conferir**), S88, S89, E15, L23
- [ ] T010 Valor a pagar e ações no Rateio (`docs/ui/telas.md`, seção 9)
- [ ] T011 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T012 L23 nas APIs 29 e 36
- [ ] T013 Ensaio e `supabase db push`; advisors
