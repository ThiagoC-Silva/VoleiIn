# Contrato app ↔ servidor: Fatia 2

O contrato oficial está no `docs/contratos-api.md` (seção 9, "Acesso direto do app", e `current_terms_versions()`). Esta página só lista, por repositório do app, as chamadas que a fatia faz e o erro que cada uma pode devolver. Os textos dos erros estão no `docs/copy.md` (5.5 e 6.8).

## `AuthRepository` (Supabase Auth e Google)

| Método | Chamada | Erros convertidos |
|--------|---------|-------------------|
| `signInWithPassword` | `auth.signInWithPassword` | `authInvalidCredentials`, `authEmailNotConfirmed`, `authRateLimited` |
| `signUp(name, email, password)` | `auth.signUp(data: {'name'})` | `authWeakPassword`, `authInvalidEmail`, `authEmailRateLimited` |
| `verifySignupCode(email, code)` | `auth.verifyOTP(type: email)` | `authInvalidCode` |
| `resendSignupCode(email)` | `auth.resend(type: signup)` | `authEmailRateLimited` |
| `sendRecoveryCode(email)` | `auth.resetPasswordForEmail` | `authEmailRateLimited` |
| `verifyRecoveryCode(email, code)` | `auth.verifyOTP(type: recovery)` | `authInvalidCode` |
| `updatePassword(password)` | `auth.updateUser(password)` | `authSamePassword`, `authWeakPassword` |
| `requestEmailChange(newEmail)` | `auth.updateUser(email)` | `authEmailInUse`, `authInvalidEmail`, `authEmailRateLimited` |
| `verifyEmailChange(newEmail, code)` | `auth.verifyOTP(type: emailChange)` | `authInvalidCode` |
| `reauthenticate(password)` | `auth.signInWithPassword(email atual)` | `authInvalidCredentials` (a tela mostra `passwordCurrentWrong`) |
| `signInWithGoogle()` → `bool` | `GoogleSignIn.authenticate` + `auth.signInWithIdToken` | `false` se o seletor foi fechado (E12); `authGoogleFailed` |
| `signOut()` | `GoogleSignIn.signOut` + `auth.signOut` | Sem conexão: `noConnection` |
| `currentEmail`, `hasEmailPassword` | `auth.currentUser` | — |

## `ProfileRepository` (banco e Storage)

| Método | Chamada | Erros |
|--------|---------|-------|
| `fetchOwn()` | `select` em `profiles` e `profile_private`, `eq(id/user_id, uid)` | `noConnection`, `internalError` |
| `uploadPhoto(bytes, type)` → `path` | `storage.from('avatars').uploadBinary('profiles/{uid}/{uuid}.{ext}', upsert: false)` | `photoTooLarge` (413), `photoInvalidType` |
| `updateProfile(name, nickname, photoPath)` | `update` em `profiles` | Constraints → `internalError` |
| `updatePrivate(phone, phoneVisible)` | `update` em `profile_private` | Constraints → `internalError` |
| `savePixKey(type, key)` / `removePixKey()` | `update` em `profile_private` | `pixKeyInUse` (*trigger* da RN105) |
| `deletePhoto(path)` | `storage.from('avatars').remove([path])` | Ignorado (`telas.md`, 5.8) |
| `signedPhotoUrl(path)` | `createSignedUrl(path, 3600)` | Sem foto, o avatar mostra as iniciais |

## `TermsRepository`

| Método | Chamada | Erros |
|--------|---------|-------|
| `fetchStatus()` → `TermsStatus` | `rpc('current_terms_versions')` e `select document, version from terms_acceptances` | `noConnection`, `internalError` |
| `accept(List<TermsVersion>)` | `insert` em `terms_acceptances`, uma linha por documento que falta | `42501` (versão trocada): o app relê o status e mostra a tela de novo |
