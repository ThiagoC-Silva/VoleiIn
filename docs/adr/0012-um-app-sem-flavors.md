# 0012. Um app só, sem *flavors*; homologação no emulador

- **Status:** Aceito
- **Data:** 2026-11-09

## Contexto
No Android, dois builds com o mesmo pacote não convivem no aparelho: instalar um apaga o outro. O responsável também joga na turma e quer o app real no celular.

## Decisão
Um pacote só, `br.com.voleiin`, com o ambiente escolhido no build por `--dart-define-from-file` (`setup.md`, seção 5.1). A versão em desenvolvimento é testada no **emulador**, contra o Supabase local. O celular fica com o app da Google Play.

## Alternativas descartadas
- **Flavors (`br.com.voleiin` e `br.com.voleiin.dev`):** os dois conviveriam no celular, mas exigiriam um app a mais no Firebase e clientes Google a mais.
- **Um app, testado no celular:** cada teste apagaria o app real e a sessão.

## Consequências
- Os emuladores precisam de imagem Google Play, para o login com Google e o push (`setup.md`, seção 3).
- Se um dia for preciso testar no celular físico com frequência, os *flavors* podem entrar sem refazer o app.
