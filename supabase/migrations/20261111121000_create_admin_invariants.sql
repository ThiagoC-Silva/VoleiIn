-- Fatia 1 - Fundação. Invariantes de admin (RN13, RN25).
-- Documentos: docs/modelo-dados.md (4.2, 4.3), docs/testes-referencia.md (B29 a B36).
--
-- São a rede de segurança: as funções das fatias 3 e 4 validam antes e devolvem
-- o mesmo código de erro (docs/contratos-api.md, seção 2). Os triggers são
-- `constraint trigger ... deferrable initially deferred`, para que uma troca de
-- papéis dentro da mesma transação seja aceita (B31, B33).

-- RN13: um grupo não arquivado sempre tem ao menos um admin ------------------
create or replace function private.assert_group_has_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_id uuid;
  v_archived boolean;
begin
  if tg_table_name = 'groups' then
    v_group_id := new.id;
  elsif tg_op = 'DELETE' then
    v_group_id := old.group_id;
  else
    v_group_id := new.group_id;
  end if;

  select g.archived_at is not null into v_archived
  from public.groups g
  where g.id = v_group_id;

  -- Grupo inexistente ou arquivado: nada a exigir (RN17, B33).
  if v_archived is null or v_archived then
    return null;
  end if;

  if not exists (
    select 1 from public.group_members m
    where m.group_id = v_group_id and m.role = 'admin'
  ) then
    raise exception using errcode = 'P0001', message = 'LAST_ADMIN';
  end if;

  return null;
end;
$$;

comment on function private.assert_group_has_admin() is
  'RN13: grupo ativo sem admin derruba a transação com LAST_ADMIN.';

create constraint trigger groups_admin_invariant
after insert or update on public.groups
deferrable initially deferred
for each row execute function private.assert_group_has_admin();

create constraint trigger group_members_admin_invariant
after insert or update or delete on public.group_members
deferrable initially deferred
for each row execute function private.assert_group_has_admin();

-- RN25: um jogo sempre tem ao menos um admin --------------------------------
create or replace function private.assert_game_has_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game_id uuid;
begin
  if tg_table_name = 'games' then
    v_game_id := new.id;
  elsif tg_op = 'DELETE' then
    v_game_id := old.game_id;
  else
    v_game_id := new.game_id;
  end if;

  -- Jogo inexistente: nada a exigir.
  if not exists (select 1 from public.games g where g.id = v_game_id) then
    return null;
  end if;

  if not exists (select 1 from public.game_admins a where a.game_id = v_game_id) then
    raise exception using errcode = 'P0001', message = 'LAST_GAME_ADMIN';
  end if;

  return null;
end;
$$;

comment on function private.assert_game_has_admin() is
  'RN25: jogo sem admin derruba a transação com LAST_GAME_ADMIN.';

create constraint trigger games_admin_invariant
after insert on public.games
deferrable initially deferred
for each row execute function private.assert_game_has_admin();

create constraint trigger game_admins_admin_invariant
after insert or update or delete on public.game_admins
deferrable initially deferred
for each row execute function private.assert_game_has_admin();
