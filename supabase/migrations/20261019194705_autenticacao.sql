-- Ligação entre auth.users e pessoa (RN21, RNF07). Detalhes em docs/stack.md, seção Autenticação.
-- São gatilhos, não RPC: ficam em privado e ninguém recebe execute.

-- Primeiro acesso: cria o perfil com o mesmo id do usuário e o nome enviado nos metadados
-- do cadastro. Nome ausente ou só com espaços vira null e cai no not null de pessoa.nome,
-- desfazendo o cadastro inteiro: não existe usuário sem perfil nem perfil sem nome.
create function privado.criar_pessoa() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pessoa (id, nome)
  values (new.id, nullif(btrim(new.raw_user_meta_data ->> 'nome'), ''));
  return new;
end;
$$;

create trigger criar_pessoa after insert on auth.users
  for each row execute function privado.criar_pessoa();

-- Troca de e-mail: apaga todos os aparelhos de push do titular, para os avisos pararem em
-- todo lugar (RNF07). Com double_confirm_changes, o email só muda depois das duas confirmações.
-- O aparelho que confirmou a troca registra a si mesmo de novo.
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

create trigger apagar_dispositivos_na_troca after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function privado.apagar_dispositivos_na_troca();

revoke execute on function privado.criar_pessoa() from public, anon, authenticated;
revoke execute on function privado.apagar_dispositivos_na_troca() from public, anon, authenticated;
