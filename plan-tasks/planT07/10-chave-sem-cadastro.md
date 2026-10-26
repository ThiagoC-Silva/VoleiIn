# T07.10 — Celular: build com chave sem cadastro (cenário 22)

**Estado:** feito · **Depende de:** T07.9

## Objetivo

Descobrir o que o app mostra quando o APK foi assinado com uma chave cujo SHA-1 não está no cliente Android do Google. Isso vai acontecer de verdade numa máquina nova, na chave própria do passo 10 ou no APK de outra pessoa.

O risco: `_traduzirGoogle` trata `canceled` como "a pessoa fechou o seletor" e volta sem mensagem. Se o Google sinalizar a chave sem cadastro como `canceled`, o toque em "Entrar com Google" não faz nada e ninguém sabe por quê. O esperado é "A entrada pelo Google não está configurada neste aparelho. Entre com e-mail e senha."

## O que já existe

- `apksigner` em `~/Android/Sdk/build-tools/37.0.0/` e `keytool` do JDK.
- O APK de debug da T07.7.

## O que falta

Tudo no scratchpad; `build.gradle.kts` e `~/.android/debug.keystore` não são tocados.

- [x] Chave descartável:
  ```
  keytool -genkeypair -keystore <scratchpad>/descartavel.jks -alias descartavel \
    -keyalg RSA -keysize 2048 -validity 1 -storepass descartavel -dname "CN=descartavel"
  ```
- [x] Reassinar o APK de debug:
  ```
  apksigner sign --ks <scratchpad>/descartavel.jks --ks-pass pass:descartavel \
    --out <scratchpad>/app-descartavel.apk build/app/outputs/flutter-apk/app-debug.apk
  ```
- [x] `adb uninstall br.com.voleiin` (assinaturas diferentes não se sobrepõem; a sessão do app no aparelho se perde), `adb install` do reassinado, "Entrar com Google".
- [x] Anotar a mensagem da tela e o que o `adb logcat` mostra do `google_sign_in` e do Credential Manager. Se a tela não deixar claro o `GoogleSignInExceptionCode`, um `debugPrint` temporário, fora do commit, mostra o código.
- [x] Se vier `canceled` ou cair no genérico: decidir com o Thiago como distinguir (o código sozinho pode não bastar) e corrigir `_traduzirGoogle` e o teste.
- [x] Desinstalar o reassinado e reinstalar o build normal; "Entrar com Google" volta a funcionar.
- [x] Registrar no `CLAUDE.md` da raiz, junto do passo do SHA-1, o sintoma de uma máquina sem cadastro.

## Resultado

Executado em 2026-10-26 no Motorola Edge 60 Pro, com o APK de debug do `main` reassinado por uma chave descartável no scratchpad (SHA-1 `95:6B:12:…`). `build.gradle.kts` e `~/.android/debug.keystore` não foram tocados.

**O que a tela mostrou, antes da correção:** "Entrar com Google" abre o seletor com as duas contas, a conta é escolhida e a A1 volta **sem mensagem nenhuma**. O risco da task se confirmou.

**O código**, lido com um `print` temporário, fora do commit:

| Caso | `GoogleSignInException.code` | `description` |
| --- | --- | --- |
| Chave sem cadastro | `canceled` | `[16] Account reauth failed.` |
| A pessoa fecha o seletor com "voltar" | `canceled` | `[16] Cancelled by user.` |

O `google_sign_in_android` 7.2.18 só produz `canceled` a partir de `GetCredentialCancellationException`, e o Play Services usa essa exceção nos dois casos. O status 16 também é o mesmo (`CANCELED`). Só o texto em inglês do Play Services separa os dois, e ele não é API documentada.

**O `adb logcat`** mostra a causa real, do lado do Play Services:
- `W Auth: [GetTokenResponseHandler] Server returned error: This android application is not registered to use OAuth2.0, please confirm the package name and SHA-1 certificate fingerprint match what you registered in Google Developer Console.`
- `W Auth.Api.Credentials: cwsp: [8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE].`
- seguido de `cwsp: [16] Account reauth failed.`, que é o que chega ao app.

**Decisão do Thiago:** o silêncio fica restrito ao `canceled` cuja `description` contém "Cancelled by user". Qualquer outro `canceled` mostra a falha genérica, "Não foi possível entrar com o Google. Entre com e-mail e senha.". Se o Play Services mudar o texto, quem fecha o seletor passa a ver a mensagem: a tela fica mais barulhenta, mas nunca muda. A mensagem genérica, e não a de "não está configurada neste aparelho", porque não se sabe se "Account reauth failed" vem só da chave sem cadastro.

**Divergência com o roteiro:** o esperado do cenário 22 em `07-e2e-local.md` era "não está configurada neste aparelho". Pela decisão acima, a tela mostra a genérica. A T07.11 registra isso no resultado do cenário.

**Correção:** `_traduzirGoogle` virou a função de topo `traduzirGoogle` em `app/lib/dados/auth_repositorio.dart`, que devolve nulo para o seletor fechado. Testes novos em `app/test/dados/auth_repositorio_test.dart`. Antes não havia teste da tradução, e o "e o teste" da task se cumpre com o arquivo novo. `dart analyze` sem erro; `flutter test` com 31 testes.

**Conferido no aparelho com a correção**, reassinado com a chave descartável: escolher a conta mostra a mensagem genérica, e fechar o seletor com "voltar" volta sem mensagem.

**Volta ao app normal:** desinstalado o reassinado e instalado o build de debug com a correção, assinado pela chave de debug da máquina (SHA-1 `A6:12:57:…`, a mesma assinatura do app de antes da task). As duas primeiras tentativas pelo Google, às 11:31 e às 11:32, **falharam igual à chave descartável**: o logcat repetiu `not registered to use OAuth2.0`, embora o SHA-1 fosse o cadastrado. O Play Services guarda por alguns minutos o veredito do pacote. Depois de esperar, sem limpar nada no celular, a tentativa das 11:42 entrou direto em "Olá, Bruno", a conta do cenário 18. **Quem cadastrar o SHA-1 de uma máquina nova depois de uma falha deve esperar uns dez minutos antes de concluir que o cadastro não pegou.**

**`CLAUDE.md` da raiz:** o sintoma de máquina sem SHA-1 cadastrado entrou junto do passo do SHA-1, com a mensagem da tela e as duas linhas do logcat.

**Para a operação pelo `adb`:**
- O app pode abrir deitado (2712×1220) ou em pé (1220×2712), conforme o celular está. As coordenadas saem do dump, não de valores fixos.
- O `apksigner sign` sem opções assina com os esquemas v2 e v3, sem v1, e o Motorola instala sem reclamar.

## Pronto quando

O código real está anotado, a tela mostra uma mensagem que leva ao problema (ou a divergência está registrada com decisão), e o app normal está de volta no aparelho.

## Commit

`Trata a chave sem cadastro na entrada pelo Google`, se houver correção; senão, a linha do `CLAUDE.md` entra na T07.11. Em qualquer caso, um commit com o registro da task.
