# 0007. Fuso único `America/Fortaleza`

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
Os jogos acontecem em Parnaíba (PI). Prazos, lembretes e a cobrança das 9h e das 20h precisam de um horário de referência único, mesmo que alguém abra o app em outro fuso.

## Decisão
Todo instante é gravado em UTC (`timestamptz`) e exibido em `America/Fortaleza` (RN01, RNF06). Os horários fixos das tarefas agendadas também usam esse fuso. A exceção é a hora lida do comprovante, interpretada em `America/Sao_Paulo` (RN88).

## Alternativas descartadas
- **Fuso do aparelho:** a mesma partida apareceria com horários diferentes para pessoas da mesma turma.
- **Deslocamento fixo de −3 h:** quebraria se o horário de verão voltar. O pacote `timezone` segue a base oficial de fusos.

## Consequências
- O app converte com o pacote `timezone`, sem usar o fuso do aparelho (`arquitetura-app.md`, seção 8).
- Os testes de tempo usam `now()` do servidor (`testes-referencia.md`, seção 1).
