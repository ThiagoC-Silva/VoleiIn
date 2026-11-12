-- Fatia 1 - Fundação. Tabelas de conta.
-- Documento: docs/modelo-dados.md, seção 4.1.
-- RLS ativado sem política: ninguém lê nada (docs/rls-matriz.md, seção 3).
-- A fatia 2 concede o acesso do dono e cria a trigger da RN105.

-- profiles ---------------------------------------------------------------
-- Dados visíveis a quem compartilha contexto (RN107).
-- A linha nasce por trigger em auth.users quando o e-mail fica confirmado
-- (migração create_profile_from_auth_user).
create table public.profiles (
  id uuid primary key references auth.users (id) on delete restrict,
  name text not null,
  nickname text,
  display_name text generated always as (coalesce(nickname, name)) stored,
  photo_path text,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_name_length check (char_length(btrim(name)) between 1 and 80),
  constraint profiles_nickname_length check (
    nickname is null or char_length(btrim(nickname)) between 1 and 30
  )
);

alter table public.profiles enable row level security;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

comment on table public.profiles is
  'Perfil público do usuário, visível a quem compartilha contexto (RN107).';
comment on column public.profiles.display_name is
  'coalesce(nickname, name): o nome exibido no app (RN100).';
comment on column public.profiles.deleted_at is
  'Preenchida na anonimização da conta (RN104). A linha nunca é apagada.';

-- profile_private --------------------------------------------------------
-- Telefone e chave Pix ficam fora de profiles porque o RLS filtra linhas,
-- não colunas (docs/modelo-dados.md, seção 9.1). Terceiros leem por
-- get_profile_contact (fatia 4).
create table public.profile_private (
  user_id uuid primary key references public.profiles (id),
  phone text,
  phone_visible boolean not null default false,
  pix_key_type public.pix_key_type,
  pix_key text,
  updated_at timestamptz not null default now(),
  constraint profile_private_phone_format check (
    phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'
  ),
  constraint profile_private_pix_pair check ((pix_key_type is null) = (pix_key is null)),
  -- Chave normalizada: CPF/CNPJ só dígitos, e-mail minúsculo, telefone E.164,
  -- aleatória no formato uuid (docs/modelo-dados.md, 4.1).
  constraint profile_private_pix_format check (
    pix_key is null or case pix_key_type
      when 'cpf' then pix_key ~ '^[0-9]{11}$'
      when 'cnpj' then pix_key ~ '^[0-9]{14}$'
      when 'email' then pix_key = lower(pix_key) and pix_key ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
      when 'phone' then pix_key ~ '^\+[1-9][0-9]{7,14}$'
      when 'random' then pix_key ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    end
  )
);

alter table public.profile_private enable row level security;

create trigger profile_private_set_updated_at
before update on public.profile_private
for each row execute function private.set_updated_at();

comment on table public.profile_private is
  'Telefone e chave Pix, com visibilidade própria (RN101, RN102).';

-- terms_acceptances ------------------------------------------------------
create table public.terms_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  document public.legal_document not null,
  version text not null,
  accepted_at timestamptz not null default now(),
  constraint terms_acceptances_version_not_blank check (char_length(btrim(version)) > 0),
  constraint terms_acceptances_unique unique (user_id, document, version)
);

alter table public.terms_acceptances enable row level security;

comment on table public.terms_acceptances is
  'Aceite de Termos e Privacidade por versão (RF105).';
