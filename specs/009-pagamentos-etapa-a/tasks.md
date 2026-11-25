# Tasks: Pagamentos, etapa A (fatia 6)

**Input**: `specs/009-pagamentos-etapa-a/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 8 e 14, linha A.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `mark_charge_paid(uuid)` e `revert_charge(uuid)`
- [x] T002 [P] [US1] PG01 a PG03 em `payment_functions.test.sql`
- [x] T003 [P] [US2] PG04 a PG07 em `payment_functions.test.sql`
- [x] T004 [P] [US1] C09 em `concurrency/payments_test.ts`
- [x] T005 Saída da falha e *commit* só de testes
- [x] T006 Migração `create_manual_payment` (research R1 a R5)
- [x] T007 Seed com o valor Pago da Carla (R6)
- [x] T008 Comandos verdes, documentos e PR

**Sessão 2 concluída em 24/11/2026** no *branch* `fatia-6/servidor-a`, criado a partir do `fatia-6/docs` (PR #31, ainda aberto): `supabase test db` (813 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` (16 testes) verdes. Testes antes no *commit* "Testes da etapa A da fatia 6 no servidor, antes do código", com a saída da falha. Depois dele, só um ajuste de estrutura, sem resultado esperado alterado: o PG07, último do arquivo, saiu do *savepoint*, porque o `finish()` do pgTAP recusa um arquivo em que todos os testes voltam atrás.

- **Decisão do responsável (24/11/2026):** `revert_charge` recusa o pagador que virou o recebedor do jogo (research R4). RN85, contrato e PG07 atualizados.
- **Auxiliares novos**, em `private` e sem `execute` para o app: `lock_charge`, que a `review_receipt` da etapa B pode usar, e `payment_notification_data`.
- **Seed:** o `share` da Carla no Quinta concluído fica Pago (R6).

## Sessão 3 — App

Precisa do `charge.png` em `docs/ui/referencias/fatia-6/`.

- [ ] T009 Testes antes: S77 (sem comprovantes), S84 (sem **Conferir comprovante**), S85 (sem **Para conferir**), S88, S89, E15, L23
- [ ] T010 Valor a pagar e ações no Rateio (`docs/ui/telas.md`, seção 9)
- [ ] T011 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T012 L23 nas APIs 29 e 36
- [ ] T013 Ensaio e `supabase db push`; advisors
