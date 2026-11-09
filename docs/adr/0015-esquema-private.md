# 0015. Funções auxiliares no esquema `private` e privilégios revogados

- **Status:** Aceito
- **Data:** 2026-11-09

## Contexto
O Supabase expõe pela API toda função e tabela do esquema `public`. Por padrão, `anon` e `authenticated` ganham acesso a tudo o que é criado ali, e o RLS é a única barreira. As funções auxiliares das políticas (`shares_context`, `can_view_game` etc.) e as internas (`emit_notification`, tarefas agendadas) não devem ser chamadas pelo app.

## Decisão
- Funções auxiliares e internas ficam no esquema `private`, que a API não expõe.
- A primeira migração revoga os privilégios padrão. Cada fatia concede só o necessário: `select` nas tabelas lidas, `insert`/`update` por coluna nas escritas diretas e `execute` nas funções do app (`arquitetura-app.md`, 14.2).

## Alternativas descartadas
- **Tudo em `public`, protegido só pelo RLS:** um `shares_context(a, b)` público deixaria qualquer usuário descobrir quem se conhece, e uma tabela nova sem política ficaria aberta por engano.

## Consequências
- Toda função nova do app precisa de `grant execute ... to authenticated`, ou o app recebe erro de permissão. O teste de RLS confere a lista de funções executáveis.
- A forma como as Edge Functions chamam as funções internas é decidida na fatia 6.
- Lição herdada do v0, onde o mesmo arranjo funcionou.
