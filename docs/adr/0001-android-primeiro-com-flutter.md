# 0001. Android primeiro, com Flutter

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
O público é um grupo local de Parnaíba, que usa Android em sua maioria. O responsável não tem equipamento Apple para desenvolver e publicar para iOS. O app precisa de push, câmera e galeria, compartilhamento e deep links.

## Decisão
App só para Android, escrito em Flutter (`stacks.md`, seções 1 e 3). `minSdk` 29 e `targetSdk` 36 (RNF01, RNF02).

## Alternativas descartadas
- **Kotlin nativo:** prenderia o app ao Android. Incluir o iOS depois exigiria reescrever tudo.
- **PWA:** push e deep links menos confiáveis no Android, e sem presença na Google Play.

## Consequências
- O iOS pode entrar depois sem reescrever o app. O FCM e o campo `platform` de `device_tokens` já o preveem.
- A página de convite avisa quem abre num iPhone ou computador que o app é só para Android (`stacks.md`, seção 8).
