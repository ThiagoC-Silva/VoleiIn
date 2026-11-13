-- Fatia 2 - Conta e perfil. Versão vigente dos Termos de Uso e da Política de
-- Privacidade.
-- Documentos: docs/contratos-api.md (seção 9), docs/modelo-dados.md (4.1),
-- docs/rls-matriz.md (fatia 2), cenários P10 e P14d de docs/testes-referencia.md.
--
-- As versões ficam escritas no corpo: a função não lê tabela nem depende de quem
-- chama. Para mudar uma versão, uma migração nova recria a função com o valor
-- novo, e o seed (docs/setup.md, seção 8) muda junto. O roteador do app compara
-- com o último aceite (RF105), e a política de inserção de terms_acceptances só
-- aceita estas versões (migração account_rls).

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

revoke execute on function public.current_terms_versions() from public, anon;
grant execute on function public.current_terms_versions() to authenticated;

comment on function public.current_terms_versions() is
  'Versão vigente de cada documento legal (RF105). Trocada por migração.';
