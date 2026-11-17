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

**Checkpoint**: testes vermelhos pelo motivo certo (*commit* `71ce7c1`, com a saída da falha na mensagem).

### Phase 2: Implementação do servidor

- [x] T008 Migração `create_game_access_helpers`: `private.is_game_admin` e `private.can_view_game` (`docs/rls-matriz.md`, fatia 4)
- [x] T009 [US2] Migração `games_rls`: privilégios, as cinco políticas e a publicação do Realtime (research R8)
- [x] T010 [US1] [US3] [US4] Migração `create_game_functions`: auxiliares (research R2 e R5), `create_game`, `update_game`, `join_game`, `join_waitlist`, `set_slot_limit` (`docs/contratos-api.md`, seção 4; ordem do research R4)
- [x] T011 [US2] Migração `create_game_read_functions`: `get_profile_contact` e `get_game_groups`

### Phase 3: Convergência do servidor

- [x] T012 `supabase db reset`, `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes
- [x] T013 Atualizar os documentos afetados (`README` de `_tests/`, CI, `docs/setup.md`, seção 8) e a linha "Estado atual" do `CLAUDE.md`; enviar o *branch* e abrir o PR. A `docs/rastreabilidade.md` é preenchida no fechamento da fatia, como na fatia 3

**Sessão 2 concluída em 16/11/2026** no *branch* `fatia-4/servidor-a`: `supabase test db` (398 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes, com C01, C02, C04 e C05 em 50 de 50 repetições. Decisões técnicas no `research.md`: `join_waitlist` entrou nesta etapa (a linha A lista O03, O04, O06, O07 e T05); o código de convite é aceito e ignorado até a fatia 8 (R3); a concorrência usa 27 contas só de teste com tokens assinados pelo `JWT_SECRET` local, por causa do limite de 30 logins a cada 5 minutos do Auth (R7), e o CI passou a entregar o `JWT_SECRET` ao `deno test`. Os testes das fatias 2 e 3 apagam os jogos do seed no preparo (R6), sem mudar nenhum resultado esperado. As migrações vão à produção só na sessão 4, depois do ensaio.

---

## Sessão 3 — App

Começa numa conversa nova, depois do *merge* da sessão 2, com os PNGs de `docs/ui/referencias/fatia-4/` conferidos contra o `docs/ui/telas.md`, seção 7 (`docs/trabalho-com-agente.md`, etapa 2b). Só as telas e os estados desta etapa: Meus jogos, Criar jogo, o detalhe (entrar na lista e na espera, chave Pix, lista e espera, Realtime), Editar jogo e os jogos no detalhe do grupo.

### Phase 4: Contratos e testes do app primeiro

- [x] T014 Escrever `specs/003-jogo-etapa-a/contracts/repositories.md` (repositórios da feature `games`)
- [x] T015 [P] U09 a U11 e E15 (com os códigos das funções desta etapa) em `app/test/`
- [x] T016 [P] S36 a S42, S50 a S53 e S59 e S60 das telas desta etapa (`docs/ui/telas.md`, 7.10)
- [x] T017 [P] L15 (sem o cancelamento) em `app/integration_test/`
- [x] T018 Rodar `flutter test`, guardar a saída da falha e fazer o *commit* só de testes

### Phase 5: Implementação do app

- [x] T019 Textos da seção 8 do `docs/copy.md` usados nesta etapa no `app_pt.arb` e os códigos de erro novos
- [x] T020 [US1] [US2] [US3] Domain e data da feature `games` (leituras, Realtime e chamadas às funções)
- [x] T021 Rotas `/games`, `/games/new`, `/games/:gameId` e `/games/:gameId/edit`
- [x] T022 [US2] Meus jogos e card de jogo (7.1)
- [x] T023 [US1] Criar jogo (7.2)
- [x] T024 [US2] [US3] Detalhe do jogo: topo, trio de números, lista, espera, chave Pix, entrar na lista e na espera (7.3)
- [x] T025 [US4] Editar jogo, com o contador de vagas (7.4)
- [x] T026 [US2] Jogos no detalhe do grupo e o botão Criar jogo (7.6)

### Phase 6: Convergência do app

- [x] T027 `dart format`, `dart analyze` e `flutter test` verdes; lista de acessibilidade (`docs/ui/design-system.md`, seção 8)

**Sessão 3 concluída em 16/11/2026** no *branch* `fatia-4/app-a`, na `main` pelo PR #12: `dart format`, `dart analyze` e `flutter test` (419 testes) verdes, com os testes escritos antes (*commit* `dcaa0f6`, com a saída da falha). Decisões do responsável: os textos dos PNGs que faltavam no `docs/copy.md` (`gameSlotsUnit`, `gameTrioFreeSlots`, `gameTrioFull`, `gameTrioEstimate`) e a composição pelo roteador (`docs/arquitetura-app.md`, seção 2). Decisões técnicas no `research.md` (R9 a R13): a seção "Próximos jogos" vem da feature `games`, montada pelo roteador; o perfil na aba Jogos pela rota `gamePerson`; relógio e Realtime trocáveis; o detalhe só com as ações da etapa A; o S55 escrito já nesta etapa. O L15 foi escrito (`app/integration_test/games_flow_test.dart`), com os seletores de data e hora trocados por respostas fixas, e roda na sessão 4. Ajustes nos testes existentes, sem mudar resultado esperado: o E02 usava `GAME_FULL` como código desconhecido, e três testes do S26 passaram a rolar até **Sair do grupo**, que desceu com a seção de jogos.

---

## Sessão 4 — Validação

### Phase 7

- [x] T028 L15 (sem o cancelamento) no emulador, APIs 29 e 36, pelos `scripts/`; M06 com o responsável, no celular
- [x] T029 Ensaio da migração (`docs/setup.md`, 9.2) e `supabase db push` na produção; `get_advisors`
- [x] T030 Atualizar `docs/rastreabilidade.md` (RFs com teste, ainda "Em andamento" até a etapa C) e a linha "Estado atual" do `CLAUDE.md`

**Sessão 4 em 17/11/2026:** L15 verde nas APIs 29 e 36, depois de dois ajustes no próprio teste, sem mudar o que ele confere. O `.last` do `flutter_test` lança `StateError` quando ainda não há widget, e o `pumpUntil` caía na primeira volta na API 29, mais lenta. E na tela menor da API 29 o card novo ficava abaixo da dobra, então a espera em Meus jogos e no grupo passou a rolar a lista (`pumpUntilScrolled`). As 4 migrações na produção, com o ensaio (`docs/setup.md`, 9.6). **M06 em 17/11/2026**, no celular do responsável, com o build da produção e o jogo de teste "Teste M06" (grupo Vôlei Fox): 10 de 10 medições abaixo de 2 s (250, 317, 333, 350, 433, 450, 450, 583, 683 e 1.583 ms), do primeiro quadro em que o toque muda a tela até o detalhe parar com a lista, medidas quadro a quadro numa gravação de tela a 60 fps. **Desvio:** a medição foi no Wi-Fi, e não no 4G que o M06 pede, porque a depuração sem fio só funciona com o Wi-Fi ligado. O responsável escolheu assim. O jogo de teste fica na produção até a etapa C, que traz o cancelamento.

## Dependencies & Execution Order

- Fase 1 antes da 2; T006 depois de T002 a T004 (o seed muda o preparo dos testes existentes).
- Na fase 2, T008 antes de T009 a T011.
- A sessão 3 começa depois do *merge* da sessão 2.
