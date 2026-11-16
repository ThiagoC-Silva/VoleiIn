-- Fatia 4 - Jogo e lista de presença. Leitura das tabelas de jogo e Realtime.
-- Documentos: docs/rls-matriz.md (fatia 4), docs/stacks.md (4.1), research R8
-- de specs/003-jogo-etapa-a. Cenários W01 a W07 e W15 de docs/testes-referencia.md.
--
-- Quem pode ver o jogo lê o jogo, os admins, a lista e a espera. O histórico de
-- limite fica só com os admins do jogo. Nenhuma escrita direta: toda mudança
-- passa pelas funções de docs/contratos-api.md, seção 4.

grant select on public.games to authenticated;
grant select on public.game_admins to authenticated;
grant select on public.game_participants to authenticated;
grant select on public.game_waitlist to authenticated;
grant select on public.game_limit_history to authenticated;

create policy games_select_viewer on public.games
for select to authenticated
using (private.can_view_game(id, (select auth.uid())));

create policy game_admins_select_viewer on public.game_admins
for select to authenticated
using (private.can_view_game(game_id, (select auth.uid())));

create policy game_participants_select_viewer on public.game_participants
for select to authenticated
using (private.can_view_game(game_id, (select auth.uid())));

create policy game_waitlist_select_viewer on public.game_waitlist
for select to authenticated
using (private.can_view_game(game_id, (select auth.uid())));

create policy game_limit_history_select_admin on public.game_limit_history
for select to authenticated
using (private.is_game_admin(game_id, (select auth.uid())));

-- Realtime: só recebe o evento quem pode ler a linha (docs/rls-matriz.md, seção 1).
-- game_admins e game_limit_history ficam fora: as telas que as usam releem ao abrir.
alter publication supabase_realtime add table public.games, public.game_participants, public.game_waitlist;
