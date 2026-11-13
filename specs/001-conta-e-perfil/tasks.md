# Tasks: Conta e perfil (fatia 2)

**Input**: Design documents from `specs/001-conta-e-perfil/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/repositories.md, quickstart.md

**Tests**: obrigatórios e **antes do código** (constituição, princípio III; `docs/trabalho-com-agente.md`, seção 3). A fase 2 é só de testes, com *commit* próprio e a saída da falha. Os resultados esperados vêm de `docs/testes-referencia.md`, seção 10, e nenhum deles muda para o teste passar.

**Organization**: por história do `spec.md`. Regras, contratos e textos são citados pelo documento de origem (template de tarefa, `docs/trabalho-com-agente.md`, seção 4).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência pendente).
- **[Story]**: história do `spec.md` (US1 a US8).

## Path Conventions

`app/` (Flutter) e `supabase/` (banco, Auth, Storage), como em `docs/setup.md`, seção 2.

---

## Phase 1: Setup

**Purpose**: dependências e esqueleto da fatia.

- [x] T001 Acrescentar `google_sign_in` e `image_picker` em `app/pubspec.yaml`, com o comentário de uso, e rodar `flutter pub get` (`docs/arquitetura-app.md`, seção 3)
- [x] T002 [P] Criar os modelos de e-mail `supabase/templates/confirmation.html`, `recovery.html` e `email_change.html`, com os corpos de `docs/copy.md`, 6.9
- [x] T003 Ajustar `supabase/config.toml` com as opções de `docs/setup.md`, 6.1 (confirmação por código, senha de 8, `double_confirm_changes = false`, modelos, `email_sent = 30`) e o `[auth.external.google]` (research R11); reiniciar o Supabase local
- [x] T004 [P] Preencher `GOOGLE_WEB_CLIENT_ID` em `app/env/local.json` e exigir a variável em `app/lib/core/env.dart` (`docs/setup.md`, 5.1)

---

## Phase 2: Testes primeiro (bloqueia todo o resto)

**Purpose**: todos os cenários automáticos da seção 10 de `docs/testes-referencia.md`, escritos e **falhando pelo motivo certo** (o objeto ainda não existe). Um *commit* só de testes.

- [x] T005 [P] Atualizar as listas esperadas de B03, B04, B06, B08 e B10 em `supabase/tests/database/base_security.test.sql` (`docs/rls-matriz.md`, fatia 2; `docs/testes-referencia.md`, 9.1)
- [x] T006 [P] Escrever P01 a P16 em `supabase/tests/database/account_security.test.sql`
- [x] T007 [P] Escrever X01 a X10 e N01 a N09 em `supabase/tests/database/account_pix.test.sql`
- [x] T008 [P] Escrever A01 a A06 em `supabase/functions/_tests/avatars_test.ts`
- [x] T009 [P] Escrever U01 e U02 em `app/test/core/format/documents_test.dart`, U03 e U04 em `app/test/core/format/phone_test.dart`, U05 e U06 em `app/test/features/auth/domain/pix_key_test.dart` e U07 em `app/test/features/auth/domain/auth_access_test.dart`
- [x] T010 [P] Escrever E09 a E11 (e o novo exemplo do E06) em `app/test/core/errors/error_mapper_test.dart`, e E12 em `app/test/features/auth/data/auth_repository_test.dart`
- [x] T011 [P] Escrever S01 e S02 em `app/test/features/auth/presentation/signup_screen_test.dart`, S03 a S05 em `confirm_email_screen_test.dart` e S06 e S07 em `login_screen_test.dart`
- [x] T012 [P] Escrever S08 em `app/test/features/auth/presentation/forgot_password_screen_test.dart`, S09 em `terms_screen_test.dart` e S10 em `app/test/core/router/app_router_test.dart`
- [x] T013 [P] Escrever S11 e S17 em `app/test/features/auth/presentation/profile_screen_test.dart`, S12 em `profile_edit_screen_test.dart`, S13 em `profile_pix_screen_test.dart`, S14 em `profile_email_screen_test.dart` e S15 em `profile_password_screen_test.dart`
- [x] T014 [P] Escrever S16 (fonte em 150% em todas as telas da seção 5 do `docs/ui/telas.md`) em `app/test/features/auth/presentation/text_scale_test.dart`
- [x] T015 [P] Escrever L08 a L11 em `app/integration_test/account_flow_test.dart`, com a leitura do código no Mailpit
- [x] T016 Rodar `supabase test db`, `deno test` e `flutter test`, guardar a saída da falha e fazer o *commit* só de testes

**Checkpoint**: testes vermelhos pelo motivo certo.

---

## Phase 3: Foundational (bloqueia as histórias)

**Purpose**: o que todas as histórias usam: acesso no banco, conversão de erros, textos e componentes.

- [x] T017 Conferir no Supabase local o comportamento do cadastro repetido de um e-mail não confirmado (research R5) e registrar o resultado em `specs/001-conta-e-perfil/research.md`
- [x] T018 Criar a migração `create_current_terms_versions` em `supabase/migrations/` (`docs/contratos-api.md`, seção 9): `sql`, `immutable`, `security invoker`, `revoke execute ... from public, anon` e `grant` a `authenticated`
- [x] T019 Criar a migração `create_pix_key_validators`: `private.is_valid_cpf(text)` e `private.is_valid_cnpj(text)`, `immutable`, que recusam sequência de um dígito só, e a constraint `profile_private_pix_format` com os dígitos verificadores (`docs/modelo-dados.md`, 4.1; research R6)
- [x] T020 Criar a migração `create_pix_key_removal_guard`: *trigger* em `profile_private` que rejeita `pix_key = null` com `PIX_KEY_IN_USE` "se o usuário for `receiver_id` de um jogo `open`/`confirmed` ou de um `charge` `pending`/`under_review`" (`docs/modelo-dados.md`, 4.1)
- [x] T021 Criar a migração `account_rls`: privilégios por coluna e as seis políticas de `docs/rls-matriz.md`, fatia 2, com `(select auth.uid())`
- [x] T022 Criar a migração `avatars_profile_policies`: `avatars_profile_select_own`, `avatars_profile_insert_own` e `avatars_profile_delete_own` em `storage.objects` (`docs/rls-matriz.md`, fatia 2)
- [x] T023 Completar `supabase/seed.sql` com os perfis da fatia 2 (`docs/setup.md`, seção 8) e rodar `supabase db reset`, `supabase db lint` e `supabase test db` até B, P, X e N passarem
- [x] T024 Fazer o teste do Storage rodar no job `database` de `.github/workflows/ci.yml` (research R10) e passar A01 a A06 no local
- [x] T025 [P] Acrescentar os `ErrorCode` de `docs/copy.md`, 6.8, em `app/lib/core/errors/error_code.dart`, a conversão em `error_mapper.dart` (Auth, `PIX_KEY_IN_USE`, Storage) e os textos em `error_text.dart`
- [x] T026 [P] Acrescentar ao `app/lib/l10n/app_pt.arb` todas as chaves de `docs/copy.md`, seção 6, corrigir `errorAuthEmailNotConfirmed` (research R9) e gerar com `flutter gen-l10n`
- [x] T027 [P] Criar `app/lib/core/format/documents.dart` (CPF e CNPJ), `phone.dart` e `input_masks.dart`, e `app/lib/features/auth/domain/pix_key.dart` com o enum do tipo e a conferência, a normalização e a exibição por tipo (U01 a U06; research R8)
- [x] T028 [P] Criar os modelos de `data-model.md` em `app/lib/features/auth/domain/` (`profile.dart`, `profile_private.dart`, `own_profile.dart`, `legal_document.dart`, `terms.dart`, `auth_access.dart`) e rodar o `build_runner`
- [x] T029 [P] Criar os componentes comuns em `app/lib/shared/widgets/`: campo com rótulo, campo de senha, botão com carregando, barra superior interna, campo de código, reenviar código, avatar, lista de linhas com seta, quadrado de ícone e sheet de confirmação (`docs/ui/design-system.md`, seção 7; PNGs de `docs/ui/referencias/fatia-2/`)
- [x] T030 Criar `google_id_token_source.dart` e completar `auth_repository.dart` em `app/lib/features/auth/data/`, conforme `contracts/repositories.md` (E12)
- [x] T031 [P] Criar `profile_repository.dart`, `terms_repository.dart` e `photo_picker.dart` (a escolha da foto, trocável por dublê) em `app/lib/features/auth/data/`, conforme `contracts/repositories.md`
- [x] T032 Criar os providers de sessão, rascunho de acesso, recuperação em andamento e conferência dos termos em `app/lib/features/auth/presentation/auth_providers.dart`, e desligar a repetição automática no `ProviderScope` de `app/lib/main.dart` (research R2 a R4)

**Checkpoint**: B, P, X, N, A, U e E verdes.

---

## Phase 4: User Story 1 - Criar a conta com e-mail e confirmar por código (P1) 🎯 MVP

**Goal**: cadastro, confirmação por código e login completado (`docs/ui/telas.md`, 5.1 a 5.3).

**Independent Test**: S01 a S06 verdes; L08 no emulador.

- [x] T033 [US1] Acrescentar as rotas `/signup`, `/confirm-email` e `/forgot-password` e os redirecionamentos de acesso em `app/lib/core/router/routes.dart` e `app_router.dart` (`docs/ui/telas.md`, 3.1)
- [x] T034 [US1] Completar `app/lib/features/auth/presentation/login_screen.dart` e `login_controller.dart` conforme `login.png`: bloco do topo, Esqueci minha senha, divisor, Continuar com Google, Criar conta e a ação Confirmar do e-mail não confirmado (S06, S07)
- [x] T035 [P] [US1] Criar `signup_screen.dart` e `signup_controller.dart` conforme `signup.png` (S01, S02)
- [x] T036 [US1] Criar `confirm_email_screen.dart` e `confirm_email_controller.dart` conforme `confirmEmail.png`, com a senha regravada depois do código (S03 a S05; research R5)

**Checkpoint**: uma conta nova chega ao app.

---

## Phase 5: User Story 2 - Aceitar os termos na versão vigente (P1)

**Goal**: aceite obrigatório depois do primeiro acesso e a cada versão nova (`docs/ui/telas.md`, 3.1, 5.5 e 5.6).

**Independent Test**: S09 e S10 verdes.

- [x] T037 [US2] Acrescentar as rotas `/terms` e `/terms/:document` e o redirecionamento dos termos em `app/lib/core/router/app_router.dart` (S10; research R3)
- [x] T038 [US2] Criar `terms_screen.dart` e `terms_controller.dart` em `app/lib/features/auth/presentation/` conforme `terms.png`, com os estados carregando e erro e a releitura quando o RLS recusa (S09)
- [x] T039 [P] [US2] Criar `terms_document_screen.dart` conforme `termsDocument.png`, com "não encontrado" para outro valor de `:document`

**Checkpoint**: do cadastro à aba Jogos, com aceite.

---

## Phase 6: User Story 3 - Entrar com Google e vincular (P2)

**Goal**: RF03 e RF108 (`docs/ui/telas.md`, 5.1).

**Independent Test**: S07 e E12 verdes; M01 e M02 pelo responsável.

- [x] T040 [US3] Ligar o Continuar com Google ao `signInWithGoogle` em `app/lib/features/auth/presentation/login_controller.dart`, com os dois botões bloqueados até o fim (S07)

---

## Phase 7: User Story 4 - Ver o perfil e sair (P2)

**Goal**: a aba Perfil real (`docs/ui/telas.md`, 5.7).

**Independent Test**: S11 e S17 verdes.

- [x] T041 [US4] Criar `profile_providers.dart` (perfil próprio e URL da foto) em `app/lib/features/auth/presentation/`
- [x] T042 [US4] Refazer `profile_screen.dart` conforme `profile.png` e `profile-google.png`, com os estados carregando, erro e sem conexão e o Sair definitivo da fatia 2 (S11, S17)
- [x] T043 [US4] Acrescentar as rotas `/profile/edit`, `/profile/pix`, `/profile/email` e `/profile/password`, fora das abas, com a volta ao perfil de quem não tem acesso por e-mail e senha, em `app/lib/core/router/app_router.dart` (S11)

---

## Phase 8: User Story 5 - Editar nome, apelido, foto e telefone (P2)

**Goal**: `docs/ui/telas.md`, 5.8.

**Independent Test**: S12 verde; L10 no emulador.

- [x] T044 [US5] Criar `profile_edit_screen.dart` e `profile_edit_controller.dart` conforme `profileEdit.png` e `profileEdit-foto.png` (sheet sem título): nome até 80, apelido até 30, telefone com `+55` fixo e 10 ou 11 dígitos gravado em E.164, interruptor desabilitado sem telefone, foto com no máximo 1024 px no maior lado e a ordem de gravação do `telas.md`, 5.8 (S12)

---

## Phase 9: User Story 6 - Chave Pix (P2)

**Goal**: `docs/ui/telas.md`, 5.9.

**Independent Test**: S13 verde.

- [x] T045 [US6] Criar `profile_pix_screen.dart` e `profile_pix_controller.dart` conforme `profilePix.png`, `profilePix-tipo.png` e `profilePix-remover.png`: menu suspenso do tipo com ícones, máscara e conferência por tipo, e a confirmação destrutiva da remoção (S13)

---

## Phase 10: User Story 7 - Recuperar a senha (P3)

**Goal**: `docs/ui/telas.md`, 5.4.

**Independent Test**: S08 verde; L09 no emulador.

- [x] T046 [US7] Criar `forgot_password_screen.dart` e `forgot_password_controller.dart` conforme `forgotPassword-etapa1.png` e `-etapa2.png`, com a marca de recuperação em andamento (S08; research R2)

---

## Phase 11: User Story 8 - Trocar e-mail e senha (P3)

**Goal**: `docs/ui/telas.md`, 5.10 e 5.11.

**Independent Test**: S14 e S15 verdes; L11 no emulador.

- [x] T047 [P] [US8] Criar `profile_email_screen.dart` e `profile_email_controller.dart` conforme `profileEmail-etapa1.png` e `-etapa2.png` (S14)
- [x] T048 [P] [US8] Criar `profile_password_screen.dart` e `profile_password_controller.dart` conforme `profilePassword.png` (S15)

---

## Phase 12: Polish e fechamento

- [ ] T049 Passar S16 (fonte em 150%) e a lista de acessibilidade de `docs/ui/design-system.md`, seção 8, em todas as telas novas
- [x] T050 Rodar os comandos do `quickstart.md` até ficarem verdes: `dart format`, `dart analyze`, `flutter test`, `supabase db reset`, `supabase db lint`, `supabase test db`, `deno fmt --check`, `deno lint` e `deno test`
- [ ] T051 Rodar L06 a L11 no emulador (`app/integration_test/`) e conferir cada tela contra o PNG
  - L06 a L11 verdes nas APIs 29 e 36 em 13/11/2026, por `scripts/integration-test.sh`. A primeira rodada achou o `SubmitController` nascendo em carregamento (campos desabilitados no primeiro quadro, *autofocus* perdido), corrigido com teste. Falta a conferência das telas contra o PNG.
- [x] T052 Atualizar os documentos afetados: `docs/arquitetura-app.md` (seções 3, 5 e 12), `docs/ui/telas.md` (5.3, research R5), `docs/rls-matriz.md` (research R6), `docs/setup.md` (Google e CI), `docs/ui/design-system.md` (componentes novos) e um ADR para a senha do cadastro pendente
- [ ] T053 Fechar a fatia (`docs/trabalho-com-agente.md`, seção 11): matriz de rastreabilidade do `plan-docs.md` (5.4), linha "Estado atual" do `CLAUDE.md` e a lista do que fica para o responsável (M01 a M04 e a produção)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (1)** → **Testes primeiro (2)** → **Foundational (3)** → histórias → **Polish (12)**.
- A fase 2 vem antes de qualquer código de produção. O T016 fecha a fase com o *commit* de testes.

### User Story Dependencies

- **US1 (P1)**: depende da fase 3.
- **US2 (P1)**: depende da fase 3. O fluxo L08 precisa de US1 e US2.
- **US3 (P2)**: depende de US1 (tela de login).
- **US4 (P2)**: depende da fase 3.
- **US5, US6, US8**: dependem de US4 (rotas a partir do perfil).
- **US7 (P3)**: depende de US1 (rota a partir do login).

### Within Each User Story

Modelos e repositórios (fase 3) antes dos providers, providers antes das telas, telas antes das rotas que as abrem.

### Parallel Opportunities

- Fase 2: T005 a T015 são arquivos diferentes.
- Fase 3: T025 a T029 e T031, entre si. As migrações (T018 a T022) são em sequência, pela ordem dos arquivos.
- US8: T047 e T048.

## Parallel Example: fase 2

```text
T006 supabase/tests/database/account_security.test.sql
T007 supabase/tests/database/account_pix.test.sql
T008 supabase/functions/_tests/avatars_test.ts
T009 app/test/core/format/*_test.dart
```

## Implementation Strategy

### MVP First

Fases 1 a 5: uma pessoa cria a conta, confirma o código, aceita os termos e chega à aba Jogos (L08).

### Incremental Delivery

Depois do MVP: perfil (US4), edições (US5, US6), Google (US3), recuperação (US7) e trocas (US8). Cada história fecha com os seus cenários S verdes.

## Notes

- *Commits* pequenos, em pt-BR, no *branch* `fatia-2/conta-e-perfil` (`docs/trabalho-com-agente.md`, 6.1). Sem *push* nem PR até o responsável pedir.
- Nenhuma tela sem o PNG obrigatório. Se o PNG divergir do `telas.md` em conteúdo, parar e perguntar.
- Produção, segredos e M01 a M04 são do responsável.
