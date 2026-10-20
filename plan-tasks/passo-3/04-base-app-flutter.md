# T04 — Base do app Flutter

**Estado:** feito · **Depende de:** T01

## Objetivo

Projeto Flutter Android pronto para os passos seguintes: `applicationId` `br.com.voleiin`, `minSdk` 24, cliente Supabase configurado por `--dart-define`, tema e raiz que escolhe a tela pela sessão.

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
