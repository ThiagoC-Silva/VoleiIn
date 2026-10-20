# T04 — Base do app Flutter

**Estado:** feito · **Depende de:** T01, T11

## Objetivo

Projeto Flutter Android pronto para os passos seguintes: `applicationId` `br.com.voleiin`, `minSdk` 24, cliente Supabase e cliente Google configurados por `--dart-define`, tema e raiz que escolhe a tela pela sessão.

## Reaberta em 2026-10-20 — senha e Google

A entrada pelo Google é nativa, pelo pacote `google_sign_in` (ver as decisões no [README](README.md) e `docs/stack.md`, Autenticação). Depende do cliente web criado na T11.

### O que falta

- [x] `app/pubspec.yaml`: `google_sign_in`, na versão estável atual. `app/CLAUDE.md` pede justificar pacote novo por custo e tamanho: o custo é zero, a justificativa está em `docs/stack.md`, e o tamanho se mede no APK release antes e depois. Anotar a diferença para a T10.
- [x] `app/lib/core/`:
  - `GOOGLE_WEB_CLIENT_ID` por `String.fromEnvironment`, no padrão de `supabase.dart`: sem o valor, o app falha cedo com a mesma mensagem apontando o `CLAUDE.md`;
  - `GoogleSignIn.instance.initialize(serverClientId: ...)` no `main.dart`, depois de `iniciarSupabase()`.
- [x] `CLAUDE.md` da raiz:
  - `--dart-define=GOOGLE_WEB_CLIENT_ID=<id do cliente web>` nos dois `flutter run` (emulador e celular físico), dizendo de onde sai o valor (T11);
  - em "Por aparelho e por máquina, uma vez": cadastrar o SHA-1 da chave de debug da máquina no cliente Android do Google Cloud, com `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`. Sem ele, o login pelo Google falha nos builds daquela máquina, como o pareamento do `adb`;
  - o APK release também assina com a chave de debug de quem o gera (`signingConfig = debug` em `build.gradle.kts`), até a chave própria do passo 10.

### Feito em 2026-10-20

- `google_sign_in` ^7.2.0. A leitura do ID e a inicialização ficam em `app/lib/core/google.dart` (`iniciarGoogle`), no mesmo padrão de `supabase.dart`, chamada no `main.dart` depois de `iniciarSupabase()`.
- APK release (todas as arquiteturas): 52.722.572 bytes antes e 53.144.602 depois, **+412 KB** (0,8%). Vai para a T10.
- `dart analyze` sem erro e `flutter test` com os 10 testes passando.
- A falha de `flutter run` sem `GOOGLE_WEB_CLIENT_ID` não foi vista num aparelho: não havia celular conectado. O `StateError` é o mesmo de `supabase.dart`; conferir no primeiro `flutter run` da T07.

### Pronto quando

- `dart analyze` sem erro.
- `flutter run` sem `GOOGLE_WEB_CLIENT_ID` falha com a mensagem.

### Commit

`Acrescenta o google_sign_in e o cliente web do Google ao app`

## O que já existe

Commitado em `a9a99cf`:
- `app/pubspec.yaml` — `flutter_riverpod`, `supabase_flutter`.
- `app/lib/main.dart`, `app/lib/core/supabase.dart` (lê `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`), `app/lib/core/tema.dart`, `app/lib/core/rotas.dart` (`Raiz`: sem sessão → `EntrarTela`; com sessão → `InicioTela`).
- `app/lib/features/feed/inicio_tela.dart` — tela provisória (nome, e-mail, trocar e-mail, sair); o feed do passo 5 toma o lugar dela.
- `app/android/app/build.gradle.kts` — `namespace` e `applicationId` `br.com.voleiin`.
- `app/CLAUDE.md`.

## O que falta

- [x] `app/android/app/src/main/AndroidManifest.xml`: declarar `<uses-permission android:name="android.permission.INTERNET"/>`. Hoje só os manifestos de debug e profile têm, e um APK release não alcançaria o Supabase.
- [x] `android:label="voleiin"` → `"VoleiIn"`.
- [x] `build.gradle.kts`: `minSdk = 24` explícito, no lugar de `flutter.minSdkVersion`, para o build não mudar sozinho quando o Flutter subir o padrão. O TODO já resolvido do `applicationId` saiu junto.
- [x] `CLAUDE.md` da raiz, seção Comandos: tirar "O projeto Flutter ainda não foi inicializado" e registrar:
  - `flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave de supabase status>` (emulador falando com o Supabase local);
  - `flutter test`;
  - `dart analyze` e o motivo abaixo.
- [x] Contorno do analyzer: `flutter analyze` quebra com `FormatException` no servidor LSP por causa do "Á" em "Área de trabalho". **O link simbólico previsto não resolve**: o Dart resolve o caminho real e manda o "Á" do mesmo jeito. O contorno é `dart analyze`, que usa outro protocolo, roda do caminho real e aplica o mesmo `analysis_options.yaml` (conferido com um erro proposital). Registrado no `CLAUDE.md` da raiz.
- [x] Conferir que `app/.gitignore` deixa de fora `.idea/`, `*.iml`, `.dart_tool/` e `build/` antes do `git add app/`.

## Pronto quando

- `dart analyze` sem erro.
- `flutter build apk --release --dart-define=...` gera o APK, e o manifesto mesclado em `build/app/intermediates/merged_manifest/release/` tem `android.permission.INTERNET`, `minSdkVersion="24"` e `android:label="VoleiIn"`. O build debug não serve de prova: o manifesto de debug já declara INTERNET.
- `git status` depois do commit não mostra `build/`, `.dart_tool/` nem `.idea/`.

## Commit

O projeto já entrou em `a9a99cf`. O que falta vai em: `Libera a internet no APK release e registra os comandos do Flutter`
