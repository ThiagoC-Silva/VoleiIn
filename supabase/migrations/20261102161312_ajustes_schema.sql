-- Estrutura que as decisões de 2026-11-01 pedem antes das funções do passo 4.

-- Remarcação (RN20): grava o novo início, até o qual cancelar não gera multa.
-- O prazo sem multa é o mais tardio entre ele e inicio − prazo_cancelamento_horas (RN02).
alter table public.jogo add column cancelamento_livre_ate timestamptz;

comment on column public.jogo.cancelamento_livre_ate is
  'Novo início gravado na remarcação; até ele, cancelar não gera multa (RN02, RN20).';

-- O recebedor que joga ocupa vaga sem cobrança: não deve a si mesmo (RN07).
alter table public.cobranca
  add constraint cobranca_devedor_nao_e_credor check (devedor_id <> credor_id);
