# Data Model: Conta e perfil (fatia 2)

As tabelas, colunas e constraints são as de `docs/modelo-dados.md`, 4.1. Os privilégios e as políticas são os de `docs/rls-matriz.md`, fatia 2. Este arquivo só diz **o que a fatia acrescenta** e em que migração.

## Migrações

Criadas com `supabase migration new`, nesta ordem:

| Migração | Conteúdo | Documento |
|----------|----------|-----------|
| `create_current_terms_versions` | `public.current_terms_versions()`, com `revoke` de `public` e `anon` e `grant` a `authenticated` | `contratos-api.md`, seção 9 |
| `create_pix_key_validators` | `private.is_valid_cpf(text)` e `private.is_valid_cnpj(text)`; a constraint `profile_private_pix_format` passa a conferir os dígitos | `modelo-dados.md`, 4.1; X01 a X10 |
| `create_pix_key_removal_guard` | *Trigger* da RN105 em `profile_private`, que devolve `PIX_KEY_IN_USE` | `modelo-dados.md`, 4.1; N01 a N09 |
| `account_rls` | Privilégios por coluna e as seis políticas das três tabelas | `rls-matriz.md`, fatia 2; P01 a P14 |
| `avatars_profile_policies` | As três políticas de `storage.objects` para `avatars/profiles/{uid}/` | `rls-matriz.md`, fatia 2; P15, P16, A01 a A06 |

Nenhuma tabela, coluna ou enum novo.

## Modelos do app (`features/auth/domain`)

| Modelo | Origem | Campos |
|--------|--------|--------|
| `Profile` | `profiles` | `id`, `name`, `nickname`, `displayName`, `photoPath` |
| `ProfilePrivate` | `profile_private` | `phone`, `phoneVisible`, `pixKeyType`, `pixKey` |
| `PixKeyType` | enum `pix_key_type` | `cpf`, `cnpj`, `email`, `phone`, `random` |
| `LegalDocument` | enum `legal_document` | `termsOfUse`, `privacyPolicy` |
| `TermsVersion` | `current_terms_versions()` e `terms_acceptances` | `document`, `version` |
| `TermsStatus` | calculado no provider | `current`, `missing`, `hadPreviousAcceptance` |
| `OwnProfile` | as duas leituras juntas | `profile`, `private` |

- `freezed` e `json_serializable`, com `field_rename: snake` (`arquitetura-app.md`, seção 4).
- `TermsStatus` e `OwnProfile` não vêm de JSON: são montados na camada `data` ou no provider.
- O modelo não calcula regra. CPF, CNPJ e telefone (conferência e formato) ficam em `core/format/`. A conferência, a normalização e a exibição da chave **por tipo** ficam em `features/auth/domain/pix_key.dart`, ao lado do enum, para o `core` não depender da feature.

## Estado em memória

Nada disto vai para o aparelho nem para a rota (`arquitetura-app.md`, seção 9):

| Provider | Guarda | Vive até |
|----------|--------|----------|
| `accessDraftProvider` | Nome, e-mail e senha do cadastro ou do login em andamento | A sessão começar ou o app fechar |
| `passwordRecoveryInProgressProvider` | Se a `/forgot-password` está entre o código e a senha (R2) | A tela fechar ou a senha ser gravada |
| `termsStatusProvider` | Resultado da conferência dos termos (R3) | A sessão acabar ou o aceite ser gravado |

## Seed

`supabase/seed.sql` passa a ter os perfis completos da fatia 2 (`setup.md`, seção 8): apelido, telefone visível e oculto e chave Pix, com valores que passam nas constraints novas.
