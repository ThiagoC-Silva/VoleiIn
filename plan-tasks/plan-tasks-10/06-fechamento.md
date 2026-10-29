# T10.6 — Fechamento da T10 e do passo

**Estado:** a fazer · **Depende de:** T10.5

## Objetivo

Fechar a própria T10 e o passo 3: caixas marcadas, estados trocados, `git status` limpo e o commit `Fecha o passo 3 — Autenticação`.

## O que já existe

- A entrada do passo 3 no `progresso.md`, completa (T10.2, T10.3) e com o estado virado (T10.4).
- A memória atualizada (T10.5), fora do git.
- A linha "Commit" de [`10-fechamento.md`](../passo-3/10-fechamento.md) ainda diz um commit só, de quando a T10 não estava quebrada em tasks.
- O precedente das T07, T08 e T09: a pasta do plano da task sai em commit próprio depois do fechamento, e fica no histórico.

## O que falta

- [ ] [`10-fechamento.md`](../passo-3/10-fechamento.md): caixas marcadas, estado → **feito**, e um "Resultado" curto com a data, os totais medidos na T10.1, o que a conferência corrigiu e a nota de que a pasta `plan-tasks/plan-tasks-10/` será removida em commit próprio e fica no histórico.
- [ ] A linha "Commit" da T10 passa a listar os cinco commits das tasks, em vez de um só.
- [ ] [README do passo 3](../passo-3/README.md): T10 → **feito**. Com isso, as catorze tasks do passo estão fechadas.
- [ ] [README deste plano](README.md): as seis tasks → **feito**.
- [ ] `git status` limpo depois do commit, e `git log --oneline` mostrando a sequência do fechamento.
- [ ] Conferir uma última vez que `docs/progresso.md` responde em poucas linhas onde o projeto está: passo 4, com o passo 3 registrado.
- [ ] Não começar o passo 4 nesta task. O passo 4 abre com plano próprio, em `plan-tasks/passo-4/`.

## Resultado

## Pronto quando

A T10 está "feito" nos dois READMEs e no próprio arquivo, `docs/progresso.md` mostra o passo 3 feito com data e o passo 4 como atual, e `git status` está limpo.

## Commit

`Fecha o passo 3 — Autenticação`

A remoção desta pasta é o commit seguinte, `Remove o plano da T10, já concluída`, fora da T10.
