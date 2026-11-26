-- Seed de desenvolvimento. Roda a cada `supabase db reset`, só no local.
-- Documento: docs/setup.md, seção 8. Nunca roda na produção.
--
-- Fatia 1: as quatro contas do login técnico. Fatia 2: perfis completos e o
-- aceite dos termos. Fatia 3: os grupos Vôlei de Quinta e Vôlei de Domingo.
-- Fatia 4: os sete jogos (Aberto, Confirmado, em andamento, Cancelado, prazo
-- vencido, o da Carla e o avulso). Fatia 5, etapa A: o jogo concluído, com os
-- valores, e o jogo aguardando conclusão. Fatia 6, etapa B: o jogo com
-- comprovantes nos três status.
-- Cada fatia acrescenta os seus cenários (jogos, valores, comprovantes...).
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

-- Grupos (fatia 3, docs/setup.md, seção 8). IDs e códigos fixos para os testes
-- de Deno e os fluxos L12 a L14. Sem foto. Diego continua sem grupo: a
-- solicitação pendente no Domingo não é contexto (RN107), e só o Bruno, admin do
-- Domingo, vê o perfil dele (RN107, exceção 2).
insert into public.groups (id, name, invite_code, invite_code_updated_at, created_by)
values
  ('00000000-0000-0000-0000-000000000101', 'Vôlei de Quinta', 'VoleiQuinta1', now(),
   '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-000000000102', 'Vôlei de Domingo', 'VoleiDomingo', now(),
   '00000000-0000-0000-0000-00000000000b');

insert into public.group_members (group_id, user_id, role)
values
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-00000000000a', 'admin'),
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-00000000000b', 'member'),
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-00000000000c', 'member'),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-00000000000b', 'admin');

insert into public.group_join_requests (group_id, user_id)
values ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-00000000000d');

-- Jogos (fatia 4, docs/setup.md, seção 8). IDs e códigos fixos para os fluxos
-- L15 a L19. "Dia +n" é hoje mais n dias em America/Fortaleza, nas horas desse
-- fuso. Quem está primeiro na lista é o admin e o recebedor; a trigger grava o
-- limite inicial em game_limit_history. Diego fica fora de todos.
-- Um bloco só: a invariante de admin do jogo (RN25) é conferida no fim da
-- transação, e o jogo e o admin precisam entrar juntos.
do $seed$
declare
  v_today date := (now() at time zone 'America/Fortaleza')::date;
  v_ana constant uuid := '00000000-0000-0000-0000-00000000000a';
  v_bruno constant uuid := '00000000-0000-0000-0000-00000000000b';
  v_carla constant uuid := '00000000-0000-0000-0000-00000000000c';
  v_quinta constant uuid := '00000000-0000-0000-0000-000000000101';
  v_receipt_charge uuid;
  v_receipt jsonb;
begin
  insert into public.games (
    id, group_id, created_by, receiver_id, invite_code, location_name, maps_url,
    cancellation_deadline, starts_at, ends_at, total_cents, slot_limit, status,
    cancelled_at, cancelled_by
  )
  values
    -- Quinta Aberto: Ana na lista; Carla cancelou no prazo.
    ('00000000-0000-0000-0000-000000000201', v_quinta, v_ana, v_ana, 'JogoAberto01',
     'Quadra do Sesc', 'https://www.google.com/maps/search/?api=1&query=Sesc+Parna%C3%ADba',
     (v_today + 2 + time '18:00') at time zone 'America/Fortaleza',
     (v_today + 2 + time '20:00') at time zone 'America/Fortaleza',
     (v_today + 2 + time '22:00') at time zone 'America/Fortaleza',
     12000, 12, 'open', null, null),
    -- Quinta Confirmado: Ana e Carla; Bruno na espera.
    ('00000000-0000-0000-0000-000000000202', v_quinta, v_ana, v_ana, 'JogoCheio001',
     'Ginásio Verdão', null,
     (v_today + 3 + time '18:00') at time zone 'America/Fortaleza',
     (v_today + 3 + time '20:00') at time zone 'America/Fortaleza',
     (v_today + 3 + time '22:00') at time zone 'America/Fortaleza',
     6000, 2, 'confirmed', null, null),
    -- Quinta em andamento: começou 30 min antes do reset e termina 90 min depois.
    ('00000000-0000-0000-0000-000000000203', v_quinta, v_ana, v_ana, 'JogoAndamen1',
     'Quadra do Sesc', null,
     now() - interval '210 minutes', now() - interval '30 minutes', now() + interval '90 minutes',
     12000, 12, 'open', null, null),
    -- Quinta cancelado pela Ana.
    ('00000000-0000-0000-0000-000000000204', v_quinta, v_ana, v_ana, 'JogoCancel01',
     'Quadra do Sesc', null,
     (v_today + 4 + time '18:00') at time zone 'America/Fortaleza',
     (v_today + 4 + time '20:00') at time zone 'America/Fortaleza',
     (v_today + 4 + time '22:00') at time zone 'America/Fortaleza',
     12000, 12, 'cancelled', now(), v_ana),
    -- Quinta prazo vencido: começa 1 h depois do reset, prazo 1 h antes dele.
    ('00000000-0000-0000-0000-000000000205', v_quinta, v_ana, v_ana, 'JogoPrazo001',
     'Ginásio Verdão', null,
     now() - interval '1 hour', now() + interval '1 hour', now() + interval '3 hours',
     6000, 6, 'open', null, null),
    -- Jogo da Carla: ela é a recebedora e a única admin (L19).
    ('00000000-0000-0000-0000-000000000206', v_quinta, v_carla, v_carla, 'JogoCarla001',
     'Arena Delta', null,
     (v_today + 5 + time '17:00') at time zone 'America/Fortaleza',
     (v_today + 5 + time '19:00') at time zone 'America/Fortaleza',
     (v_today + 5 + time '21:00') at time zone 'America/Fortaleza',
     8000, 8, 'open', null, null),
    -- Avulso da Ana, sem grupo.
    ('00000000-0000-0000-0000-000000000207', null, v_ana, v_ana, 'JogoAvulso01',
     'Praia do Coqueiro', null,
     (v_today + 6 + time '16:00') at time zone 'America/Fortaleza',
     (v_today + 6 + time '18:00') at time zone 'America/Fortaleza',
     (v_today + 6 + time '20:00') at time zone 'America/Fortaleza',
     4000, 4, 'open', null, null);

  insert into public.game_admins (game_id, user_id)
  values
    ('00000000-0000-0000-0000-000000000201', v_ana),
    ('00000000-0000-0000-0000-000000000202', v_ana),
    ('00000000-0000-0000-0000-000000000203', v_ana),
    ('00000000-0000-0000-0000-000000000204', v_ana),
    ('00000000-0000-0000-0000-000000000205', v_ana),
    ('00000000-0000-0000-0000-000000000206', v_carla),
    ('00000000-0000-0000-0000-000000000207', v_ana);

  -- Passagens: o primeiro entrou 2 dias antes; os outros, depois, na ordem da lista.
  insert into public.game_participants (game_id, user_id, joined_at)
  values
    ('00000000-0000-0000-0000-000000000201', v_ana, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000202', v_ana, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000202', v_carla, now() - interval '1 day'),
    ('00000000-0000-0000-0000-000000000203', v_ana, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000203', v_bruno, now() - interval '1 day'),
    ('00000000-0000-0000-0000-000000000203', v_carla, now() - interval '20 hours'),
    ('00000000-0000-0000-0000-000000000204', v_ana, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000204', v_bruno, now() - interval '1 day'),
    ('00000000-0000-0000-0000-000000000205', v_ana, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000206', v_carla, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000206', v_ana, now() - interval '1 day'),
    ('00000000-0000-0000-0000-000000000207', v_ana, now() - interval '2 days');

  -- Cancelamentos: Carla no prazo, no Quinta Aberto; Bruno fora do prazo, 30 min
  -- antes do reset, no Quinta prazo vencido.
  insert into public.game_participants (
    game_id, user_id, joined_at, status, left_at, late_cancellation
  )
  values
    ('00000000-0000-0000-0000-000000000201', v_carla, now() - interval '1 day', 'cancelled',
     now() - interval '1 hour', false),
    ('00000000-0000-0000-0000-000000000205', v_bruno, now() - interval '1 day', 'cancelled',
     now() - interval '30 minutes', true);

  insert into public.game_waitlist (game_id, user_id, joined_at)
  values ('00000000-0000-0000-0000-000000000202', v_bruno, now() - interval '12 hours');

  -- Fatia 5, etapa A (research R8 de specs/006-conclusao-etapa-a). Quinta
  -- concluído: ontem, concluído pela Ana com a mesma função do app. Quinta
  -- aguardando conclusão: terminou 10 min antes do reset; a conclusão automática
  -- o conclui 50 min depois.
  insert into public.games (
    id, group_id, created_by, receiver_id, invite_code, location_name, maps_url,
    cancellation_deadline, starts_at, ends_at, total_cents, slot_limit, status
  )
  values
    ('00000000-0000-0000-0000-000000000208', v_quinta, v_ana, v_ana, 'JogoConclu01',
     'Quadra do Sesc', null,
     (v_today - 1 + time '18:00') at time zone 'America/Fortaleza',
     (v_today - 1 + time '20:00') at time zone 'America/Fortaleza',
     (v_today - 1 + time '22:00') at time zone 'America/Fortaleza',
     6000, 6, 'open'),
    ('00000000-0000-0000-0000-000000000209', v_quinta, v_ana, v_ana, 'JogoAguard01',
     'Ginásio Verdão', null,
     now() - interval '250 minutes', now() - interval '130 minutes', now() - interval '10 minutes',
     -- 3 vagas, lista cheia: R$ 30,00 por vaga e R$ 60,00 a receber no L20.
     9000, 3, 'confirmed');

  insert into public.game_admins (game_id, user_id)
  values ('00000000-0000-0000-0000-000000000208', v_ana), ('00000000-0000-0000-0000-000000000209', v_ana);

  insert into public.game_participants (game_id, user_id, joined_at)
  values
    ('00000000-0000-0000-0000-000000000208', v_ana, now() - interval '3 days'),
    ('00000000-0000-0000-0000-000000000208', v_bruno, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000208', v_carla, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000209', v_ana, now() - interval '2 days'),
    ('00000000-0000-0000-0000-000000000209', v_bruno, now() - interval '1 day'),
    ('00000000-0000-0000-0000-000000000209', v_carla, now() - interval '1 day');

  perform private.complete_game_core(
    (select g from public.games g where g.id = '00000000-0000-0000-0000-000000000208'),
    v_ana, null, '{}', 'manual', false
  );

  -- Fatia 5, etapa B (research R4 de specs/007-conclusao-etapa-b). Quinta com
  -- multas: anteontem, Ana e Carla na lista e Bruno com cancelamento fora do
  -- prazo. Ana conclui com a Carla faltosa (as 2 vagas ociosas mantêm a multa
  -- do Bruno) e isenta a multa do Bruno pela waive_penalty.
  insert into public.games (
    id, group_id, created_by, receiver_id, invite_code, location_name, maps_url,
    cancellation_deadline, starts_at, ends_at, total_cents, slot_limit, status
  )
  values (
    '00000000-0000-0000-0000-000000000210', v_quinta, v_ana, v_ana, 'JogoMultas01',
    'Ginásio Verdão', null,
    (v_today - 2 + time '18:00') at time zone 'America/Fortaleza',
    (v_today - 2 + time '20:00') at time zone 'America/Fortaleza',
    (v_today - 2 + time '22:00') at time zone 'America/Fortaleza',
    4000, 4, 'open'
  );

  insert into public.game_admins (game_id, user_id)
  values ('00000000-0000-0000-0000-000000000210', v_ana);

  insert into public.game_participants (game_id, user_id, joined_at)
  values
    ('00000000-0000-0000-0000-000000000210', v_ana, now() - interval '4 days'),
    ('00000000-0000-0000-0000-000000000210', v_carla, now() - interval '3 days');
  insert into public.game_participants (
    game_id, user_id, joined_at, status, left_at, late_cancellation
  )
  values (
    '00000000-0000-0000-0000-000000000210', v_bruno, now() - interval '3 days', 'cancelled',
    (v_today - 2 + time '18:30') at time zone 'America/Fortaleza', true
  );

  perform private.complete_game_core(
    (select g from public.games g where g.id = '00000000-0000-0000-0000-000000000210'),
    v_ana, null, array[v_carla], 'manual', false
  );

  perform set_config('request.jwt.claims', json_build_object('sub', v_ana)::text, true);
  perform public.waive_penalty(
    (select c.id from public.charges c
     where c.game_id = '00000000-0000-0000-0000-000000000210' and c.payer_id = v_bruno)
  );
  perform set_config('request.jwt.claims', '', true);

  -- Fatia 5, etapa C (research R7 de specs/008-conclusao-etapa-c). Quinta com
  -- troca: três dias antes, Ana, Bruno e Carla na lista. Ana conclui e passa o
  -- recebimento para a Carla pela change_receiver: o share da Carla fica Isento,
  -- o do Bruno passa à Carla e a Ana ganha um share Pendente para a Carla.
  insert into public.games (
    id, group_id, created_by, receiver_id, invite_code, location_name, maps_url,
    cancellation_deadline, starts_at, ends_at, total_cents, slot_limit, status
  )
  values (
    '00000000-0000-0000-0000-000000000211', v_quinta, v_ana, v_ana, 'JogoTroca001',
    'Quadra da Lagoa', null,
    (v_today - 3 + time '18:00') at time zone 'America/Fortaleza',
    (v_today - 3 + time '20:00') at time zone 'America/Fortaleza',
    (v_today - 3 + time '22:00') at time zone 'America/Fortaleza',
    6000, 3, 'confirmed'
  );

  insert into public.game_admins (game_id, user_id)
  values ('00000000-0000-0000-0000-000000000211', v_ana);

  insert into public.game_participants (game_id, user_id, joined_at)
  values
    ('00000000-0000-0000-0000-000000000211', v_ana, now() - interval '5 days'),
    ('00000000-0000-0000-0000-000000000211', v_bruno, now() - interval '4 days'),
    ('00000000-0000-0000-0000-000000000211', v_carla, now() - interval '4 days');

  perform private.complete_game_core(
    (select g from public.games g where g.id = '00000000-0000-0000-0000-000000000211'),
    v_ana, null, '{}', 'manual', false
  );

  perform set_config('request.jwt.claims', json_build_object('sub', v_ana)::text, true);
  perform public.change_receiver('00000000-0000-0000-0000-000000000211', v_carla);
  perform set_config('request.jwt.claims', '', true);

  -- Fatia 6, etapa A (research R6 de specs/009-pagamentos-etapa-a). Ana marca
  -- como pago o share da Carla no Quinta concluído; o do Bruno fica Pendente.
  perform set_config('request.jwt.claims', json_build_object('sub', v_ana)::text, true);
  perform public.mark_charge_paid(
    (select c.id from public.charges c
     where c.game_id = '00000000-0000-0000-0000-000000000208' and c.payer_id = v_carla)
  );
  perform set_config('request.jwt.claims', '', true);

  -- Fatia 6, etapa B (research R12 de specs/010-pagamentos-etapa-b). Quinta com
  -- comprovantes: quatro dias antes, Ana, Bruno e Carla, R$ 60,00, concluído pela
  -- Ana. Os comprovantes passam pela record_receipt, com a leitura pronta. A
  -- Carla tem um aprovado automaticamente (a chave da Ana confere: o perfil dela
  -- tem um nome só). O Bruno tem um recusado pela Ana e um Em análise, com o nome
  -- lido sem conferir. Os decididos ficam com o arquivo apagado; o Em análise,
  -- com um caminho sem arquivo (docs/setup.md, seção 8).
  insert into public.games (
    id, group_id, created_by, receiver_id, invite_code, location_name, maps_url,
    cancellation_deadline, starts_at, ends_at, total_cents, slot_limit, status
  )
  values (
    '00000000-0000-0000-0000-000000000212', v_quinta, v_ana, v_ana, 'JogoCompr001',
    'Ginásio Verdão', null,
    (v_today - 4 + time '18:00') at time zone 'America/Fortaleza',
    (v_today - 4 + time '20:00') at time zone 'America/Fortaleza',
    (v_today - 4 + time '22:00') at time zone 'America/Fortaleza',
    6000, 3, 'confirmed'
  );

  insert into public.game_admins (game_id, user_id)
  values ('00000000-0000-0000-0000-000000000212', v_ana);

  insert into public.game_participants (game_id, user_id, joined_at)
  values
    ('00000000-0000-0000-0000-000000000212', v_ana, now() - interval '6 days'),
    ('00000000-0000-0000-0000-000000000212', v_bruno, now() - interval '5 days'),
    ('00000000-0000-0000-0000-000000000212', v_carla, now() - interval '5 days');

  perform private.complete_game_core(
    (select g from public.games g where g.id = '00000000-0000-0000-0000-000000000212'),
    v_ana, null, '{}', 'manual', false
  );

  select c.id into v_receipt_charge from public.charges c
  where c.game_id = '00000000-0000-0000-0000-000000000212' and c.payer_id = v_carla;
  perform public.record_receipt(
    v_receipt_charge, v_carla,
    v_receipt_charge::text || '/00000000-0000-0000-0000-0000000002c1.jpg', 'image/jpeg', 182000,
    jsonb_build_object(
      'outcome', 'read', 'amount_cents', 2000,
      'paid_at', to_char(v_today - 4 + time '22:31', 'YYYY-MM-DD"T"HH24:MI'),
      'recipient_name', 'ANA', 'recipient_key', '529.982.247-25',
      'transaction_id', 'E11122233' || to_char(
        (v_today - 4 + time '22:31') at time zone 'America/Fortaleza' at time zone 'UTC',
        'YYYYMMDDHH24MI') || 'SEEDCARLA01',
      'raw', jsonb_build_object('model', 'seed', 'prompt_version', 1)
    )
  );

  select c.id into v_receipt_charge from public.charges c
  where c.game_id = '00000000-0000-0000-0000-000000000212' and c.payer_id = v_bruno;
  v_receipt := public.record_receipt(
    v_receipt_charge, v_bruno,
    v_receipt_charge::text || '/00000000-0000-0000-0000-0000000002b1.jpg', 'image/jpeg', 95000,
    jsonb_build_object(
      'outcome', 'read', 'amount_cents', null, 'paid_at', null, 'recipient_name', null,
      'recipient_key', null, 'transaction_id', null,
      'raw', jsonb_build_object('model', 'seed', 'prompt_version', 1)
    )
  );
  perform set_config('request.jwt.claims', json_build_object('sub', v_ana)::text, true);
  perform public.review_receipt(
    (v_receipt ->> 'receipt_id')::uuid, false, 'Não dá para ler o valor. Envie outro.'
  );
  perform set_config('request.jwt.claims', '', true);
  perform public.record_receipt(
    v_receipt_charge, v_bruno,
    v_receipt_charge::text || '/00000000-0000-0000-0000-0000000002b2.png', 'image/png', 240000,
    jsonb_build_object(
      'outcome', 'read', 'amount_cents', 2000,
      'paid_at', to_char(v_today - 3 + time '09:12', 'YYYY-MM-DD"T"HH24:MI'),
      'recipient_name', 'ANA PAULA', 'recipient_key', null,
      'transaction_id', 'E11122233' || to_char(
        (v_today - 3 + time '09:12') at time zone 'America/Fortaleza' at time zone 'UTC',
        'YYYYMMDDHH24MI') || 'SEEDBRUNO02',
      'raw', jsonb_build_object('model', 'seed', 'prompt_version', 1)
    )
  );

  update public.receipts r set storage_path = null, file_deleted_at = now()
  from public.charges c
  where c.id = r.charge_id and c.game_id = '00000000-0000-0000-0000-000000000212'
    and r.status <> 'under_review';
end;
$seed$;
