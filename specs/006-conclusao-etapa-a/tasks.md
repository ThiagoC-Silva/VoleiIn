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

- [x] T010 Testes antes: U13, E15, S61 a S66, S68, S69 (sem Isentos), S75, S76, L20
- [x] T011 Detalhe depois do fim e concluído, Concluir jogo e Rateio (`docs/ui/telas.md`, 8.1 a 8.3)
- [x] T012 `dart format`, `dart analyze` e `flutter test` verdes

**Sessão 3 concluída em 18/11/2026** no *branch* `fatia-5/app-a`: `dart format`, `dart analyze` e `flutter test` (502 testes) verdes. Testes antes no *commit* `c408b9e`, com a saída da falha (`+66 -31`). Depois dele, só um seletor mudou no S69: o selo e o total "Pendente" têm o mesmo texto, e a contagem passou a ser pelos selos. Nenhum resultado esperado mudou. Decisões da sessão:

- **L20 (responsável):** o jogo do seed aguardando conclusão (`...0209`) passou a ter 3 vagas e status Confirmado, para dar os R$ 30,00 por vaga e os R$ 60,00 a receber do L20 (`setup.md`, seção 8). O L20 está em `integration_test/completion_flow_test.dart` e roda na sessão 4.
- **Fora da etapa A, apesar dos PNGs:** as caixas de "Quem faltou?" e o card "Sua participação" (etapa B), Trocar recebedor no menu e o contador da aba Cobranças (etapa C). O S61 confere o menu só com **Admins do jogo**; **Trocar recebedor** entra na etapa C.
- **Legendas dos números, pelos PNGs:** `gameTrioAtStart`, `gameTrioFinal`, `gameTrioVenue`, `completeShareFormula`, `splitTrioLimit` e `splitShareFormula` (`copy.md`, 9.1 a 9.3). As linhas "11 valores de R$ 20,84", "11 pessoas" e "Recebe os valores do jogo" dos PNGs ficaram de fora: não estão no `copy.md`, e a primeira exigiria conta no app.
- **"Seu valor" para o recebedor:** aparece, com `splitNoChargeReceiver`, como manda o `telas.md` (8.3), embora o PNG do recebedor não o mostre.

## Sessão 4 — Validação

- [ ] T013 L20 nas APIs 29 e 36; M08 com o responsável
- [ ] T014 Ensaio e `supabase db push`; advisors
