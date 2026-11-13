-- Fatia 2 - Conta e perfil. Versão vigente dos Termos de Uso e da Política de Privacidade.
-- Documentos: docs/contratos-api.md (seção 9), docs/modelo-dados.md (4.1), RF105.
--
-- Não lê tabela nem depende de quem chama: as versões ficam no corpo. Para mudar
-- uma versão, uma migração nova recria a função com o valor novo, e todo mundo
-- que aceitou a anterior vê o aceite de novo na próxima abertura. Quando a versão
-- mudar, o seed (docs/setup.md, seção 8) muda junto.
-- A política de inserção de terms_acceptances usa esta mesma função (account_rls).

create or replace function public.current_terms_versions()
returns table (document public.legal_document, version text)
language sql
immutable
security invoker
set search_path = ''
as $$
  values
    ('terms_of_use'::public.legal_document, '1.0'::text),
    ('privacy_policy'::public.legal_document, '1.0'::text);
$$;

comment on function public.current_terms_versions() is
  'Versão vigente de cada documento legal (RF105). Trocada só por migração.';

-- Toda função de public nasce com execute para public (docs/rls-matriz.md, 1).
revoke execute on function public.current_terms_versions() from public, anon;
grant execute on function public.current_terms_versions() to authenticated;
