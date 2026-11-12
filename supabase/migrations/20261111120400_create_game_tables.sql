-- Fatia 1 - Fundação. Tabelas de jogo, lista de presença e espera.
-- Documento: docs/modelo-dados.md, seção 4.3. RLS ativado sem política (fatia 4 libera).

-- games ------------------------------------------------------------------
create table public.games (
  id uuid primary key default gen_random_uuid(),
  -- null = jogo avulso (RF26).
  group_id uuid references public.groups (id),
  created_by uuid not null references public.profiles (id),
  location_name text not null,
  maps_url text,
  cancellation_deadline timestamptz not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  total_cents integer not null,
  slot_limit integer not null,
  status public.game_status not null default 'open',
  receiver_id uuid not null references public.profiles (id),
  invite_code text not null unique,
  share_cents integer,
  completed_at timestamptz,
  completion_mode public.game_completion_mode,
  completed_by uuid references public.profiles (id),
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint games_location_name_length check (char_length(btrim(location_name)) between 1 and 120),
  constraint games_maps_url_scheme check (maps_url is null or maps_url like 'https://%'),
  -- RN23. "Início no futuro" depende de now() e é validado em create_game (fatia 4).
  constraint games_dates check (cancellation_deadline <= starts_at and starts_at < ends_at),
  constraint games_total_cents_positive check (total_cents > 0),
  constraint games_slot_limit_min check (slot_limit >= 1),
  constraint games_invite_code_format check (invite_code ~ '^[0-9A-Za-z]{12}$'),
  constraint games_completed check (
    (status = 'completed')
      = (completed_at is not null and share_cents is not null and completion_mode is not null)
  ),
  constraint games_cancelled check ((status = 'cancelled') = (cancelled_at is not null))
);

alter table public.games enable row level security;

-- Jogos do grupo (RF44).
create index games_group_starts_idx on public.games (group_id, starts_at);
-- Conclusão automática e aviso aos admins (RF42, RF94).
create index games_ends_active_idx on public.games (ends_at) where status in ('open', 'confirmed');
-- Lembretes de prazo e de início (RF92, RF93).
create index games_deadline_active_idx
  on public.games (cancellation_deadline) where status in ('open', 'confirmed');
create index games_starts_active_idx on public.games (starts_at) where status in ('open', 'confirmed');
create index games_receiver_idx on public.games (receiver_id);

create trigger games_set_updated_at
before update on public.games
for each row execute function private.set_updated_at();

comment on column public.games.share_cents is
  'Parte por vaga, gravada na conclusão (RN71). O servidor decide; o app só exibe.';
comment on column public.games.slot_limit is
  'Limite de vagas, congelado a partir do início (RN34).';

-- game_limit_history -----------------------------------------------------
-- Cada valor do limite de vagas, para calcular o L da RN62.
-- Preenchida por trigger (migração create_game_limit_history_trigger).
create table public.game_limit_history (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id),
  slot_limit integer not null,
  effective_from timestamptz not null default now(),
  constraint game_limit_history_slot_limit_min check (slot_limit >= 1)
);

alter table public.game_limit_history enable row level security;

create index game_limit_history_game_idx on public.game_limit_history (game_id, effective_from);

-- game_admins ------------------------------------------------------------
create table public.game_admins (
  game_id uuid not null references public.games (id),
  user_id uuid not null references public.profiles (id),
  -- null quando é o criador do jogo.
  added_by uuid references public.profiles (id),
  added_at timestamptz not null default now(),
  primary key (game_id, user_id)
);

alter table public.game_admins enable row level security;

create index game_admins_user_idx on public.game_admins (user_id);

comment on table public.game_admins is
  'Admins do jogo. Ao menos um por jogo (RN25); sair da lista não tira o papel (RN26).';

-- game_participants ------------------------------------------------------
-- Cada linha é uma passagem pela lista. Quem cancela e volta ganha uma linha
-- nova, e a linha antiga fica com o cancelamento anulado (RN56).
create table public.game_participants (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id),
  user_id uuid not null references public.profiles (id),
  -- now() do servidor; define a ordem da lista (RN52).
  joined_at timestamptz not null default now(),
  status public.participant_status not null default 'active',
  left_at timestamptz,
  removal_reason public.removal_reason,
  -- Fixado no cancelamento: left_at > cancellation_deadline (RN35, RN61).
  late_cancellation boolean,
  cancellation_voided_at timestamptz,
  -- Resultado da isenção automática, gravado na conclusão (RN62).
  late_cancellation_exempt boolean,
  absent boolean not null default false,
  absence_source public.absence_source,
  constraint game_participants_active check ((status = 'active') = (left_at is null)),
  constraint game_participants_cancelled check ((status = 'cancelled') = (late_cancellation is not null)),
  constraint game_participants_removed check ((status = 'removed') = (removal_reason is not null)),
  constraint game_participants_absent check (absent = (absence_source is not null)),
  constraint game_participants_voided_only_when_cancelled check (
    cancellation_voided_at is null or status = 'cancelled'
  )
);

alter table public.game_participants enable row level security;

-- Uma vaga por pessoa. Vaga ocupada = active ou left_after_start (RN57).
create unique index game_participants_one_slot_idx
  on public.game_participants (game_id, user_id) where status in ('active', 'left_after_start');
-- Lista ordenada e texto do WhatsApp (RF100).
create index game_participants_game_joined_idx on public.game_participants (game_id, joined_at);
-- "Meus jogos" (RF44) e visibilidade de perfil (RN107).
create index game_participants_user_game_idx on public.game_participants (user_id, game_id);
-- Candidatos a multa de cancelamento (RN62).
create index game_participants_penalty_candidates_idx
  on public.game_participants (game_id, left_at)
  where status = 'cancelled' and late_cancellation and cancellation_voided_at is null;

-- game_waitlist ----------------------------------------------------------
-- A linha é mantida com left_at preenchido, em vez de apagada: passar pela
-- espera também conta como contexto compartilhado (RN107).
create table public.game_waitlist (
  game_id uuid not null references public.games (id),
  user_id uuid not null references public.profiles (id),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (game_id, user_id)
);

alter table public.game_waitlist enable row level security;

create index game_waitlist_user_idx on public.game_waitlist (user_id);

-- receiver_changes -------------------------------------------------------
create table public.receiver_changes (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id),
  old_receiver_id uuid not null references public.profiles (id),
  new_receiver_id uuid not null references public.profiles (id),
  changed_by uuid not null references public.profiles (id),
  after_completion boolean not null,
  changed_at timestamptz not null default now(),
  constraint receiver_changes_distinct check (old_receiver_id <> new_receiver_id)
);

alter table public.receiver_changes enable row level security;

create index receiver_changes_game_idx on public.receiver_changes (game_id, changed_at);

comment on table public.receiver_changes is
  'Histórico das trocas de recebedor (RN30, RN31, RN115).';
