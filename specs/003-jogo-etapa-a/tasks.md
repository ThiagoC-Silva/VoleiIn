# Tasks: Jogo e lista de presença, etapa A (fatia 4)

**Input**: Design documents from `specs/003-jogo-etapa-a/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: obrigatórios e **antes do código** (constituição, princípio III; `docs/trabalho-com-agente.md`, seção 3). Em cada sessão, a fase de testes tem *commit* próprio e a saída da falha. Os resultados esperados vêm de `docs/testes-referencia.md`, seção 12 (linha A da tabela "Cenários por etapa"), e nenhum deles muda para o teste passar.

**Sessões** (`docs/trabalho-com-agente.md`, 3.1): fases 1 a 3 na sessão 2 (servidor), fases 4 a 6 na sessão 3 (app), fase 7 na sessão 4 (validação). As etapas B e C da fatia 4 têm especificação própria.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência pendente).
- **[Story]**: história do `spec.md` (US1 a US4).

---

## Sessão 2 — Servidor

### Phase 1: Testes do servidor primeiro

**Purpose**: todos os cenários automáticos de servidor da linha A, escritos e **falhando pelo motivo certo** (a função ou a política ainda não existe). Um *commit* só de testes.

- [x] T001 [P] Atualizar as listas esperadas de B03, B04 e B06 em `supabase/tests/database/base_security.test.sql` com o que a etapa A cria (`docs/rls-matriz.md`, fatia 4)
- [x] T002 [P] [US1] [US4] Escrever J01 a J13 em `supabase/tests/database/games_functions.test.sql`, com a base da seção 12 e a limpeza do research R6
- [x] T003 [P] [US3] [US4] Escrever O01 a O07, O20 a O23 e T03 a T05 em `supabase/tests/database/games_list.test.sql`
- [x] T004 [P] [US2] Escrever W01 a W11 e W13 a W15 em `supabase/tests/database/games_security.test.sql`
- [x] T005 [P] [US3] [US4] Escrever C01, C02, C04 e C05 em `supabase/functions/_tests/concurrency/games_test.ts`, com as contas de teste do research R7
- [x] T006 Acrescentar ao `supabase/seed.sql` os sete jogos da `docs/setup.md`, seção 8, e a limpeza dos jogos do seed no preparo de `account_security`, `groups_functions` e `groups_security` (research R6)
- [x] T007 Rodar `supabase test db` e `deno test`, guardar a saída da falha e fazer o *commit* só de testes

**Checkpoint**: testes vermelhos pelo motivo certo.

### Phase 2: Implementação do servidor

- [x] T008 Migração `create_game_access_helpers`: `private.is_game_admin` e `private.can_view_game` (`docs/rls-matriz.md`, fatia 4)
- [x] T009 [US2] Migração `games_rls`: privilégios, as cinco políticas e a publicação do Realtime (research R8)
- [x] T010 [US1] [US3] [US4] Migração `create_game_functions`: auxiliares (research R2 e R5), `create_game`, `update_game`, `join_game`, `join_waitlist`, `set_slot_limit` (`docs/contratos-api.md`, seção 4; ordem do research R4)
- [x] T011 [US2] Migração `create_game_read_functions`: `get_profile_contact` e `get_game_groups`

### Phase 3: Convergência do servidor

- [x] T012 `supabase db reset`, `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes
- [ ] T013 Atualizar os documentos afetados (`docs/rastreabilidade.md` com o estado do servidor, `README` de `_tests/`) e a linha "Estado atual" do `CLAUDE.md`; enviar o *branch* e abrir o PR

---

## Sessão 3 — App

Começa numa conversa nova, depois do *merge* da sessão 2, com os PNGs de `docs/ui/referencias/fatia-4/` conferidos contra o `docs/ui/telas.md`, seção 7 (`docs/trabalho-com-agente.md`, etapa 2b). Só as telas e os estados desta etapa: Meus jogos, Criar jogo, o detalhe (entrar na lista e na espera, chave Pix, lista e espera, Realtime), Editar jogo e os jogos no detalhe do grupo.

### Phase 4: Contratos e testes do app primeiro

- [ ] T014 Escrever `specs/003-jogo-etapa-a/contracts/repositories.md` (repositórios da feature `games`)
- [ ] T015 [P] U09 a U11 e E15 (com os códigos das funções desta etapa) em `app/test/`
- [ ] T016 [P] S36 a S42, S50 a S53 e S59 e S60 das telas desta etapa (`docs/ui/telas.md`, 7.10)
- [ ] T017 [P] L15 (sem o cancelamento) em `app/integration_test/`
- [ ] T018 Rodar `flutter test`, guardar a saída da falha e fazer o *commit* só de testes

### Phase 5: Implementação do app

- [ ] T019 Textos da seção 8 do `docs/copy.md` usados nesta etapa no `app_pt.arb` e os códigos de erro novos
- [ ] T020 [US1] [US2] [US3] Domain e data da feature `games` (leituras, Realtime e chamadas às funções)
- [ ] T021 Rotas `/games`, `/games/new`, `/games/:gameId` e `/games/:gameId/edit`
- [ ] T022 [US2] Meus jogos e card de jogo (7.1)
- [ ] T023 [US1] Criar jogo (7.2)
- [ ] T024 [US2] [US3] Detalhe do jogo: topo, trio de números, lista, espera, chave Pix, entrar na lista e na espera (7.3)
- [ ] T025 [US4] Editar jogo, com o contador de vagas (7.4)
- [ ] T026 [US2] Jogos no detalhe do grupo e o botão Criar jogo (7.6)

### Phase 6: Convergência do app

- [ ] T027 `dart format`, `dart analyze` e `flutter test` verdes; lista de acessibilidade (`docs/ui/design-system.md`, seção 8)

---

## Sessão 4 — Validação

### Phase 7

- [ ] T028 L15 (sem o cancelamento) no emulador, APIs 29 e 36, pelos `scripts/`; M06 com o responsável, no celular
- [ ] T029 Ensaio da migração (`docs/setup.md`, 9.2) e `supabase db push` na produção; `get_advisors`
- [ ] T030 Atualizar `docs/rastreabilidade.md` (RFs com teste, ainda "Em andamento" até a etapa C) e a linha "Estado atual" do `CLAUDE.md`

## Dependencies & Execution Order

- Fase 1 antes da 2; T006 depois de T002 a T004 (o seed muda o preparo dos testes existentes).
- Na fase 2, T008 antes de T009 a T011.
- A sessão 3 começa depois do *merge* da sessão 2.
