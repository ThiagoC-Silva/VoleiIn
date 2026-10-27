# T09.3 — APK release apontando para o remoto

**Estado:** a fazer · **Depende de:** T09.1

## Objetivo

Instalar no celular o APK release que fala com o projeto remoto. É o primeiro build release do projeto e a prova da permissão `INTERNET` da T04, que o build de depuração não exige.

## O que já existe

- `app/dart_defines.json` tem o `GOOGLE_WEB_CLIENT_ID`, que é o mesmo no remoto, e o `SUPABASE_URL` e a chave do local. Um `--dart-define` depois do arquivo vence o valor dele (`CLAUDE.md` da raiz).
- O release assina com a chave de debug desta máquina (`signingConfig = debug`), cujo SHA-1 está no cliente Android do Google (T11).
- O APK de depuração instalado tem a sessão do Supabase local guardada no aparelho.

## O que falta

- [ ] A partir de `app/`:

  ```
  flutter build apk --release \
    --dart-define-from-file=dart_defines.json \
    --dart-define=SUPABASE_URL=https://zmokpmovphikmobynssy.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave pública do remoto>
  ```

  Anotar o tamanho do APK, para comparar com os de depuração da T04 e da T05.
- [ ] `adb uninstall br.com.voleiin`, para o release não herdar a sessão do local, e depois `adb install build/app/outputs/flutter-apk/app-release.apk`.
- [ ] Abrir o app: cai na A1. **[Thiago]** Um "Entrar" com um endereço qualquer e uma senha errada responde "E-mail ou senha incorretos." (`invalid_credentials`), e não "Sem conexão…". É a prova de que o release alcança o remoto.
- [ ] Se o Google, mais adiante (T09.5), falhar só no release, suspeitar primeiro da redução de código do build release, antes da configuração.

## Resultado

## Pronto quando

O release está instalado, abre na A1 e recebe resposta do remoto.

## Commit

`Registra o APK release apontando para o remoto`
