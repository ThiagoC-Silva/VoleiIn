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

- [x] T009 Testes antes: S67, S69 (Isentos), S70, S71, S75, S76, E15, L21
- [x] T010 Faltas na conclusão, isenção manual e histórico da pessoa no jogo (`docs/ui/telas.md`, seção 8)
- [x] T011 `dart format`, `dart analyze` e `flutter test` verdes

**Sessão 3 concluída em 18/11/2026** no *branch* `fatia-5/app-b`: `dart analyze` e `flutter test` (525 testes) verdes. Testes antes, num *commit* só deles, com a saída da falha (14 testes vermelhos; S69 Isentos já passava com o Rateio da etapa A). Os testes novos estão em `app/test/features/games/presentation/game_penalties_test.dart` e nos testes de erro (E15).

- **Sua participação (responsável):** o card aparece com outra passagem, falta ou multa. Quem só jogou e tem a parte não o vê, como no S71 e no PNG. A `telas.md` (8.1) dizia "valor a pagar" e foi corrigida.
- **Sheet de isentar:** pelo `gameSplit-isentar.png`, o cabeçalho tem o avatar e "{rótulo} · {valor} · {status}", e a opção ganhou a linha de apoio `waiveActionHint` ("O valor deixa de ser cobrado"), nova no `copy.md` (9.3). O `SheetOption` ganhou o parâmetro `subtitle`.
- **L21:** usa o jogo do seed "Quinta aguardando conclusão" (`...0209`), como o L20, em `integration_test/penalties_flow_test.dart`. Os dois concluem o mesmo jogo: cada um roda logo depois de um `supabase db reset`. Rodou uma vez na API 36, verde; a rodada das APIs 29 e 36 é a T012.

## Sessão 4 — Validação

- [ ] T012 L21 nas APIs 29 e 36
- [ ] T013 Ensaio e `supabase db push`; advisors
