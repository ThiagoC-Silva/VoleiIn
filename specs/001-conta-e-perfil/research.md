# Pesquisa: Fatia 2 — Conta e perfil

Decisões técnicas que os documentos deixam para a implementação. Nenhuma muda regra. As que puderem ser contestadas depois vão para o `arquitetura-app.md` ou viram ADR no fechamento da fatia (`trabalho-com-agente.md`, seção 10).

## 1. Ambiente da máquina

- **Decisão**: Flutter estável (3.50, Dart 3.14) instalado por `git clone` em `~/development/flutter` e Deno 2.9 em `~/.deno`, os dois no `PATH` pelo `~/.bashrc`, sem `sudo` (autorizado pelo responsável em 12/11/2026).
- **Motivo**: a máquina não tinha nenhum dos dois. O `setup.md` (seção 3) sugere `snap`, que exige `sudo`.
- **Alternativas**: `snap install flutter --classic` (exige `sudo`).

## 2. Ordem das migrações

- **Decisão**: cinco migrações novas, nesta ordem: `create_current_terms_versions` (a política de aceite depende dela), `account_rls`, `avatars_profile_policies`, `pix_key_check_digits`, `pix_key_removal_trigger`.
- **Motivo**: uma migração por assunto (`arquitetura-app.md`, 14.1). As 13 da fatia 1 já estão na produção e não são editadas.

## 3. Dígitos verificadores na constraint

- **Decisão**: `private.is_valid_cpf(text)` e `private.is_valid_cnpj(text)`, `language plpgsql immutable`, com `search_path` vazio. A constraint `profile_private_pix_format` é recriada (`drop constraint` + `add constraint`) chamando as duas para `cpf` e `cnpj`. A sequência de um dígito só é recusada dentro das funções.
- **Motivo**: constraint de `check` só aceita função `immutable`. O esquema `private` não é exposto (ADR 0015).
- **Privilégio**: a constraint roda com o privilégio de quem grava, e sem `execute` o `update` do app dá `42501` (medido nos testes N07 e P08). As duas funções recebem `execute` para `authenticated`; sem `usage` no esquema, o app não as alcança pela API. Registrado na `rls-matriz.md` (Fatia 2).
- **Cuidado**: recriar a constraint valida as linhas existentes. Na produção não há chave cadastrada (sem usuários reais, fatia 1), então não há risco. No ensaio de migração (`setup.md`, 9.2), uma chave inválida faria a migração falhar, e isso é o comportamento desejado.

## 4. *Trigger* da RN105

- **Decisão**: `private.guard_pix_key_removal()`, `security definer`, `before update of pix_key_type, pix_key on public.profile_private`, que só age quando `old.pix_key is not null and new.pix_key is null`. Consulta `public.games` (`receiver_id = new.user_id and status in ('open','confirmed')`) e `public.charges` (`receiver_id = new.user_id and status in ('pending','under_review')`) e levanta `P0001` com `message = 'PIX_KEY_IN_USE'`.
- **Motivo**: `security definer` para ler jogos e valores, que o usuário não lê pelo RLS nesta fatia. Os índices `(receiver_id)` de `games` e `(receiver_id, status)` de `charges` já existem.
- **Corrida com a fatia 4**: o `update` bloqueia a linha de `profile_private`. Para que `create_game` e `change_receiver` não escolham um recebedor que está removendo a chave, essas funções devem ler a linha do recebedor com `for share`. Registro para a fatia 4, não implementado agora.

## 5. `current_terms_versions()`

- **Decisão**: `language sql immutable security invoker`, `set search_path = ''`, `returns table (document public.legal_document, version text)`, com `values ('terms_of_use', '1.0'), ('privacy_policy', '1.0')`. `revoke execute ... from public, anon` e `grant ... to authenticated`.
- **Motivo**: contrato do `contratos-api.md` (seção 9). A política `terms_acceptances_insert_own` chama a função; como o `insert` roda como `authenticated`, o `grant` basta.

## 6. Storage: políticas e teste

- **Decisão**: três políticas em `storage.objects` (`avatars_profile_select_own`, `_insert_own`, `_delete_own`) `to authenticated`, com a condição da `rls-matriz.md`. Testadas em pgTAP (P15, P16, insert direto em `storage.objects`) e em Deno (A01 a A06, pela API do Storage, que é onde o tamanho e o tipo são conferidos).
- **Motivo**: o pgTAP não passa pela API, então não testa os limites do bucket; o Deno não alcança o caso do `update`.
- **CI**: o `avatars_test.ts` precisa do Supabase de pé. Ele passa a rodar no job `database`, depois do `supabase test db`, com `SUPABASE_URL` e a chave pública lidas de `supabase status -o env`. O job `functions` continua com `fmt`, `lint` e os testes que não precisam do Supabase (ignora `_tests/`).

## 7. Supabase Auth no local

- **Decisão** (`setup.md`, 6.1): `enable_confirmations = true`, `double_confirm_changes = false`, `minimum_password_length = 8`, `[auth.rate_limit] email_sent = 30`, modelos `confirmation`, `recovery` e `email_change` em `supabase/templates/` com os assuntos do `copy.md` (6.9).
- **Google**: `[auth.external.google] enabled = true`, `client_id` = o ID do cliente web (identificador público, `setup.md`, 6.2), `secret = "env(SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET)"` e `skip_nonce_check = true` (exigido pelo login nativo no local, comentário do próprio `config.toml`). **Pendência:** o ID do cliente web não está no `app/env/local.json` desta máquina; o responsável informa o valor. Sem ele, o resto da fatia funciona e só M01 e M02 esperam.

## 8. Login com Google no app

- **Decisão**: `google_sign_in` 7.x. `GoogleSignIn.instance.initialize(serverClientId: Env.googleWebClientId)` uma vez; `authenticate()` devolve a conta; `account.authentication.idToken` vai para `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: ...)`. `GoogleSignInException` com `code == canceled` (seletor fechado) vira retorno nulo, sem erro (E12); outra exceção vira `authGoogleFailed`. No Sair, `GoogleSignIn.instance.signOut()` antes do `auth.signOut()` (`telas.md`, 5.7), ignorando falha do Google.
- **Motivo**: a versão 7 trocou a API (`signIn()` deu lugar a `authenticate()`, sobre o Credential Manager no Android). O `idToken` basta para o Supabase; o `accessToken` é opcional.
- **Vinculação (RF108)**: feita pelo Supabase Auth, que liga identidades com o mesmo e-mail verificado. O app não faz nada além do `signInWithIdToken`.

## 9. Fluxos de código (ADR 0017)

| Fluxo | Pedido | Confirmação | Reenvio |
|-------|--------|-------------|---------|
| Cadastro | `signUp(email, password, data: {'name': nome})` | `verifyOTP(type: OtpType.email, email, token)` | `resend(type: OtpType.signup, email)` |
| Senha esquecida | `resetPasswordForEmail(email)` | `verifyOTP(type: OtpType.recovery, email, token)` e `updateUser(UserAttributes(password))` | `resetPasswordForEmail(email)` |
| Troca de e-mail | `updateUser(UserAttributes(email: novo))` | `verifyOTP(type: OtpType.emailChange, email: novo, token)` | `updateUser` de novo |
| Troca de senha | `signInWithPassword(email atual, senha atual)` | `updateUser(UserAttributes(password: nova))` | — |

- O e-mail do código pendente fica num `Notifier` em memória (`pendingEmailProvider`), nunca na rota nem no aparelho (`arquitetura-app.md`, seção 9).
- A contagem de 60 s do Reenviar usa um `Timer` de tela; não decide nada no servidor.

## 10. Conferência dos termos no roteador

- **Decisão**: `termsStatusProvider` (`FutureProvider`, sem `autoDispose`, invalidado na mudança de usuário e depois do aceite) devolve os documentos que faltam aceitar, comparando `current_terms_versions()` com `terms_acceptances` do próprio usuário. O `redirect` do `go_router`, com sessão: se o estado não tem valor (carregando ou erro), ou se falta algum documento, vai para `/terms` (exceto `/terms/:document`); se não falta nada e está em `/terms`, vai para `/games`. A `/terms` mostra os estados carregando, erro e sem conexão do próprio provider (`telas.md`, 3.1).
- **Motivo**: o `redirect` é síncrono. Mandar para a própria `/terms` durante a carga dá o "estado carregando" que o `telas.md` pede sem criar uma rota a mais. O `refreshListenable` passa a ouvir também o provider dos termos.
- **Frase da tela**: `termsSubtitleUpdated` quando a pessoa tem algum aceite anterior de um documento que falta; senão `termsSubtitleFirst` (S09, S10).

## 11. Acesso por e-mail e senha (U07)

- **Decisão**: `hasEmailPassword(identities)` é verdadeiro quando alguma identidade do usuário tem `provider == 'email'`. As rotas `/profile/email` e `/profile/password` redirecionam para `/profile` quando é falso (S11).

## 12. Foto: escolha, tipo e envio

- **Decisão**: `image_picker` com `maxWidth: 1024, maxHeight: 1024` (RN106). O tipo é deduzido dos primeiros bytes do arquivo (assinaturas de JPEG, PNG e WebP), e não do nome nem do `mimeType` do `XFile`, que pode vir nulo. Tipo fora dos três: `photoInvalidType` sem enviar. Envio com `uploadBinary(path, bytes, fileOptions: FileOptions(contentType: tipo, upsert: false))` em `profiles/{uid}/{uuid}.{ext}`. A imagem exibida vem de `createSignedUrl(path, 3600)`.
- **UUID do nome do arquivo**: 16 bytes de `Random.secure()` formatados como UUID v4, numa função de `core/`, sem pacote novo. O `gen_random_uuid()` do banco não serve, porque o envio vem antes da gravação.
- **Motivo**: a ordem de gravação do `telas.md` (5.8) e o "nome sempre novo" da `rls-matriz.md`.

## 13. Validação e formatação no app

- **Decisão**: funções puras em `core/format/`: `br_documents.dart` (CPF e CNPJ: dígitos, validação, máscara), `phone.dart` (digitado ↔ E.164 ↔ exibição, só Brasil, 10 ou 11 dígitos) e `pix_key.dart` (normalização, validação por tipo, exibição). Máscaras dos campos com `TextInputFormatter` próprios em `shared/widgets/`, sem pacote.
- **Motivo**: são formato e validação de entrada, não regra de negócio; o banco decide de verdade (constraints). O `domain` fica só com modelos (`arquitetura-app.md`, seção 2).

## 14. Título com "e-mail" que não quebra

- **Decisão**: o widget do título da `/confirm-email` troca o hífen por U+2011 (hífen não separável) na exibição, mantendo o ARB igual ao `copy.md`. Se a fonte não tiver o glifo, usa um `Text.rich` com o "e-mail" num `WidgetSpan` sem quebra.
- **Motivo**: conferência dos PNGs (`docs/ui/referencias/README.md`).

## 15. Seed da fatia 2

- **Decisão** (`setup.md`, seção 8): Ana com telefone visível (`+5586999991234`) e chave CPF `52998224725`; Bruno com apelido `Bruninho` e telefone oculto (`+5586988887777`); Carla e Diego sem dados opcionais. Aceites na versão `1.0`, iguais a `current_terms_versions()`.
- **Motivo**: o `setup.md` pede "apelido, telefone visível e oculto, chave Pix" sem fixar valores. L10 muda o apelido da Ana para `Aninha` e devolve o original; por isso a Ana começa sem apelido.

## 16. Integração no emulador

- **Decisão**: L08 a L11 em `app/integration_test/account_flows_test.dart`, lendo o código pela API do Mailpit (`http://10.0.2.2:54324/api/v1/...`) com o pacote `http`, que já é dependência. Rodam no emulador do responsável; nesta máquina não há SDK Android configurado para o agente.
