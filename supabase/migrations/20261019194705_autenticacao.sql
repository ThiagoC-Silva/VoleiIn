-- Ligação entre auth.users e pessoa (RN21, RNF07). Detalhes em docs/stack.md, seção Autenticação.
-- São gatilhos, não RPC: ficam em privado e ninguém recebe execute.

-- Nome de exibição nos metadados do usuário: o do cadastro com senha (nome) ou o que o Google
-- informa (full_name, name), nessa ordem, sem espaços nas pontas. Vazio vira null.
create function privado.nome_dos_metadados(metadados jsonb) returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    nullif(btrim(metadados ->> 'nome'), ''),
    nullif(btrim(metadados ->> 'full_name'), ''),
    nullif(btrim(metadados ->> 'name'), '')
  );
$$;

-- Antes do cadastro: sem nome de exibição, o usuário não é criado e o pedido falha na hora,
-- não só na confirmação. Vale para a senha e para o Google: conta Google sem nome também é
-- recusada, em vez de nascer com um nome inventado.
create function privado.conferir_nome() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if privado.nome_dos_metadados(new.raw_user_meta_data) is null then
    raise exception 'cadastro sem nome de exibição'
      using errcode = 'not_null_violation', constraint = 'conferir_nome';
  end if;
  return new;
end;
$$;

create trigger conferir_nome before insert on auth.users
  for each row execute function privado.conferir_nome();

-- Perfil: nasce quando o e-mail fica confirmado, com o mesmo id do usuário e o nome dos
-- metadados. No cadastro com senha, é a confirmação do código, na mesma transação, e por isso
-- a sessão devolvida ao app já encontra o perfil; cadastro nunca confirmado não deixa perfil.
-- Quem já nasce confirmado, como no primeiro acesso pelo Google ou pelo Studio, ganha o perfil
-- no próprio insert. Na vinculação do Google a um cadastro pendente, o serviço troca os
-- metadados pelos do Google antes de confirmar, e o perfil nasce com o nome do Google.
create function privado.criar_pessoa() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pessoa (id, nome)
  values (new.id, privado.nome_dos_metadados(new.raw_user_meta_data));
  return new;
end;
$$;

create trigger criar_pessoa_no_cadastro after insert on auth.users
  for each row
  when (new.email_confirmed_at is not null)
  execute function privado.criar_pessoa();

create trigger criar_pessoa_na_confirmacao after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function privado.criar_pessoa();

-- Troca de e-mail ou de senha: apaga todos os aparelhos de push do titular, para os avisos
-- pararem em todo lugar (RNF07). O email só muda quando o código enviado ao endereço novo é
-- confirmado, e a senha, quando a redefinição por código se conclui. O aparelho que confirmou
-- a troca registra a si mesmo de novo. Também dispara quando o serviço apaga a senha de um
-- cadastro pendente na vinculação do Google, mas aí ainda não há perfil nem aparelho.
create function privado.apagar_dispositivos_na_troca() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.dispositivo_push where pessoa_id = new.id;
  return new;
end;
$$;

create trigger apagar_dispositivos_na_troca after update of email, encrypted_password on auth.users
  for each row
  when (old.email is distinct from new.email
        or old.encrypted_password is distinct from new.encrypted_password)
  execute function privado.apagar_dispositivos_na_troca();

revoke execute on function privado.nome_dos_metadados(jsonb) from public, anon, authenticated;
revoke execute on function privado.conferir_nome() from public, anon, authenticated;
revoke execute on function privado.criar_pessoa() from public, anon, authenticated;
revoke execute on function privado.apagar_dispositivos_na_troca() from public, anon, authenticated;
