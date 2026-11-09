# Trabalho com o Agente

> Decisões de 09/11/2026. Base: `CLAUDE.md`, `plano-implementacao.md`, `plan-docs.md` (seções 3.2, 5.3 e 8.4) e `setup.md`.
> Como o agente (Claude Code ou similar) trabalha neste projeto. O objetivo é que, olhando um PR, dê para dizer se a regra de pronto foi cumprida.

## 1. Papéis

| Quem | Faz | Não faz |
|------|-----|---------|
| **Responsável** (dono do produto e único desenvolvedor) | Decide regras e escopo, aprova documentos, revisa e faz o *merge* dos PRs, confere os fluxos no emulador, mexe na produção e nos segredos | — |
| **Agente** | Escreve documentos da fatia quando pedido, especifica com o Spec Kit, escreve testes e código, abre PRs | Decide regra, faz *merge*, mexe na produção ou em segredos (seção 7) |

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
| 2. Documentar | Telas (`docs/ui/telas.md`), textos (`docs/copy.md`), RLS (`docs/rls-matriz.md`) e os cenários de teste da fatia, só o que ela usa | PR só de documentação, aprovado pelo responsável |
| 3. Especificar | `/speckit-specify`, `/speckit-plan` e `/speckit-tasks`. O `spec.md` **cita** os RFs, RNs e seções dos documentos, sem copiar o texto | `specs/<nnn>-<nome>/` |
| 4. Testes primeiro | Os testes da tarefa são escritos e rodados, e **falham** pelo motivo certo: a função ainda não existe ou não faz o esperado | *Commit* só de testes |
| 5. Implementar | `/speckit-implement`, tarefa por tarefa, até os testes passarem | *Commits* de implementação |
| 6. Convergir | `/speckit-converge` e a definição de pronto (seção 5) | PR pronto para revisão |
| 7. Fechar a fatia | Seção 9 | Fatia marcada como concluída |

- Fatias grandes (4 e 5) seguem as etapas A, B e C do plano, cada uma como uma especificação própria.
- Na fatia 1, `/speckit-constitution` roda uma vez e aponta para o `CLAUDE.md` e para `docs/`, sem duplicar regras. O Spec Kit é testado antes num repositório descartável (`plano-implementacao.md`, fatia 1).

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
- [ ] O fluxo de "Pronto quando" da fatia foi conferido no emulador. O agente roda os testes de integração nos emuladores (e no celular do responsável, quando conectado), põe a saída e os passos no PR, e o responsável confere.
- [ ] As telas novas passam na lista de acessibilidade (`design-system.md`, seção 8).
- [ ] Nenhuma string de interface solta e nenhuma cor fora do tema.
- [ ] Os documentos afetados foram atualizados no mesmo PR.

## 6. Git, PR e pipeline

### 6.1 Branches e commits

- `main` é a linha principal. O agente nunca faz *commit* nem *push* direto em `main`.
- Um *branch* por tarefa: `fatia-<n>/<assunto>` (por exemplo, `fatia-4/join-game`). Documentação da fatia: `fatia-<n>/docs`.
- *Commits* pequenos, em pt-BR, no imperativo e com o assunto em uma linha ("Cria a função join_game"). *Commits* do agente levam a linha `Co-Authored-By` indicada pela ferramenta.
- O agente faz *commit* e abre PR quando pedido. O *merge* é sempre do responsável, com o CI verde.

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
- Num repositório privado do plano grátis, o GitHub não bloqueia o *merge* com o CI vermelho. A regra "só com CI verde" vale pela revisão do responsável.

## 7. O que o agente nunca faz

- Aplicar migração, rodar SQL, publicar Edge Function, alterar configuração ou mexer em segredos na **produção**, inclusive pelo MCP do Supabase.
- Baixar dados da produção (`supabase db dump`). A cópia tem dados pessoais e é feita só pelo responsável.
- Fazer *merge*, *push* em `main` ou `push --force`.
- Editar uma migração já aplicada na produção (`arquitetura-app.md`, 14.1).
- Alterar um resultado esperado de `testes-referencia.md`, ou um teste já aprovado, para o código passar.
- Criar tabela sem RLS, ou mudar política sem teste.
- Apagar dados, arquivos ou *branches* que não criou na tarefa.
- Instalar pacote, skill ou plugin fora das listas de `stacks.md` e `arquitetura-app.md` sem perguntar.
- Implementar fora do escopo da fatia atual.

## 8. Guardrails

**Sem bloqueio técnico.** Por decisão do responsável (09/11/2026), o projeto não tem `.claude/settings.json` com proibições: o agente trabalha com autonomia durante o desenvolvimento. As regras da seção 7 e do "Nunca faça" do `CLAUDE.md` continuam valendo como regras escritas, e o agente as segue sem precisar de bloqueio.

**MCP do Supabase.** O único projeto remoto é a produção. O agente usa o MCP **só para leitura**: `list_tables`, `list_migrations`, `get_advisors`, `query_logs`, `search_docs` e `generate_typescript_types`. As ferramentas de escrita alcançam a produção e não são usadas.

**Comandos de produção** (`supabase db push`, `link`, `secrets`, `config push`, `functions deploy`, `db dump`) e o *merge* são executados pelo responsável, no terminal ou pelo pipeline. O agente entrega o comando pronto e explica o que ele faz.

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
