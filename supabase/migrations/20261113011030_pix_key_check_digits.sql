-- Fatia 2 - Conta e perfil. Dígitos verificadores de CPF e CNPJ na chave Pix.
-- Documentos: docs/modelo-dados.md (4.1, decisão de 12/11/2026), cenários X01 a X10.
--
-- As funções ficam em private (ADR 0015) e são immutable, como exige uma
-- constraint de check. A mesma regra está no app, só para o aviso no campo
-- (app/lib/core/format/br_documents.dart); quem decide é o banco.
-- Sequências de um dígito só (00000000000, 11111111111...) passam na conta e são
-- recusadas aqui.

create or replace function private.is_valid_cpf(p_value text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_sum integer;
  v_digit integer;
begin
  if p_value is null or p_value !~ '^[0-9]{11}$' then
    return false;
  end if;
  if p_value ~ '^(.)\1{10}$' then
    return false;
  end if;

  -- Primeiro dígito: pesos 10 a 2 sobre os 9 primeiros.
  v_sum := 0;
  for i in 1..9 loop
    v_sum := v_sum + substr(p_value, i, 1)::integer * (11 - i);
  end loop;
  v_digit := (v_sum * 10) % 11 % 10;
  if v_digit <> substr(p_value, 10, 1)::integer then
    return false;
  end if;

  -- Segundo dígito: pesos 11 a 2 sobre os 10 primeiros.
  v_sum := 0;
  for i in 1..10 loop
    v_sum := v_sum + substr(p_value, i, 1)::integer * (12 - i);
  end loop;
  v_digit := (v_sum * 10) % 11 % 10;
  return v_digit = substr(p_value, 11, 1)::integer;
end;
$$;

comment on function private.is_valid_cpf(text) is
  'CPF de 11 dígitos com os verificadores corretos e sem dígito repetido (modelo-dados.md, 4.1).';

create or replace function private.is_valid_cnpj(p_value text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_weights1 constant integer[] := array[5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  v_weights2 constant integer[] := array[6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  v_sum integer;
  v_digit integer;
begin
  if p_value is null or p_value !~ '^[0-9]{14}$' then
    return false;
  end if;
  if p_value ~ '^(.)\1{13}$' then
    return false;
  end if;

  v_sum := 0;
  for i in 1..12 loop
    v_sum := v_sum + substr(p_value, i, 1)::integer * v_weights1[i];
  end loop;
  v_digit := case when v_sum % 11 < 2 then 0 else 11 - v_sum % 11 end;
  if v_digit <> substr(p_value, 13, 1)::integer then
    return false;
  end if;

  v_sum := 0;
  for i in 1..13 loop
    v_sum := v_sum + substr(p_value, i, 1)::integer * v_weights2[i];
  end loop;
  v_digit := case when v_sum % 11 < 2 then 0 else 11 - v_sum % 11 end;
  return v_digit = substr(p_value, 14, 1)::integer;
end;
$$;

comment on function private.is_valid_cnpj(text) is
  'CNPJ de 14 dígitos com os verificadores corretos e sem dígito repetido (modelo-dados.md, 4.1).';

-- A constraint de check roda com o privilégio de quem grava. Por isso
-- authenticated precisa de execute nas duas funções, que são puras e não leem
-- nada. O esquema private continua sem usage para o app (B07): ele não consegue
-- chamá-las pela API (docs/rls-matriz.md, Fatia 2).
revoke execute on function private.is_valid_cpf(text) from public, anon;
revoke execute on function private.is_valid_cnpj(text) from public, anon;
grant execute on function private.is_valid_cpf(text) to authenticated;
grant execute on function private.is_valid_cnpj(text) to authenticated;

-- Recria a constraint de formato com os verificadores. A recriação valida as
-- linhas existentes: uma chave inválida faz a migração falhar, de propósito.
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
