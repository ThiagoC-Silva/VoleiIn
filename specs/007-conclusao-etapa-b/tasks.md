# Tasks: Conclusão, multas e rateio, etapa B (fatia 5)

**Input**: `specs/007-conclusao-etapa-b/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 3 a 6, 8 e 13, linha B.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `waive_penalty(uuid)`
- [x] T002 [P] [US2] T16, Z08 e Z09 em `completion_functions.test.sql`
- [x] T003 [P] [US1] [US2] [US3] R08, I01 a I12, F01, F02 e F05 a F14 em `completion_split.test.sql`
- [x] T004 [P] [US3] C09 em `_tests/concurrency/completion_test.ts`
- [x] T005 Saída da falha e *commit* só de testes
- [x] T006 Migração `create_waive_penalty` (research R1 a R3)
- [x] T007 Seed com o jogo "Quinta com multas" (R4)
- [x] T008 Comandos verdes, documentos e PR

**Sessão 2 concluída em 18/11/2026** no *branch* `fatia-5/servidor-b`: `supabase test db` (710 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` (15 testes) verdes, com o C09 em 50 de 50. Testes antes no *commit* `25ac7be`, com a saída da falha. Depois dele, só um ajuste de estrutura em `completion_functions.test.sql`: o bloco da etapa B passou para antes do Z07, porque o *rollback* do último *savepoint* apagava a contagem do `finish()` do pgTAP (o mesmo caso do R10 na etapa A). Nenhum resultado esperado mudou. Os cenários de faltas e de isenção automática passaram contra o `complete_game` da etapa A, sem mudança nele (research R1 de `specs/006-conclusao-etapa-a`).

## Sessão 3 — App

- [ ] T009 Testes antes: S67, S69 (Isentos), S70, S71, S75, S76, E15, L21
- [ ] T010 Faltas na conclusão, isenção manual e histórico da pessoa no jogo (`docs/ui/telas.md`, seção 8)
- [ ] T011 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T012 L21 nas APIs 29 e 36
- [ ] T013 Ensaio e `supabase db push`; advisors
