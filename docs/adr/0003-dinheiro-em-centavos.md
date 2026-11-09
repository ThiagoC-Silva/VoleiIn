# 0003. Dinheiro em centavos inteiros, com arredondamento para cima

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
O comprovante só é aprovado com o valor **exato** do valor a pagar (RN88). Um centavo de diferença manda o pagamento para análise manual. Ponto flutuante não representa centavos com exatidão.

## Decisão
Todo valor é `integer` em centavos, em colunas `_cents`. Contas intermediárias que possam estourar usam `bigint`. A parte por vaga é `(total_cents + slot_limit - 1) / slot_limit`, arredondada para cima ao centavo (RF67, RN71), e a sobra fica com o recebedor (RN75). No app, `int` e formatação com conta inteira (`arquitetura-app.md`, seção 8).

## Alternativas descartadas
- **`numeric` com casas decimais:** exato no banco, mas convida a `double` no app e no JSON.
- **Arredondar para o centavo mais próximo:** a soma das partes poderia ficar abaixo do valor total, e o recebedor arcaria com a diferença sem regra.

## Consequências
- Nenhuma conta de dinheiro em `double`, nem no app (CLAUDE.md, "Nunca faça").
- Os testes de rateio (`testes-referencia.md`, seção 4) conferem os centavos exatos.
