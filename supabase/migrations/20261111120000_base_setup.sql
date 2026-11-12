-- Fatia 1 - Fundação. Base do banco: esquema `private` e privilégios padrão revogados.
-- Documentos: docs/adr/0015-esquema-private.md, docs/arquitetura-app.md (14.2), docs/rls-matriz.md (1 e 3).
--
-- Depois desta migração, toda tabela e toda função criada em `public` pelo papel `postgres`
-- nasce sem privilégio para `anon` e `authenticated` (cenário B05 de docs/testes-referencia.md).
-- Cada fatia concede explicitamente o que a sua tela precisa.

-- 1. Esquema das funções auxiliares e internas, que a API do Supabase não expõe.
create schema if not exists private;

revoke all on schema private from public;
revoke usage on schema private from anon, authenticated;

comment on schema private is
  'Funções auxiliares e internas (RLS, triggers, tarefas agendadas). Não exposta pela API (ADR 0015).';

-- 2. Privilégios padrão revogados em `public`.
-- O Supabase concede, por padrão, tudo a `anon` e `authenticated` no que `postgres` cria.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated;

-- O Postgres também dá `execute` ao papel `public` (todos os papéis) em toda
-- função nova. Os dois revokes abaixo declaram a intenção, mas NÃO bastam: o
-- Postgres soma o padrão embutido ao que ficou configurado aqui, então a
-- concessão a `public` volta em cada função nova (cenário B05b).
-- Por isso toda função de `public` leva o seu próprio
-- `revoke execute ... from public, anon` (docs/arquitetura-app.md, 14.3), e o
-- cenário B06 fica vermelho se alguma esquecer.
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema private revoke execute on functions from public;
alter default privileges for role postgres in schema private revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema private revoke all on functions from anon, authenticated;

-- 3. Nada que já exista em `public` fica aberto.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated;

-- 4. Trigger de `updated_at` (docs/modelo-dados.md, seção 1).
-- Instante do servidor, nunca do aparelho (RN02).
create or replace function private.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function private.set_updated_at() is
  'Mantém updated_at com o relógio do servidor (RN02).';
