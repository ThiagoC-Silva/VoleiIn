-- Fatia 1 - Fundação. Valores a pagar, transições e comprovantes.
-- Documento: docs/modelo-dados.md, seção 4.4. RLS ativado sem política
-- (fatia 5 libera charges e charge_events; fatia 6, receipts).

-- charges ----------------------------------------------------------------
create table public.charges (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id),
  -- A passagem pela lista que originou o valor.
  participant_id uuid not null references public.game_participants (id),
  payer_id uuid not null references public.profiles (id),
  -- Recebedor a quem o valor é devido (RN32).
  receiver_id uuid not null references public.profiles (id),
  kind public.charge_kind not null,
  amount_cents integer not null,
  status public.charge_status not null default 'pending',
  -- Leituras automáticas de comprovante já usadas (RN86).
  auto_reads_used smallint not null default 0,
  paid_at timestamptz,
  paid_via public.payment_method,
  waived_at timestamptz,
  waive_reason public.charge_waive_reason,
  waived_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint charges_amount_positive check (amount_cents > 0),
  constraint charges_auto_reads_range check (auto_reads_used between 0 and 3),
  -- O recebedor nunca paga a si mesmo (RF71).
  constraint charges_payer_not_receiver check (payer_id <> receiver_id),
  constraint charges_paid check ((status = 'paid') = (paid_at is not null and paid_via is not null)),
  constraint charges_waived check (
    (status = 'waived') = (waived_at is not null and waive_reason is not null)
  ),
  -- Só multa pode ser isentada pelo admin (RN66).
  constraint charges_share_not_manually_waived check (
    not (kind = 'share' and waive_reason = 'manual_waiver')
  )
);

alter table public.charges enable row level security;

-- No máximo um valor ativo por pessoa por jogo.
create unique index charges_one_active_per_payer_idx
  on public.charges (game_id, payer_id) where status <> 'waived';
-- Total que devo e cobrança diária (RF75, RF96).
create index charges_payer_status_idx on public.charges (payer_id, status);
-- Total a receber (RF76) e bloqueio da RN105.
create index charges_receiver_status_idx on public.charges (receiver_id, status);
-- Rateio do jogo (RF73, RF74).
create index charges_game_idx on public.charges (game_id);

create trigger charges_set_updated_at
before update on public.charges
for each row execute function private.set_updated_at();

comment on table public.charges is
  'Valor a pagar de uma pessoa em um jogo: parte do rateio ou multa (RN72).';

-- receipts ---------------------------------------------------------------
-- A linha é criada pela Edge Function process-receipt ao fim da leitura, já
-- com o status final da etapa automática (fatia 6).
create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.charges (id),
  payer_id uuid not null references public.profiles (id),
  -- Recebedor do valor no envio: define quem vê o arquivo (RN87).
  receiver_id uuid not null references public.profiles (id),
  -- null depois que o arquivo é apagado (RN91).
  storage_path text,
  mime_type text not null,
  size_bytes integer not null,
  status public.receipt_status not null,
  -- true se contou como leitura automática (RN86).
  auto_read boolean not null,
  extracted_amount_cents integer,
  -- Minuto lido no comprovante, interpretado em America/Sao_Paulo (RN88c).
  extracted_paid_at timestamptz,
  extracted_recipient_name text,
  extracted_recipient_key text,
  transaction_id text,
  extraction jsonb,
  validation jsonb,
  rejection_reason public.receipt_rejection_reason,
  receiver_note text,
  -- null quando a decisão é automática.
  decided_by uuid references public.profiles (id),
  -- Início do prazo de retenção (RN91).
  decided_at timestamptz,
  file_deleted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint receipts_mime_type check (
    mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf')
  ),
  constraint receipts_size_bytes check (size_bytes between 1 and 10485760),
  constraint receipts_decided check ((status = 'under_review') = (decided_at is null)),
  constraint receipts_rejected check ((status = 'rejected') = (rejection_reason is not null)),
  -- Recusa do recebedor exige observação (RN83).
  constraint receipts_receiver_note_required check (
    rejection_reason is distinct from 'receiver_rejected'
      or char_length(btrim(coalesce(receiver_note, ''))) > 0
  ),
  constraint receipts_file_deleted check (file_deleted_at is null or storage_path is null),
  -- Normalizado: trim e maiúsculas (RN89).
  constraint receipts_transaction_id_normalized check (
    transaction_id is null or transaction_id = upper(btrim(transaction_id))
  )
);

alter table public.receipts enable row level security;

-- ID de transação repetido (RN89). Recusado volta a ficar livre.
create unique index receipts_transaction_id_idx
  on public.receipts (transaction_id)
  where status in ('under_review', 'approved') and transaction_id is not null;
-- Um comprovante em análise por valor a pagar.
create unique index receipts_one_under_review_idx
  on public.receipts (charge_id) where status = 'under_review';
-- Histórico do participante (RF86).
create index receipts_charge_created_idx on public.receipts (charge_id, created_at);
-- Fila de análise do recebedor (RF83).
create index receipts_receiver_status_idx on public.receipts (receiver_id, status);
-- Job de retenção: apaga o arquivo 30 dias depois da decisão (RN91, RN92).
create index receipts_retention_idx on public.receipts (decided_at) where storage_path is not null;

-- charge_events ----------------------------------------------------------
-- Toda transição de status de um valor a pagar (RN85, RN93).
create table public.charge_events (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.charges (id),
  -- null na criação do valor.
  from_status public.charge_status,
  to_status public.charge_status not null,
  -- null = sistema.
  actor_id uuid references public.profiles (id),
  receipt_id uuid references public.receipts (id),
  note text,
  created_at timestamptz not null default now()
);

alter table public.charge_events enable row level security;

create index charge_events_charge_idx on public.charge_events (charge_id, created_at);
