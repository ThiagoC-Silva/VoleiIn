# T07.7 — Preparar o celular e conferir o teclado

**Estado:** a fazer · **Depende de:** T07.6

## Objetivo

Deixar o app instalado no celular físico falando com o Supabase local, confirmar que o Claude consegue operá-lo pelo `adb`, e fazer as conferências que pedem o dedo do Thiago **antes** de qualquer tecla injetada.

## O que já existe

- O celular pareado por depuração sem fio (`adb devices` o mostra).
- `app/dart_defines.json` local, e o SHA-1 da chave de debug desta máquina no cliente Android do Google (T11).

## O que falta

- [ ] `hostname -I` e `SUPABASE_URL` atualizado em `app/dart_defines.json`.
- [ ] O celular alcança a máquina: `adb shell am start -a android.intent.action.VIEW -d http://<ip>:54321/auth/v1/health` abre no navegador, conferido por `screencap`. Se não abrir, é a rede, não o app.
- [ ] **Falha sem `GOOGLE_WEB_CLIENT_ID`** (pendente da T04): build com uma cópia de `dart_defines.json` sem a chave, no scratchpad; abrir; o `StateError` aparece no `adb logcat` com a mensagem que aponta o `CLAUDE.md`. Anotar o que a tela mostra.
- [ ] Build e instalação normais:
  ```
  flutter build apk --debug --dart-define-from-file=dart_defines.json
  adb -s <id> install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s <id> shell am start -n br.com.voleiin/.MainActivity
  ```
- [ ] **Operação pelo `adb`**: `uiautomator dump` mostra os elementos do Flutter (rótulos e textos da A1)? Se não mostrar, a operação segue por coordenadas tiradas da captura. Registrar qual dos dois funcionou.
- [ ] **Contas Google no aparelho**: os dois Gmails aparecem em Configurações → Contas. Se faltar algum, **o Thiago** adiciona.
- [ ] **Teclado e colar, pelo Thiago, com o dedo** (primeira coisa do app, antes de qualquer `adb input`):
  - criar uma conta descartável na A2 digitando à mão;
  - na A3, o teclado numérico abre inteiro ao chegar e ao tocar nas casas;
  - copiar o código no navegador do celular (`http://<ip>:54324`, o Mailpit) e colar nas casas: as seis se preenchem;
  - o Claude acompanha por `screencap`.
- [ ] Registrar como devolver o Gboard ao normal se as teclas injetadas o deixarem em modo de teclado físico (Configurações → Sistema → Idiomas e entrada → Teclado físico → "Usar teclado na tela"), para a T07.11.

## Resultado

_Preenchido na execução._

## Pronto quando

O app abre no celular com a A1, o Claude consegue tocar e ler a tela, e as conferências do teclado e do colar estão anotadas.

## Commit

Sem commit, salvo se a falha sem `GOOGLE_WEB_CLIENT_ID` pedir correção.
