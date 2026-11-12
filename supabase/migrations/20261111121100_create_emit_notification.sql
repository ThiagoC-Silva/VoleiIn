-- Fatia 1 - Fundação. Registro de notificação.
-- Documentos: docs/contratos-api.md (seção 7), docs/plano-implementacao.md (decisão 2),
-- docs/testes-referencia.md (B37).
--
-- Toda função que gera um evento chama esta, na mesma transação (RN110). Até a
-- fatia 7 o texto é provisório: title = o tipo e body vazio. A fatia 7 entrega o
-- texto final, as preferências e o disparo do push.

create or replace function private.emit_notification(
  p_type public.notification_type,
  p_user_id uuid,
  p_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_type::text, '', coalesce(p_data, '{}'::jsonb))
  returning id into v_id;

  return v_id;
end;
$$;

comment on function private.emit_notification(public.notification_type, uuid, jsonb) is
  'Grava a notificação no histórico e devolve o id. Texto provisório até a fatia 7 (RN110).';

-- Nunca exposta ao app (ADR 0015).
revoke all on function private.emit_notification(public.notification_type, uuid, jsonb)
  from public, anon, authenticated;
