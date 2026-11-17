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

- [ ] T005 [US1] [US2] [US3] Migração `create_game_exit_functions`: `leave_game`, `remove_participant`, `leave_waitlist` (research R1 a R5)

### Phase 3: Convergência do servidor

- [ ] T006 `supabase db reset`, `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` verdes
- [ ] T007 Atualizar os documentos afetados e a linha "Estado atual" do `CLAUDE.md`; enviar o *branch* e abrir o PR

---

## Sessão 3 — App

Numa conversa nova, depois do *merge* da sessão 2, com os PNGs da etapa B conferidos.

- [ ] T008 Códigos de erro novos e textos da etapa (`docs/copy.md`, seção 8) e testes E15, S43 a S47, L16, L17 escritos antes
- [ ] T009 Repositório e ações de sair, sair da espera e remover no detalhe do jogo (7.3)
- [ ] T010 `dart format`, `dart analyze` e `flutter test` verdes; acessibilidade (S59, S60)

## Sessão 4 — Validação

- [ ] T011 L16 e L17 no emulador, APIs 29 e 36, pelos `scripts/`
- [ ] T012 Ensaio (`docs/setup.md`, 9.2) e `supabase db push`; `get_advisors`
- [ ] T013 `docs/rastreabilidade.md` e a linha "Estado atual" do `CLAUDE.md`
