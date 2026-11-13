-- Chave Pix: formato e RN105 (fatia 2).
-- Cenários X01 a X10 e N01 a N09 de docs/testes-referencia.md, seção 10.2.
--
-- Os formatos rodam como postgres, direto em profile_private ("recusado" é a
-- violação de constraint, 23514). A RN105 roda como Ana logada, para provar que
-- a trigger vale também para a escrita do app.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

-- Ajudantes ------------------------------------------------------------------

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
    ('00000000-0000-0000-0000-00000000000b'::uuid, 'bruno@voleiin.test', 'Bruno'),
    ('00000000-0000-0000-0000-00000000000d'::uuid, 'diego@voleiin.test', 'Diego')
) as u (id, email, name)
on conflict do nothing;

-- Jogo com Ana como recebedora e admin, no status pedido.
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
    share_cents, completed_at, completion_mode, cancelled_at
  )
  values (
    '00000000-0000-0000-0000-00000000000a', 'Quadra do teste',
    now() + interval '1 day', now() + interval '2 days', now() + interval '2 days 2 hours',
    20000, 10, '00000000-0000-0000-0000-00000000000a',
    substr(replace(gen_random_uuid()::text, '-', ''), 1, 12), p_status,
    case when p_status = 'completed' then 2000 end,
    case when p_status = 'completed' then now() end,
    case when p_status = 'completed' then 'manual'::public.game_completion_mode end,
    case when p_status = 'cancelled' then now() end
  )
  returning id into v_id;

  insert into public.game_admins (game_id, user_id)
  values (v_id, '00000000-0000-0000-0000-00000000000a');

  return v_id;
end;
$fn$;

create function pg_temp.login_as(p_user uuid)
returns void
language sql
as $fn$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
$fn$;

-- Ana e Bruno com chave; Diego sem chave, para os formatos.
update public.profile_private set pix_key_type = 'cpf', pix_key = '52998224725'
where user_id = '00000000-0000-0000-0000-00000000000a';
update public.profile_private set pix_key_type = 'email', pix_key = 'bruno@exemplo.com'
where user_id = '00000000-0000-0000-0000-00000000000b';

-- Formato (X01 a X10) --------------------------------------------------------

select lives_ok(
  $$ update public.profile_private set pix_key_type = 'cpf', pix_key = '52998224725'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  'X01: CPF válido é aceito'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'cpf', pix_key = '52998224724'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X02: CPF com dígito verificador errado é recusado'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'cpf', pix_key = '11111111111'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X03: CPF de um dígito só é recusado'
);
select lives_ok(
  $$ update public.profile_private set pix_key_type = 'cnpj', pix_key = '11222333000181'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  'X04: CNPJ válido é aceito'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'cnpj', pix_key = '11222333000180'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X05: CNPJ com dígito verificador errado é recusado'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'cnpj', pix_key = '00000000000000'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X06: CNPJ de um dígito só é recusado'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'email', pix_key = 'Ana@Exemplo.com'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X07a: e-mail com maiúsculas é recusado'
);
select lives_ok(
  $$ update public.profile_private set pix_key_type = 'email', pix_key = 'ana@exemplo.com'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  'X07b: e-mail em minúsculas é aceito'
);
select lives_ok(
  $$ update public.profile_private set pix_key_type = 'phone', pix_key = '+5586999991234'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  'X08a: telefone em E.164 é aceito'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'phone', pix_key = '86999991234'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X08b: telefone sem +55 é recusado'
);
select lives_ok(
  $$ update public.profile_private set pix_key_type = 'random', pix_key = '123e4567-e89b-12d3-a456-426614174000'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  'X09a: chave aleatória em minúsculas é aceita'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'random', pix_key = '123E4567-E89B-12D3-A456-426614174000'
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X09b: chave aleatória em maiúsculas é recusada'
);
select throws_ok(
  $$ update public.profile_private set pix_key_type = 'cpf', pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000d' $$,
  '23514', null,
  'X10: tipo sem chave é recusado (profile_private_pix_pair)'
);

-- Remoção da chave (RN105) ---------------------------------------------------

create temporary table t_game (label text primary key, id uuid) on commit drop;
grant select on t_game to authenticated;
insert into t_game values ('g1', pg_temp.mk_game('open'));

select pg_temp.login_as('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

-- N01
select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N01: recebedora de jogo open não remove a chave'
);
select is(
  (select pix_key from public.profile_private where user_id = '00000000-0000-0000-0000-00000000000a'),
  '52998224725',
  'N01b: a chave continua'
);

-- N02
reset role;
update public.games set status = 'confirmed' where id = (select id from t_game where label = 'g1');
set local role authenticated;
select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N02: recebedora de jogo confirmed não remove a chave'
);

-- N07 (como N01: ainda recebedora de jogo em aberto)
select lives_ok(
  $$ update public.profile_private set pix_key_type = 'email', pix_key = 'ana@exemplo.com'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N07: a troca da chave por outra válida, de outro tipo, é livre'
);

-- N09
select lives_ok(
  $$ update public.profile_private set phone = '+5586999991234'
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N09: trocar só o telefone não é barrado pela trigger'
);

-- N03: só jogos cancelled e completed, sem valor a receber.
reset role;
update public.games
set status = 'completed', share_cents = 2000, completed_at = now(), completion_mode = 'manual'
where id = (select id from t_game where label = 'g1');
insert into t_game values ('g2', pg_temp.mk_game('cancelled'));
set local role authenticated;
select lives_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N03: recebedora só de jogos cancelled e completed remove a chave'
);

-- N04: valor pending devido à Ana.
reset role;
update public.profile_private set pix_key_type = 'cpf', pix_key = '52998224725'
where user_id = '00000000-0000-0000-0000-00000000000a';
insert into public.game_participants (id, game_id, user_id)
select gen_random_uuid(), id, '00000000-0000-0000-0000-00000000000b' from t_game where label = 'g1';
insert into public.charges (game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
select g.id, p.id, p.user_id, '00000000-0000-0000-0000-00000000000a', 'share', 2000
from t_game g
join public.game_participants p on p.game_id = g.id
where g.label = 'g1';
set local role authenticated;
select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N04: com valor a receber pending, a chave não é removida'
);

-- N05: valor under_review.
reset role;
update public.charges set status = 'under_review'
where receiver_id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select throws_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'P0001', 'PIX_KEY_IN_USE',
  'N05: com valor a receber under_review, a chave não é removida'
);

-- N06: só valores paid e waived.
reset role;
update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
where receiver_id = '00000000-0000-0000-0000-00000000000a';
insert into public.charges (
  game_id, participant_id, payer_id, receiver_id, kind, amount_cents, status, waived_at, waive_reason
)
select g.id, p.id, p.user_id, '00000000-0000-0000-0000-00000000000a',
       'absence_penalty', 1000, 'waived', now(), 'manual_waiver'
from t_game g
join public.game_participants p on p.game_id = g.id
where g.label = 'g1';
set local role authenticated;
select lives_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000a' $$,
  'N06: com valores só paid e waived, a chave é removida'
);

-- N08: Bruno é participante, não recebedor, de um jogo open.
reset role;
insert into t_game values ('g3', pg_temp.mk_game('open'));
insert into public.game_participants (game_id, user_id)
select id, '00000000-0000-0000-0000-00000000000b' from t_game where label = 'g3';
select pg_temp.login_as('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select lives_ok(
  $$ update public.profile_private set pix_key_type = null, pix_key = null
     where user_id = '00000000-0000-0000-0000-00000000000b' $$,
  'N08: participante que não é recebedor remove a própria chave'
);
reset role;
select is(
  (select pix_key from public.profile_private where user_id = '00000000-0000-0000-0000-00000000000b'),
  null,
  'N08b: a chave do Bruno foi removida'
);

select * from finish();
rollback;
