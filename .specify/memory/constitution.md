# Constituição do VoleiIn

Esta constituição não repete regras. Ela aponta para onde cada regra vive, e o Spec Kit a lê no começo de cada `/speckit-specify`, `/speckit-plan` e `/speckit-tasks`.

## Princípios

### I. Os documentos são a fonte da verdade
`docs/` define o que o app faz (`requisitos.md`), como as regras funcionam (`regras-negocio.md`), o banco (`modelo-dados.md`), as funções do servidor (`contratos-api.md`) e os resultados esperados (`testes-referencia.md`). O `spec.md` de cada fatia **cita** RFs, RNs e seções, e nunca copia o texto. Se o código diverge do documento, o código está errado. Se dois documentos divergem, a tarefa para e pergunta (`CLAUDE.md`, "Antes de implementar").

### II. Uma fatia por vez
O escopo vem de `docs/plano-implementacao.md`. O que a fatia marca como "fora de escopo" não entra, mesmo que pareça pequeno.

### III. Testes antes do código
Os testes da tarefa são escritos primeiro, falham pelo motivo certo e só então vem a implementação (`docs/trabalho-com-agente.md`, seção 3). Um resultado esperado de `testes-referencia.md` nunca muda para o teste passar.

### IV. O servidor decide
Rateio, multa, status e prazos são calculados no servidor, com o relógio do servidor. O app exibe. Dinheiro é `integer` em centavos. Toda tabela tem RLS, e toda política tem teste (`CLAUDE.md`, "Nunca faça").

### V. Produção é do responsável
O agente não aplica migração, não roda SQL, não publica função nem mexe em segredos na produção, e não faz *merge*. Ele entrega o comando pronto (`docs/trabalho-com-agente.md`, seções 7 e 8).

## Convenções

Linguagens, stack, pastas, nomes e padrões do app estão em `CLAUDE.md` ("Stack", "Convenções", "Glossário"), `docs/stacks.md`, `docs/arquitetura-app.md`, `docs/ui/design-system.md` e `docs/copy.md`.

## Fluxo de trabalho

Ciclo da fatia, template de tarefa, definição de pronto, Git, PR e pipeline: `docs/trabalho-com-agente.md`. Os *branches* seguem `fatia-<n>/<assunto>`; o *branch* numérico que o Spec Kit propõe não é usado.

## Governança

Esta constituição muda só quando `CLAUDE.md` ou `docs/trabalho-com-agente.md` mudam, e nunca cria regra que eles não tenham. Decisões de arquitetura ficam em `docs/adr/` e não são reabertas.

**Versão**: 1.0.0 | **Ratificada**: 2026-11-12 | **Última alteração**: 2026-11-12
