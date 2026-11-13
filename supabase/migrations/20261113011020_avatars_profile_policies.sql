-- Fatia 2 - Conta e perfil. Fotos de perfil no bucket avatars.
-- Documentos: docs/rls-matriz.md ("Fatia 2", Storage), docs/modelo-dados.md (seção 7),
-- cenários P15, P16 e A01 a A06.
--
-- Cada pessoa envia, lê e apaga só os arquivos de profiles/{uid}/. Sem update:
-- o app nunca sobrescreve um arquivo (upsert: false). Tipo e tamanho (RN106) são
-- conferidos pelo próprio bucket, antes das políticas. A pasta groups/ e a
-- leitura das fotos de outras pessoas, por contexto, entram na fatia 3.

create policy avatars_profile_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy avatars_profile_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy avatars_profile_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);
