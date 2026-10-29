# T10.5 — Memória do projeto

**Estado:** a fazer · **Depende de:** T10.4

## Objetivo

Deixar na memória do projeto só o que **não está no repositório** e que a próxima sessão precisaria redescobrir. É o último item da [T10](../passo-3/10-fechamento.md), e o único cuja mudança fica fora do git.

## O que já existe

- **Duas memórias**, as duas sobre operar o celular: `claude-opera-celular-adb` (o Claude opera o aparelho pelo `adb`, e lê códigos nas notificações do Gmail) e `adb-sem-fio-rede-5g` (na rede de 2,4 GHz o roteador isola máquina e celular). As duas nasceram da T09 e da T14 e continuam valendo no passo 4.
- **O critério da memória:** não guardar o que o repositório já registra — estrutura de código, correção passada, histórico do git, `CLAUDE.md`. Memória que repete documento é ruído, porque ela não tem como ser corrigida quando o documento muda.
- **O que a T10 pediu guardar:** "passo 3 fechado e `plan-tasks/` versionado por passo".

## O que falta

- [ ] Avaliar item por item antes de escrever:
  - **"passo 3 fechado" não vira memória.** O `progresso.md` é a fonte de verdade do andamento, e o `CLAUDE.md` da raiz manda lê-lo antes de implementar; uma memória com o passo atual envelhece no primeiro fechamento seguinte e passa a contradizer o arquivo.
  - **O fluxo do `plan-tasks/` vira memória**, na parte que não está em arquivo: o plano do passo mora em `plan-tasks/passo-N/`, a quebra de uma task em subtasks mora numa pasta irmã, e essa pasta é removida em commit próprio quando a task fecha, ficando no histórico. O README do passo 3 diz que `plan-tasks/` é versionado por passo, mas não diz nada da quebra nem da remoção.
- [ ] Escrever a memória do fluxo em `/home/thiggoc/.claude/projects/-home-thiggoc--rea-de-trabalho-VoleiIn/memory/`, tipo `project`, com **Why** e **How to apply**, ligando às duas existentes se couber.
- [ ] Acrescentar a linha dela no `MEMORY.md`, uma linha só, com o gancho.
- [ ] Conferir que as duas memórias existentes continuam verdadeiras depois da T14 (a da rede de 2,4 GHz foi confirmada nela) e corrigir ou apagar o que não estiver.
- [ ] **[Thiago]** Se ele quiser mesmo a memória do passo atual, apesar do argumento acima, escrevê-la — é preferência dele sobre como o Claude trabalha, não decisão de produto.

## Resultado

## Pronto quando

A memória do projeto tem o fluxo do `plan-tasks/` registrado, com a linha no `MEMORY.md`, e nenhuma memória repetindo o `progresso.md`.

## Commit

Sem commit: a memória fica em `~/.claude`, fora do repositório. O Resultado desta task entra no commit da T10.6.
