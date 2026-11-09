# 0014. `dart analyze` no lugar de `flutter analyze`

- **Status:** Aceito
- **Data:** 2026-11-09

## Contexto
O projeto fica em "Área de trabalho". Com acento no caminho, o `flutter analyze` (Flutter 3.47.7) termina com `FormatException: Unexpected end of input`, porque a ferramenta quebra ao abrir o servidor de análise. O problema já tinha aparecido no v0 e foi confirmado em 2026-11-09.

## Decisão
A análise estática usa `dart analyze`, no local e no CI, e esse é o comando da definição de pronto. O projeto continua onde está.

## Alternativas descartadas
- **Mover o projeto para um caminho sem acento:** resolveria o problema na raiz, mas o responsável preferiu manter o local atual.

## Consequências
- `dart analyze` lê o mesmo `analysis_options.yaml` e dá o mesmo resultado.
- Ninguém deve rodar `flutter analyze` neste projeto. O `setup.md` (seção 11) explica o erro.
