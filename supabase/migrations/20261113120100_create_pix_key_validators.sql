-- Fatia 2 - Conta e perfil. Dígitos verificadores de CPF e CNPJ na chave Pix.
-- Documentos: docs/modelo-dados.md (4.1), research R6 de
-- specs/001-conta-e-perfil, cenários X01 a X10 de docs/testes-referencia.md.
--
-- A constraint roda com os privilégios de quem faz o update, inclusive o app
-- (authenticated). Por isso as duas funções recebem execute para authenticated.
-- Sem usage no esquema private, elas continuam inalcançáveis pela API (ADR 0015):
-- a constraint guarda a função pelo OID e não precisa achar o nome.

-- CPF: 11 dígitos, os dois últimos conferidos com pesos 10..2 e 11..2.
-- Sequências de um dígito só passam na conta, mas são recusadas.
create or replace function private.is_valid_cpf(p_digits text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_sum integer;
  v_check integer;
begin
  if p_digits is null or p_digits !~ '^[0-9]{11}$' or p_digits ~ '^(.)\1*$' then
    return false;
  end if;

  -- v_len: quantos dígitos entram na conta (9 para o primeiro verificador,
  -- 10 para o segundo). O peso do dígito i é v_len + 2 - i.
  for v_len in 9..10 loop
    v_sum := 0;
    for i in 1..v_len loop
      v_sum := v_sum + substr(p_digits, i, 1)::integer * (v_len + 2 - i);
    end loop;
    v_check := (v_sum * 10) % 11 % 10;
    if v_check <> substr(p_digits, v_len + 1, 1)::integer then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

-- CNPJ: 14 dígitos, os dois últimos conferidos com pesos 5..2,9..2 e 6..2,9..2.
create or replace function private.is_valid_cnpj(p_digits text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_sum integer;
  v_rest integer;
  v_check integer;
begin
  if p_digits is null or p_digits !~ '^[0-9]{14}$' or p_digits ~ '^(.)\1*$' then
    return false;
  end if;

  -- v_len: 12 para o primeiro verificador, 13 para o segundo. O peso do dígito
  -- i vai de 9 a 2 e recomeça, da direita para a esquerda: (v_len - i) % 8 + 2.
  for v_len in 12..13 loop
    v_sum := 0;
    for i in 1..v_len loop
      v_sum := v_sum + substr(p_digits, i, 1)::integer * ((v_len - i) % 8 + 2);
    end loop;
    v_rest := v_sum % 11;
    v_check := case when v_rest < 2 then 0 else 11 - v_rest end;
    if v_check <> substr(p_digits, v_len + 1, 1)::integer then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

revoke execute on function private.is_valid_cpf(text) from public, anon;
revoke execute on function private.is_valid_cnpj(text) from public, anon;
grant execute on function private.is_valid_cpf(text) to authenticated;
grant execute on function private.is_valid_cnpj(text) to authenticated;

comment on function private.is_valid_cpf(text) is
  'CPF com 11 dígitos e verificadores corretos, sem sequência de um dígito só.';
comment on function private.is_valid_cnpj(text) is
  'CNPJ com 14 dígitos e verificadores corretos, sem sequência de um dígito só.';

-- A constraint da fatia 1 conferia só o formato. Agora CPF e CNPJ conferem
-- também os dígitos (decisão de 12/11/2026).
alter table public.profile_private drop constraint profile_private_pix_format;

alter table public.profile_private add constraint profile_private_pix_format check (
  pix_key is null or case pix_key_type
    when 'cpf' then private.is_valid_cpf(pix_key)
    when 'cnpj' then private.is_valid_cnpj(pix_key)
    when 'email' then pix_key = lower(pix_key) and pix_key ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
    when 'phone' then pix_key ~ '^\+[1-9][0-9]{7,14}$'
    when 'random' then pix_key ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  end
);
