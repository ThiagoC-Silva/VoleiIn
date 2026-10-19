-- Unicidades de docs/modelo-de-dados.md e índices de leitura.

-- Ninguém entra duas vezes no mesmo grupo.
create unique index membro_grupo_grupo_pessoa_unico on membro_grupo (grupo_id, pessoa_id);

-- Ninguém ocupa duas vagas no mesmo jogo.
create unique index participacao_jogo_pessoa_unico on participacao (jogo_id, pessoa_id);

-- Uma vaga gera no máximo um débito (RN01, RN25).
create unique index cobranca_participacao_unico on cobranca (participacao_id);

create unique index convite_token_unico on convite (token);

create unique index dispositivo_push_token_fcm_unico on dispositivo_push (token_fcm);

-- Parcial: comprovante ilegível entra sem identificador e não disputa com os outros (RN10).
create unique index comprovante_id_transacao_unico on comprovante (id_transacao)
  where id_transacao is not null;

-- Feed de jogos do grupo, por data.
create index jogo_grupo_inicio on jogo (grupo_id, inicio);

-- Checagens da RN15: sobreposição na quadra e simultaneidade no local.
create index jogo_quadra_inicio on jogo (quadra_id, inicio);
create index jogo_local_inicio on jogo (local_id, inicio);

-- Painéis de débitos e de recebimentos.
create index cobranca_devedor_status on cobranca (devedor_id, status);
create index cobranca_credor_status on cobranca (credor_id, status);

-- Confirmados e fila de espera de um jogo.
create index participacao_jogo_status on participacao (jogo_id, status);

-- Sino: avisos da pessoa, não lidos primeiro.
create index notificacao_pessoa_lida_em on notificacao (pessoa_id, lida_em);

create index quadra_local on quadra (local_id);
create index horario_funcionamento_local on horario_funcionamento (local_id);
