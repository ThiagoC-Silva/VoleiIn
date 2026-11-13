-- Fatia 2 - Conta e perfil. CNPJ alfanumérico na chave Pix.
-- Documentos: docs/modelo-dados.md (4.1, decisão de 13/11/2026), cenários X04 a
-- X06 e X11 a X14 de docs/testes-referencia.md.
--
-- Formato da Receita Federal: 14 caracteres, os 12 primeiros letras maiúsculas
-- (A a Z) ou números e os 2 últimos dígitos verificadores numéricos. Na conta,
-- cada caractere vale o código ASCII menos 48: os números valem eles mesmos, A
-- vale 17 e Z vale 42. Os pesos e o módulo 11 são os do CNPJ numérico, que é o
-- caso particular da mesma conta e continua válido.
--
-- O `create or replace` mantém o OID da função, e a constraint
-- profile_private_pix_format, que a guarda pelo OID, passa a usar a regra nova.
-- A regra só amplia o que é aceito: nenhuma chave gravada fica inválida.
-- O parâmetro mantém o nome p_digits, porque o replace não permite renomeá-lo.

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
  if p_digits is null
     or p_digits !~ '^[0-9A-Z]{12}[0-9]{2}$'
     or p_digits ~ '^(.)\1*$' then
    return false;
  end if;

  -- v_len: 12 para o primeiro verificador, 13 para o segundo. O peso do
  -- caractere i vai de 9 a 2 e recomeça, da direita para a esquerda:
  -- (v_len - i) % 8 + 2. O valor do caractere é ascii - 48.
  for v_len in 12..13 loop
    v_sum := 0;
    for i in 1..v_len loop
      v_sum := v_sum + (ascii(substr(p_digits, i, 1)) - 48) * ((v_len - i) % 8 + 2);
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

comment on function private.is_valid_cnpj(text) is
  'CNPJ no formato alfanumérico da Receita (12 caracteres A-Z ou 0-9 e 2 '
  'verificadores numéricos), sem sequência de um caractere só.';
