-- Fatia 6 - Pagamentos, etapa B. Leitura de receipts e bucket receipts.
-- Documentos: docs/rls-matriz.md (fatia 6, linhas da etapa B), research R6 de
-- specs/010-pagamentos-etapa-b, cenários RS01 a RS09, B03, B04, B06 e B10 de
-- docs/testes-referencia.md.

-- Auxiliares -----------------------------------------------------------------

-- Conta não excluída (RN104). Na etapa C, private.require_uid() passa a usá-la.
create or replace function private.is_active_account(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p where p.id = p_user_id and p.deleted_at is null
  );
$$;

-- Pode enviar um arquivo de comprovante: o pagador de um valor Pendente (RN86).
create or replace function private.can_upload_receipt(p_charge_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.charges c
    where c.id = p_charge_id and c.payer_id = p_user_id and c.status = 'pending'
  ) and private.is_active_account(p_user_id);
$$;

-- Pode abrir o arquivo: quem pagou ou quem recebe, pelo registro do comprovante.
create or replace function private.can_read_receipt_file(p_path text, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.receipts r
    where r.storage_path = p_path and (r.payer_id = p_user_id or r.receiver_id = p_user_id)
  );
$$;

revoke all on function private.is_active_account(uuid) from public, anon;
revoke all on function private.can_upload_receipt(uuid, uuid) from public, anon;
revoke all on function private.can_read_receipt_file(text, uuid) from public, anon;
grant execute on function private.is_active_account(uuid) to authenticated;
grant execute on function private.can_upload_receipt(uuid, uuid) to authenticated;
grant execute on function private.can_read_receipt_file(text, uuid) to authenticated;

-- Um arquivo, um comprovante. Também apoia a leitura do arquivo.
create unique index receipts_storage_path_idx
  on public.receipts (storage_path) where storage_path is not null;

-- receipts -------------------------------------------------------------------

grant select on public.receipts to authenticated;

-- O pagador e o recebedor gravado no comprovante (RF87, RN32).
create policy receipts_select_party on public.receipts
for select to authenticated
using (payer_id = (select auth.uid()) or receiver_id = (select auth.uid()));

-- Bucket receipts --------------------------------------------------------------
-- Nome {charge_id}/{uuid}.{ext}, sem subpasta. A pasta só vira uuid depois de
-- conferido o formato: o case garante a ordem.

create policy receipts_insert_payer on storage.objects
for insert to authenticated
with check (
  bucket_id = 'receipts'
  and case
    when name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|heic|pdf)$'
    then private.can_upload_receipt(split_part(name, '/', 1)::uuid, (select auth.uid()))
    else false
  end
);

create policy receipts_select_party on storage.objects
for select to authenticated
using (
  bucket_id = 'receipts'
  and private.can_read_receipt_file(name, (select auth.uid()))
);
