# Tasks: Grupos (fatia 3)

**Input**: Design documents from `specs/002-grupos/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: obrigatórios e **antes do código** (constituição, princípio III; `docs/trabalho-com-agente.md`, seção 3). Em cada sessão, a fase de testes tem *commit* próprio e a saída da falha. Os resultados esperados vêm de `docs/testes-referencia.md`, seção 11, e nenhum deles muda para o teste passar.

**Sessões** (`docs/trabalho-com-agente.md`, 3.1): fases 1 a 3 na sessão 2 (servidor), fases 4 a 6 na sessão 3 (app), fase 7 na sessão 4 (validação e fechamento).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência pendente).
- **[Story]**: história do `spec.md` (US1 a US6).

---

## Sessão 2 — Servidor

### Phase 1: Testes do servidor primeiro

**Purpose**: todos os cenários automáticos de servidor da seção 11, escritos e **falhando pelo motivo certo** (a função ou a política ainda não existe). Um *commit* só de testes.

- [x] T001 [P] Atualizar as listas esperadas de B03, B04, B06, B08 e B10 em `supabase/tests/database/base_security.test.sql` (`docs/rls-matriz.md`, fatia 3; `docs/testes-referencia.md`, 9.1 e 11)
- [x] T002 [P] Escrever G01 a G33 em `supabase/tests/database/groups_functions.test.sql`, com a base da seção 11 e a limpeza do research R3
- [x] T003 [P] Escrever K01 a K15 em `supabase/tests/database/groups_security.test.sql`
- [x] T004 [P] Escrever A07 a A13 em `supabase/functions/_tests/avatars_test.ts`
- [x] T005 [P] Escrever Q01 a Q07 em `supabase/functions/preview-invite/index_test.ts`
- [x] T006 [P] Escrever C13 e C15 em `supabase/functions/_tests/concurrency/groups_test.ts` (research R4)
- [x] T007 Acrescentar ao `supabase/seed.sql` os grupos da `docs/setup.md`, seção 8 (pré-requisito dos testes Deno, não é código de produção)
- [x] T008 Rodar `supabase test db` e `deno test`, guardar a saída da falha e fazer o *commit* só de testes

**Checkpoint**: testes vermelhos pelo motivo certo (*commit* `99aedd5`, com a saída da falha na mensagem).

### Phase 2: Implementação do servidor

- [x] T009 Migração `create_group_access_helpers`: as quatro funções auxiliares e `private.generate_invite_code()` (`docs/rls-matriz.md`, fatia 3; research R1)
- [x] T010 Migração `groups_rls`: privilégios e as seis políticas (US4, US5)
- [x] T011 [US1] [US6] Migração `create_group_functions`, parte 1: `create_group`, `update_group`, `regenerate_group_invite`, `invalidate_group_invite` (`docs/contratos-api.md`, seção 3)
- [x] T012 [US2] Mesma migração, parte 2: `request_group_join` e `decide_join_request`, com as notificações e o bloqueio do research R2
- [x] T013 [US4] [US6] Mesma migração, parte 3: `set_group_role`, `leave_group`, `remove_group_member`, `archive_group` (RN13, RN17; `games_left` vazio até a fatia 4)
- [x] T014 Migração `avatars_group_policies`: as quatro políticas de Storage, com a conversão segura da pasta para `uuid` (A13)
- [x] T015 [US2] Edge Function `preview-invite` em `supabase/functions/preview-invite/index.ts`, com `_shared/http.ts` e `verify_jwt = false` no `supabase/config.toml` (research R5)
- [x] T016 CI: testes da `preview-invite` no job `database` (research R6)

### Phase 3: Convergência do servidor

- [x] T017 `supabase db reset`, `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes
- [x] T018 Atualizar os documentos afetados (`docs/rastreabilidade.md` com o estado do servidor, `README` de `_shared/` e `_tests/`) e a linha "Estado atual" do `CLAUDE.md`; enviar o *branch* e abrir o PR

**Sessão 2 concluída em 15/11/2026** no *branch* `fatia-3/servidor`: `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes. Decisões do responsável na sessão: o C14 foi retirado (rebaixamento cruzado simultâneo, pouco provável) e o A06 passou a usar o Diego no lugar do Bruno (`docs/testes-referencia.md`, 10.3 e 11.5). As migrações vão à produção só na sessão 4, depois do ensaio.

---

## Sessão 3 — App

Começa numa conversa nova, depois do *merge* da sessão 2, com os PNGs de `docs/ui/referencias/fatia-3/` conferidos contra o `docs/ui/telas.md`, seção 6 (`docs/trabalho-com-agente.md`, etapa 2b).

### Phase 4: Contratos e testes do app primeiro

- [x] T019 Escrever `specs/002-grupos/contracts/repositories.md` (repositórios da feature `groups` e do perfil de outra pessoa)
- [x] T020 [P] U08 (código digitado) e E13, E14 (conversão de erros) em `app/test/`
- [x] T021 [P] S18 a S35 (telas, `docs/ui/telas.md`, 6.10)
- [x] T022 [P] L12 a L14 em `app/integration_test/`
- [x] T023 Rodar `flutter test`, guardar a saída da falha e fazer o *commit* só de testes

### Phase 5: Implementação do app

- [x] T024 Textos da seção 7 do `docs/copy.md` no `app_pt.arb` e os códigos de erro novos
- [x] T025 [US1] [US4] Domain e data da feature `groups` (leituras por `select` e chamadas às funções)
- [x] T026 Rotas da seção 6 do `docs/ui/telas.md` no roteador
- [x] T027 [US4] Meus grupos e Detalhe do grupo (6.1, 6.4)
- [x] T028 [US1] [US6] Criar e Editar grupo (6.2, 6.8)
- [x] T029 [US2] Entrar com código e Solicitações (6.3, 6.7)
- [x] T030 [US3] Sheet do convite (6.5)
- [x] T031 [US4] [US5] Integrantes e Perfil de outra pessoa (6.6, 6.9)

### Phase 6: Convergência do app

- [x] T032 `dart format`, `dart analyze` e `flutter test` verdes; lista de acessibilidade (`docs/ui/design-system.md`, seção 8)

**Sessão 3 concluída em 15/11/2026** no *branch* `fatia-3/app`: testes escritos antes (*commit* `3cfa415`, com a saída da falha na mensagem), depois `dart format`, `dart analyze` (só os avisos `deprecated_member_use` do Flutter 3.50, já conhecidos) e `flutter test` verdes, com 306 testes, inclusive S35 e a lista de acessibilidade das telas da seção 6 (`groups_accessibility_test.dart`). Os 18 PNGs foram conferidos contra o `telas.md`, seção 6, sem divergência de conteúdo. Decisões da sessão, registradas no `contracts/repositories.md`: o perfil de outra pessoa fica na feature `auth`; `PhotoPicker`, `PhotoChange` e `SubmitController` foram para `core/`, e a sheet da foto, para `shared/widgets/`; as telas de grupo leem a sessão pelo `sessionUserIdProvider` (exceção registrada no `arquitetura-app.md`, seção 2). O código do convite usa Roboto 700 22, como manda o 6.5, e não a fonte monoespaçada dos PNGs (confirmado pelo responsável em 15/11/2026). Entrou na `main` pelo PR #8. L12 a L14 estão escritos e rodam na sessão 4.

---

## Sessão 4 — Validação e fechamento

### Phase 7

- [ ] T033 L12 a L14 no emulador, APIs 29 e 36, pelos `scripts/`; M05 com o responsável
- [ ] T034 Ensaio da migração (`docs/setup.md`, 9.2) e `supabase db push` na produção; `get_advisors`
- [ ] T035 Atualizar o princípio V da constituição com a decisão de 13/11/2026 (`docs/trabalho-com-agente.md`, seção 8)
- [ ] T036 Fechar a fatia (`docs/trabalho-com-agente.md`, seção 11): rastreabilidade, "Estado atual", seed e documentos
