-- As treze entidades de docs/modelo-de-dados.md, em ordem de dependência.
-- Aqui ficam só as restrições de linha única; o que cruza tabelas vive nas funções do passo 4.
-- Unicidades e índices vêm na migração seguinte (indices).

-- Mantém atualizado_em com a hora do servidor em todo update.
create function tocar_atualizado_em() returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- Sem default no id: ele espelha auth.users e é fornecido pelo gatilho do passo 3.
-- A ausência de chave estrangeira para auth.users é deliberada (docs/stack.md, Autenticação).
create table pessoa (
  id uuid primary key,
  nome text not null,
  avatar_url text,
  telefone text,
  chave_pix text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table local (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  endereco text,
  latitude numeric,
  longitude numeric,
  telefone text,
  criado_por uuid not null references pessoa (id),
  dono_id uuid references pessoa (id),
  verificado boolean not null default false,
  modo_reserva local_modo_reserva not null,
  preco_hora integer,
  capacidade integer,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- RN14, RN15
  constraint local_preco_hora_nao_negativo check (preco_hora >= 0),
  constraint local_capacidade_positiva check (capacidade > 0)
);

create table horario_funcionamento (
  id uuid primary key default gen_random_uuid(),
  local_id uuid not null references local (id),
  dia_semana integer not null,
  abre time not null,
  -- Menor ou igual a abre significa que a faixa termina no dia seguinte (RN15).
  fecha time not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- 0 é domingo, 6 é sábado
  constraint horario_funcionamento_dia_semana_valido check (dia_semana between 0 and 6)
);

create table quadra (
  id uuid primary key default gen_random_uuid(),
  local_id uuid not null references local (id),
  nome text not null,
  tipo quadra_tipo not null,
  -- Vazio usa o preço do local (RN14).
  preco_hora integer,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  constraint quadra_preco_hora_nao_negativo check (preco_hora >= 0)
);

create table grupo (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  cor text not null,
  criado_por uuid not null references pessoa (id),
  local_padrao_id uuid references local (id),
  vagas_padrao integer,
  custo_total_padrao integer,
  prazo_cancelamento_horas integer not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- RN12
  constraint grupo_vagas_padrao_positivo check (vagas_padrao > 0),
  constraint grupo_custo_total_padrao_nao_negativo check (custo_total_padrao >= 0)
);

create table membro_grupo (
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null references grupo (id),
  pessoa_id uuid not null references pessoa (id),
  papel membro_grupo_papel not null,
  entrou_em timestamptz not null default now(),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table jogo (
  id uuid primary key default gen_random_uuid(),
  -- Vazio indica jogo avulso.
  grupo_id uuid references grupo (id),
  criador_id uuid not null references pessoa (id),
  recebedor_id uuid not null references pessoa (id),
  -- Snapshot da chave do recebedor (RN24); só esvazia na anonimização (RN27).
  chave_pix_recebedor text,
  local_id uuid not null references local (id),
  -- Obrigatória no modo por_quadra; checada em criar_jogo (RN15).
  quadra_id uuid references quadra (id),
  inicio timestamptz not null,
  duracao_minutos integer not null,
  vagas_total integer not null,
  custo_total integer not null,
  preco_por_vaga integer not null,
  -- Vazio herda do grupo (RN12).
  prazo_cancelamento_horas integer,
  status jogo_status not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  constraint jogo_vagas_total_positivo check (vagas_total > 0),
  constraint jogo_duracao_minutos_positiva check (duracao_minutos > 0),
  constraint jogo_custo_total_nao_negativo check (custo_total >= 0),
  -- RN01, RN16: teto da divisão em aritmética inteira, arredondado no centavo.
  -- O case evita divisão por zero; vagas_total <= 0 já é recusado acima.
  constraint jogo_preco_por_vaga_arredondado check (
    case
      when vagas_total > 0
        then preco_por_vaga = (custo_total + vagas_total - 1) / vagas_total
    end
  ),
  -- RN12: jogo avulso informa o próprio prazo.
  constraint jogo_avulso_tem_prazo check (
    grupo_id is not null or prazo_cancelamento_horas is not null
  ),
  -- RN24, RN27
  constraint jogo_chave_pix_recebedor_nao_vazia check (chave_pix_recebedor <> '')
);

create table convite (
  id uuid primary key default gen_random_uuid(),
  token text not null,
  tipo convite_tipo not null,
  grupo_id uuid references grupo (id),
  jogo_id uuid references jogo (id),
  criado_por uuid not null references pessoa (id),
  -- Vazio significa sem prazo (RN22).
  expira_em timestamptz,
  -- Vazio significa convite ativo (RF32).
  revogado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- RN22: exatamente um alvo, conforme o tipo.
  constraint convite_alvo_conforme_tipo check (
    (tipo = 'grupo' and grupo_id is not null and jogo_id is null)
    or (tipo = 'jogo' and jogo_id is not null and grupo_id is null)
  )
);

create table participacao (
  id uuid primary key default gen_random_uuid(),
  jogo_id uuid not null references jogo (id),
  pessoa_id uuid not null references pessoa (id),
  status participacao_status not null,
  confirmado_em timestamptz,
  cancelado_em timestamptz,
  posicao_espera integer,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- RN08: posição só existe na lista de espera, e começa em 1.
  constraint participacao_posicao_so_na_espera check (
    (status = 'lista_espera') = (posicao_espera is not null)
  ),
  constraint participacao_posicao_espera_positiva check (posicao_espera > 0)
);

create table cobranca (
  id uuid primary key default gen_random_uuid(),
  participacao_id uuid not null references participacao (id),
  -- Igual ao pessoa_id da participação; checado nas funções do passo 4.
  devedor_id uuid not null references pessoa (id),
  -- Igual ao recebedor_id do jogo e migra com ele (RN20); checado nas funções.
  credor_id uuid not null references pessoa (id),
  valor integer not null,
  origem cobranca_origem not null,
  status cobranca_status not null,
  -- Quem resolveu a cobrança, por baixa ou isenção manual; vazio nas transições automáticas (RN07).
  confirmado_por uuid references pessoa (id),
  confirmado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  constraint cobranca_valor_nao_negativo check (valor >= 0),
  -- RN07: o par anda junto.
  constraint cobranca_confirmacao_em_par check (
    (confirmado_por is null) = (confirmado_em is null)
  )
);

create table comprovante (
  id uuid primary key default gen_random_uuid(),
  cobranca_id uuid not null references cobranca (id),
  -- Esvazia no descarte; a linha fica para id_transacao seguir bloqueando reenvio (RN10, RN19).
  arquivo_url text,
  enviado_em timestamptz not null default now(),
  valor_lido integer,
  data_lida timestamptz,
  destinatario_lido text,
  id_transacao text,
  -- Calculado no servidor a partir dos campos lidos, nunca informado pelo app (RN09).
  resultado comprovante_resultado not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  -- RN10: texto vazio burlaria a unicidade parcial.
  constraint comprovante_id_transacao_nao_vazio check (id_transacao <> '')
);

create table notificacao (
  id uuid primary key default gen_random_uuid(),
  pessoa_id uuid not null references pessoa (id),
  tipo notificacao_tipo not null,
  titulo text not null,
  corpo text,
  jogo_id uuid references jogo (id),
  cobranca_id uuid references cobranca (id),
  -- Vazio significa não lida.
  lida_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table dispositivo_push (
  id uuid primary key default gen_random_uuid(),
  pessoa_id uuid not null references pessoa (id),
  token_fcm text not null,
  modelo_aparelho text,
  -- Marca token expirado, que a rotina descarta.
  ultimo_erro_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create trigger tocar_atualizado_em before update on pessoa
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on local
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on horario_funcionamento
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on quadra
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on grupo
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on membro_grupo
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on jogo
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on convite
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on participacao
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on cobranca
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on comprovante
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on notificacao
  for each row execute function tocar_atualizado_em();
create trigger tocar_atualizado_em before update on dispositivo_push
  for each row execute function tocar_atualizado_em();
