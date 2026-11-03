# Passo 4 — Núcleo financeiro

Quebra do passo 4 de [`docs/stack.md`](../../docs/stack.md) em tasks menores, implementadas **uma por vez, na ordem abaixo**. Cada task fecha com um commit próprio; o passo fecha na T13, com a entrada em [`docs/progresso.md`](../../docs/progresso.md).

> As funções de grupo, de jogo, presença e cobrança, e a `excluir_conta`, todas gravando os próprios avisos, com um script SQL de cenários rodando contra o Supabase local. Abre com as migrações `ajustes_funcoes` e `ajustes_schema`.

## Contexto

As decisões de produto que bloqueavam o passo foram fechadas em 2026-11-01 (`plan-tasks/resolve-before-step4.md`, commits `1c14ba1` e `c569258`). Ao planejar o passo, apareceram mais sete lacunas, respondidas pelo usuário no mesmo dia. Elas entram nos documentos na T01, antes de qualquer código:

1. **Cancelar presença só até o início do jogo.** Depois dele, a ausência é falta (RN04). Confirmar depois do início já era vedado (RN06).
2. **Data, horário, local e quadra só mudam até o início** (RN20), como as vagas.
3. **Qualquer admin promove outro membro a admin** (RN13 muda).
4. **Admin único, quem criou o grupo ou não, só sai depois de promover outro admin**; o último membro sai livre (RN30).
5. **Excluir conta (RN27)** é recusado também enquanto o titular for recebedor de jogo `aberto`; ao excluir, ele sai de todos os grupos, e quem estava em lista de espera vira `cancelou_no_prazo`.
6. **Aviso de regra do grupo (RN11)** só quando o prazo muda, e só aos confirmados de jogos abertos que seguem o prazo do grupo.
7. **Textos dos avisos:** a T01 propõe os 9 textos que o G1 não mostra e o nome do jogo avulso nos textos; o usuário aprova antes de qualquer função gravar aviso.

## Convenções

Valem para todas as tasks. O que mudar durante o passo é registrado aqui e, no fechamento, em `docs/progresso.md`.

**Migrações**
- Sequência: `ajustes_funcoes` → `ajustes_schema` → `rpc_grupo` → `rpc_jogo` → `rpc_presenca` → `rpc_cobranca` → `rpc_conta`, cada uma criada com `supabase migration new <nome>`.
- `rpc_jogo` e `rpc_presenca` nascem numa task e crescem nas seguintes, **editadas no lugar**. É permitido porque nenhuma migração do passo vai ao remoto antes da T13 — a mesma regra que o passo 3 usou. Depois do `db push`, vale a de `supabase/CLAUDE.md`: corrige-se criando a próxima.
- Auxiliares que jogo e presença compartilham ficam em `rpc_jogo`, a mais antiga das duas. O plpgsql resolve chamada de função na execução, então uma função de `rpc_jogo` pode chamar outra de `rpc_presenca`; os testes rodam com todas aplicadas.

**Funções**
- Toda RPC é `security definer`, `set search_path = ''`, confere o papel (RN13) com as auxiliares que já existem em `20261019183743_rls.sql` — `privado.eh_membro`, `eh_admin`, `pode_ver_jogo`, `conhece` — e ganha `grant execute ... to authenticated`, porque o privilégio padrão está revogado.
- Auxiliares internas ficam em `privado`, sem `execute` para ninguém, nem `authenticated`.
- Idempotência por estado (RNF10): repetir a operação não muda nada e devolve o estado atual, sem erro.
- Hora de regra é `now()`. Dia e hora de funcionamento (RN15) são lidos em `America/Sao_Paulo`. Vencimento e janela de falta partem de `privado.encerramento_previsto`.
- Mutação de jogo e de presença trava a linha do jogo com `select ... for update` (RNF09). Criação e remarcação travam o local com `pg_advisory_xact_lock` antes de checar a RN15.

**Recusa**
- Regra violada: `raise exception using errcode = 'P0001', message = '<codigo_estavel>'`, por exemplo `quadra_ocupada`, `fora_do_funcionamento`, `jogo_ja_comecou`. O app traduz o código para o texto da tela; o código não muda depois de publicado.
- Falta de papel: `errcode = '42501'`, `message = 'sem_permissao'`.
- A convenção é escrita em `supabase/CLAUDE.md`, seção Funções, na T03, e cada task lista os códigos que cria.

**Avisos**
- `privado.avisar(pessoa, tipo, titulo, corpo, jogo, cobranca)`, criada na T03, grava a linha de `notificacao` na mesma transação. Os textos e os destinatários são os de `docs/design/telas/08-avisos/implementacao.md`, aprovados na T01. Valores em reais e datas em horário de Brasília, formatados no banco.

**Testes**
- Uma suíte por migração de função: `supabase/testes/rpc_grupo.sql`, `rpc_jogo.sql`, `rpc_presenca.sql`, `rpc_cobranca.sql`, `rpc_conta.sql`. Cada uma é uma transação desfeita, com o arnês de `rls.sql` (`espera_erro`, `espera_ok`, `espera_verdade`, `como`) e um auxiliar novo, `espera_recusa(descricao, comando, codigo)`, que exige `P0001` e o `sqlerrm` igual ao código.
- Pessoas entram como `postgres`, direto em `pessoa`, que não tem chave estrangeira para `auth.users`. Grupos e jogos nascem pelas funções, agindo como a pessoa (`como`). Locais e quadras são os do `seed.sql`, com UUIDs fixos: Arena Beira-Mar (`10000000-…-0001`, `por_quadra`, Quadras 1 e 2, seg a sex 18h–23h, sáb 20h–2h) e Ginásio Municipal (`10000000-…-0002`, `por_horario`, capacidade 2, todo dia 7h–22h, sex 19h–0h).
- Datas são calculadas a partir de `now()` em Brasília, como "próxima segunda às 19h", para a suíte passar em qualquer dia.
- O tempo passa movendo `jogo.inicio` por SQL, como `postgres` — é assim que um cenário vê o jogo começar, terminar ou vencer.
- Toda suíte começa e termina com as anteriores verdes: a task só fecha com `supabase db reset` e **todas** as suítes passando.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T01](01-documentacao-abertura.md) | Documentação de abertura | feito | — |
| [T02](02-migracoes-ajuste.md) | Migrações de ajuste | feito | T01 |
| [T03](03-rpc-grupo.md) | `rpc_grupo` e a base das funções | feito | T02 |
| [T04](04-criar-duplicar-jogo.md) | `rpc_jogo`: criar e duplicar jogo | feito | T03 |
| [T05](05-confirmar-presenca.md) | `rpc_presenca`: confirmar presença | feito | T04 |
| [T06](06-cancelar-presenca.md) | `rpc_presenca`: cancelar presença | feito | T05 |
| [T07](07-editar-jogo.md) | `rpc_jogo`: editar jogo | feito | T06 |
| [T08](08-cancelar-encerrar-jogo.md) | `rpc_jogo`: cancelar e encerrar jogo | feito | T06 |
| [T09](09-marcar-falta.md) | `rpc_presenca`: marcar falta | feito | T08 |
| [T10](10-rpc-cobranca.md) | `rpc_cobranca`: baixa e isenção | feito | T09 |
| [T11](11-excluir-conta.md) | `rpc_conta`: excluir conta | feito | T10 |
| [T12](12-concorrencia.md) | Concorrência | feito | T05, T07 |
| [T13](13-fechamento.md) | Fechamento do passo | a fazer | todas |

Ordem: T01 → T02 → T03 → T04 → T05 → T06 → T07 → T08 → T09 → T10 → T11 → T12 → T13. Uma task só começa com a anterior fechada e commitada.

Ao concluir uma task, troque o estado nesta tabela e no cabeçalho do arquivo dela.

## Modelo de task

```
# TNN — Nome
**Estado:** feito | parcial | a fazer · **Depende de:** TNN
## Objetivo
## O que já existe
## O que falta
## Pronto quando
## Commit
```
