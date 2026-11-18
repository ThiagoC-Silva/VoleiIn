# Tasks: Jogo e lista de presença, etapa C (fatia 4)

**Input**: `specs/005-jogo-etapa-c/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seção 12, linha C.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `cancel_game`, `add_game_admin` e `remove_game_admin`
- [x] T002 [P] [US1] [US2] J14 a J21 em `games_functions.test.sql`
- [x] T003 [P] [US3] H01 a H10 em `groups_games.test.sql`
- [x] T004 [P] [US4] W12 em `games_security.test.sql`
- [x] T005 [P] [US1] [US3] C07 e C16 em `_tests/concurrency/games_test.ts`
- [x] T006 Saída da falha e *commit* só de testes
- [x] T007 Migração `create_game_admin_functions` (research R1 a R4)
- [x] T008 Comandos verdes, documentos e PR

**Sessão 2 concluída em 17/11/2026** no *branch* `fatia-4/servidor-c`: `supabase test db` (505 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes, com C07 e C16 em 50 de 50. Testes antes no *commit* `5a2d339`, com a saída da falha. O C16 devolve a conta `conc-26` ao grupo a cada repetição (`rejoinGroup` em `support.ts`).

## Sessão 3 — App

- [x] T009 Testes antes: E15 e E16, U12, S48, S49, S54 a S58, L15 (cancelamento), L18, L19
- [x] T010 Cancelar jogo, admins do jogo (7.5), sheet de saída bloqueada (7.8) e telefone no perfil (6.9)
- [x] T011 `dart format`, `dart analyze` e `flutter test` verdes; S59 e S60

**Sessão 3 concluída em 17/11/2026** no *branch* `fatia-4/app-c`: `dart format`, `dart analyze` e `flutter test` (468 testes) verdes, com os testes antes (*commit* `8367fa1`, com a saída da falha). O menu do admin tem Editar jogo, Admins do jogo e Cancelar jogo; a tela de admins lê `game_admins` com o perfil, porque quem saiu da lista continua admin (RN26); a sheet de bloqueio é da feature `games` e chega às telas de grupo pelo roteador (`docs/arquitetura-app.md`, seção 2); o `AppException` guarda `game_ids` (E16). Ajustes em testes de etapas anteriores, sem mudar resultado de `testes-referencia.md`: o teste da etapa A que esperava o menu sumir depois do início passou a conferir o menu sem Editar jogo (S48, `telas.md` 7.3); os dublês de `leaveGroup` e `removeMember` devolvem o número de jogos.

## Sessão 4 — Validação

- [x] T012 L15, L18 e L19 nas APIs 29 e 36; M07 com o responsável
- [x] T013 Ensaio e `supabase db push`; advisors
- [x] T014 Fechamento da fatia 4 (`docs/trabalho-com-agente.md`, seção 11): rastreabilidade e "Estado atual"

**Sessão 4, parcial, em 17/11/2026:** L15 a L19 verdes nas APIs 29 e 36, e o fluxo de grupos da fatia 3 verde na API 29. Ajustes só nos testes de integração, sem mudar o que conferem: o L19 rola até **Sair do grupo** (os jogos do grupo o empurram para baixo da dobra) e o L15 espera o nome do grupo na criação (mais lento na API 29). **Falta:** M07 com o responsável no celular, o ensaio e o `supabase db push` da migração `20261117130000` (T013) e o fechamento da fatia 4 (T014).

**Sessão 4 concluída em 18/11/2026:** M07 conferido no celular (Abrir no Maps com o build da produção; Ligar e WhatsApp com o build do Supabase local, logado como Bruno, no perfil da Ana), a migração `20261117130000` na produção com o ensaio (`docs/setup.md`, 9.8) e a fatia 4 fechada em `docs/rastreabilidade.md`.
