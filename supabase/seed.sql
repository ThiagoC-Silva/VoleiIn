-- Seed de desenvolvimento. Roda a cada `supabase db reset`, só no local.
-- Documento: docs/setup.md, seção 8. Nunca roda na produção.
--
-- Fatia 1: as quatro contas do login técnico. Fatia 2: perfis completos e o
-- aceite dos termos. Cada fatia acrescenta os seus cenários (grupos, jogos,
-- valores, comprovantes...).
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

-- Perfis completos (fatia 2): apelido, telefone visível e oculto, chave Pix de
-- vários tipos, e o Diego com o perfil mínimo, sem telefone nem chave.
update public.profiles p
set nickname = v.nickname
from (
  values
    ('00000000-0000-0000-0000-00000000000a'::uuid, null::text),
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'Brunão'),
    ('00000000-0000-0000-0000-00000000000c'::uuid, 'Carlinha'),
    ('00000000-0000-0000-0000-00000000000d'::uuid, null::text)
) as v (id, nickname)
where p.id = v.id;

update public.profile_private pp
set phone = v.phone,
    phone_visible = v.phone_visible,
    pix_key_type = v.pix_key_type,
    pix_key = v.pix_key
from (
  values
    -- Ana, recebedora: telefone visível e chave CPF.
    ('00000000-0000-0000-0000-00000000000a'::uuid, '+5586999991234', true,
     'cpf'::public.pix_key_type, '52998224725'),
    -- Bruno: telefone oculto e chave e-mail.
    ('00000000-0000-0000-0000-00000000000b'::uuid, '+5586988887777', false,
     'email'::public.pix_key_type, 'bruno@exemplo.com'),
    -- Carla: sem telefone, chave aleatória.
    ('00000000-0000-0000-0000-00000000000c'::uuid, null, false,
     'random'::public.pix_key_type, '123e4567-e89b-12d3-a456-426614174000'),
    -- Diego: nada além do nome.
    ('00000000-0000-0000-0000-00000000000d'::uuid, null, false, null, null)
) as v (user_id, phone, phone_visible, pix_key_type, pix_key)
where pp.user_id = v.user_id;

-- Termos e Privacidade aceitos na versão vigente (docs/setup.md, seção 8), lida
-- da própria função: quando uma migração trocar a versão, o seed acompanha.
insert into public.terms_acceptances (user_id, document, version)
select p.id, v.document, v.version
from public.profiles p
cross join public.current_terms_versions() as v;
