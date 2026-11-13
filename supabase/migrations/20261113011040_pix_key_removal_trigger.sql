-- Fatia 2 - Conta e perfil. A chave Pix não pode ser removida em uso (RN105).
-- Documentos: docs/regras-negocio.md (RN105), docs/modelo-dados.md (4.1),
-- docs/contratos-api.md (seção 2, PIX_KEY_IN_USE), cenários N01 a N09.
--
-- Recusa pix_key = null se o usuário for receiver_id de um jogo open/confirmed
-- ou de um valor pending/under_review. A troca de chave é livre (N07), e mudar
-- outras colunas não passa por aqui (N09).
-- security definer para ler games e charges, que o dono não lê pelo RLS nesta
-- fatia. Vale também para o update do app (P0001, convertido em pixKeyInUse).
--
-- Fatia 4: create_game e change_receiver devem ler a linha de profile_private
-- do recebedor com `for share`, para não escolher quem está removendo a chave
-- ao mesmo tempo (specs/001-conta-e-perfil/research.md, 4).

create or replace function private.guard_pix_key_removal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.pix_key is null or new.pix_key is not null then
    return new;
  end if;

  if exists (
    select 1 from public.games
    where receiver_id = new.user_id
      and status in ('open', 'confirmed')
  ) or exists (
    select 1 from public.charges
    where receiver_id = new.user_id
      and status in ('pending', 'under_review')
  ) then
    raise exception using errcode = 'P0001', message = 'PIX_KEY_IN_USE';
  end if;

  return new;
end;
$$;

comment on function private.guard_pix_key_removal() is
  'Trigger da RN105: recusa a remoção da chave Pix em uso com PIX_KEY_IN_USE.';

revoke execute on function private.guard_pix_key_removal() from public, anon, authenticated;

create trigger profile_private_guard_pix_key_removal
before update of pix_key_type, pix_key on public.profile_private
for each row execute function private.guard_pix_key_removal();
