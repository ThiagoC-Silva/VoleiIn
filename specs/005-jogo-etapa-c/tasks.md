# Tasks: Jogo e lista de presença, etapa C (fatia 4)

**Input**: `specs/005-jogo-etapa-c/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seção 12, linha C.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `cancel_game`, `add_game_admin` e `remove_game_admin`
- [x] T002 [P] [US1] [US2] J14 a J21 em `games_functions.test.sql`
- [x] T003 [P] [US3] H01 a H10 em `groups_games.test.sql`
- [x] T004 [P] [US4] W12 em `games_security.test.sql`
- [x] T005 [P] [US1] [US3] C07 e C16 em `_tests/concurrency/games_test.ts`
- [x] T006 Saída da falha e *commit* só de testes
- [ ] T007 Migração `create_game_admin_functions` (research R1 a R4)
- [ ] T008 Comandos verdes, documentos e PR

## Sessão 3 — App

- [ ] T009 Testes antes: E15 e E16, U12, S48, S49, S54 a S58, L15 (cancelamento), L18, L19
- [ ] T010 Cancelar jogo, admins do jogo (7.5), sheet de saída bloqueada (7.8) e telefone no perfil (6.9)
- [ ] T011 `dart format`, `dart analyze` e `flutter test` verdes; S59 e S60

## Sessão 4 — Validação

- [ ] T012 L15, L18 e L19 nas APIs 29 e 36; M07 com o responsável
- [ ] T013 Ensaio e `supabase db push`; advisors
- [ ] T014 Fechamento da fatia 4 (`docs/trabalho-com-agente.md`, seção 11): rastreabilidade e "Estado atual"
