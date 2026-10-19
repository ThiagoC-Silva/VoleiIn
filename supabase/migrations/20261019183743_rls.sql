-- Política de linha em toda tabela e a listar_participantes (RN26).
-- A matriz de quem lê o quê está em docs/stack.md, seção Política de linha.
-- O app só escreve em três lugares fora do rateio; o resto passa pelas funções do passo 4.

-- Auxiliares das políticas. Ficam fora de public para não virar RPC.
-- São security definer porque leem tabelas que também têm política: sem isso,
-- jogo e participacao consultariam uma à outra em recursão.
create schema privado;
revoke all on schema privado from public;
grant usage on schema privado to authenticated;

create function privado.eh_membro(p_grupo_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membro_grupo m
    where m.grupo_id = p_grupo_id and m.pessoa_id = (select auth.uid())
  );
$$;

create function privado.eh_admin(p_grupo_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membro_grupo m
    where m.grupo_id = p_grupo_id and m.pessoa_id = (select auth.uid()) and m.papel = 'admin'
  );
$$;

-- Ver o jogo: criador, recebedor, membro do grupo ou participação em qualquer status.
create function privado.pode_ver_jogo(p_jogo_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.jogo j
    where j.id = p_jogo_id
      and (
        j.criador_id = (select auth.uid())
        or j.recebedor_id = (select auth.uid())
        or exists (
          select 1 from public.membro_grupo m
          where m.grupo_id = j.grupo_id and m.pessoa_id = (select auth.uid())
        )
        or exists (
          select 1 from public.participacao p
          where p.jogo_id = j.id and p.pessoa_id = (select auth.uid())
        )
      )
  );
$$;

-- Membro, ou quem joga um jogo do grupo sem ser membro: o feed precisa do selo (RF12).
create function privado.pode_ver_grupo(p_grupo_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select privado.eh_membro(p_grupo_id)
    or exists (
      select 1 from public.jogo j
      join public.participacao p on p.jogo_id = j.id
      where j.grupo_id = p_grupo_id and p.pessoa_id = (select auth.uid())
    );
$$;

-- O próprio, quem divide grupo e quem está envolvido num jogo que eu vejo.
create function privado.conhece(p_pessoa_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_pessoa_id = (select auth.uid())
    or exists (
      select 1 from public.membro_grupo eu
      join public.membro_grupo outro on outro.grupo_id = eu.grupo_id
      where eu.pessoa_id = (select auth.uid()) and outro.pessoa_id = p_pessoa_id
    )
    or exists (
      select 1 from public.jogo j
      where (
          j.criador_id = p_pessoa_id
          or j.recebedor_id = p_pessoa_id
          or exists (
            select 1 from public.participacao p
            where p.jogo_id = j.id and p.pessoa_id = p_pessoa_id
          )
        )
        and privado.pode_ver_jogo(j.id)
    );
$$;

-- Hora em que o encerramento automático acontece: uma hora depois do fim reservado (RN17).
-- Vencimento da cobrança e fim da janela de falta são 24 horas depois disso (RN04, RN07).
create function privado.encerramento_previsto(p_inicio timestamptz, p_duracao_minutos integer)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select p_inicio + make_interval(mins => p_duracao_minutos) + interval '1 hour';
$$;

-- Funções criadas pelo postgres não nascem executáveis por todo mundo.
alter default privileges revoke execute on functions from public;
revoke execute on all functions in schema privado from public;
grant execute on function
  privado.eh_membro(uuid),
  privado.eh_admin(uuid),
  privado.pode_ver_jogo(uuid),
  privado.pode_ver_grupo(uuid),
  privado.conhece(uuid)
to authenticated;

-- Privilégios. Revogar além da política faz a escrita indevida falhar com 42501,
-- em vez de passar em silêncio sem tocar linha nenhuma.
revoke all on all tables in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;

-- As três escritas diretas fora do rateio, limitadas por coluna (RF02, RF38, RF40).
grant update (nome, avatar_url, telefone, chave_pix) on pessoa to authenticated;
grant update (lida_em) on notificacao to authenticated;
grant insert (pessoa_id, token_fcm, modelo_aparelho), delete on dispositivo_push to authenticated;

revoke execute on function tocar_atualizado_em() from public, anon, authenticated;

-- As próximas migrações concedem o que cada objeto precisa, em vez de herdar tudo.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;

-- Políticas. Nome: <tabela>_<operação>_<quem>.
alter table pessoa enable row level security;
alter table grupo enable row level security;
alter table membro_grupo enable row level security;
alter table convite enable row level security;
alter table local enable row level security;
alter table horario_funcionamento enable row level security;
alter table quadra enable row level security;
alter table jogo enable row level security;
alter table participacao enable row level security;
alter table cobranca enable row level security;
alter table comprovante enable row level security;
alter table notificacao enable row level security;
alter table dispositivo_push enable row level security;

create policy pessoa_select_conhecidos on pessoa
  for select to authenticated
  using (privado.conhece(id));

create policy pessoa_update_proprio on pessoa
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy grupo_select_membro_participante on grupo
  for select to authenticated
  using (privado.pode_ver_grupo(id));

create policy membro_grupo_select_membros on membro_grupo
  for select to authenticated
  using (privado.eh_membro(grupo_id));

create policy convite_select_criador_admin on convite
  for select to authenticated
  using (criado_por = (select auth.uid()) or (tipo = 'grupo' and privado.eh_admin(grupo_id)));

-- RN18: só leitura; quem grava é a chave de serviço, que contorna a política.
create policy local_select_todos on local
  for select to authenticated
  using (true);

create policy horario_funcionamento_select_todos on horario_funcionamento
  for select to authenticated
  using (true);

create policy quadra_select_todos on quadra
  for select to authenticated
  using (true);

create policy jogo_select_quem_ve on jogo
  for select to authenticated
  using (privado.pode_ver_jogo(id));

create policy participacao_select_quem_ve_jogo on participacao
  for select to authenticated
  using (privado.pode_ver_jogo(jogo_id));

-- RN19, RNF02
create policy cobranca_select_devedor_credor on cobranca
  for select to authenticated
  using (devedor_id = (select auth.uid()) or credor_id = (select auth.uid()));

create policy comprovante_select_devedor_credor on comprovante
  for select to authenticated
  using (
    exists (
      select 1 from cobranca c
      where c.id = cobranca_id
        and (c.devedor_id = (select auth.uid()) or c.credor_id = (select auth.uid()))
    )
  );

create policy notificacao_select_destinatario on notificacao
  for select to authenticated
  using (pessoa_id = (select auth.uid()));

create policy notificacao_update_destinatario on notificacao
  for update to authenticated
  using (pessoa_id = (select auth.uid()))
  with check (pessoa_id = (select auth.uid()));

create policy dispositivo_push_select_titular on dispositivo_push
  for select to authenticated
  using (pessoa_id = (select auth.uid()));

create policy dispositivo_push_insert_titular on dispositivo_push
  for insert to authenticated
  with check (pessoa_id = (select auth.uid()));

create policy dispositivo_push_delete_titular on dispositivo_push
  for delete to authenticated
  using (pessoa_id = (select auth.uid()));

-- RN26: participantes do jogo, com a marca de débito vencido só para criador,
-- recebedor e admins do grupo; para os demais a coluna vem vazia.
-- Débito vencido é cobrança ainda pendente 24 horas depois do encerramento previsto,
-- de jogo do mesmo grupo ou, no avulso, devida ao mesmo recebedor.
-- Quem não vê o jogo recebe nenhuma linha, como na política de participacao.
create function listar_participantes(p_jogo_id uuid)
returns table (
  participacao_id uuid,
  pessoa_id uuid,
  nome text,
  avatar_url text,
  status participacao_status,
  confirmado_em timestamptz,
  cancelado_em timestamptz,
  posicao_espera integer,
  debito_vencido boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id,
    p.pessoa_id,
    pe.nome,
    pe.avatar_url,
    p.status,
    p.confirmado_em,
    p.cancelado_em,
    p.posicao_espera,
    case
      when j.criador_id = (select auth.uid())
        or j.recebedor_id = (select auth.uid())
        or privado.eh_admin(j.grupo_id)
      then exists (
        select 1 from public.cobranca c
        join public.participacao p2 on p2.id = c.participacao_id
        join public.jogo j2 on j2.id = p2.jogo_id
        where c.devedor_id = p.pessoa_id
          and c.status = 'pendente'
          and j2.status = 'encerrado'
          and privado.encerramento_previsto(j2.inicio, j2.duracao_minutos) + interval '24 hours' <= now()
          and case
            when j.grupo_id is not null then j2.grupo_id = j.grupo_id
            else c.credor_id = j.recebedor_id
          end
      )
    end
  from public.jogo j
  join public.participacao p on p.jogo_id = j.id
  join public.pessoa pe on pe.id = p.pessoa_id
  where j.id = p_jogo_id
    and privado.pode_ver_jogo(j.id)
  order by
    case p.status when 'confirmado' then 0 when 'lista_espera' then 1 else 2 end,
    p.confirmado_em,
    p.posicao_espera,
    p.cancelado_em;
$$;

grant execute on function listar_participantes(uuid) to authenticated;
