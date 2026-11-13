-- Fatia 2 - Conta e perfil. Acesso do dono a profiles, profile_private e
-- terms_acceptances.
-- Documentos: docs/rls-matriz.md (fatia 2), docs/contratos-api.md (seção 9),
-- cenários B03, B04 e P01 a P14 de docs/testes-referencia.md.
--
-- A pessoa lê e edita só a própria linha. Ninguém vê o perfil de outra pessoa
-- nesta fatia: a leitura por contexto (RN107) entra na fatia 3.
-- Sem insert em profiles e profile_private (as linhas nascem pela trigger de
-- auth.users) e sem delete em nenhuma das três tabelas.

-- Privilégios ----------------------------------------------------------------
-- Por coluna: o app nunca grava id, deleted_at, display_name, updated_at nem
-- accepted_at, que vem sempre do now() do servidor (RN02).
grant select on public.profiles to authenticated;
grant update (name, nickname, photo_path) on public.profiles to authenticated;

grant select on public.profile_private to authenticated;
grant update (phone, phone_visible, pix_key_type, pix_key) on public.profile_private to authenticated;

grant select on public.terms_acceptances to authenticated;
grant insert (user_id, document, version) on public.terms_acceptances to authenticated;

-- profiles -------------------------------------------------------------------
create policy profiles_select_own on public.profiles
for select to authenticated
using (id = (select auth.uid()));

-- Perfil anonimizado não é editável (RN104). O photo_path só aponta para a
-- pasta da própria pessoa no bucket avatars.
create policy profiles_update_own on public.profiles
for update to authenticated
using (id = (select auth.uid()) and deleted_at is null)
with check (
  id = (select auth.uid())
  and (photo_path is null or photo_path like 'profiles/' || id::text || '/%')
);

-- profile_private ------------------------------------------------------------
-- A trigger da RN105 (migração create_pix_key_removal_guard) roda também aqui.
create policy profile_private_select_own on public.profile_private
for select to authenticated
using (user_id = (select auth.uid()));

create policy profile_private_update_own on public.profile_private
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- terms_acceptances ----------------------------------------------------------
create policy terms_acceptances_select_own on public.terms_acceptances
for select to authenticated
using (user_id = (select auth.uid()));

-- Só em nome próprio e só na versão vigente (RF105).
create policy terms_acceptances_insert_own on public.terms_acceptances
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.current_terms_versions() v
    where v.document = terms_acceptances.document
      and v.version = terms_acceptances.version
  )
);
