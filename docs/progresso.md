# Progresso — VoleiIn

Registro do que já foi entregue, seguindo os dez passos de [stack.md](stack.md). Existe para que o estado do projeto seja conhecido em poucas linhas, sem reler o código.

O que entra aqui é o que **não se descobre lendo o código**: a decisão tomada durante a implementação e o motivo dela. Decisão de produto continua no [PRD](prd.md); aqui ficam só as de implementação.

## Estado

**Passo atual: 3 — Autenticação.**

| Passo | Estado |
| --- | --- |
| 1. Schema | feito |
| 2. Política de linha | feito |
| 3. Autenticação | a fazer |
| 4. Núcleo financeiro | a fazer |
| 5. App | a fazer |
| 6. Comprovante | a fazer |
| 7. Avisos | a fazer |
| 8. Rotinas | a fazer |
| 9. Convites | a fazer |
| 10. Distribuição | a fazer |

## Entregas

## Passo 1 — Schema · 2026-10-19

Os dez enums, as treze tabelas com as 27 chaves estrangeiras do modelo, as seis unicidades e os índices de leitura, mais um seed provisório do piloto. `supabase db reset` parte de banco vazio e `supabase/testes/schema.sql` passa com 61 asserções.

**Arquivos:** `supabase/migrations/` (`enums`, `tabelas`, `indices`), `supabase/seed.sql`, `supabase/testes/schema.sql`.

**Decisões de implementação:**
- Restrição de linha única vira `check` declarativo já no schema, para o banco recusar linha inválida venha de onde vier, inclusive do Studio. O que cruza tabelas fica nas funções do passo 4.
- A RN16 é `check` em `jogo`: `preco_por_vaga = (custo_total + vagas_total - 1) / vagas_total`, dentro de um `case` para não dividir por zero. Todo `update` de `custo_total` ou `vagas_total` precisa recalcular o preço no mesmo comando.
- `cobranca.confirmado_por` e `confirmado_em` andam juntos por `check`; a isenção manual também os preenche (RN07).
- `pessoa.id` não tem `default`: um `insert` sem id falha em vez de criar perfil sem credencial. É a única tabela fora da regra de `supabase/CLAUDE.md`.
- Enums nomeados `<entidade>_<campo>`. Unicidades são índices únicos, nomeados `<tabela>_<colunas>_unico`.
- Chaves estrangeiras sem `on delete cascade`: nada some em cascata, coerente com a preservação do histórico da RN27.
- Os únicos `default` de domínio são `local.verificado = false`, `membro_grupo.entrou_em` e `comprovante.enviado_em` com `now()`. Os `status` não têm padrão: as funções informam.
- `latitude` e `longitude` são `numeric` sem precisão fixa.
- As asserções rodam numa transação desfeita e exigem o nome da restrição que recusou, não só o código do erro. São a semente do script de cenários do passo 4.

**Aberto:**
- O seed é provisório (dois locais fictícios); trocar pelos locais, quadras, preços e horários reais do piloto quando existirem.
- `local.verificado` "sempre falso no MVP" (RN18) não tem `check`: ficou fora da lista do passo. Decidir se entra numa migração futura.
- Não há índice em `comprovante (cobranca_id)` nem nas chaves estrangeiras que ninguém consulta. Irrelevante no volume do piloto; reavaliar quando o passo 6 definir as consultas do comprovante.
- O usuário está no grupo `docker`, mas a sessão precisa ser reaberta para valer; até lá, os comandos rodam com `sg docker -c '…'`.

## Passo 2 — Política de linha · 2026-10-19

Política de linha ligada nas treze tabelas, conforme a matriz de `docs/stack.md`; o papel `anon` não alcança nada, e `authenticated` só escreve nas três exceções fora do rateio. A `listar_participantes` devolve a marca de débito vencido da RN26. `supabase/testes/rls.sql` passa com 69 asserções, e a `schema.sql` segue com 61.

**Arquivos:** `supabase/migrations/` (`rls`), `supabase/testes/rls.sql`.

**Decisões de implementação:**
- As auxiliares das políticas (`eh_membro`, `eh_admin`, `pode_ver_jogo`, `pode_ver_grupo`, `conhece`) são `security definer` num schema `privado`, fora da API: assim jogo e participação não se consultam em recursão, e nenhuma delas vira RPC.
- `privado.encerramento_previsto(inicio, duracao_minutos)` é a âncora da RN17; vencimento (RN07) e fim da janela de falta (RN04) são ela mais 24 horas. Os passos 4 e 8 devem usá-la, não recalcular.
- Além da política, os privilégios foram revogados: escrita sem privilégio falha com 42501, em vez de passar em silêncio sem tocar linha. As três escritas diretas têm grant por coluna — `pessoa` (nome, avatar_url, telefone, chave_pix), `notificacao` (lida_em), `dispositivo_push` (insert das colunas do app e delete).
- Privilégio padrão revogado: função ou tabela nova nasce sem acesso para `anon`, `authenticated` nem `public`. **Toda função RPC do passo 4 precisa de `grant execute ... to authenticated` explícito.**
- `listar_participantes` devolve `debito_vencido` vazio (`null`) para quem não tem papel, em vez de `false`, para não afirmar que a pessoa está em dia. Quem não vê o jogo recebe lista vazia, como na política.
- Os testes trocam de usuário como a API faz: papel `authenticated` e o id em `request.jwt.claims`, lido por `auth.uid()`.

**Aberto:**
- Token FCM já registrado por outra conta no mesmo aparelho: decidido depois do fechamento que o registro passa pela `registrar_dispositivo`, que transfere a linha (`docs/stack.md`, Política de linha). A migração `rls` ainda concede `insert` em `dispositivo_push`; a migração `avisos` do passo 7 revoga esse privilégio e a política `dispositivo_push_insert_titular`, e o `rls.sql` troca as asserções de insert direto pelas da função.
- Funções de grupo, de convite, `apagar_comprovante` e `registrar_dispositivo` entraram na lista de `docs/stack.md`, com passo definido: grupo no 4 (`rpc_grupo`), `apagar_comprovante` no 6, `registrar_dispositivo` no 7 (`avisos`), convites no 9 (`rpc_convite`).
- ~~Quem apaga os aparelhos na troca de e-mail (RNF07)~~ — resolvido na abertura do passo 3: um gatilho na mudança de `email` em `auth.users` apaga todo `dispositivo_push` do titular (`docs/stack.md`, Autenticação).

<!-- Modelo de entrada, a copiar ao fechar um passo:

## Passo N — Nome · 2026-00-00

O que foi entregue, em duas ou três linhas.

**Arquivos:** os caminhos principais, não a lista completa.
**Decisões de implementação:** o que foi escolhido aqui e não está no PRD, com o motivo.
**Aberto:** o que ficou pendente e por quê.

Ao fechar uma tela: divergência em relação ao desenho vai para `docs/design/telas/<grupo>/implementacao.md`, não para cá.
-->
