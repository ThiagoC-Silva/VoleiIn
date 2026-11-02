-- Ajustes em duas funções existentes, sem mudar comportamento.

-- A soma de timestamptz com intervalo é stable no Postgres, não immutable: depende do fuso
-- da sessão quando o intervalo tem dias ou meses. Declarar immutable deixaria o planejador
-- guardar um resultado que não vale. Mesmo corpo e mesmo search_path.
create or replace function privado.encerramento_previsto(p_inicio timestamptz, p_duracao_minutos integer)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select p_inicio + make_interval(mins => p_duracao_minutos) + interval '1 hour';
$$;

-- search_path fixo, como o verificador de segurança do Supabase pede
-- (function_search_path_mutable). O corpo só usa now(), que mora em pg_catalog.
alter function public.tocar_atualizado_em() set search_path = '';
