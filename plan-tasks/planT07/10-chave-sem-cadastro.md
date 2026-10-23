# T07.10 — Celular: build com chave sem cadastro (cenário 22)

**Estado:** a fazer · **Depende de:** T07.9

## Objetivo

Descobrir o que o app mostra quando o APK foi assinado com uma chave cujo SHA-1 não está no cliente Android do Google. Isso vai acontecer de verdade numa máquina nova, na chave própria do passo 10 ou no APK de outra pessoa.

O risco: `_traduzirGoogle` trata `canceled` como "a pessoa fechou o seletor" e volta sem mensagem. Se o Google sinalizar a chave sem cadastro como `canceled`, o toque em "Entrar com Google" não faz nada e ninguém sabe por quê. O esperado é "A entrada pelo Google não está configurada neste aparelho. Entre com e-mail e senha."

## O que já existe

- `apksigner` em `~/Android/Sdk/build-tools/37.0.0/` e `keytool` do JDK.
- O APK de debug da T07.7.

## O que falta

Tudo no scratchpad; `build.gradle.kts` e `~/.android/debug.keystore` não são tocados.

- [ ] Chave descartável:
  ```
  keytool -genkeypair -keystore <scratchpad>/descartavel.jks -alias descartavel \
    -keyalg RSA -keysize 2048 -validity 1 -storepass descartavel -dname "CN=descartavel"
  ```
- [ ] Reassinar o APK de debug:
  ```
  apksigner sign --ks <scratchpad>/descartavel.jks --ks-pass pass:descartavel \
    --out <scratchpad>/app-descartavel.apk build/app/outputs/flutter-apk/app-debug.apk
  ```
- [ ] `adb uninstall br.com.voleiin` (assinaturas diferentes não se sobrepõem; a sessão do app no aparelho se perde), `adb install` do reassinado, "Entrar com Google".
- [ ] Anotar a mensagem da tela e o que o `adb logcat` mostra do `google_sign_in` e do Credential Manager. Se a tela não deixar claro o `GoogleSignInExceptionCode`, um `debugPrint` temporário, fora do commit, mostra o código.
- [ ] Se vier `canceled` ou cair no genérico: decidir com o Thiago como distinguir (o código sozinho pode não bastar) e corrigir `_traduzirGoogle` e o teste.
- [ ] Desinstalar o reassinado e reinstalar o build normal; "Entrar com Google" volta a funcionar.
- [ ] Registrar no `CLAUDE.md` da raiz, junto do passo do SHA-1, o sintoma de uma máquina sem cadastro.

## Resultado

_Preenchido na execução: o código, a mensagem e a decisão._

## Pronto quando

O código real está anotado, a tela mostra uma mensagem que leva ao problema (ou a divergência está registrada com decisão), e o app normal está de volta no aparelho.

## Commit

`Trata a chave sem cadastro na entrada pelo Google`, se houver correção; senão, a linha do `CLAUDE.md` entra na T07.11.
