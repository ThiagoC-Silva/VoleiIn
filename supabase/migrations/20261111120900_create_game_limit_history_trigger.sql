-- Fatia 1 - Fundação. Histórico do limite de vagas.
-- Documentos: docs/modelo-dados.md (4.3), docs/testes-referencia.md (B26 a B28).
-- Serve para calcular o L da RN62 (menor limite vigente entre o prazo e o início).

create or replace function private.track_slot_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Só grava quando o limite realmente muda (B28).
  if tg_op = 'INSERT' or new.slot_limit is distinct from old.slot_limit then
    insert into public.game_limit_history (game_id, slot_limit)
    values (new.id, new.slot_limit);
  end if;
  return null;
end;
$$;

comment on function private.track_slot_limit() is
  'Registra cada valor de slot_limit em game_limit_history, com effective_from = now() (RN62).';

create trigger games_track_slot_limit
after insert or update of slot_limit on public.games
for each row execute function private.track_slot_limit();
