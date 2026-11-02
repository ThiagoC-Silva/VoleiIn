# T01 — Documentação de abertura

**Estado:** feito · **Depende de:** —

## Objetivo

Gravar nos documentos as sete decisões tomadas ao planejar o passo (ver [README](README.md), Contexto) e fechar os textos dos avisos, para que nenhuma task seguinte precise inventar regra ou texto. Só documentação; nenhum código.

## O que já existe

- `docs/prd.md`, `docs/modelo-de-dados.md` e `docs/stack.md` com as decisões de 2026-11-01 (`1c14ba1`, `c569258`).
- O G1 (`docs/design/telas/08-avisos/G1-avisos.png`) mostra o texto de 5 tipos de aviso:
  - `vaga_liberada` — "Abriu uma vaga em Areia de Sábado" / "sáb, 24 out · 20:00. Fica com quem confirmar primeiro."
  - `comprovante_recebido` — "Diego enviou um comprovante" / "R$ 21,43 · Vôlei de Quinta, qui 15 out"
  - `valor_recalculado` — "Vôlei de Quinta mudou o custo" / "Total R$ 300,00. Sua parte passou para R$ 21,43."
  - `cobranca_vencida` — "Cobrança vencida" / "R$ 20,00 para Ana Souza · Areia de Sábado"
  - `pagamento_liberado` — "Pagamento liberado" / "R$ 20,00 para Ana Souza. Vence dom, 18 out · 23:00."
- `supabase/CLAUDE.md` lista a sequência antiga de migrações, sem `ajustes_funcoes`, `ajustes_schema`, `rpc_conta` e `visoes`.

## O que falta

- [x] `docs/prd.md`:
  - RN02: cancelar presença só até o início do jogo; depois dele, a ausência é falta (RN04);
  - RN20: data, horário, local e quadra editáveis até o início;
  - RN13, tabela de papéis: "Promover membro a admin | Qualquer admin do grupo";
  - RN30: o admin único — quem criou o grupo ou não — só sai depois de promover outro admin; o último membro sai livre;
  - RN27: recusa também enquanto o titular for recebedor de jogo `aberto`; na exclusão ele sai de todos os grupos, e a participação em lista de espera vira `cancelou_no_prazo`;
  - RN11: o aviso vai só quando o prazo muda, aos confirmados de jogos abertos que seguem o prazo do grupo;
  - Decisões tomadas: linhas para cancelamento após o início, promoção por qualquer admin e admin único.
- [x] `docs/modelo-de-dados.md`, invariantes: cancelar e remarcar só antes do início; grupo com mais de um membro tem ao menos um admin; exclusão recusada com recebedor de jogo aberto.
- [x] Criar `docs/design/telas/08-avisos/implementacao.md`, no formato de `01-acesso/implementacao.md`, com uma linha por tipo de `notificacao_tipo` (14): título, corpo, destinatários e a função que grava.
  - Os 5 do G1 como estão.
  - Propor os 9 que faltam no mesmo tom: `jogo_editado` (remarcação, inclusive a quem teve a multa cancelada), `jogo_cancelado` (proposta de destinatários: confirmados e lista de espera), `regra_grupo_alterada`, `cobranca_confirmada`, `cobranca_isenta` (manual e automática da RN05), `falta_marcada`, `removido_do_grupo`, `promovido_a_admin`, `comprovante_recusado` (este usado só no passo 6).
  - Como o jogo aparece nos textos: o nome do grupo, como no G1; no avulso, proposta: o nome do local ("Arena Beira-Mar").
  - **Mostrar os textos ao usuário e só seguir com a aprovação dele.**
- [x] Atualizar em `DESIGN.md` (Precedência) a lista de `implementacao.md` existentes.
- [x] Abrir `docs/design/telas/04-grupos/D3-membros.png` e conferir o menu "promover": se a imagem limitar a quem criou o grupo, registrar em `04-grupos/implementacao.md` que vale para qualquer admin.
- [x] `supabase/CLAUDE.md`, seção Migrações: a sequência de `docs/stack.md` (com `ajustes_funcoes`, `ajustes_schema`, `rpc_conta`, `visoes`).
- [x] `grep` das RNs alteradas (RN02, RN11, RN13, RN20, RN27, RN30) nos três documentos sem texto contraditório; contagem de RN (30) e RF intacta.

## Pronto quando

- `git diff --stat` só mostra `.md`.
- O usuário aprovou os textos dos avisos.
- Nenhuma das sete decisões do README depende mais deste plano para ser encontrada: estão no PRD, no modelo ou no `implementacao.md` dos avisos.

## Commit

`Documenta as decisões de abertura do passo 4 e os textos dos avisos` — só documentação.
