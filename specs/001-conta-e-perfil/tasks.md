---
description: "Tarefas da fatia 2 — Conta e perfil"
---

# Tarefas: Fatia 2 — Conta e perfil

**Entrada**: `specs/001-conta-e-perfil/` (spec, plan, research, data-model, contracts, quickstart)

**Testes**: obrigatórios e **antes** do código (constituição, princípio III; `trabalho-com-agente.md`, seção 3). Em cada bloco, a tarefa de teste roda e **falha pelo motivo certo** antes da tarefa de implementação. O *commit* dos testes vem antes do *commit* da implementação. Os resultados esperados vêm de `docs/testes-referencia.md`, seção 10, e não mudam.

**Formato**: `- [ ] Tnnn [P] [USn] descrição com caminho`. `[P]` = pode rodar em paralelo (arquivos diferentes, sem dependência pendente).

**Campos do template de tarefa** (`trabalho-com-agente.md`, seção 4): cada fase abaixo traz Contexto, Regras, Contratos, Arquivos, Testes, Pronto quando e Fora de escopo no cabeçalho, e cada tarefa traz o caminho e os IDs de cenário.

---

## Fase 1: Preparação

- [ ] T001 Acrescentar `google_sign_in: ^7.2.0` e `image_picker: ^1.2.4` em `app/pubspec.yaml`, com o comentário de uso (tabela da seção 3 do `arquitetura-app.md`), e rodar `flutter pub get`
- [ ] T002 Configurar o Supabase Auth local em `supabase/config.toml` (`research.md`, 7; `setup.md`, 6.1): `enable_confirmations = true`, `double_confirm_changes = false`, `minimum_password_length = 8`, `[auth.rate_limit] email_sent = 30`, `[auth.email.template.confirmation|recovery|email_change]` com `subject` do `copy.md` 6.9 e `content_path = "./supabase/templates/<arquivo>.html"`, e `[auth.external.google]` com `enabled`, `client_id`, `secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"` e `skip_nonce_check = true`
- [ ] T003 [P] Criar os modelos de e-mail `supabase/templates/confirmation.html`, `recovery.html` e `email_change.html` com o corpo do `copy.md` 6.9 (`{{ .Token }}`, HTML mínimo, sem imagem)
- [ ] T004 Reiniciar o Supabase local (`supabase stop && supabase start`) e conferir no Mailpit que um `signUp` manda o código de 6 dígitos com o assunto certo

---

## Fase 2: Base (bloqueia todas as histórias)

**Contexto**: o que todas as telas usam: erros, formatação, componentes, rotas e as listas de segurança da fatia. **Regras**: RN01, RN04 (já cobertas), `copy.md` 5.5 e 6.8. **Pronto quando**: `flutter test test/core` e `supabase test db` (B03, B04, B06, B10) verdes no fim da fatia.

### Testes da base (escrever e ver falhar)

- [ ] T005 Atualizar `supabase/tests/database/base_security.test.sql`: B03 vira `set_eq` com as 6 políticas da `rls-matriz.md` (Fatia 2); B04a/B04b com os privilégios de tabela e de coluna da fatia; B06 com `current_terms_versions()` executável só por `authenticated`; B10 passa a inserir em `receipts` (`<uuid>/x.png`, recusado) e a exigir exatamente as 3 políticas `avatars_profile_*` em `storage.objects`; B08a passa a fazer `select` em `groups` (`42501`), como manda o `testes-referencia.md` 9.1. Rodar `supabase test db` e registrar a falha
- [ ] T006 [P] Testes de conversão de erros E09 a E11 em `app/test/core/errors/error_mapper_test.dart` (cada código da tabela 6.8 do `copy.md`, `P0001`/`PIX_KEY_IN_USE`, `StorageException` 413 e `invalid_mime_type`) e o texto de cada `ErrorCode` novo em `app/test/core/errors/error_text_test.dart`
- [ ] T007 [P] Testes U01 a U06 em `app/test/core/format/br_documents_test.dart`, `phone_test.dart` e `pix_key_test.dart`
- [ ] T008 Rodar `flutter test test/core` e registrar a falha de compilação/asserção esperada

### Implementação da base

- [ ] T009 Acrescentar ao `ErrorCode` em `app/lib/core/errors/error_code.dart`: `authWeakPassword`, `authInvalidCode`, `authInvalidEmail`, `authEmailInUse`, `authSamePassword`, `authEmailRateLimited`, `authGoogleFailed`, `pixKeyInUse`, `photoTooLarge`, `photoInvalidType`; mapear em `app/lib/core/errors/error_mapper.dart` (`_authCodes` da tabela 6.8, `PIX_KEY_IN_USE` em `_serverCodes`, `StorageException` por `statusCode == '413'` e `invalid_mime_type`) e os textos em `app/lib/core/errors/error_text.dart`
- [ ] T010 Acrescentar ao `app/lib/l10n/app_pt.arb` **todas** as chaves do `copy.md` seção 6 (6.1 a 6.8), com o mesmo texto, e corrigir `errorAuthEmailNotConfirmed` para o texto atual da seção 5.5 ("Confirme o seu e-mail antes de entrar."); rodar `flutter gen-l10n`
- [ ] T011 [P] Implementar `app/lib/core/format/br_documents.dart` (CPF e CNPJ: `digitsOnly`, `isValidCpf`, `isValidCnpj` com sequência repetida recusada, `formatCpf`, `formatCnpj`)
- [ ] T012 [P] Implementar `app/lib/core/format/phone.dart` (só Brasil: `phoneToE164` com 10 ou 11 dígitos, `formatPhoneE164`)
- [ ] T013 [P] Implementar `app/lib/core/format/pix_key.dart` (`normalizePixKey`, `validatePixKey` por tipo com as regras da tabela do `telas.md` 5.9, `formatPixKey`) e o enum `PixKeyType` em `app/lib/features/auth/domain/pix_key_type.dart` com `@JsonValue`
- [ ] T014 Rodar `flutter test test/core` até verde
- [ ] T015 [P] Componentes em `app/lib/shared/widgets/`: `field_label.dart` (tirar o `_FieldLabel` do login), `password_field.dart` (olho com rótulo para o TalkBack e área de 48), `code_field.dart` (6 dígitos, `AutofillHints.oneTimeCode`, `onCompleted`), `resend_code_button.dart` (60 s com `authResendCodeIn`), `nav_row.dart` (linha com seta, `design-system.md` 7.13), `app_avatar.dart` (foto ou iniciais, `design-system.md` 3.4), `confirm_dialog.dart` (destrutiva, `design-system.md` 7.15), `masked_input_formatters.dart` (CPF, CNPJ, telefone), `loading_button.dart` (botão carregando)
- [ ] T016 Rotas novas em `app/lib/core/router/routes.dart` (`signup`, `confirmEmail`, `forgotPassword`, `terms`, `termsDocument`, `profileEdit`, `profilePix`, `profileEmail`, `profilePassword`), com caminhos do `telas.md` 2.2

**Ponto de controle**: base pronta; as histórias podem começar.

---

## Fase 3: História 1 — Criar a conta por e-mail e confirmar com o código (P1) 🎯 MVP

**Contexto**: cadastro, confirmação e o login completado no que toca o e-mail não confirmado. **Regras**: RF01, RF02, RF04, RF05; ADR 0017. **Contratos**: `AuthRepository.signUp`, `verifySignupCode`, `resendSignupCode`. **Testes**: S01 a S06 (widget), L08 (integração). **Pronto quando**: S01 a S06 verdes e o L08 passa no emulador. **Fora de escopo**: Google (US3).

- [ ] T017 [P] [US1] Testes S01 e S02 em `app/test/features/auth/presentation/signup_screen_test.dart`
- [ ] T018 [P] [US1] Testes S03, S04 e S05 em `app/test/features/auth/presentation/confirm_email_screen_test.dart`
- [ ] T019 [P] [US1] Teste S06 em `app/test/features/auth/presentation/login_screen_test.dart` (acrescentar ao arquivo da fatia 1)
- [ ] T020 [US1] Rodar os três e registrar a falha
- [ ] T021 [US1] `AuthRepository` em `app/lib/features/auth/data/auth_repository.dart`: `signUp`, `verifySignupCode` (`OtpType.email`), `resendSignupCode` (`OtpType.signup`), tudo com `guard` (`contracts/app-servidor.md`)
- [ ] T022 [US1] `pendingEmailProvider` (`Notifier<String?>`, memória) em `app/lib/features/auth/presentation/pending_email_provider.dart`
- [ ] T023 [US1] `SignupScreen` e `SignupController` em `app/lib/features/auth/presentation/signup_screen.dart` e `signup_controller.dart` (`telas.md` 5.2, `signup.png`): validação local (nome vazio ou acima de 80, e-mail vazio, senha abaixo de 8), `goNamed(confirmEmail)` substituindo a pilha
- [ ] T024 [US1] `ConfirmEmailScreen` e controller em `app/lib/features/auth/presentation/confirm_email_screen.dart` (`telas.md` 5.3, `confirmEmail.png`): confirma ao completar o código, limpa o campo no erro, reenviar com 60 s, sem e-mail em memória vai ao login, título sem quebrar o "e-mail" (`research.md`, 14)
- [ ] T025 [US1] Login completado, parte do e-mail: `SnackBar` com a ação Confirmar no `authEmailNotConfirmed` em `app/lib/features/auth/presentation/login_screen.dart` (`telas.md` 5.1, `login.png`), mais o pé "Não tem conta? Criar conta"
- [ ] T026 [US1] Rotas `/signup` e `/confirm-email` em `app/lib/core/router/app_router.dart`, liberadas sem sessão (`arquitetura-app.md`, seção 9)
- [ ] T027 [US1] Rodar S01 a S06 até verde

---

## Fase 4: História 2 — Aceitar os termos (P1)

**Contexto**: `current_terms_versions()`, RLS de `terms_acceptances`, a conferência no roteador e a tela. **Regras**: RF105, RN02. **Contratos**: `current_terms_versions()` (`contratos-api.md`, 9), `TermsRepository`. **Testes**: P10 a P14 (pgTAP), S09, S10 (widget). **Pronto quando**: os cenários verdes; um seed com `1.0` passa direto e uma versão `1.1` local manda à `/terms`. **Fora de escopo**: textos jurídicos (provisório, `telas.md` 5.6).

- [ ] T028 [P] [US2] Testes P10 a P14 (a parte de `terms_acceptances` e `current_terms_versions()`, e o `anon` nas três tabelas) em `supabase/tests/database/account_security.test.sql`, com Ana e Bruno inseridos no começo da transação (`arquitetura-app.md`, 14.4)
- [ ] T029 [P] [US2] Testes S09 em `app/test/features/auth/presentation/terms_screen_test.dart` e S10 em `app/test/core/router/app_router_test.dart`
- [ ] T030 [US2] Rodar e registrar a falha
- [ ] T031 [US2] Migração `supabase/migrations/<ts>_create_current_terms_versions.sql` (`research.md`, 5), com o `revoke` de `public, anon` e o `grant` a `authenticated`
- [ ] T032 [US2] Migração `supabase/migrations/<ts>_account_rls.sql`: privilégios e as 6 políticas da `rls-matriz.md` (Fatia 2) para `profiles`, `profile_private` e `terms_acceptances`, com `(select auth.uid())`
- [ ] T033 [US2] Modelos `LegalDocument`, `TermsVersion` e `TermsStatus` em `app/lib/features/auth/domain/terms.dart` e `TermsRepository` em `app/lib/features/auth/data/terms_repository.dart` (`fetchStatus`, `accept`)
- [ ] T034 [US2] `termsStatusProvider` e `AcceptTermsController` em `app/lib/features/auth/presentation/terms_providers.dart`; invalidar na troca de usuário (`authStateProvider`)
- [ ] T035 [US2] `TermsScreen` (`telas.md` 5.5, `terms.png`) e `TermsDocumentScreen` (`telas.md` 5.6, `termsDocument.png`) em `app/lib/features/auth/presentation/`; versão trocada no meio (`42501`): reler e desmarcar a caixa
- [ ] T036 [US2] Redirecionamento dos termos em `app/lib/core/router/app_router.dart` (`research.md`, 10), com o `refreshListenable` ouvindo também o status dos termos
- [ ] T037 [US2] `supabase db reset` e `supabase test db` (P10 a P14) e `flutter test` (S09, S10) até verde

---

## Fase 5: História 3 — Entrar e sair, inclusive pelo Google (P1)

**Contexto**: Google no login e o Sair definitivo. **Regras**: RF03, RF05, RF07, RF108. **Contratos**: `signInWithGoogle`, `signOut`. **Testes**: S07, E12 (app); M01, M02 (manual, responsável). **Pronto quando**: S07 e E12 verdes; M01 e M02 conferidos no emulador com o ID do cliente web. **Fora de escopo**: token de push no logout (fatia 7).

- [ ] T038 [P] [US3] Teste S07 em `app/test/features/auth/presentation/login_screen_test.dart` e E12 em `app/test/features/auth/data/auth_repository_test.dart` (seletor fechado devolve `false`, sem erro)
- [ ] T039 [US3] Rodar e registrar a falha
- [ ] T040 [US3] `signInWithGoogle` e `signOut` com Google no `AuthRepository` (`research.md`, 8), com o cliente do Google atrás de uma interface para os testes
- [ ] T041 [US3] Login: botão "Continuar com Google", divisor "ou" e "Esqueci minha senha" em `app/lib/features/auth/presentation/login_screen.dart` (`login.png`), os dois botões bloqueados durante o Google
- [ ] T042 [US3] `Env.ensureComplete` passa a exigir `GOOGLE_WEB_CLIENT_ID` em `app/lib/core/env.dart`
- [ ] T043 [US3] Rodar S07 e E12 até verde

---

## Fase 6: História 4 — Recuperar a senha (P2)

**Regras**: RF06; ADR 0017. **Contratos**: `sendRecoveryCode`, `verifyRecoveryCode`, `updatePassword`. **Testes**: S08, L09. **Pronto quando**: S08 verde e L09 no emulador.

- [ ] T044 [P] [US4] Teste S08 em `app/test/features/auth/presentation/forgot_password_screen_test.dart`
- [ ] T045 [US4] Rodar e registrar a falha
- [ ] T046 [US4] Métodos de recuperação no `AuthRepository` e `ForgotPasswordScreen` com controller em `app/lib/features/auth/presentation/forgot_password_screen.dart` (`telas.md` 5.4, `forgotPassword-etapa1.png` e `-etapa2.png`); rota `/forgot-password` liberada sem sessão
- [ ] T047 [US4] Rodar S08 até verde

---

## Fase 7: História 5 — Cuidar do próprio perfil (P2)

**Contexto**: perfil, edição e foto. **Regras**: RF08, RF09, RF10, RF12, RN100, RN101, RN106. **Contratos**: `ProfileRepository` (`contracts/app-servidor.md`). **Testes**: P01 a P09, P15, P16 (pgTAP), A01 a A06 (Deno), S11, S12, S17 (widget), U07 (unitário), L10. **Pronto quando**: todos verdes e L10 no emulador. **Fora de escopo**: telefone visível para outros (RF101), fotos de outras pessoas (RN107).

- [ ] T048 [P] [US5] Testes P01 a P09 em `supabase/tests/database/account_security.test.sql`
- [ ] T049 [P] [US5] Testes P15 e P16 (Storage) no mesmo arquivo
- [ ] T050 [P] [US5] Testes A01 a A06 em `supabase/functions/_tests/avatars_test.ts` (Ana e Bruno logados por senha; arquivos de teste gerados em memória; remove o que enviou)
- [ ] T051 [P] [US5] Testes U07 em `app/test/features/auth/domain/identities_test.dart`, S11 e S17 em `app/test/features/auth/presentation/profile_screen_test.dart` e S12 em `profile_edit_screen_test.dart`
- [ ] T052 [US5] Rodar os quatro e registrar a falha
- [ ] T053 [US5] Migração `supabase/migrations/<ts>_avatars_profile_policies.sql` (3 políticas em `storage.objects`, `research.md`, 6)
- [ ] T054 [US5] Modelos `Profile` e `ProfilePrivate` em `app/lib/features/auth/domain/profile.dart` (`freezed`) e `hasEmailPassword` em `app/lib/features/auth/domain/identities.dart`
- [ ] T055 [US5] `ProfileRepository` em `app/lib/features/auth/data/profile_repository.dart` (`fetchOwn`, `uploadPhoto`, `updateProfile`, `updatePrivate`, `deletePhoto`, `signedPhotoUrl`) e o detector de tipo da imagem pelos primeiros bytes em `app/lib/core/format/image_type.dart` (`research.md`, 12)
- [ ] T056 [US5] `ProfileScreen` real em `app/lib/features/auth/presentation/profile_screen.dart` (`telas.md` 5.7, `profile.png` e `profile-google.png`), com o Sair definitivo
- [ ] T057 [US5] `ProfileEditScreen`, a sheet da foto e o controller em `app/lib/features/auth/presentation/profile_edit_screen.dart` e `profile_edit_controller.dart` (`telas.md` 5.8, `profileEdit.png`, `profileEdit-foto.png`): ordem de gravação foto → `profiles` → `profile_private` → remoção da antiga
- [ ] T058 [US5] Rotas `/profile/edit`, `/profile/email` e `/profile/password` (estas duas voltam ao perfil sem acesso por e-mail e senha, S11) em `app/lib/core/router/app_router.dart`
- [ ] T059 [US5] `supabase db reset`, `supabase test db`, `deno test` e `flutter test` até verde

---

## Fase 8: História 6 — Chave Pix (P2)

**Regras**: RF11, RF12, RN105. **Contratos**: `savePixKey`, `removePixKey`; erro `PIX_KEY_IN_USE`. **Testes**: X01 a X10, N01 a N09 (pgTAP), S13 (widget). **Pronto quando**: todos verdes.

- [ ] T060 [P] [US6] Testes X01 a X10 e N01 a N09 em `supabase/tests/database/account_pix.test.sql` (jogos e valores inseridos como `postgres`; N01 a N09 rodam como Ana logada)
- [ ] T061 [P] [US6] Teste S13 em `app/test/features/auth/presentation/profile_pix_screen_test.dart`
- [ ] T062 [US6] Rodar e registrar a falha
- [ ] T063 [US6] Migração `supabase/migrations/<ts>_pix_key_check_digits.sql` (`research.md`, 3)
- [ ] T064 [US6] Migração `supabase/migrations/<ts>_pix_key_removal_trigger.sql` (`research.md`, 4)
- [ ] T065 [US6] `savePixKey`/`removePixKey` no `ProfileRepository` e `ProfilePixScreen` com controller em `app/lib/features/auth/presentation/profile_pix_screen.dart` (`telas.md` 5.9, `profilePix.png`, `profilePix-tipo.png`, `profilePix-remover.png`): menu suspenso com ícones, máscara por tipo, confirmação destrutiva
- [ ] T066 [US6] Rota `/profile/pix`; `supabase test db` e `flutter test` até verde

---

## Fase 9: História 7 — Trocar e-mail e senha (P3)

**Regras**: RF106, RF107. **Contratos**: `requestEmailChange`, `verifyEmailChange`, `reauthenticate`, `updatePassword`. **Testes**: S14, S15, L11. **Pronto quando**: S14 e S15 verdes e L11 no emulador.

- [ ] T067 [P] [US7] Testes S14 em `app/test/features/auth/presentation/profile_email_screen_test.dart` e S15 em `profile_password_screen_test.dart`
- [ ] T068 [US7] Rodar e registrar a falha
- [ ] T069 [US7] Métodos no `AuthRepository`, `ProfileEmailScreen` (`telas.md` 5.10, `profileEmail-etapa1.png` e `-etapa2.png`) e `ProfilePasswordScreen` (`telas.md` 5.11, `profilePassword.png`) em `app/lib/features/auth/presentation/`
- [ ] T070 [US7] Rodar S14 e S15 até verde

---

## Fase 10: Acabamento e transversais

- [ ] T071 Teste S16 (fonte em 150% em todas as telas da seção 5 do `telas.md`) em `app/test/features/auth/presentation/text_scale_test.dart`, e corrigir os *overflows*
- [ ] T072 [P] Fluxos L08 a L11 em `app/integration_test/account_flows_test.dart`, com o código lido do Mailpit (`research.md`, 16); adaptar `app/integration_test/auth_flow_test.dart` da fatia 1 ao login completado
- [ ] T073 [P] Seed da fatia 2 em `supabase/seed.sql` (`research.md`, 15)
- [ ] T074 [P] CI em `.github/workflows/ci.yml`: Deno no job `database` rodando `_tests/` com o Supabase de pé; job `functions` ignorando `_tests/` (`research.md`, 6)
- [ ] T075 Documentos: `arquitetura-app.md` (seção 12 com a feature real; `core/format` com validação; `core/` com o gerador de UUID), `setup.md` (6.2 com o `client_id` no `config.toml`, seção 3 com a instalação sem `sudo`, se o responsável quiser), `rls-matriz.md` (se algo mudar), `CLAUDE.md` ("Estado atual")
- [ ] T076 Definição de pronto completa (`trabalho-com-agente.md`, seção 5): `dart format`, `dart analyze`, `flutter test`, `supabase db reset`, `supabase test db`, `supabase db lint`, `deno fmt --check`, `deno lint`, `deno test`; conferir a acessibilidade (`design-system.md`, seção 8)
- [ ] T077 `/speckit-converge` e o texto do PR (`trabalho-com-agente.md`, 6.2), com os passos do emulador e os comandos da produção para o responsável

---

## Dependências

- Fase 1 → Fase 2 → histórias.
- US1 e US2 são o MVP: sem elas não se chega à aba Jogos com uma conta nova.
- US2 traz a migração `account_rls`, de que US5 e US6 dependem (leitura e escrita da própria linha).
- US3 e US4 dependem só da base e do `AuthRepository` da US1.
- US7 depende das rotas da US5 (redirecionamento de quem não tem acesso por e-mail e senha).
- Fase 10 depois de todas.

## Paralelismo

- Na base: T006, T007 e T011 a T013 em paralelo; T015 em paralelo com T009 e T010.
- US1: T017, T018 e T019 em paralelo.
- US5: T048 a T051 em paralelo (pgTAP, Deno e Flutter em arquivos diferentes).
- Depois da US2, US3, US4 e US6 podem andar em paralelo.

## Estratégia

1. MVP: Fases 1 e 2, US1 e US2. Uma conta nova chega à aba Jogos com os termos aceitos (L08).
2. Depois, US3 (Google), US5 e US6 (perfil e chave, que a fatia 4 exige), US4 e US7.
3. A fatia só fecha com todos os "Pronto quando" do `plano-implementacao.md` e M01 a M04 conferidos pelo responsável.
