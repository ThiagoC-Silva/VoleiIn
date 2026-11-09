# 0004. Regras no servidor, nunca só no app

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
Rateio, multas, mudança de status, disputa de vagas e prazos decidem quanto cada pessoa paga. O app roda num aparelho que o usuário controla, inclusive o relógio, e duas implementações da mesma regra divergem com o tempo.

## Decisão
Toda escrita com regra passa por uma função SQL `security definer` ou por uma Edge Function, que valida papel, estado e tempo com `now()` do servidor, numa transação (`contratos-api.md`, seção 1). O app escreve direto só no que a seção 9 do `contratos-api.md` permite. O app exibe; o servidor decide.

## Alternativas descartadas
- **Regras no app, com o banco só guardando:** qualquer cliente adulterado ou desatualizado gravaria valores errados, e a disputa de vagas não teria bloqueio.
- **Regras duplicadas (app e servidor):** duas fontes para manter iguais, sem ganho, já que o app não funciona sem conexão (RNF07).

## Consequências
- As regras são testadas em pgTAP, no banco, sem depender do app.
- Toda ação do app é uma chamada de rede. O tempo de resposta conta para a RNF04.
- O app pode esconder um botão pelo relógio do aparelho, mas nunca liberar uma ação (`arquitetura-app.md`, seção 8).
