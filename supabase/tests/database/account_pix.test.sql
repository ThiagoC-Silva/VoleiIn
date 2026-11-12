-- Chave Pix e RN105 (fatia 2).
-- Cenários X01 a X10 e N01 a N09 de docs/testes-referencia.md, seção 10.2.
-- Formatos: docs/modelo-dados.md, 4.1. Trigger: RN105, contratos-api.md (PIX_KEY_IN_USE).
--
-- Os formatos rodam como postgres, direto em profile_private. A RN105 roda como
-- a pessoa logada, para provar que a trigger vale também para a escrita do app.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

-- Personagens do seed (docs/setup.md, seção 8), criados aqui se faltarem.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  'nao-usado-no-teste', now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb, jsonb_build_object('name', u.name),
  now(), now(), '', '', '', ''
from (
  values
    ('00000000-0000-0000-0000-00000000000a'::uuid, 'ana@voleiin.test', 'Ana'),
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'bruno@voleiin.test', 'Bruno')
) as u (id, email, name)
on conflict do nothing;

-- Ajudantes ------------------------------------------------------------------

-- Grava a chave da Ana, como postgres (formatos X01 a X10).
create function pg_temp.set_pix(p_type public.pix_key_type, p_key text)
returns void
language sql
as $fn$
  update public.profile_private
  set pix_key_type = p_type, pix_key = p_key
  where user_id = '00000000-0000-0000-0000-00000000000a';
$fn$;

-- Deixa Ana e Bruno com chave e sem nada em aberto como recebedores, qualquer
-- que seja o seed: cada cenário N parte daqui e monta só o que descreve.
create function pg_temp.clean_receiver_state()
returns void
language plpgsql
as $fn$
begin
  update public.games
  set status = 'cancelled', cancelled_at = now()
  where status in ('open', 'confirmed')
    and receiver_id in (
      '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'
    );

  update public.charges
  set status = 'waived', waived_at = now(), waive_reason = 'receiver_change'
  where status in ('pending', 'under_review')
    and receiver_id in (
      '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'
    );

  update public.profile_private
  set pix_key_type = 'cpf', pix_key = '52998224725', phone = null, phone_visible = false
  where user_id = '00000000-0000-0000-0000-00000000000a';

  update public.profile_private
  set pix_key_type = 'email', pix_key = 'bruno@exemplo.com'
  where user_id = '00000000-0000-0000-0000-00000000000b';
end;
$fn$;

-- Jogo com Ana como recebedora, no status pedido.
create function pg_temp.mk_game(p_status public.game_status)
returns uuid
language plpgsql
as $fn$
declare
  v_id uuid;
begin
  insert into public.games (
    created_by, location_name, cancellation_deadline, starts_at, ends_at,
    total_cents, slot_limit, receiver_id, invite_code, status,
    cancelled_at, completed_at, share_cents, completion_mode
  )
  values (
    '00000000-0000-0000-0000-00000000000a', 'Quadra do teste',
    now() + interval '1 day', now() + interval '2 days', now() + interval '2 days 2 hours',
    20000, 12, '00000000-0000-0000-0000-00000000000a',
    substr(replace(gen_random_uuid()::text, '-', ''), 1, 12), p_status,
    case when p_status = 'cancelled' then now() end,
    case when p_status = 'completed' then now() end,
    case when p_status = 'completed' then 10000 end,
    case when p_status = 'completed' then 'manual'::public.game_completion_mode end
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

-- Valor que o Bruno deve à Ana por um jogo concluído, no status pedido.
create function pg_temp.mk_charge(p_status public.charge_status)
returns uuid
language plpgsql
as $fn$
declare
  v_game uuid := pg_temp.mk_game('completed');
  v_participant uuid;
  v_id uuid;
begin
  insert into public.game_participants (game_id, user_id)
  values (v_game, '00000000-0000-0000-0000-00000000000b')
  returning id into v_participant;

  insert into public.charges (
    game_id, participant_id, payer_id, receiver_id, kind, amount_cents, status,
    paid_at, paid_via, waived_at, waive_reason
  )
  values (
    v_game, v_participant,
    '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a',
    'share', 10000, p_status,
    case when p_status = 'paid' then now() end,
    case when p_status = 'paid' then 'manual'::public.payment_method end,
    case when p_status = 'waived' then now() end,
    case when p_status = 'waived' then 'receiver_change'::public.charge_waive_reason end
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

create function pg_temp.login_as(p_user uuid)
returns void
language plpgsql
as $fn$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
end;
$fn$;

-- Formato da chave (X01 a X10) ------------------------------------------------
-- "Recusado" é a violação de constraint (23514).

select lives_ok(
  $$ select pg_temp.set_pix('cpf', '52998224725') $$,
  'X01: CPF 52998224725 é aceito'
);
select throws_ok(
  $$ select pg_temp.set_pix('cpf', '52998224724') $$, '23514', null,
  'X02: CPF com o último dígito trocado é recusado'
);
select throws_ok(
  $$ select pg_temp.set_pix('cpf', '11111111111') $$, '23514', null,
  'X03: CPF de um dígito só é recusado, embora passe na conta'
);
select lives_ok(
  $$ select pg_temp.set_pix('cnpj', '11222333000181') $$,
  'X04: CNPJ 11222333000181 é aceito'
);
select throws_ok(
  $$ select pg_temp.set_pix('cnpj', '11222333000180') $$, '23514', null,
  'X05: CNPJ com o último dígito trocado é recusado'
);
select throws_ok(
  $$ select pg_temp.set_pix('cnpj', '00000000000000') $$, '23514', null,
  'X06: CNPJ de um dígito só é recusado'
);
select throws_ok(
  $$ select pg_temp.set_pix('email', 'Ana@Exemplo.com') $$, '23514', null,
  'X07a: e-mail com maiúsculas é recusado'
);
select lives_ok(
  $$ select pg_temp.set_pix('email', 'ana@exemplo.com') $$,
  'X07b: e-mail em minúsculas é aceito'
);
select lives_ok(
  $$ select pg_temp.set_pix('phone', '+5586999991234') $$,
  'X08a: telefone em E.164 é aceito'
);
select throws_ok(
  $$ select pg_temp.set_pix('phone', '86999991234') $$, '23514', null,
  'X08b: telefone sem o + e o país é recusado'
);
select lives_ok(
  $$ select pg_temp.set_pix('random', '123e4567-e89b-12d3-a456-426614174000') $$,
  'X09a: chave aleatória em minúsculas é aceita'
);
select throws_ok(
  $$ select pg_temp.set_pix('random', '123E4567-E89B-12D3-A456-426614174000') $$, '23514', null,
  'X09b: chave aleatória em maiúsculas é recusada'
);
select throws_ok(
  $$ select pg_temp.set_pix('cpf', null) $$, '23514', null,
  'X10: tipo sem chave é recusado (profile_private_pix_pair)'
);

-- Remoção da chave (N01 a N09, RN105) -----------------------------------------
-- "Remover" é o update de pix_key_type e pix_key para nulo.

-- N01. Recebedora de um jogo open.
select pg_temp.clean_receiver_state();
select pg_temp.mk_game('open');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N01a: recebedora de jogo open não remove a chave'
);
select is(
  (select pix_key from public.profile_private
   where user_id = '00000000-0000-0000-0000-00000000000a'),
  '52998224725',
  'N01b: a chave continua'
);

-- N07. Na mesma situação, a troca é livre.
select lives_ok(
  $$ update public.profile_private set pix_key_type = 'email', pix_key = 'ana@exemplo.com'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N07: recebedora de jogo open troca a chave por outra, de outro tipo'
);

-- N09. Trocar só o telefone não esbarra na trigger. A chave é CPF, então a
-- constraint dos dígitos roda com os privilégios da própria pessoa.
reset role;
select pg_temp.clean_receiver_state();
select pg_temp.mk_game('open');
set local role authenticated;

select lives_ok(
  $$ update public.profile_private set phone = '+5586999991234'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N09: recebedora de jogo open troca só o telefone'
);

-- N02. Recebedora de um jogo confirmed.
reset role;
select pg_temp.clean_receiver_state();
select pg_temp.mk_game('confirmed');
set local role authenticated;

select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N02: recebedora de jogo confirmed não remove a chave'
);

-- N04. Valor pending a receber.
reset role;
select pg_temp.clean_receiver_state();
select pg_temp.mk_charge('pending');
set local role authenticated;

select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N04: com valor pending a receber, não remove a chave'
);

-- N05. Valor under_review a receber.
reset role;
select pg_temp.clean_receiver_state();
select pg_temp.mk_charge('under_review');
set local role authenticated;

select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N05: com valor under_review a receber, não remove a chave'
);

-- N08. Bruno é participante, não recebedor, de um jogo open.
reset role;
select pg_temp.clean_receiver_state();
insert into public.game_participants (game_id, user_id)
values (pg_temp.mk_game('open'), '00000000-0000-0000-0000-00000000000b');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;

select lives_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000b' $$,
  'N08: participante que não é recebedor remove a própria chave'
);

-- N03. Só jogos cancelled e completed, sem valor a receber.
reset role;
select pg_temp.clean_receiver_state();
select pg_temp.mk_game('cancelled');
select pg_temp.mk_game('completed');
select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

select lives_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N03: com jogos só cancelled e completed, remove a chave'
);

-- N06. Só valores paid e waived a receber.
reset role;
select pg_temp.clean_receiver_state();
select pg_temp.mk_charge('paid');
select pg_temp.mk_charge('waived');
set local role authenticated;

select lives_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N06: com valores só paid e waived a receber, remove a chave'
);

reset role;

select * from finish();
rollback;
