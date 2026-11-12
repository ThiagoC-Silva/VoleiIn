# Contratos internos do app: repositórios da feature `auth`

A fronteira com o servidor está em `docs/contratos-api.md`, seção 9, e não muda aqui. Este arquivo descreve **o que cada repositório expõe às telas**, para os testes de widget trocarem por dublês (`docs/arquitetura-app.md`, seção 11). Todo método converte a falha em `AppException` (`arquitetura-app.md`, seção 7).

## `AuthRepository` (`features/auth/data/auth_repository.dart`)

| Membro | Chama | Observação |
|--------|-------|------------|
| `hasSession`, `currentUserId`, `currentEmail`, `onAuthStateChange` | Sessão do Supabase Auth | RF05 |
| `hasEmailAccess` | Identidades da conta | Verdadeiro com a identidade `email` (`telas.md`, 5.7; U07) |
| `signInWithPassword({email, password})` | `signInWithPassword` | RF04 |
| `signInWithGoogle()` → `bool` | `GoogleIdTokenSource` e `signInWithIdToken` | Falso quando a pessoa fecha o seletor, sem erro (E12). RF03, RF108 |
| `signUp({name, email, password})` | `signUp`, com `name` nos metadados | RF01 |
| `confirmSignup({email, code, password})` | `verifyOTP` tipo `email` e, em seguida, `updateUser` com a senha (research R5) | RF02 |
| `resendSignupCode(email)` | `resend` tipo `signup` | |
| `sendPasswordRecovery(email)` | `resetPasswordForEmail` | RF06. Serve também para reenviar |
| `verifyRecoveryCode({email, code})` | `verifyOTP` tipo `recovery` | Cria a sessão |
| `updatePassword(newPassword)` | `updateUser` | RF06, RF107 |
| `verifyCurrentPassword(password)` | `signInWithPassword` no e-mail da conta | RF107 |
| `requestEmailChange(newEmail)` | `updateUser` com o e-mail | RF106. Serve também para reenviar |
| `confirmEmailChange({newEmail, code})` | `verifyOTP` tipo `email_change` | |
| `signOut()` | `signOut` do Supabase Auth e do Google | RF07 |

## `GoogleIdTokenSource` (`features/auth/data/google_id_token_source.dart`)

| Membro | Devolve |
|--------|---------|
| `idToken()` | O ID token da conta escolhida, ou nulo se a pessoa fechou o seletor. Outra falha lança `AppException(authGoogleFailed)` |
| `signOut()` | Encerra a sessão do Google. Falha é ignorada |

## `ProfileRepository` (`features/auth/data/profile_repository.dart`)

| Membro | Chama | Erros próprios |
|--------|-------|----------------|
| `fetchOwn()` → `OwnProfile` | `select` da própria linha de `profiles` e de `profile_private` | |
| `avatarUrl(photoPath)` | URL assinada no bucket `avatars` | |
| `uploadAvatar({bytes, extension})` → caminho | Envio para `profiles/{uid}/{uuid}.{ext}`, sem sobrescrever | `photoTooLarge`, `photoInvalidType` |
| `updateProfile({name, nickname, photoPath})` | `update` em `profiles` | |
| `updateContact({phone, phoneVisible})` | `update` em `profile_private` | |
| `deleteAvatar(photoPath)` | Remoção no bucket | |
| `updatePixKey({type, key})` | `update` em `profile_private`. Os dois nulos removem a chave | `pixKeyInUse` |

A ordem do Salvar da edição (`telas.md`, 5.8; S12) é do controller: `uploadAvatar`, `updateProfile`, `updateContact`, `deleteAvatar`.

## `TermsRepository` (`features/auth/data/terms_repository.dart`)

| Membro | Chama |
|--------|-------|
| `currentVersions()` → `List<TermsVersion>` | `rpc('current_terms_versions')` |
| `ownAcceptances()` → `List<TermsVersion>` | `select` em `terms_acceptances` |
| `accept(List<TermsVersion>)` | `insert` de uma linha por documento, só com `user_id`, `document` e `version` |
