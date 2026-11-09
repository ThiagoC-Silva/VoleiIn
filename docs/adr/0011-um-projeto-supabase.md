# 0011. Um projeto Supabase remoto; homologação no local

- **Status:** Aceito
- **Data:** 2026-11-09

## Contexto
O plano previa três ambientes: local, homologação e produção, os dois últimos como projetos remotos. Já existe o projeto `VoleiIn` do v0 (`sa-east-1`), com o SMTP do Resend e o login Google configurados. Não há backup do banco (RNF09).

## Decisão
- **Um projeto remoto só, a produção:** o `VoleiIn` do v0, limpo e adaptado na fatia 1 (`setup.md`, seção 9.3).
- **A homologação é o Supabase local.** Testes, CI e conferência dos fluxos rodam no banco local.
- **Depois do lançamento, toda migração é ensaiada** com uma cópia dos dados da produção, restaurada no local, antes de ser aplicada. A cópia fica guardada na máquina do responsável até a próxima migração (`setup.md`, seção 9.2).

## Alternativas descartadas
- **Projeto remoto de homologação:** mais um projeto para configurar (SMTP, Google, segredos) e manter ativo contra a pausa, para um único desenvolvedor.
- **Migração testada só em banco limpo:** sem backup, uma migração que falhasse com dados que o local não tem poderia apagar valores sem volta.

## Consequências
- Até o lançamento, a produção só tem dados de teste e serve também para conferir o que o local não reproduz (e-mail pelo Resend, App Links com domínio verificado, push real).
- O merge em `main` não publica nada no Supabase. O deploy é um disparo manual (`trabalho-com-agente.md`, seção 6.3).
- A cópia de antes da migração tem dados pessoais: fica só na máquina do responsável, fora do Git.
- O MCP do Supabase alcança só a produção e por isso é usado apenas para leitura (`trabalho-com-agente.md`, seção 8).
