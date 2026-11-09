# 0002. Supabase como backend, em `sa-east-1`

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
O app precisa de autenticação, banco relacional com regras transacionais (vagas disputadas, rateio), arquivos privados, funções serverless e tempo real, com custo mensal de até US$ 5 (RNF10).

## Decisão
Supabase (Postgres, Auth, Storage, Edge Functions e Realtime) no plano grátis, na região de São Paulo (`stacks.md`, seção 4).

## Alternativas descartadas
- **Firebase (Firestore):** sem transações relacionais nem constraints para o rateio e a disputa de vagas, e regras de acesso mais difíceis de testar que o RLS com pgTAP.
- **Backend próprio:** exigiria servidor, deploy e monitoramento, com custo e manutenção que não cabem no projeto.
- **Outra região:** maior latência para o Brasil e dados fora do país.

## Consequências
- A região não muda depois sem migrar o projeto.
- O plano grátis pausa o projeto após 1 semana sem uso e não tem backup (RNF09).
- As regras críticas viram funções SQL testáveis com pgTAP (ADR 0004).
