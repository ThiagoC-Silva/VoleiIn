# T09.3 — APK release apontando para o remoto

**Estado:** feito · **Depende de:** T09.1

## Objetivo

Instalar no celular o APK release que fala com o projeto remoto. É o primeiro build release do projeto e a prova da permissão `INTERNET` da T04, que o build de depuração não exige.

## O que já existe

- `app/dart_defines.json` tem o `GOOGLE_WEB_CLIENT_ID`, que é o mesmo no remoto, e o `SUPABASE_URL` e a chave do local. Um `--dart-define` depois do arquivo vence o valor dele (`CLAUDE.md` da raiz).
- O release assina com a chave de debug desta máquina (`signingConfig = debug`), cujo SHA-1 está no cliente Android do Google (T11).
- O APK de depuração instalado tem a sessão do Supabase local guardada no aparelho.

## O que falta

- [x] A partir de `app/`:

  ```
  flutter build apk --release \
    --dart-define-from-file=dart_defines.json \
    --dart-define=SUPABASE_URL=https://zmokpmovphikmobynssy.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave pública do remoto>
  ```

  Anotar o tamanho do APK, para comparar com os de depuração da T04 e da T05.
- [x] `adb uninstall br.com.voleiin`, para o release não herdar a sessão do local, e depois `adb install build/app/outputs/flutter-apk/app-release.apk`.
- [x] Abrir o app: cai na A1. **[Thiago]** Um "Entrar" com um endereço qualquer e uma senha errada responde "E-mail ou senha incorretos." (`invalid_credentials`), e não "Sem conexão…". É a prova de que o release alcança o remoto.
- [x] Se o Google, mais adiante (T09.5), falhar só no release, suspeitar primeiro da redução de código do build release, antes da configuração.

## Resultado

Feito em 2026-10-27.

- **Chave do remoto:** a `publishable` (`sb_publishable_…`), lida pelo MCP do Supabase. A CLI não está logada nesta máquina (`AccessTokenRequiredError`), e o `supabase projects api-keys` da task não roda sem `supabase login`.
- **O primeiro release travou na abertura**, no ícone do Flutter, com `NoSuchMethodError` em `SharedPreferencesApiRegistrar.getAll` no `logcat`. O `shared_preferences_android` 2.5.0 chama o Kotlin por JNI e não trazia regra de R8, que renomeou as classes no build release. O de depuração não reduz código, por isso nunca apareceu.
- **Correção:** `shared_preferences_android` de 2.5.0 para 2.5.4 no `pubspec.lock` (`flutter pub upgrade shared_preferences_android`). É dependência transitiva, o `pubspec.yaml` não muda. A 2.5.2 trouxe o `consumer-rules.pro` que mantém as classes Kotlin. A primeira compilação depois da troca falhou com `Unresolved reference` no Kotlin do plugin, sobra da compilação incremental da 2.5.0; `flutter clean` resolveu. Os 36 testes de widget passam.
- **Tamanho:** 54,0 MB (53.999.223 bytes) o release, contra 107,5 MB do APK de depuração de 2026-10-21.
- **Pacote:** sem `DEBUGGABLE` nos `pkgFlags`, `versionName` 0.1.0.
- **Prova do remoto:** a pedido do Thiago, o Claude operou o celular pelo `adb shell input`, e não o Thiago com o dedo. `teste.t093@example.com` e uma senha qualquer, toque em "Entrar": "E-mail ou senha incorretos.". Nos logs do Auth remoto, às 22:32:45 UTC, `POST /token?grant_type=password` de `Dart/3.13`, 400, `invalid_credentials`. Nenhum e-mail enviado.
- **Preenchimento automático:** na primeira tentativa, o gerenciador de senhas do aparelho já tinha posto no campo o e-mail principal do Thiago e uma senha salva, e o texto digitado entrou colado a eles. Essa tentativa também chegou ao remoto (22:31:09 UTC, `invalid_credentials`, com um endereço sem conta). Ao operar o celular pelo `adb`, conferir a tela antes de digitar.
- **Para a T09.5:** a suspeita do R8 continua valendo para o `google_sign_in`; o que caiu foi só a do `shared_preferences`.

## Pronto quando

O release está instalado, abre na A1 e recebe resposta do remoto.

## Commit

`Registra o APK release apontando para o remoto`
