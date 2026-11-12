-- Fatia 1 - Fundação. Perfil criado quando o e-mail fica confirmado.
-- Documentos: docs/modelo-dados.md (4.1), docs/testes-referencia.md (cenários B15 a B23).
--
-- O perfil e a linha de profile_private nascem juntos: na confirmação do link
-- (cadastro por e-mail) ou no próprio cadastro (Google, que já chega confirmado).
-- Um cadastro nunca confirmado não deixa perfil. Assim, quando o Supabase vincula
-- o Google a um cadastro pendente com o mesmo e-mail (RF108), o perfil nasce com
-- os dados do Google (B23).

create or replace function private.create_profile_for_confirmed_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  -- Só a confirmação cria o perfil.
  if new.email_confirmed_at is null then
    return new;
  end if;

  -- Já estava confirmado: nada muda e não há erro (B22).
  if tg_op = 'UPDATE' and old.email_confirmed_at is not null then
    return new;
  end if;

  -- name, depois full_name, depois o início do e-mail (B17, B18, B21).
  v_name := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'name', '')), '');
  if v_name is null then
    v_name := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), '');
  end if;
  if v_name is null then
    v_name := nullif(btrim(split_part(coalesce(new.email, ''), '@', 1)), '');
  end if;
  -- Sem espaço nas pontas e cortado em 80 caracteres (B19, B20).
  v_name := btrim(left(v_name, 80));

  insert into public.profiles (id, name)
  values (new.id, v_name)
  on conflict (id) do nothing;

  insert into public.profile_private (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

comment on function private.create_profile_for_confirmed_user() is
  'Cria profiles e profile_private quando o e-mail do usuário fica confirmado (RF108, B15 a B23).';

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.create_profile_for_confirmed_user();

create trigger on_auth_user_confirmed
after update of email_confirmed_at on auth.users
for each row execute function private.create_profile_for_confirmed_user();
