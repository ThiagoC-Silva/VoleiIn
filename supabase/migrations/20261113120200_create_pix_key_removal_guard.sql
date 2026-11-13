-- Fatia 2 - Conta e perfil. Trigger da RN105: quem ainda vai receber não remove
-- a chave Pix.
-- Documentos: docs/modelo-dados.md (4.1), docs/contratos-api.md (seção 2,
-- PIX_KEY_IN_USE), cenários N01 a N09 de docs/testes-referencia.md.
--
-- Recusa pix_key nula se a pessoa for receiver_id de um jogo open ou confirmed,
-- ou de um valor pending ou under_review. Trocar a chave por outra é livre.
-- Vale para toda escrita, inclusive a direta do app (contratos-api.md, seção 9).
-- É security definer porque a pessoa não lê games nem charges nesta fatia.

create or replace function private.guard_pix_key_removal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.games g
    where g.receiver_id = new.user_id
      and g.status in ('open', 'confirmed')
  ) or exists (
    select 1
    from public.charges c
    where c.receiver_id = new.user_id
      and c.status in ('pending', 'under_review')
  ) then
    raise exception using errcode = 'P0001', message = 'PIX_KEY_IN_USE';
  end if;

  return new;
end;
$$;

revoke execute on function private.guard_pix_key_removal() from public, anon, authenticated;

comment on function private.guard_pix_key_removal() is
  'RN105: sem chave Pix, a pessoa não pode ser recebedora de nada em aberto.';

-- Só na remoção: o update do telefone, ou de uma pessoa ainda sem chave, não
-- consulta jogos nem valores.
create trigger profile_private_guard_pix_key_removal
before update of pix_key on public.profile_private
for each row
when (old.pix_key is not null and new.pix_key is null)
execute function private.guard_pix_key_removal();
