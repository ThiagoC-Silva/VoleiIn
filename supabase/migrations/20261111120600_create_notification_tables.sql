-- Fatia 1 - Fundação. Notificações e tarefas agendadas.
-- Documento: docs/modelo-dados.md, seção 4.5. RLS ativado sem política (fatia 7 libera
-- notifications, device_tokens e notification_preferences; scheduled_notifications_log
-- nunca é lida pelo app).

-- device_tokens ----------------------------------------------------------
create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  token text not null unique,
  platform public.device_platform not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create index device_tokens_user_idx on public.device_tokens (user_id);

create trigger device_tokens_set_updated_at
before update on public.device_tokens
for each row execute function private.set_updated_at();

comment on table public.device_tokens is
  'Tokens de push. Apagados no logout (RF07) e quando o FCM os invalida.';

-- notification_preferences -----------------------------------------------
-- Sem linha = ativado (RF98).
create table public.notification_preferences (
  user_id uuid not null references public.profiles (id),
  type public.notification_type not null,
  enabled boolean not null,
  primary key (user_id, type)
);

alter table public.notification_preferences enable row level security;

-- notifications (sino) ---------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  type public.notification_type not null,
  title text not null,
  body text not null,
  -- IDs e rota de abertura.
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  -- null quando a preferência está desativada ou o push falhou.
  push_sent_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications enable row level security;

create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
-- Contador do sino.
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

-- scheduled_notifications_log --------------------------------------------
-- Torna as tarefas agendadas idempotentes (RN111, RN113).
create table public.scheduled_notifications_log (
  id uuid primary key default gen_random_uuid(),
  type public.notification_type not null,
  user_id uuid not null references public.profiles (id),
  -- null: a cobrança diária não é por jogo.
  game_id uuid references public.games (id),
  -- Horário de referência: prazo, início ou fim do jogo, ou 9h/20h da cobrança.
  scheduled_for timestamptz not null,
  sent_at timestamptz not null default now()
);

alter table public.scheduled_notifications_log enable row level security;

-- Como o horário de referência faz parte da chave, um jogo remarcado gera um
-- lembrete novo (RN111) e a cobrança diária sai uma vez por usuário e horário.
create unique index scheduled_notifications_log_unique_idx
  on public.scheduled_notifications_log (type, user_id, game_id, scheduled_for) nulls not distinct;
