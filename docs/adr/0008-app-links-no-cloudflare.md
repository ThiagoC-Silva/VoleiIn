# 0008. App Links próprios, com página no Cloudflare Pages

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
Os convites são enviados pelo WhatsApp. O link precisa abrir o app no grupo ou no jogo certo e, sem o app instalado, levar à Google Play, sem custo e sem depender de serviço de terceiros que possa ser descontinuado.

## Decisão
App Links do Android em `https://convite.voleiin.com.br/g/<codigo>` e `/j/<codigo>`, com `assetlinks.json` e a página de fallback hospedados no Cloudflare Pages (`stacks.md`, seção 8).

## Alternativas descartadas
- **Firebase Dynamic Links:** descontinuado.
- **Vercel:** o plano grátis é só para uso não comercial.
- **Firebase Hosting:** limite de 360 MB de transferência por dia no plano grátis.
- **Branch e serviços similares:** custo ou dependência de terceiros.

## Consequências
- Não há *deferred deep link*: a página mostra o código para digitar no app (RF16).
- O `assetlinks.json` lista o SHA-256 de cada chave que assina o app, inclusive as de debug (`setup.md`, seção 10).
- O uso comercial no plano grátis do Cloudflare Pages precisa ser confirmado antes do lançamento (`stacks.md`, seção 14).
