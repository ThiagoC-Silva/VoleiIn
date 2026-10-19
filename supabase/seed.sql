-- Dados do piloto (RN18), mantidos pelo desenvolvedor e aplicados só no banco local pelo db reset.
-- PROVISÓRIO: conjunto mínimo plausível, a substituir pelos locais reais quando existirem.
-- UUIDs fixos para que cenários de teste possam referenciar as linhas.

-- Quem cadastra os locais; satisfaz local.criado_por.
-- Sem linha em auth.users: pessoa não tem chave estrangeira para lá (docs/stack.md, Autenticação).
insert into pessoa (id, nome) values
  ('00000000-0000-0000-0000-000000000001', 'Desenvolvedor');

-- Local que aluga por quadra: o jogo escolhe a quadra (RN15).
insert into local (id, nome, endereco, criado_por, modo_reserva, preco_hora) values
  ('10000000-0000-0000-0000-000000000001', 'Arena Beira-Mar', 'Endereço provisório',
   '00000000-0000-0000-0000-000000000001', 'por_quadra', 12000);

-- Quadra 1 usa o preço do local; quadra 2 tem o próprio (RN14).
insert into quadra (id, local_id, nome, tipo, preco_hora) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Quadra 1', 'areia', null),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Quadra 2', 'areia', 15000);

-- Segunda a sexta das 18h às 23h; sábado das 20h às 02h, atravessando a meia-noite (RN15).
insert into horario_funcionamento (local_id, dia_semana, abre, fecha)
select '10000000-0000-0000-0000-000000000001', d, '18:00', '23:00'
from generate_series(1, 5) d;

insert into horario_funcionamento (local_id, dia_semana, abre, fecha) values
  ('10000000-0000-0000-0000-000000000001', 6, '20:00', '02:00');

-- Local que aluga por horário: sem quadra, com até dois jogos simultâneos (RN15).
insert into local (id, nome, endereco, criado_por, modo_reserva, preco_hora, capacidade) values
  ('10000000-0000-0000-0000-000000000002', 'Ginásio Municipal', 'Endereço provisório',
   '00000000-0000-0000-0000-000000000001', 'por_horario', 9000, 2);

-- Todos os dias das 07h às 22h; sexta das 19h à meia-noite, com fecha igual a 00:00 (RN15).
insert into horario_funcionamento (local_id, dia_semana, abre, fecha)
select '10000000-0000-0000-0000-000000000002', d, '07:00', '22:00'
from generate_series(0, 6) d;

insert into horario_funcionamento (local_id, dia_semana, abre, fecha) values
  ('10000000-0000-0000-0000-000000000002', 5, '19:00', '00:00');
