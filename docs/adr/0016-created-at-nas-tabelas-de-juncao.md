# 0016. `created_at` segue a lista de colunas de cada tabela

- **Status:** Aceito
- **Data:** 2026-11-11

## Contexto
A seção 1 do `modelo-dados.md` diz que toda tabela tem `created_at` com padrão `now()`. As listas de colunas da seção 4, porém, não trazem `created_at` em nove tabelas: `profile_private` (só `updated_at`), `terms_acceptances` (`accepted_at`), `group_members` (`joined_at`), `game_limit_history` (`effective_from`), `game_admins` (`added_at`), `game_participants` (`joined_at`), `game_waitlist` (`joined_at`), `scheduled_notifications_log` (`sent_at`) e `notification_preferences` (sem instante). Na fatia 1 era preciso decidir qual das duas leituras vale, porque o banco inteiro nasce de uma vez.

## Decisão
Vale a **lista de colunas da seção 4**: a fatia 1 criou as tabelas exatamente com as colunas descritas lá. Em oito das nove tabelas, a coluna de instante própria (`joined_at`, `added_at`, `accepted_at`, `effective_from`, `sent_at`) já registra a criação da linha, com `not null` e padrão `now()`. A `notification_preferences` fica sem instante, como está escrito.

O cenário B14 de `testes-referencia.md` continua cobrando a regra onde ela se aplica: toda coluna `created_at` que existe é `not null` com padrão `now()` (RN02).

## Alternativas descartadas
- **Acrescentar `created_at` nas nove tabelas:** criaria colunas que nenhum documento pede e duplicaria o instante que `joined_at`, `added_at` e companhia já guardam.
- **Parar e perguntar antes de criar o banco:** a divergência é interna a um documento e não muda regra de negócio, valor nem nome de função. Registrar a leitura num ADR custa menos que bloquear a fatia.

## Consequências
- Quem precisar de "quando a linha nasceu" usa a coluna de instante da própria tabela.
- Se a `notification_preferences` precisar de histórico na fatia 7, a coluna entra por migração nova.
- A seção 1 do `modelo-dados.md` pode ser ajustada para citar esta exceção quando o documento for revisado.
