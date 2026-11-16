-- Fatia 4 - Jogo e lista de presença. Funções auxiliares do RLS dos jogos.
-- Documento: docs/rls-matriz.md (fatia 4).
--
-- Mesmas propriedades das auxiliares da fatia 3: `security definer`, para
-- consultar game_admins, game_participants, game_waitlist e group_members sem
-- passar pelo RLS dessas tabelas (o que evita a recursão das políticas), e
-- `execute` só para authenticated, que continua sem `usage` no esquema private.

-- Admin do jogo (RN25).
create or replace function private.is_game_admin(p_game_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.game_admins a
    where a.game_id = p_game_id and a.user_id = p_user_id
  );
$$;

-- Pode ver o jogo (docs/modelo-dados.md, seção 8): membro do grupo do jogo, quem
-- tem ou teve passagem na lista ou na espera, em qualquer status, e admin do jogo.
-- Jogo avulso: só os três últimos. Grupo arquivado não tem membros (RN17).
create or replace function private.can_view_game(p_game_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
      select 1 from public.games g
      join public.group_members m on m.group_id = g.group_id and m.user_id = p_user_id
      where g.id = p_game_id
    )
    or exists (
      select 1 from public.game_participants p
      where p.game_id = p_game_id and p.user_id = p_user_id
    )
    or exists (
      select 1 from public.game_waitlist w
      where w.game_id = p_game_id and w.user_id = p_user_id
    )
    or private.is_game_admin(p_game_id, p_user_id);
$$;

revoke execute on function private.is_game_admin(uuid, uuid) from public, anon;
revoke execute on function private.can_view_game(uuid, uuid) from public, anon;
grant execute on function private.is_game_admin(uuid, uuid) to authenticated;
grant execute on function private.can_view_game(uuid, uuid) to authenticated;
