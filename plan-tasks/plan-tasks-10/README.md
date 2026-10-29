# Plano da T10 — Fechamento do passo 3

Quebra de [T10](../passo-3/10-fechamento.md) em tasks executadas **uma por vez**: a seguinte só começa quando a anterior está feita, com o estado trocado nesta tabela e no cabeçalho do arquivo dela. Cada task fecha com um commit próprio, menos a T10.5, cuja mudança fica fora do git.

A T10 não escreve código. Ela transforma o que as treze tasks anteriores apuraram na entrada do passo 3 em [`docs/progresso.md`](../../docs/progresso.md) e libera o passo 4. O trabalho é de redação e de conferência: **cada linha da entrada tem de ter fonte numa task**, e o que não tiver, não entra.

Os itens marcados **[Thiago]** exigem painel, conta ou decisão dele e são feitos à mão.

## Estado conferido em 2026-10-29

- **T01 a T09 e T11 a T14 feitas.** A T10 é a última do passo. A T14 fechou a única decisão de produto que estava aberta (a mensagem do teto de e-mails), em dois commits: `0ebe603`/`315aafe` (documentos) e `a504c6f` (código).
- **`git status` limpo** no começo deste planejamento. A remoção da pasta `planT09/` e a criação desta pasta entram no commit do planejamento, não numa task.
- **Remoto:** ref `zmokpmovphikmobynssy`. Chega ao passo 4 com as cinco migrações aplicadas, sem usuário, sem `pessoa`, sem `dispositivo_push`, sem `seed.sql` e com o teto de e-mails em 30 por hora (T09.9, T14).
- **Nada pendente de execução.** O APK release está instalado no celular apontando para o remoto (T14), e nenhuma task deixou caixa desmarcada.

## De onde sai cada bloco da entrada

A T10 não apura nada novo: ela colhe. Antes de escrever, abrir a fonte de cada bloco.

| Bloco da entrada | Fonte |
| --- | --- |
| Resumo e **Arquivos** | as tasks T02 a T06, T12 a T14, e a árvore de `supabase/` e `app/lib/` |
| Decisões de configuração e banco | [T02](../passo-3/02-config-auth-local.md), [T03](../passo-3/03-migracao-autenticacao.md), [T08](../passo-3/08-projeto-remoto-resend.md) |
| Decisões do app e das telas | [T04](../passo-3/04-base-app-flutter.md), [T05](../passo-3/05-tela-entrar.md), [T06](../passo-3/06-tela-trocar-email.md), [T12](../passo-3/12-redefinir-senha.md), [T13](../passo-3/13-cadastro-refeito.md), [T14](../passo-3/14-teto-de-emails.md) |
| Decisões vindas do comportamento observado | "Anotar para a T10" de [T07](../passo-3/07-e2e-local.md) e o "Resultado" de [T09](../passo-3/09-e2e-remoto.md) |
| Decisões de produto tomadas no meio do passo | as seções "Decisões de…" do [README do passo 3](../passo-3/README.md) |
| "Aberto" | a lista da própria [T10](../passo-3/10-fechamento.md), mais os riscos de `docs/stack.md` |

A lista da T10 já enumera os 17 itens de decisão e os 12 de "Aberto". Ela é o roteiro; a fonte é para conferir número, data e redação, não para descobrir item novo. **Item novo que aparecer na conferência entra na lista da T10 antes de entrar na entrada.**

## Decidido no planejamento

- **A T10 fecha em cinco commits, e não em um.** O `Fecha o passo 3 — Autenticação` passa a ser o commit da última task; as anteriores levam o próprio. O motivo é o mesmo das outras tasks do passo: cada registro é revisável sozinho. A linha "Commit" de [`10-fechamento.md`](../passo-3/10-fechamento.md) é corrigida na T10.6.
- **Decisão e "Aberto" entram em commits separados.** São 29 itens densos, de fontes diferentes, e a conferência de cada metade é uma passada própria. A entrada fica sem "Aberto" entre os dois commits; não é release, e o estado do passo só vira "feito" depois, na T10.4.
- **O estado do passo troca depois da entrada, não antes** (T10.4). Enquanto a entrada não estiver escrita, `progresso.md` não deve dizer que o passo 3 está feito.
- **A memória do projeto é task própria** (T10.5), porque o que ela guarda não é cópia do `progresso.md`: memória que repete o repositório é ruído, e o critério está na task.
- **Nada de código, nada de migração, nada no painel.** A T10 só escreve documento. Se a conferência da T10.1 achar defeito de código, ele não se corrige aqui: vira task nova no passo 3, antes da T10, como foi a T14.
- **Esta pasta é removida depois**, em commit próprio, e fica no histórico — como as de T07, T08 e T09. A T10.6 registra isso, e a remoção é o commit seguinte ao fechamento.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T10.1](01-conferencia.md) | Conferência do estado do passo 3 | feito | — |
| [T10.2](02-decisoes-progresso.md) | Entrada do passo 3: resumo, arquivos e decisões | feito | T10.1 |
| [T10.3](03-aberto-progresso.md) | "Aberto" da entrada | feito | T10.2 |
| [T10.4](04-estado-e-readme.md) | Passo atual 4 e estado das tasks | feito | T10.3 |
| [T10.5](05-memoria.md) | Memória do projeto | a fazer | T10.4 |
| [T10.6](06-fechamento.md) | Fechamento da T10 e do passo | a fazer | T10.5 |

Ordem: T10.1 → T10.2 → T10.3 → T10.4 → T10.5 → T10.6. Nenhuma pode ser antecipada: cada uma escreve no mesmo arquivo que a anterior.

## Para a execução

- **Parar** se uma suíte falhar ou o `dart analyze` acusar algo na T10.1. O passo não fecha com teste vermelho, e a correção é task nova no passo 3.
- **Parar** se a conferência achar decisão de produto aberta. A regra do `CLAUDE.md` vale aqui: documento fecha antes de código, e passo não fecha com decisão pendente.
- **Parar** se uma linha da lista da T10 não tiver fonte em nenhuma task. Não inventar o motivo de uma decisão: perguntar ao Thiago.
- O que entra em `progresso.md` é o que **não se descobre lendo o código**: a decisão e o motivo. Nome de widget, assinatura de função e caminho de arquivo ficam fora, menos na linha "Arquivos".
- Divergência em relação ao desenho não vai para o `progresso.md`: vai para `docs/design/telas/01-acesso/implementacao.md`, e a entrada só aponta para lá.

## Modelo de task

```
# T10.N — Nome
**Estado:** feito | parcial | a fazer · **Depende de:** T10.x
## Objetivo
## O que já existe
## O que falta
## Resultado        ← preenchido na execução
## Pronto quando
## Commit
```
