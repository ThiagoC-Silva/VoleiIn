-- Fatia 2 - Conta e perfil. Acesso do dono a profiles, profile_private e terms_acceptances.
-- Documento: docs/rls-matriz.md, "Fatia 2" (privilégios e políticas), cenários P01 a P14.
--
-- A pessoa lê e edita só a própria linha. A leitura por contexto (RN107) entra
-- na fatia 3. Sem insert em profiles e profile_private (as linhas nascem pela
-- trigger de auth.users) e sem delete em nenhuma das três tabelas.
-- Nas condições, (select auth.uid()) é calculado uma vez por consulta
-- (docs/rls-matriz.md, seção 6).

-- Privilégios ----------------------------------------------------------------
-- Por coluna nas escritas: o app não grava id, deleted_at, display_name,
-- updated_at nem accepted_at, que vem sempre do now() do servidor (RN02).

grant select on table public.profiles to authenticated;
grant update (name, nickname, photo_path) on table public.profiles to authenticated;

grant select on table public.profile_private to authenticated;
grant update (phone, phone_visible, pix_key_type, pix_key) on table public.profile_private to authenticated;

grant select on table public.terms_acceptances to authenticated;
grant insert (user_id, document, version) on table public.terms_acceptances to authenticated;

-- profiles -------------------------------------------------------------------

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));

-- O photo_path só aponta para a pasta da própria pessoa no bucket avatars, para
-- ninguém exibir como sua a foto de outra (P05). Perfil anonimizado não é
-- editado (P06).
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = (select auth.uid()) and deleted_at is null)
with check (
  id = (select auth.uid())
  and (photo_path is null or photo_path like 'profiles/' || id::text || '/%')
);

-- profile_private ------------------------------------------------------------
-- A trigger da RN105 (pix_key_removal_trigger) vale também para este update.

create policy profile_private_select_own
on public.profile_private
for select
to authenticated
using (user_id = (select auth.uid()));

create policy profile_private_update_own
on public.profile_private
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- terms_acceptances ----------------------------------------------------------
-- Só a versão vigente e só em nome próprio (P11, P12).

create policy terms_acceptances_select_own
on public.terms_acceptances
for select
to authenticated
using (user_id = (select auth.uid()));

create policy terms_acceptances_insert_own
on public.terms_acceptances
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.current_terms_versions() v
    where v.document = terms_acceptances.document
      and v.version = terms_acceptances.version
  )
);
