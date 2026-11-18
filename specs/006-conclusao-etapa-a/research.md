# Research: etapa A da fatia 5

## R1. `complete_game` inteira na etapa A

**Decisão (responsável, 18/11/2026):** a etapa A já aplica a isenção automática (RN62), em vez de cobrar todas as multas de cancelamento até a etapa B. A migração da etapa A vai para a produção na sessão 4, e uma conclusão nesse intervalo cobraria multas que a regra isenta. Pelo mesmo motivo, a função nasce com o passo a passo inteiro do `modelo-dados.md` (seção 6): as faltas de `p_absent_user_ids`, com `ABSENT_NOT_PARTICIPANT` e `RECEIVER_CANNOT_BE_ABSENT`, e a notificação `penalty_waived` da conclusão. A etapa B fica com os cenários que cobrem isso (T16, I01 a I12, F01, F02, F05 a F14, R08, Z09), mais `waive_penalty`, o C09 e o histórico da pessoa no jogo. A tabela "Cenários por etapa" de `testes-referencia.md` (seção 13) ganha essa nota.

## R2. Um núcleo para as três funções

**Decisão:** `private.complete_game_core(p_game public.games, p_actor uuid, p_total_cents integer, p_absent_user_ids uuid[], p_mode, p_dry_run boolean)` calcula e, sem `p_dry_run`, grava. `preview_complete_game` e `complete_game` validam o chamador e chamam o núcleo; `auto_complete_due_games` chama com `p_mode = automatic`, total nulo e as faltas que já estão gravadas (RN46, RN49). O *preview* roda as mesmas validações de `complete_game` (contrato).

## R3. `L` da RN62

**Decisão:** o limite vigente no prazo é o da linha de `game_limit_history` com o maior `effective_from <= cancellation_deadline`; se não houver (jogo inserido direto, depois do prazo), vale a primeira linha do histórico. `L` é o menor entre ele e os das linhas com `effective_from` entre o prazo e o início. Sem histórico, `L = slot_limit`.

## R4. Desempate da RN62

**Decisão:** as multas mantidas são as dos cancelamentos com `left_at` mais recente; no empate, a de maior `id` (`order by left_at desc, id desc`). O recebedor nunca entra na conta, nem como cancelamento (RF71).

## R5. Vagas não cobertas

**Decisão:** `uncovered_slots = max(0, slot_limit − (ocupadas + multas mantidas))`, com o limite final, pela definição de "Vagas cobertas" do `modelo-dados.md` (seção 5). R01 dá 0 e R06 dá 6.

## R6. Concorrência da conclusão (C08)

**Decisão:** `complete_game` bloqueia o jogo (`lock_game`) e confere o status depois do lock. `auto_complete_due_games` percorre os jogos vencidos com `for update skip locked`, em ordem de `id`: se a manual pegar o jogo primeiro, a automática o pula e, na próxima rodada, ele já está `completed`; se a automática pegar primeiro, a manual espera e recebe `GAME_NOT_OPEN`. O C08 dispara a automática por uma conexão de `postgres` (`npm:postgres`), com `SUPABASE_DB_URL` e, sem ela, a URL do banco local.

## R7. Agendamento

**Decisão:** a migração cria a extensão `pg_cron` (`with schema pg_catalog`, como na documentação da Supabase) e agenda `auto-complete-due-games` com `*/5 * * * *` chamando `select public.auto_complete_due_games()`. A função fica em `public`, sem `execute` para `public`, `anon` e `authenticated` (Y07 espera `42501`).

## R8. Seed

**Decisão:** dois jogos novos no Quinta: "Quinta concluído" (`...0208`), concluído pela `complete_game_core` dentro do seed, e "Quinta aguardando conclusão" (`...0209`), que terminou 10 minutos antes do `db reset`. A conclusão automática o conclui 50 minutos depois, e o `setup.md` (seção 8) avisa isso.
