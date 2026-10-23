# T07.7 — Preparar o celular e conferir o teclado

**Estado:** feito · **Depende de:** T07.6

## Objetivo

Deixar o app instalado no celular físico falando com o Supabase local, confirmar que o Claude consegue operá-lo pelo `adb`, e fazer as conferências que pedem o dedo do Thiago **antes** de qualquer tecla injetada.

## O que já existe

- O celular pareado por depuração sem fio (`adb devices` o mostra).
- `app/dart_defines.json` local, e o SHA-1 da chave de debug desta máquina no cliente Android do Google (T11).

## O que falta

- [x] `hostname -I` e `SUPABASE_URL` atualizado em `app/dart_defines.json`.
- [x] O celular alcança a máquina: `adb shell am start -a android.intent.action.VIEW -d http://<ip>:54321/auth/v1/health` abre no navegador, conferido por `screencap`. Se não abrir, é a rede, não o app.
- [x] **Falha sem `GOOGLE_WEB_CLIENT_ID`** (pendente da T04): build com uma cópia de `dart_defines.json` sem a chave, no scratchpad; abrir; o `StateError` aparece no `adb logcat` com a mensagem que aponta o `CLAUDE.md`. Anotar o que a tela mostra.
- [x] Build e instalação normais:
  ```
  flutter build apk --debug --dart-define-from-file=dart_defines.json
  adb -s <id> install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s <id> shell am start -n br.com.voleiin/.MainActivity
  ```
- [x] **Operação pelo `adb`**: `uiautomator dump` mostra os elementos do Flutter (rótulos e textos da A1)? Se não mostrar, a operação segue por coordenadas tiradas da captura. Registrar qual dos dois funcionou.
- [x] **Contas Google no aparelho**: os dois Gmails aparecem em Configurações → Contas. Se faltar algum, **o Thiago** adiciona.
- [x] **Teclado e colar, pelo Thiago, com o dedo** (primeira coisa do app, antes de qualquer `adb input`):
  - criar uma conta descartável na A2 digitando à mão;
  - na A3, o teclado numérico abre inteiro ao chegar e ao tocar nas casas;
  - copiar o código no navegador do celular (`http://<ip>:54324`, o Mailpit) e colar nas casas: as seis se preenchem;
  - o Claude acompanha por `screencap`.
- [x] Registrar como devolver o Gboard ao normal se as teclas injetadas o deixarem em modo de teclado físico (Configurações → Sistema → Idiomas e entrada → Teclado físico → "Usar teclado na tela"), para a T07.11.

## Resultado

Executado em 2026-10-23, celular Motorola Edge 60 Pro (Android 16, API 36), máquina em `192.168.2.110`.

- **Conexão:** o celular não aparecia em `adb devices` no início; `adb mdns services` o achou (`_adb-tls-connect`) e `adb connect <ip>:<porta>` o trouxe de volta, sem parear de novo. A porta muda a cada religada da depuração sem fio.
- **`SUPABASE_URL`** passou de `http://10.0.2.2:54321` (emulador) para `http://192.168.2.110:54321`.
- **Alcance:** conferido sem abrir o navegador, por `nc` no `adb shell`. O Auth responde `200` (GoTrue v2.197.0) em `:54321`, e o Mailpit responde em `:54324`. O `nc` precisa de stdin aberto até a resposta chegar (`(printf …; sleep 3) | nc -w 5 <ip> 54321`); sem isso, volta vazio e parece rede bloqueada. O `am start` do navegador foi descartado, porque abre por cima do que estiver na tela do celular.
- **Falha sem `GOOGLE_WEB_CLIENT_ID`:** `E flutter : Unhandled Exception: Bad state: Falta GOOGLE_WEB_CLIENT_ID: rode com --dart-define (ver CLAUDE.md da raiz).` A tela fica parada no splash do Flutter, porque o `iniciarGoogle()` lança antes do `runApp`. É erro de configuração de quem compila, não da pessoa usuária, e a mensagem aponta o caminho: **sem correção**.
- **Instalação:** o VoleiIn que já estava no aparelho tinha sido assinado pela chave de debug de outra máquina (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). Foi preciso `adb uninstall br.com.voleiin` antes do primeiro `install`. Depois disso, o `install -r` funciona entre builds desta máquina.
- **Operação pelo `adb`:** o `uiautomator dump` funciona. O Flutter expõe cada elemento com o rótulo em `content-desc` (o `text` vem vazio) e com `bounds`, de onde sai o centro para o `input tap`. Na A1 aparecem "Entrar no VoleiIn", "E-mail", "Senha", "Mostrar senha", "Esqueci a senha", "Entrar", "Entrar com Google" e "Criar conta". O toque em "Criar conta" levou à A2. Coordenadas tiradas da captura ficam só como reserva.
- **Contas Google:** havia uma; o Thiago adicionou a segunda. `dumpsys account` mostra duas contas `com.google` (contadas sem imprimir os endereços).
- **Teclado e colar, pelo Thiago, com o dedo:** conta descartável criada na A2 digitando à mão. Na A3, o teclado numérico abriu inteiro ao chegar e ao tocar numa casa. O código copiado do Mailpit no navegador do celular e colado preencheu **as seis casas** e confirmou o cadastro: no banco, o usuário está confirmado e com `pessoa` criada.
- **Gboard em modo de teclado físico** (para a T07.11): antes de qualquer tecla injetada, `settings get secure show_ime_with_hard_keyboard` vale `0`, e o teclado na tela aparece normalmente. Se, depois do `adb input`, o teclado na tela sumir dos campos, o caminho é Configurações → Sistema → Idiomas e entrada → Teclado físico → "Usar teclado na tela", ou `adb shell settings put secure show_ime_with_hard_keyboard 1`. Se isso não bastar, reiniciar o Gboard: `adb shell am force-stop com.google.android.inputmethod.latin`.

## Pronto quando

O app abre no celular com a A1, o Claude consegue tocar e ler a tela, e as conferências do teclado e do colar estão anotadas.

## Commit

A falha sem `GOOGLE_WEB_CLIENT_ID` não pediu correção. O registro foi junto com o da T07.6: `Registra a rodada da API e a preparação do celular`.
