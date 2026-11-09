# 0005. Leitura de comprovantes por LLM, com validação determinística

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
Os comprovantes Pix variam por banco e chegam como imagem ou PDF. É preciso extrair valor, data e hora, destinatário e ID da transação, e decidir se o pagamento confere (RN88, RN89), sem custo fixo.

## Decisão
Uma Edge Function envia o arquivo à Claude API, que **só extrai** os campos em JSON estruturado. A aprovação é decidida por regras em código: valor exato, destinatário, data no minuto e ID não usado (`stacks.md`, seção 6). O modelo é configurado por variável de ambiente.

## Alternativas descartadas
- **OCR no aparelho com regras por banco** (abordagem do v0): exigiria uma regra por layout de banco e manutenção a cada mudança de layout.
- **Deixar o modelo decidir a aprovação:** decisão não auditável e sujeita a erro do modelo, num ponto que define quem é cobrado.
- **Só análise manual:** sobrecarrega o recebedor, que confere cada pagamento à mão.

## Consequências
- Custo por leitura, limitado a 3 leituras automáticas por valor a pagar (RN86) e estimado na RNF10.
- O comprovante sai do app para um provedor externo, o que precisa constar na Política de Privacidade (`stacks.md`, 13.3).
- O prompt e o conjunto de exemplos são tratados como código, em `docs/comprovantes-ia.md` (antes da fatia 6).
