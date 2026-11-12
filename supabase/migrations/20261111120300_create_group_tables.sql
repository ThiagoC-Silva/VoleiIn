-- Fatia 1 - Fundação. Tabelas de grupo.
-- Documento: docs/modelo-dados.md, seção 4.2. RLS ativado sem política (fatia 3 libera).

-- groups -----------------------------------------------------------------
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  photo_path text,
  invite_code text unique,
  invite_code_updated_at timestamptz,
  created_by uuid not null references public.profiles (id),
  archived_at timestamptz,
  archived_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groups_name_length check (char_length(btrim(name)) between 1 and 60),
  -- 12 caracteres base62 (RN11, docs/modelo-dados.md, 9.3).
  constraint groups_invite_code_format check (invite_code is null or invite_code ~ '^[0-9A-Za-z]{12}$'),
  -- Grupo arquivado não tem convite válido (RN17).
  constraint groups_archived_without_invite check (archived_at is null or invite_code is null)
);

alter table public.groups enable row level security;

-- Lista de grupos ativos (RF25).
create index groups_active_idx on public.groups (archived_at) where archived_at is null;

create trigger groups_set_updated_at
before update on public.groups
for each row execute function private.set_updated_at();

comment on column public.groups.archived_at is
  'Preenchida na exclusão do grupo, que arquiva em vez de apagar (RN17, RF103).';

-- group_members ----------------------------------------------------------
create table public.group_members (
  group_id uuid not null references public.groups (id),
  user_id uuid not null references public.profiles (id),
  role public.group_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.group_members enable row level security;

create index group_members_user_idx on public.group_members (user_id);

-- group_join_requests ----------------------------------------------------
create table public.group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id),
  user_id uuid not null references public.profiles (id),
  status public.join_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  -- null quando o cancelamento é automático (exclusão do grupo ou da conta).
  decided_by uuid references public.profiles (id),
  constraint group_join_requests_decision check ((status = 'pending') = (decided_at is null))
);

alter table public.group_join_requests enable row level security;

-- Uma solicitação pendente por pessoa e grupo (RN12).
create unique index group_join_requests_one_pending_idx
  on public.group_join_requests (group_id, user_id) where status = 'pending';

-- Tela de solicitações do admin (RF17).
create index group_join_requests_pending_idx
  on public.group_join_requests (group_id) where status = 'pending';
