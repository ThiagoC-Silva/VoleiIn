# Tasks: Conclusão, multas e rateio, etapa B (fatia 5)

**Input**: `specs/007-conclusao-etapa-b/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 3 a 6, 8 e 13, linha B.

## Sessão 2 — Servidor

- [ ] T001 [P] B06 com `waive_penalty(uuid)`
- [ ] T002 [P] [US2] T16, Z08 e Z09 em `completion_functions.test.sql`
- [ ] T003 [P] [US1] [US2] [US3] R08, I01 a I12, F01, F02 e F05 a F14 em `completion_split.test.sql`
- [ ] T004 [P] [US3] C09 em `_tests/concurrency/completion_test.ts`
- [ ] T005 Saída da falha e *commit* só de testes
- [ ] T006 Migração `create_waive_penalty` (research R1 a R3)
- [ ] T007 Seed com o jogo "Quinta com multas" (R4)
- [ ] T008 Comandos verdes, documentos e PR

## Sessão 3 — App

- [ ] T009 Testes antes: S67, S69 (Isentos), S70, S71, S75, S76, E15, L21
- [ ] T010 Faltas na conclusão, isenção manual e histórico da pessoa no jogo (`docs/ui/telas.md`, seção 8)
- [ ] T011 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T012 L21 nas APIs 29 e 36
- [ ] T013 Ensaio e `supabase db push`; advisors
