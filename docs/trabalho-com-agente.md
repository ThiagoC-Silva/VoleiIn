# Trabalho com o Agente

> Decisões de 09/11/2026. Base: `CLAUDE.md`, `plano-implementacao.md`, `plan-docs.md` (seções 3.2, 5.3 e 8.4) e `setup.md`.
> Como o agente (Claude Code ou similar) trabalha neste projeto. O objetivo é que, olhando um PR, dê para dizer se a regra de pronto foi cumprida.

## 1. Papéis

| Quem | Faz | Não faz |
|------|-----|---------|
| **Responsável** (dono do produto e único desenvolvedor) | Decide regras e escopo, aprova documentos, revisa os PRs, confere os fluxos no emulador, faz os testes com contas reais (Google, e-mail) | — |
| **Agente** | Escreve documentos da fatia quando pedido, especifica com o Spec Kit, escreve testes e código, abre PRs, faz o *merge* com o CI verde, aplica migrações e mexe em configuração e segredos na produção (decisão de 13/11/2026) | Decide regra (seção 7) |

## 2. Começo de sessão

1. Ler o `CLAUDE.md` e a linha "Estado atual".
2. Ler a fatia atual em `plano-implementacao.md`: escopo, "Pronto quando" e "Fora de escopo".
3. Ler só os documentos que a tarefa usa (tabela do `CLAUDE.md`), sem assumir regra, valor padrão ou nome que eles já definem.
4. Conferir `git status` e o *branch* atual antes de mexer em qualquer arquivo.

## 3. Ciclo de uma fatia

**Documentação e código são etapas separadas.** Os documentos da fatia são escritos, revisados e aprovados numa rodada. O código vem em outra.

| Etapa | O que acontece | Saída |
|-------|----------------|-------|
| 1. Conferir | A lista da seção 8.4 do `plan-docs.md`: dependências concluídas e contratos das funções existentes | Lista do que falta |
| 2. Documentar | Telas (`docs/ui/telas.md`), textos (`docs/copy.md`), RLS (`docs/rls-matriz.md`) e os cenários de teste da fatia, só o que ela usa. O agente escreve também o **briefing visual** de cada tela em `docs/ui/referencias/README.md` | PR só de documentação, aprovado pelo responsável |
| 2b. Referência visual | O responsável desenha cada tela do briefing e salva o PNG em `docs/ui/referencias/fatia-<n>/` (decisão de 12/11/2026). **Nenhuma tela é implementada sem o PNG obrigatório dela.** Se o PNG divergir do `telas.md` em conteúdo, o agente pergunta antes | PNGs no repositório |
| 3. Especificar | `/speckit-specify`, `/speckit-plan` e `/speckit-tasks`. O `spec.md` **cita** os RFs, RNs e seções dos documentos, sem copiar o texto | `specs/<nnn>-<nome>/` |
| 4. Testes primeiro | Os testes da tarefa são escritos e rodados, e **falham** pelo motivo certo: a função ainda não existe ou não faz o esperado | *Commit* só de testes |
| 5. Implementar | `/speckit-implement`, tarefa por tarefa, até os testes passarem | *Commits* de implementação |
| 6. Convergir | `/speckit-converge` e a definição de pronto (seção 5) | PR pronto para revisão |
| 7. Fechar a fatia | Seção 11 | Fatia marcada como concluída |

### 3.1 Uma sessão por etapa (decisão de 13/11/2026)

Uma fatia inteira não cabe numa sessão do agente: o contexto é resumido quando a conversa fica longa, e cada resumo perde detalhe. Por isso, a fatia roda em **quatro sessões**, cada uma começada do zero, numa conversa nova:

| Sessão | Etapas do ciclo | O que entrega | Termina quando |
|--------|-----------------|---------------|----------------|
| **1. Documentação** | 1 e 2 | Lista da seção 8.4 do `plan-docs.md`; `telas.md`, `copy.md`, `rls-matriz.md`, cenários em `testes-referencia.md` e o briefing visual de cada tela | PR só de documentação na `main`. **Entre as sessões 1 e 3, o responsável desenha os PNGs (etapa 2b)** |
| **2. Servidor** | 3, 4 e 5 (banco) | Spec Kit da fatia; migrações, funções, RLS, Storage e Edge Functions, com os testes pgTAP e Deno escritos antes | `supabase test db`, `supabase db lint` e `deno test` verdes |
| **3. App** | 4 e 5 (telas) | As telas, a partir dos PNGs, com os testes de widget e de acessibilidade escritos antes | `dart analyze` e `flutter test` verdes. Sem os PNGs obrigatórios, a sessão não começa |
| **4. Validação e fechamento** | 6 e 7 | Fluxos de integração no emulador (APIs 29 e 36, pelos `scripts/`), conferência das telas e testes manuais com o responsável no celular, migrações na produção com o ensaio (`setup.md`, 9.2), *merge* e fechamento (seção 11) | Fatia concluída na `main` e na matriz de rastreabilidade |

**Em toda sessão:**
- **Começo:** `git fetch` e comparação com o remoto (o responsável usa mais de uma máquina), leitura da linha "Estado atual" do `CLAUDE.md` e do `tasks.md` da fatia.
- **Durante:** um comando pesado por vez com o emulador aberto (`setup.md`, 3.1).
- **Fim:** o que foi feito e a próxima sessão ficam registrados no `tasks.md` e na linha "Estado atual" do `CLAUDE.md`, e o trabalho fica no remoto (PR ou *branch* enviado).

- Fatias grandes (4 e 5) seguem as etapas A, B e C do plano, cada uma como uma especificação própria, e cada uma com as suas sessões 2 a 4.
- Na fatia 1, `/speckit-constitution` roda uma vez e aponta para o `CLAUDE.md` e para `docs/`, sem duplicar regras (`.specify/memory/constitution.md`). O Spec Kit foi testado antes num repositório descartável (`plano-implementacao.md`, fatia 1) e instalado com `specify init --here --force --non-interactive --integration claude`, que cria `.specify/` e as skills `.claude/skills/speckit-*`.
- O `/speckit-specify` propõe um *branch* numérico (`001-nome`). Ele não é usado: o *branch* segue a seção 6.1, e a pasta `specs/<nnn>-<nome>/` fica como está.

## 4. Template de tarefa

Todo pedido de implementação ao agente, e toda tarefa do `tasks.md`, tem estes campos:

```markdown
## <Fatia N, etapa X> — <nome curto>

**Contexto:** uma ou duas frases sobre onde a tarefa se encaixa.
**Regras:** RF.., RN.. (só os números; o texto está em docs/).
**Contratos:** funções de contratos-api.md que a tarefa cria ou usa.
**Arquivos esperados:** migrações, funções, telas, testes.
**Testes esperados:** cenários (IDs de testes-referencia.md, quando houver) e o tipo de cada um (pgTAP, Deno, unitário, widget).
**Pronto quando:** o comportamento verificável, com os comandos que provam.
**Fora de escopo:** o que fica para outra tarefa ou fatia.
```

## 5. Definição de pronto

Checklist do PR. O revisor confere cada item, e o agente marca no texto do PR.

**Testes**
- [ ] Os testes da tarefa foram escritos antes do código. **Evidência:** o *commit* dos testes vem antes do *commit* da implementação, e o PR traz a saída da falha.
- [ ] Os resultados esperados vêm dos documentos. Nenhum valor de `testes-referencia.md` foi alterado.
- [ ] Todo bug corrigido tem um teste que o reproduz.

**Comandos verdes** (os mesmos do CI)
- [ ] `dart format --output=none --set-exit-if-changed .` e `dart analyze` (em `app/`)
- [ ] `flutter test` (em `app/`)
- [ ] `supabase db reset` e `supabase test db`
- [ ] `supabase db lint`
- [ ] `deno fmt --check`, `deno lint` e `deno test` (em `supabase/functions/`)

**Segurança**
- [ ] Nenhuma tabela sem RLS (o teste da fatia 1 cobre).
- [ ] Toda política nova ou alterada tem teste, inclusive o caso negativo ("quem **não** pode").
- [ ] Nenhum segredo no código, no Git ou no app.

**Produto**
- [ ] O fluxo de "Pronto quando" da fatia foi conferido no emulador. O agente descreve os passos no PR, e o responsável confere.
- [ ] As telas novas passam na lista de acessibilidade (`design-system.md`, seção 8).
- [ ] Nenhuma string de interface solta e nenhuma cor fora do tema.
- [ ] Os documentos afetados foram atualizados no mesmo PR.

## 6. Git, PR e pipeline

### 6.1 Branches e commits

- `main` é a linha principal. O fluxo normal é por *branch* e PR, para o CI rodar antes de a mudança chegar à `main`. O agente pode fazer *push* em `main` quando for preciso, mas nunca `push --force`.
- Um *branch* por tarefa: `fatia-<n>/<assunto>` (por exemplo, `fatia-4/join-game`). Documentação da fatia: `fatia-<n>/docs`.
- *Commits* pequenos, em pt-BR, no imperativo e com o assunto em uma linha ("Cria a função join_game"). *Commits* do agente levam a linha `Co-Authored-By` indicada pela ferramenta.
- O agente faz *commit*, abre PR e faz o *merge*, sempre com o CI verde. Antes de começar, o agente roda `git fetch` e compara com o remoto: o responsável trabalha em mais de uma máquina.

### 6.2 Descrição do PR

```markdown
**Fatia / etapa:** N / X
**Regras:** RF.., RN..
**O que muda:** ...
**Testes escritos antes:** <commit> — saída da falha: ...
**Como conferir no emulador:** passos
**Documentos atualizados:** ...
**Fora de escopo:** ...
<checklist da seção 5>
```

### 6.3 Pipeline (GitHub Actions)

| Gatilho | O que roda |
|---------|------------|
| *Pull request* | Os comandos da seção 5, com o Supabase local subido dentro do CI |
| *Merge* em `main` | Nada no Supabase. A página de convite (`web/`) é publicada pelo Cloudflare Pages (fatia 8) |
| **Deploy** (disparo manual, `workflow_dispatch`) | Migrações (`supabase db push`), Edge Functions e o build assinado do app, na produção |

- **A aprovação manual é o próprio disparo.** O workflow de deploy só roda quando o responsável o dispara no GitHub, informando a versão e confirmando, num campo do formulário, que o ensaio da migração foi feito (`setup.md`, seção 9.2). Esse formato funciona em qualquer plano do GitHub.
- **O workflow de deploy ainda não existe.** Por decisão de 11/11/2026, ele entra numa fatia próxima do lançamento: o CI de *pull request* já existe desde a fatia 1, e as migrações da produção são aplicadas à mão, pelo agente ou pelo responsável, com o ensaio e os comandos da seção 9.2 do `setup.md`.
- Num repositório privado do plano grátis, o GitHub não bloqueia o *merge* com o CI vermelho. A regra "só com CI verde" vale pela conferência de quem faz o *merge*: o agente confere `gh pr checks` antes.

## 7. O que o agente nunca faz

- Aplicar migração na produção sem o ensaio de `setup.md`, seção 9.2, ou mudar o schema da produção fora de uma migração versionada no repositório (nem pelo MCP do Supabase).
- Guardar cópia da produção (`supabase db dump`) no repositório ou em nuvem. Ela tem dados pessoais e fica só em `~/voleiin-dumps` (`setup.md`, 9.2).
- Fazer *merge* com o CI vermelho, ou `push --force`.
- Editar uma migração já aplicada na produção (`arquitetura-app.md`, 14.1).
- Alterar um resultado esperado de `testes-referencia.md`, ou um teste já aprovado, para o código passar.
- Criar tabela sem RLS, ou mudar política sem teste.
- Apagar dados, arquivos ou *branches* que não criou na tarefa.
- Instalar pacote, skill ou plugin fora das listas de `stacks.md` e `arquitetura-app.md` sem perguntar.
- Implementar fora do escopo da fatia atual.

## 8. Guardrails

**Sem bloqueio técnico.** Por decisão do responsável (09/11/2026), o projeto não tem `.claude/settings.json` com proibições: o agente trabalha com autonomia durante o desenvolvimento. As regras da seção 7 e do "Nunca faça" do `CLAUDE.md` continuam valendo como regras escritas, e o agente as segue sem precisar de bloqueio.

**MCP do Supabase.** O único projeto remoto é a produção. O agente pode usar todas as ferramentas, inclusive as de escrita (decisão de 13/11/2026). Mudança de schema continua só por migração versionada no repositório, aplicada com `supabase db push` depois do ensaio: o `apply_migration` do MCP criaria uma migração que o repositório não tem.

**Comandos de produção** (`supabase db push`, `link`, `secrets`, `config push`, `functions deploy`, `db dump`) e o *merge* podem ser executados pelo agente (decisão de 13/11/2026). O que pede senha ou login interativo (a senha do banco no `supabase link`, o `supabase login`) o responsável roda com `! <comando>`. Depois de cada mudança na produção, o agente confere com `get_advisors` e registra o que fez no documento afetado.

## 9. Quando parar e perguntar

O agente para, explica e pergunta (CLAUDE.md, "Antes de implementar") quando:

- dois documentos divergem, ou uma regra é ambígua ou ausente;
- um teste de referência parece contradizer a regra;
- a tarefa exige mudar um contrato (assinatura, erro, permissão) do `contratos-api.md`;
- a tarefa exige tabela, coluna, enum, função ou pacote que nenhum documento prevê;
- a tarefa exige algo fora do escopo da fatia;
- um comando falha por motivo que não é do código (ambiente, rede, ferramenta), depois de uma tentativa de diagnóstico.

A pergunta traz o trecho de cada documento envolvido, o cenário concreto e uma recomendação.

## 10. Documento × código

- **O documento prevalece** até ser atualizado. Se o código diverge do documento, o código está errado.
- Se o documento estiver errado, a correção é decidida pelo responsável e entra num PR de documentação, antes ou junto do código que depende dela.
- Decisão técnica tomada na implementação, que não muda regra mas pode ser contestada depois, ganha um ADR em `docs/adr/`.

## 11. Fechar uma fatia

1. Todos os itens de "Pronto quando" da fatia conferidos.
2. Matriz de rastreabilidade atualizada (`plan-docs.md`, seção 5.4): RFs da fatia com teste e marcados como concluídos.
3. Linha "Estado atual" do `CLAUDE.md` atualizada.
4. Documentos e ADRs afetados atualizados.
5. Seed acrescido dos cenários da fatia (`setup.md`, seção 8).
