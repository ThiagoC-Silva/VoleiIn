-- Os dez tipos do catálogo de enums (docs/modelo-de-dados.md).
-- Vem antes das tabelas porque a coluna declara o tipo, e o tipo precisa existir primeiro.

create type membro_grupo_papel as enum ('admin', 'membro');

create type convite_tipo as enum ('grupo', 'jogo');

create type local_modo_reserva as enum ('por_quadra', 'por_horario');

create type quadra_tipo as enum ('areia', 'ginasio', 'outro');

create type jogo_status as enum ('aberto', 'cancelado', 'encerrado');

create type participacao_status as enum (
  'confirmado',
  'lista_espera',
  'cancelou_no_prazo',
  'cancelou_fora_do_prazo',
  'faltou'
);

create type cobranca_origem as enum ('parte', 'cancelamento_tardio', 'falta');

create type cobranca_status as enum (
  'pendente',
  'comprovante_enviado',
  'confirmado',
  'isenta',
  'cancelada'
);

create type comprovante_resultado as enum ('consistente', 'divergente', 'ilegivel');

create type notificacao_tipo as enum (
  'vaga_liberada',
  'jogo_editado',
  'jogo_cancelado',
  'regra_grupo_alterada',
  'valor_recalculado',
  'pagamento_liberado',
  'cobranca_vencida',
  'comprovante_recebido',
  'comprovante_recusado',
  'cobranca_confirmada',
  'cobranca_isenta',
  'falta_marcada',
  'removido_do_grupo',
  'promovido_a_admin'
);
