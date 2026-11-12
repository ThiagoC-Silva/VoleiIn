-- Fatia 1 - Fundação. Buckets privados do Storage.
-- Documentos: docs/modelo-dados.md (seção 7), docs/rls-matriz.md (seção 3),
-- docs/testes-referencia.md (B09, B10).
--
-- Criados por migração para valer igual no local e na produção. O Storage recusa
-- o arquivo fora do tamanho ou do tipo antes de qualquer política. As políticas de
-- storage.objects entram nas fatias 2, 3 e 6: aqui não há nenhuma, então ninguém
-- envia nem lê arquivo.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  -- Fotos de perfil e de grupo: até 2 MB (RN106).
  ('avatars', 'avatars', false, 2097152, array['image/jpeg', 'image/png', 'image/webp']),
  -- Comprovantes: imagem ou PDF, até 10 MB (RN87).
  ('receipts', 'receipts', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'])
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
