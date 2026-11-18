-- Fatia 5 - Conclusão, multas e rateio, etapa A. Leitura de charges,
-- charge_events e receiver_changes.
-- Documentos: docs/rls-matriz.md (fatia 5), cenários Y01 a Y03, Y05 e Y06 de
-- docs/testes-referencia.md (seção 13.4) e B03 e B04.

-- Auxiliares -----------------------------------------------------------------

-- Recebedor atual do jogo (RN28).
create or replace function private.is_game_receiver(p_game_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.games g
    where g.id = p_game_id and g.receiver_id = p_user_id
  );
$$;

-- Pode ver o valor a pagar: o pagador, o recebedor do valor (RN32), o recebedor
-- atual do jogo e os admins do jogo (RN76).
create or replace function private.can_view_charge(p_charge_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.charges c
    where c.id = p_charge_id
      and (c.payer_id = p_user_id
        or c.receiver_id = p_user_id
        or private.is_game_receiver(c.game_id, p_user_id)
        or private.is_game_admin(c.game_id, p_user_id))
  );
$$;

revoke all on function private.is_game_receiver(uuid, uuid) from public, anon;
revoke all on function private.can_view_charge(uuid, uuid) from public, anon;
grant execute on function private.is_game_receiver(uuid, uuid) to authenticated;
grant execute on function private.can_view_charge(uuid, uuid) to authenticated;

-- Privilégios ----------------------------------------------------------------

grant select on public.charges to authenticated;
grant select on public.charge_events to authenticated;
grant select on public.receiver_changes to authenticated;

-- Políticas ------------------------------------------------------------------

-- O pagador e o recebedor do valor direto nas colunas, para os índices
-- (payer_id, status) e (receiver_id, status).
create policy charges_select_party on public.charges
for select to authenticated
using (
  payer_id = (select auth.uid())
  or receiver_id = (select auth.uid())
  or private.is_game_receiver(game_id, (select auth.uid()))
  or private.is_game_admin(game_id, (select auth.uid()))
);

create policy charge_events_select_party on public.charge_events
for select to authenticated
using (private.can_view_charge(charge_id, (select auth.uid())));

create policy receiver_changes_select_admin on public.receiver_changes
for select to authenticated
using (private.is_game_admin(game_id, (select auth.uid())));
