# Passo 1 — Schema

Painel do passo atual. Vive na raiz enquanto o passo 1 estiver aberto e é apagado quando fechar: o registro permanente vai para [docs/progresso.md](docs/progresso.md). A ordem dos dez passos está em [docs/stack.md](docs/stack.md#ordem-de-implementação).

## Objetivo

Enums, tabelas, índices e unicidades, aplicados no banco local. Ao fim, `supabase db reset` partindo de banco vazio cria os dez tipos, as treze tabelas, as restrições e os índices, aplica o `seed.sql` e passa o arquivo de asserções.

**Não entrega:** política de linha (passo 2), autenticação e projeto remoto (passo 3), funções de regra (passo 4). Nada de app.

## Premissas

Decisões que os documentos não fixam, confirmadas em 19/10/2026 para ficarem auditáveis depois.

| Decisão | Escolha | Motivo |
| --- | --- | --- |
| Ambiente | Banco local em Docker | É o que `docs/stack.md` pressupõe. O local é descartável: `db reset` recria em segundos, então errar SQL não custa nada. No remoto, cada erro de schema vira correção permanente. |
| Restrições de linha única | `check` declarativo já neste passo | O banco recusa linha inválida independente de quem escreve, inclusive pelo Studio. O que cruza tabelas fica nas funções do passo 4. |
| `seed.sql` | Entra neste passo, abrindo com uma pessoa de UUID fixo | `local.criado_por` é chave estrangeira obrigatória para `pessoa`. O seed roda só no local — `db reset` nunca o envia ao remoto. |
| Verificação | Arquivo SQL de asserções versionado | Reexecutável a cada mudança de schema, e é a semente do script de cenários do passo 4. |
| Arredondamento da RN16 | `check` na tabela `jogo`, não só na função | Nenhuma escrita grava valor por vaga inconsistente — nem a função, nem o Studio, nem um script futuro. O custo é que todo `update` em `custo_total` ou `vagas_total` recalcula `preco_por_vaga` no mesmo comando, que é o que a RN01 já exige. |
| Cobrança `isenta` | Preenche `confirmado_por` e `confirmado_em`, como a baixa | O par passa a significar "quem resolveu esta cobrança e quando", e o banco exige que os dois andem juntos. Transição automática não tem autor e deixa o par vazio. Já registrado na RN07 do PRD. |

Duas convenções novas:

- **Nome de enum:** `<entidade>_<campo>` — `jogo_status`, `cobranca_origem`, `participacao_status`.
- **`pessoa.id` é `uuid primary key` sem `default`**, a única exceção à regra de `supabase/CLAUDE.md`: ele espelha o id de `auth.users`, e quem o fornece é o gatilho do passo 3 (`docs/stack.md`, seção Autenticação). Sem default, um `insert` que esqueça o id falha na hora, em vez de criar um perfil órfão sem credencial.

## Tarefas

### 1.0 — Ambiente

- [x] Instalar o Docker Engine e adicionar o usuário ao grupo `docker` (exige reabrir a sessão)
- [x] Instalar o Supabase CLI
- [x] `supabase init` na raiz — cria `supabase/config.toml`, que **vai para o Git**
- [x] `supabase start` e conferir o Studio no navegador

**Fecha quando:** `supabase status` lista os serviços de pé.

### 1.1 — Migração de enums

- [x] `supabase migration new enums`
- [x] Os dez tipos do catálogo de `docs/modelo-de-dados.md`, com os valores exatos, sem traduzir e sem acrescentar: `membro_grupo_papel` (2), `convite_tipo` (2), `local_modo_reserva` (2), `quadra_tipo` (3), `jogo_status` (3), `participacao_status` (5), `cobranca_origem` (3), `cobranca_status` (5), `comprovante_resultado` (3), `notificacao_tipo` (14)

Vem primeiro porque a tabela declara a coluna com o tipo, e o tipo precisa existir antes.

**Fecha quando:** `db reset` passa e `\dT+` lista os dez tipos com essas contagens.

### 1.2 — Migração de tabelas

- [x] `supabase migration new tabelas`
- [x] As treze entidades em ordem de dependência: `pessoa`, `local`, `horario_funcionamento`, `quadra`, `grupo`, `membro_grupo`, `jogo`, `convite`, `participacao`, `cobranca`, `comprovante`, `notificacao`, `dispositivo_push`
- [x] Colunas comuns: `id`, `criado_em timestamptz not null default now()`, `atualizado_em timestamptz not null default now()`
- [x] Gatilho `tocar_atualizado_em()`, um por tabela — é a única função desta migração
- [x] Os doze `check` da tabela abaixo

| Tabela | Restrição | Origem |
| --- | --- | --- |
| `jogo` | `vagas_total > 0`, `duracao_minutos > 0`, `custo_total >= 0` | Modelo |
| `jogo` | `preco_por_vaga` é o teto de `custo_total / vagas_total` em aritmética inteira | RN01, RN16 |
| `jogo` | `prazo_cancelamento_horas` obrigatório quando `grupo_id` é vazio | RN12 |
| `jogo` | `chave_pix_recebedor` não é texto vazio quando preenchido | RN24, RN27 |
| `participacao` | `posicao_espera` preenchido se e somente se o status é `lista_espera`, e maior que zero | RN08 |
| `convite` | exatamente um entre `grupo_id` e `jogo_id`, conforme o `tipo` | RN22 |
| `horario_funcionamento` | `dia_semana` entre 0 e 6 | Modelo |
| `local`, `quadra` | `preco_hora >= 0`; `capacidade > 0` quando preenchida | RN14, RN15 |
| `grupo` | `vagas_padrao > 0` e `custo_total_padrao >= 0` quando preenchidos | RN12 |
| `cobranca` | `valor >= 0` | Modelo |
| `cobranca` | `confirmado_por` e `confirmado_em` preenchidos juntos, ou ambos vazios | RN07 |
| `comprovante` | `id_transacao` não é texto vazio quando preenchido | RN10 |

O `check` de `preco_por_vaga` é o mais valioso dos doze: torna a RN16 estrutural, e não só uma linha dentro de `criar_jogo`.

**Fora deste passo por dependerem de outra tabela** — vão para as funções do passo 4: `cobranca.devedor_id` igual ao `pessoa_id` da participação, `cobranca.credor_id` igual ao `recebedor_id` do jogo (RN20), `quadra_id` conforme `local.modo_reserva`, sobreposição de quadra e capacidade do local (RN15), jogo cabendo na faixa de funcionamento (RN15), `vagas_total` nunca abaixo dos confirmados (RN06), comprovante só depois do encerramento (RN07).

**Fecha quando:** `db reset` passa e `\d` mostra treze tabelas com as chaves estrangeiras de `docs/modelo-de-dados.md`.

### 1.3 — Migração de índices

- [x] `supabase migration new indices`
- [x] Unicidades: `membro_grupo (grupo_id, pessoa_id)`, `participacao (jogo_id, pessoa_id)`, `cobranca (participacao_id)`, `convite (token)`, `dispositivo_push (token_fcm)`
- [x] `comprovante (id_transacao)` **parcial**, com `where id_transacao is not null` (RN10)
- [x] Índices de leitura: feed de `jogo` por grupo e por data, `jogo` por quadra e por local no tempo (checagens da RN15), `cobranca` por devedor e por credor com status, `participacao` por jogo e status, `notificacao` por pessoa e `lida_em`, `local_id` em `quadra` e `horario_funcionamento`

**Fecha quando:** dois comprovantes sem `id_transacao` convivem na mesma cobrança, e dois com o mesmo identificador são recusados.

### 1.4 — `seed.sql`

- [ ] Pessoa de UUID fixo, para satisfazer `local.criado_por`
- [ ] Locais, quadras, preços e horários do piloto (RN18)
- [ ] Pelo menos uma faixa atravessando a meia-noite, com `fecha` menor ou igual a `abre` (RN15)

**Fecha quando:** `db reset` aplica o seed sem erro.

### 1.5 — Asserções de schema

- [ ] `supabase/testes/schema.sql`, tentando violar cada restrição e esperando o erro: cada unicidade, cada `check` no valor limite, o enum recusando valor fora da lista, o gatilho de `atualizado_em` movendo o campo num `update`
- [ ] Os casos que devem passar: dois comprovantes ilegíveis na mesma cobrança, e um jogo válido ponta a ponta do local à cobrança

**Fecha quando:** o arquivo roda inteiro e reporta sucesso.

### 1.6 — Registro

- [ ] `docs/progresso.md`: passo 1 como `feito`, com a entrada no modelo previsto no arquivo
- [ ] Apagar este arquivo
- [ ] Um commit por fatia, em português

**Fecha quando:** o passo atual em `docs/progresso.md` é o 2.

## Verificação — estado em 19/10/2026

| Fatia | Estado | Evidência |
| --- | --- | --- |
| Documentos fechados e instruções no lugar | **feito** | `docs/prd.md`, `docs/modelo-de-dados.md`, `docs/stack.md`, os três `CLAUDE.md` e o `.gitignore` existem |
| 1.0 Ambiente | **feito** | Docker 29.9.1 e CLI 3.0.0-next.20 instalados; `supabase status` lista os serviços de pé e o Studio abre em `127.0.0.1:54323` |
| 1.1 Enums | **feito** | `db reset` aplica `20261019165515_enums.sql`; `\dT+` lista os dez tipos com as contagens 2, 2, 2, 3, 3, 5, 3, 5, 3, 14 |
| 1.2 Tabelas | **feito** | `db reset` aplica `20261019172256_tabelas.sql`; o banco tem 13 tabelas, 27 chaves estrangeiras (as 27 linhas de `docs/modelo-de-dados.md`), 18 `check` nas doze linhas da tabela e 13 gatilhos; 10000/7 com `preco_por_vaga` 1429 entra e 1428 é recusado |
| 1.3 Índices | **feito** | `db reset` aplica `20261019173043_indices.sql`; seis índices únicos (cinco comuns e o parcial de `id_transacao`) e nove de leitura; dois comprovantes sem `id_transacao` convivem na mesma cobrança e o segundo `E123` é recusado por `comprovante_id_transacao_unico` |
| 1.4 `seed.sql` | a fazer | — |
| 1.5 Asserções | a fazer | — |
| 1.6 Registro | a fazer | `docs/progresso.md` marca o passo 1 como a fazer |

Ao fim, conferir contra os documentos: dez tipos com os valores exatos do catálogo, treze tabelas, as chaves estrangeiras e as seis unicidades de `docs/modelo-de-dados.md`. E `supabase migration list` mostrando as três migrações aplicadas no local e nenhuma no remoto — o remoto só entra no passo 3.

## Armadilhas

- O índice único de `comprovante.id_transacao` é **parcial**. Comum, os ilegíveis disputariam entre si (RN10).
- `pessoa.id` não tem `default gen_random_uuid()`.
- Enum só muda por migração nova, com `alter type ... add value`. Nunca editando a migração original.
- **Nunca editar migração já aplicada.** O remoto não roda de novo um arquivo que já rodou, então editar faz local e remoto divergirem em silêncio.
- Dinheiro é sempre `integer` em centavos. R$ 18,29 é `1829`.

## Pendências de produto

- **Dados reais do piloto** para o `seed.sql`: quais locais, quadras, preços por hora e horários de funcionamento. Entra um conjunto mínimo plausível, para substituir quando os reais existirem.
Nenhuma outra. A semântica de `confirmado_por` está fechada nos três documentos.
