# Modelo de dados: Fatia 2 — Conta e perfil

As tabelas já existem desde a fatia 1 (`docs/modelo-dados.md`, 4.1). Esta fatia não cria tabela nem coluna: só funções, uma constraint recriada, uma *trigger*, privilégios e políticas. O que vale está no documento citado em cada linha.

## Banco

| Objeto | Mudança | Fonte |
|--------|---------|-------|
| `profiles` | `select` de todas as colunas e `update` de `name`, `nickname`, `photo_path` para `authenticated`; políticas `profiles_select_own` e `profiles_update_own` | `rls-matriz.md`, Fatia 2 |
| `profile_private` | `select` e `update` de `phone`, `phone_visible`, `pix_key_type`, `pix_key`; políticas `_select_own` e `_update_own` | idem |
| `profile_private_pix_format` | Recriada: CPF e CNPJ passam por `private.is_valid_cpf` e `private.is_valid_cnpj` | `modelo-dados.md`, 4.1; X01 a X10 |
| `private.guard_pix_key_removal()` | *Trigger* `before update` que recusa a remoção da chave nos casos da RN105 com `PIX_KEY_IN_USE` | `modelo-dados.md`, 4.1; N01 a N09 |
| `terms_acceptances` | `select` e `insert` de `user_id`, `document`, `version`; políticas `_select_own` e `_insert_own` (só a versão vigente) | `rls-matriz.md`, Fatia 2 |
| `public.current_terms_versions()` | Nova; `terms_of_use` e `privacy_policy` na `1.0` | `contratos-api.md`, 9; P10 |
| `storage.objects` (bucket `avatars`) | `avatars_profile_select_own`, `_insert_own`, `_delete_own`, pasta `profiles/{uid}/` | `rls-matriz.md`, Fatia 2; P15, P16, A01 a A06 |

## App (`features/auth/domain`)

Modelos `freezed` com JSON em `snake_case` (`arquitetura-app.md`, seção 4). Sem regra.

| Modelo | Campos | Origem |
|--------|--------|--------|
| `Profile` | `id`, `name`, `nickname?`, `displayName`, `photoPath?` | `profiles` |
| `ProfilePrivate` | `userId`, `phone?`, `phoneVisible`, `pixKeyType?`, `pixKey?` | `profile_private` |
| `PixKeyType` | `cpf`, `cnpj`, `email`, `phone`, `random` (`@JsonValue`) | enum `pix_key_type` |
| `LegalDocument` | `termsOfUse` (`terms_of_use`), `privacyPolicy` (`privacy_policy`) | enum `legal_document` |
| `TermsVersion` | `document`, `version` | `current_terms_versions()` |
| `TermsStatus` | `missing` (documentos com a versão a aceitar), `hadPreviousAcceptance` | Calculado no repositório a partir das duas leituras; só decide a navegação e a frase da tela |

## Estados de tela que dependem de dado

| Estado | Onde fica | Vida |
|--------|-----------|------|
| E-mail do código pendente | `pendingEmailProvider` (memória) | Até o código ser confirmado ou o app fechar |
| Conferência dos termos | `termsStatusProvider` (memória) | Até a sessão mudar ou o aceite ser gravado |
| Etapa da recuperação de senha e da troca de e-mail | Estado da própria tela | Enquanto a tela está aberta |
