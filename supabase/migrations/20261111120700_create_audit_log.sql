-- Fatia 1 - Fundação. Registro de auditoria.
-- Documento: docs/modelo-dados.md, seção 4.6. Sem política em nenhuma fatia:
-- o app nunca lê audit_log (docs/rls-matriz.md, seção 4).

create table public.audit_log (
  id bigint primary key generated always as identity,
  event text not null,
  -- null = sistema.
  actor_id uuid references public.profiles (id),
  entity_type text not null,
  entity_id uuid not null,
  -- Sem dados pessoais (docs/stacks.md, 13.2).
  data jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_log enable row level security;

create index audit_log_entity_idx on public.audit_log (entity_type, entity_id);
