-- Fatia 3 - Grupos. Fotos do grupo e fotos de perfil de outras pessoas no
-- bucket avatars.
-- Documentos: docs/rls-matriz.md (fatia 3), docs/modelo-dados.md (seção 7),
-- cenários B10 e A07 a A13 de docs/testes-referencia.md.
--
-- A pasta só é convertida para uuid quando tem o formato de um UUID; qualquer
-- outro nome nega a operação, sem erro de conversão (A13). Sem update, como na
-- fatia 2: o app nunca sobrescreve um arquivo. A prévia do convite gera a URL da
-- foto do grupo com a chave de serviço, para quem ainda não é membro.

-- URL assinada da foto de quem compartilha contexto (RN107) ou tem solicitação
-- pendente num grupo que quem chama administra (RN107, exceção 2).
create policy avatars_profile_select_context on storage.objects
for select to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and case
    when (storage.foldername(name))[2]
      ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    then private.shares_context((select auth.uid()), ((storage.foldername(name))[2])::uuid)
      or private.has_pending_join_request(((storage.foldername(name))[2])::uuid, (select auth.uid()))
    else false
  end
);

-- URL assinada da foto do grupo, para os membros.
create policy avatars_group_select_member on storage.objects
for select to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'groups'
  and case
    when (storage.foldername(name))[2]
      ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    then private.is_group_member(((storage.foldername(name))[2])::uuid, (select auth.uid()))
    else false
  end
);

-- Enviar a foto do grupo, sempre com nome novo (groups/{group_id}/{uuid}.{ext}).
create policy avatars_group_insert_admin on storage.objects
for insert to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'groups'
  and case
    when (storage.foldername(name))[2]
      ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    then private.is_group_admin(((storage.foldername(name))[2])::uuid, (select auth.uid()))
    else false
  end
);

-- Apagar a foto substituída ou removida.
create policy avatars_group_delete_admin on storage.objects
for delete to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = 'groups'
  and case
    when (storage.foldername(name))[2]
      ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    then private.is_group_admin(((storage.foldername(name))[2])::uuid, (select auth.uid()))
    else false
  end
);
