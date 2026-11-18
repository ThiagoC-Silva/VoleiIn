# Tasks: Conclusão, multas e rateio, etapa A (fatia 5)

**Input**: `specs/006-conclusao-etapa-a/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 3, 4, 6, 8 e 13, linha A.

## Sessão 2 — Servidor

- [x] T001 [P] B03, B04 e B06 com as políticas, os privilégios e as duas funções da etapa
- [x] T002 [P] [US1] [US2] T11 a T15, F03, F04 e Z01 a Z07 em `completion_functions.test.sql`
- [x] T003 [P] [US1] R01 a R07, R09 e R10 em `completion_split.test.sql`
- [x] T004 [P] [US3] Y01 a Y03 e Y05 a Y07 em `completion_security.test.sql`
- [x] T005 [P] [US2] C08 em `_tests/concurrency/completion_test.ts`
- [x] T006 Saída da falha e *commit* só de testes
- [x] T007 Migrações `completion_rls` e `create_completion_functions` (research R1 a R7)
- [x] T008 Seed com os jogos concluído e aguardando conclusão (R8)
- [x] T009 Comandos verdes, documentos e PR

**Sessão 2 concluída em 18/11/2026** no *branch* `fatia-5/servidor-a`: `supabase test db` (632 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` (14 testes) verdes, com o C08 em 50 de 50. Testes antes no *commit* `8032fd0`, com a saída da falha. Depois dele, só um ajuste de estrutura em `completion_split.test.sql`: o R10 saiu do *savepoint*, porque o *rollback* do último apagava o registro do `finish()` do pgTAP. Nenhum resultado esperado mudou. A isenção automática, as faltas de `p_absent_user_ids` e o `penalty_waived` da conclusão já estão no corpo de `complete_game` (research R1); os cenários deles rodam na etapa B.

## Sessão 3 — App

- [ ] T010 Testes antes: U13, E15, S61 a S66, S68, S69 (sem Isentos), S75, S76, L20
- [ ] T011 Detalhe depois do fim e concluído, Concluir jogo e Rateio (`docs/ui/telas.md`, 8.1 a 8.3)
- [ ] T012 `dart format`, `dart analyze` e `flutter test` verdes

## Sessão 4 — Validação

- [ ] T013 L20 nas APIs 29 e 36; M08 com o responsável
- [ ] T014 Ensaio e `supabase db push`; advisors
