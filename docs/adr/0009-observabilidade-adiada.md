# 0009. Observabilidade dedicada adiada

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
Na fase inicial, até 100 pessoas usam o app (RNF03), sem meta formal de disponibilidade (RNF08), e o custo mensal tem teto de US$ 5 (RNF10).

## Decisão
Sem ferramenta dedicada de monitoramento por enquanto. Valem os logs e os advisors do painel do Supabase e logs estruturados em JSON nas Edge Functions (`stacks.md`, seção 9).

## Alternativas descartadas
- **Sentry desde o início:** mais uma configuração e mais um serviço para manter, sem usuários reais que a justifiquem.

## Consequências
- Erros do app no aparelho não chegam ao responsável, a não ser que o usuário avise.
- **Gatilho para rever:** os primeiros usuários reais na produção, ou um incidente que os logs do Supabase não ajudem a investigar. A candidata é o Sentry.
