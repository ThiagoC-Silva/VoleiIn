# T10.4 — Passo atual 4 e estado das tasks

**Estado:** feito · **Depende de:** T10.3

## Objetivo

Virar o estado: o passo 3 passa a "feito" e o passo 4 passa a ser o atual, em [`docs/progresso.md`](../../docs/progresso.md), com a tabela de tasks do [README do passo 3](../passo-3/README.md) batendo.

É o que **libera o passo 4**. Até aqui, o `progresso.md` ganhou um registro; é nesta task que ele muda de resposta para quem pergunta "onde o projeto está".

## O que já existe

- **A seção "Estado"** do `progresso.md`: a linha "**Passo atual: 3 — Autenticação.**" e a tabela dos dez passos, com o 3 em "a fazer".
- **A tabela de tasks** do README do passo 3, com T01 a T09 e T11 a T14 em "feito" e a T10 em "a fazer".
- **A entrada do passo 3**, escrita na T10.2 e na T10.3.
- O `CLAUDE.md` da raiz manda ler o `progresso.md` antes de implementar: essa linha é o que a próxima sessão vai ler primeiro.

## O que falta

- [x] `docs/progresso.md`, seção "Estado": "Passo atual" → **4 — Núcleo financeiro**, com o nome que `docs/stack.md` dá ao passo.
- [x] Na tabela dos dez passos: passo 3 → **feito**. Os passos 4 a 10 seguem "a fazer".
- [x] [README do passo 3](../passo-3/README.md): a T10 continua "a fazer" até a T10.6; conferir que as outras treze estão "feito" na tabela e no cabeçalho de cada arquivo, e corrigir o que a T10.1 tiver achado.
- [x] Não mexer na "Ordem de implementação" de `docs/stack.md`: ela descreve os dez passos, não o andamento.
- [x] Reler a entrada inteira uma vez, do título ao "Aberto", procurando repetição entre decisão e aberto, linha sem motivo e número que a T10.1 não mediu.

## Resultado

Feito em 2026-10-29.

- **`docs/progresso.md`:** "Passo atual" → **4 — Núcleo financeiro**, e o passo 3 → **feito** na tabela. Os passos 4 a 10 seguem "a fazer". A data do passo 3 está no título da entrada.
- **README do passo 3:** as treze tasks fora a T10 já estavam "feito", na tabela e no cabeçalho (conferido na T10.1). A T10 muda na T10.6, junto com o próprio arquivo.
- **`docs/stack.md` intocado**, como previsto.
- **Releitura da entrada, do título ao "Aberto":** sem repetição entre decisão e aberto (o teto de e-mails está só em "Decisões", e a contagem por hora só em "Aberto"), toda linha com motivo, e os números são os da T10.1.

## Pronto quando

`docs/progresso.md` mostra o passo 3 como feito, com data, e o passo 4 como atual. A tabela do README do passo 3 bate com o cabeçalho de cada task.

## Commit

`Marca o passo 3 como feito e abre o passo 4`
