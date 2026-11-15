-- Fatia 3 - Grupos. Funções auxiliares do RLS e o gerador do código de convite.
-- Documentos: docs/rls-matriz.md (fatia 3), docs/modelo-dados.md (seção 5 e
-- seção 9, item 3), research R1 de specs/002-grupos.
--
-- As quatro funções de papel são `security definer`: consultam group_members,
-- group_join_requests, game_participants e game_waitlist sem passar pelo RLS
-- dessas tabelas, o que evita a recursão de uma política de group_members que
-- consulta group_members. A política roda com os privilégios de quem consulta e
-- guarda a função pelo OID: o authenticated precisa de `execute`, mas continua
-- sem `usage` no esquema private (B07), e a API não alcança as funções.

-- Membro do grupo. Grupo arquivado não tem membros (RN17), então nunca dá verdadeiro.
create or replace function private.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = p_user_id
  );
$$;

-- Admin do grupo.
create or replace function private.is_group_admin(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = p_user_id and m.role = 'admin'
  );
$$;

-- Compartilhar contexto (RN107, docs/modelo-dados.md, seção 5): um grupo atual em
-- comum, ou o mesmo jogo, atual ou passado, na lista ou na espera, em qualquer status.
create or replace function private.shares_context(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
      select 1
      from public.group_members ma
      join public.group_members mb on mb.group_id = ma.group_id
      where ma.user_id = p_a and mb.user_id = p_b
    )
    or exists (
      select 1
      from (select game_id from public.game_participants where user_id = p_a
            union
            select game_id from public.game_waitlist where user_id = p_a) ga
      join (select game_id from public.game_participants where user_id = p_b
            union
            select game_id from public.game_waitlist where user_id = p_b) gb
        on gb.game_id = ga.game_id
    );
$$;

-- RN107, exceção 2: p_requester tem solicitação pendente num grupo em que p_admin é admin.
create or replace function private.has_pending_join_request(p_requester uuid, p_admin uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.group_join_requests r
    join public.group_members m
      on m.group_id = r.group_id and m.user_id = p_admin and m.role = 'admin'
    where r.user_id = p_requester and r.status = 'pending'
  );
$$;

revoke execute on function private.is_group_member(uuid, uuid) from public, anon;
revoke execute on function private.is_group_admin(uuid, uuid) from public, anon;
revoke execute on function private.shares_context(uuid, uuid) from public, anon;
revoke execute on function private.has_pending_join_request(uuid, uuid) from public, anon;
grant execute on function private.is_group_member(uuid, uuid) to authenticated;
grant execute on function private.is_group_admin(uuid, uuid) to authenticated;
grant execute on function private.shares_context(uuid, uuid) to authenticated;
grant execute on function private.has_pending_join_request(uuid, uuid) to authenticated;

-- Código de convite: 12 caracteres base62 sorteados com gen_random_bytes (RN11,
-- cerca de 71 bits). Os bytes de 248 a 255 são descartados para que os 62
-- caracteres tenham a mesma chance (248 = 4 × 62). Quem grava o código trata a
-- colisão, rara, com nova tentativa (research R1).
create or replace function private.generate_invite_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  v_code text := '';
  v_bytes bytea;
  v_byte integer;
begin
  while char_length(v_code) < 12 loop
    v_bytes := extensions.gen_random_bytes(16);
    for i in 0 .. 15 loop
      v_byte := get_byte(v_bytes, i);
      if v_byte < 248 and char_length(v_code) < 12 then
        v_code := v_code || substr(v_alphabet, (v_byte % 62) + 1, 1);
      end if;
    end loop;
  end loop;

  return v_code;
end;
$$;

comment on function private.generate_invite_code() is
  'Código de convite de 12 caracteres base62, sem viés (RN11). Nunca exposta ao app.';

revoke all on function private.generate_invite_code() from public, anon, authenticated;
