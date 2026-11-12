-- Fatia 1 - Fundação. Enums do domínio.
-- Documento: docs/modelo-dados.md, seção 3. Os rótulos em pt-BR ficam no app (docs/copy.md).

-- Conta
create type public.pix_key_type as enum ('cpf', 'cnpj', 'email', 'phone', 'random');
create type public.legal_document as enum ('terms_of_use', 'privacy_policy');

-- Grupos
create type public.group_role as enum ('admin', 'member');
create type public.join_request_status as enum ('pending', 'approved', 'rejected', 'cancelled');

-- Jogos
create type public.game_status as enum ('open', 'confirmed', 'cancelled', 'completed');
create type public.game_completion_mode as enum ('manual', 'automatic');
create type public.participant_status as enum ('active', 'left_after_start', 'cancelled', 'removed');
create type public.removal_reason as enum ('by_admin', 'left_group', 'account_deleted');
create type public.absence_source as enum ('left_after_start', 'marked_by_admin');

-- Rateio e pagamentos
create type public.charge_kind as enum ('share', 'absence_penalty', 'late_cancellation_penalty');
create type public.charge_status as enum ('pending', 'under_review', 'paid', 'waived');
create type public.charge_waive_reason as enum ('manual_waiver', 'receiver_change');
create type public.payment_method as enum ('receipt', 'manual');
create type public.receipt_status as enum ('under_review', 'approved', 'rejected');
create type public.receipt_rejection_reason as enum ('duplicate_transaction', 'receiver_rejected');

-- Notificações
create type public.device_platform as enum ('android', 'ios');

create type public.notification_type as enum (
  'group_join_requested',
  'group_join_decided',
  'removed_from_group',
  'waitlist_slot_opened',
  'game_confirmed',
  'game_cancelled',
  'game_completed',
  'game_updated',
  'removed_from_game',
  'reminder_cancellation_deadline',
  'reminder_game_start',
  'reminder_complete_game',
  'charge_created',
  'penalty_waived',
  'charge_reminder',
  'receipt_needs_review',
  'payment_received',
  'charge_paid',
  'charge_back_to_pending',
  'receiver_changed'
);
