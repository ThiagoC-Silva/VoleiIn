# Tasks: Jogo e lista de presença, etapa B (fatia 4)

**Input**: `specs/004-jogo-etapa-b/` (spec, plan, research)

**Tests**: obrigatórios e antes do código. Resultados esperados de `docs/testes-referencia.md`, seção 12, linha B.

---

## Sessão 2 — Servidor

### Phase 1: Testes do servidor primeiro

- [x] T001 [P] B06 com `leave_game`, `remove_participant` e `leave_waitlist` em `supabase/tests/database/base_security.test.sql`
- [x] T002 [P] [US1] [US2] [US3] O08 a O19, T01, T02 e T06 a T10 em `supabase/tests/database/games_list.test.sql`
- [x] T003 [P] [US1] [US2] C03 e C06 em `supabase/functions/_tests/concurrency/games_test.ts`
- [x] T004 Rodar `supabase test db` e `deno test`, guardar a saída da falha e fazer o *commit* só de testes

### Phase 2: Implementação do servidor

- [x] T005 [US1] [US2] [US3] Migração `create_game_exit_functions`: `leave_game`, `remove_participant`, `leave_waitlist` (research R1 a R5)

### Phase 3: Convergência do servidor

- [x] T006 `supabase db reset`, `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes
- [x] T007 Atualizar os documentos afetados e a linha "Estado atual" do `CLAUDE.md`; enviar o *branch* e abrir o PR

**Sessão 2 concluída em 17/11/2026** no *branch* `fatia-4/servidor-b`: `supabase test db` (451 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes, com C01 a C06 em 50 de 50 repetições. Testes antes do código no *commit* `2db4778`, com a saída da falha. Um ajuste no próprio teste depois da implementação, sem mudar o que ele confere: o `set_eq` do O08f e do O17e precisava de nomes nas colunas. Decisões técnicas no `research.md` (R1 a R6). A migração vai à produção só na sessão 4, depois do ensaio.

---

## Sessão 3 — App

Numa conversa nova, depois do *merge* da sessão 2, com os PNGs da etapa B conferidos.

- [x] T008 Códigos de erro novos e textos da etapa (`docs/copy.md`, seção 8) e testes E15, S43 a S47, L16, L17 escritos antes
- [x] T009 Repositório e ações de sair, sair da espera e remover no detalhe do jogo (7.3)
- [x] T010 `dart format`, `dart analyze` e `flutter test` verdes; acessibilidade (S59, S60)

**Sessão 3 concluída em 17/11/2026**, na mesma conversa da sessão 2, a pedido do responsável, no *branch* `fatia-4/app-b`: `dart format`, `dart analyze` e `flutter test` (439 testes) verdes, com os testes escritos antes (*commit* `8b682ec`, com a saída da falha). O pé do detalhe ganhou **Sair da lista** (com a frase pelo relógio do aparelho e o `SnackBar` pelo `outcome` do servidor) e **Sair da lista de espera**; o admin remove pela sheet da linha, antes do início e sem ser sobre o recebedor (`game-participante.png`). O S46 já estava coberto pela etapa A. L16 e L17 escritos em `app/integration_test/games_flow_test.dart`, com o detalhe aberto pelo roteador, porque os cards de Meus jogos repetem locais do seed. Ajustes nos testes depois de escrevê-los, sem mudar o que conferem: um *import* sobrando e o `viewerId` no novo caso do S59.

## Sessão 4 — Validação

- [x] T011 L16 e L17 no emulador, APIs 29 e 36, pelos `scripts/`
- [x] T012 Ensaio (`docs/setup.md`, 9.2) e `supabase db push`; `get_advisors`
- [x] T013 `docs/rastreabilidade.md` e a linha "Estado atual" do `CLAUDE.md`

**Sessão 4 em 17/11/2026**, na mesma conversa: L15, L16 e L17 verdes nas APIs 29 e 36. O L17 falhou na primeira vez porque o Realtime do Supabase local estava desligado no `config.toml` desde a fatia 1, para poupar memória; ele foi religado (`docs/setup.md`, 3.1). Com o celular do responsável conectado por depuração sem fio, o `scripts/emulator.sh` recusou "mais de um aparelho"; os comandos rodaram com `ANDROID_SERIAL=emulator-5554`. Migração na produção com o ensaio (`docs/setup.md`, 9.7). RF49, RF50 e RF54 ficam "Em andamento" na `docs/rastreabilidade.md` até a etapa C.
