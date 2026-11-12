-- Seed de desenvolvimento. Roda a cada `supabase db reset`, só no local.
-- Documento: docs/setup.md, seção 8. Nunca roda na produção.
--
-- Fatia 1: as quatro contas do login técnico. Cada fatia acrescenta os seus
-- cenários (perfis completos, grupos, jogos, valores, comprovantes...).
--
-- IDs fixos e legíveis, para testes e anotações poderem citá-los:
--   Ana   00000000-0000-0000-0000-00000000000a  recebedora, admin do grupo
--   Bruno 00000000-0000-0000-0000-00000000000b  membro, participante
--   Carla 00000000-0000-0000-0000-00000000000c  membro, participante, espera
--   Diego 00000000-0000-0000-0000-00000000000d  sem grupo, testes de "sem contexto" (RN107)
-- Senha de todos: voleiin123. O domínio .test é reservado e nunca entrega e-mail.
--
-- O perfil e o profile_private nascem pela trigger de auth.users, porque as contas
-- entram já com o e-mail confirmado (docs/modelo-dados.md, 4.1).

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000',
  u.id,
  'authenticated',
  'authenticated',
  u.email,
  extensions.crypt('voleiin123', extensions.gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  jsonb_build_object('name', u.name),
  now(),
  now(),
  '', '', '', ''
from (
  values
    ('00000000-0000-0000-0000-00000000000a'::uuid, 'ana@voleiin.test', 'Ana'),
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'bruno@voleiin.test', 'Bruno'),
    ('00000000-0000-0000-0000-00000000000c'::uuid, 'carla@voleiin.test', 'Carla'),
    ('00000000-0000-0000-0000-00000000000d'::uuid, 'diego@voleiin.test', 'Diego')
) as u (id, email, name);

-- Identidade do provedor de e-mail, como o Supabase Auth cria no cadastro.
insert into auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(),
  u.id,
  u.id::text,
  'email',
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  now(),
  now(),
  now()
from auth.users u
where u.email like '%@voleiin.test';

-- Termos e Privacidade aceitos na versão vigente (docs/setup.md, seção 8).
-- A versão vigente passa a vir da configuração do servidor na fatia 2 (RF105):
-- ao implementá-la, confira se este valor continua igual ao da configuração.
insert into public.terms_acceptances (user_id, document, version)
select p.id, d.document, '1.0'
from public.profiles p
cross join (values ('terms_of_use'::public.legal_document), ('privacy_policy'::public.legal_document)) as d (document);
