-- Limite de 60 caracteres do nome de exibição (RN21). Migração nova, e não edição da
-- `autenticacao`, porque aquela já foi ao remoto.

-- O nome dos metadados passa a sair cortado em 60 caracteres, sem espaço no fim. Vale para os
-- dois gatilhos de auth.users: o do cadastro com senha, que já vem limitado pela tela, e o do
-- Google, que a pessoa não escolhe e que não deve barrar o acesso por ser longo.
create or replace function privado.nome_dos_metadados(metadados jsonb) returns text
language sql
immutable
set search_path = ''
as $$
  select btrim(left(
    coalesce(
      nullif(btrim(metadados ->> 'nome'), ''),
      nullif(btrim(metadados ->> 'full_name'), ''),
      nullif(btrim(metadados ->> 'name'), '')
    ), 60));
$$;

-- No banco, para valer em qualquer caminho de escrita, inclusive o update direto do perfil.
alter table pessoa
  add constraint pessoa_nome_tamanho_valido check (char_length(nome) between 1 and 60);
