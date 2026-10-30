# Plano — Resolver antes do passo 4

> Rodadas de perguntas interativas guiadas por este plano. Origem: análise de 2026-10-29.

## Context

A análise de 2026-10-29 (passo 3 fechado, suítes verdes, `dart analyze` limpo, migrações local = remoto) achou 8 decisões de produto abertas, 5 lacunas de plano em `docs/stack.md` e alguns desencontros de documentação. Pelo `CLAUDE.md`, lacuna de regra é decisão de produto: **documento fecha antes de código**, e o passo 4 não começa com decisão pendente. Este plano registra a análise e a transforma em **rodadas de perguntas interativas na CLI** (`AskUserQuestion`, até 4 perguntas por rodada, 2–4 opções, a recomendada primeiro). Cada resposta vira texto normativo nos documentos, num commit só de documentação. Nenhum código, migração ou painel é tocado.

Regras para a execução:
- Uma rodada por vez; a seguinte só abre com a anterior registrada no estado abaixo.
- Cada pergunta traz o trecho do PRD que a origina (RN/RF) e a consequência de cada opção.
- Resposta "Outra" do usuário vale como decisão; registre o texto dele, não uma paráfrase.
- Não inventar campo, enum ou entidade fora do que o usuário aprovar na rodada.
- O PRD vence em divergência; `modelo-de-dados.md` e `stack.md` são ajustados para acompanhá-lo.

## Estado

| Rodada | Tema | Estado |
| --- | --- | --- |
| R1 | Dinheiro, remarcação e acesso ao jogo | a fazer |
| R2 | Fila de espera e cancelamento | a fazer |
| R3 | Ciclo do jogo, falta, retenção e idempotência | a fazer |
| R4 | Plano do `stack.md` | a fazer |
| R5 | Pequenos desencontros | a fazer |
| R6 | Aplicar nos documentos e fechar | a fazer |

## T0 — Preparação

1. Copiar este plano para `plan-tasks/resolve-before-step4.md` (seguindo o modelo de task de `plan-tasks/plan-tasks-10/README.md`).
2. Reler `docs/prd.md` (RN01–RN30, RN13 tabela), `docs/modelo-de-dados.md` (invariantes) e `docs/stack.md` (funções previstas, ordem) antes de formular cada rodada.

## R1 — Dinheiro, remarcação e acesso ao jogo

**Q1.1 Reabertura sem multa na remarcação (RN20 × "prazo não é armazenado").** A RN20 manda reabrir o cancelamento sem multa até o início quando data/horário/local/quadra mudam; o modelo calcula o prazo só de `inicio − prazo_cancelamento_horas`.
- (Recomendada) Campo novo anulável em `jogo` (ex.: `cancelamento_livre_ate`), gravado por `editar_jogo` na remarcação; vale o maior entre ele e o prazo normal. Quem já estava em `cancelou_fora_do_prazo` mantém a cobrança e pode reconfirmar (RN25).
- Sem campo: a remarcação apenas recalcula o prazo a partir do novo `inicio` (fórmula atual); a RN20 é reescrita para dizer isso.
- Remarcar zera a multa de quem cancelou tarde (cobranças `cancelamento_tardio` viram `cancelada`).

**Q1.2 O recebedor joga? (RN16, RN20, C2).** `devedor_id = credor_id` não é impedido pelo schema.
- (Recomendada) O recebedor pode confirmar presença e ocupa vaga, mas **não gera cobrança** (função não cria; `check devedor <> credor`). Troca de recebedor para quem já é participante cancela a cobrança dessa pessoa.
- O recebedor não pode ser participante.
- Gera cobrança normal e ele se isenta/baixa à mão.

**Q1.3 Como o convidado de jogo (RN22) entra, dado `pode_ver_jogo` (RN13, passo 9 × passo 4).**
- (Recomendada) `aplicar_convite` de jogo cria a participação (confirmada ou em espera) via a mesma função interna de `confirmar_presenca`; `confirmar_presenca` só aceita membro do grupo ou quem já tem participação/convite aplicado.
- `confirmar_presenca` recebe o token do convite como parâmetro opcional.
- Convite concede um vínculo novo (entidade nova) — só se o usuário pedir.

**Q1.4 Criação de jogo (RN13, RF07/RF08).** Quem cria no grupo, auto-confirmação do criador, recebedor restrito a membros?
- (Recomendada) Qualquer membro cria; o criador não entra confirmado sozinho (confirma como os demais); recebedor pode ser qualquer pessoa que o criador vê e que tenha chave (RN24).
- Só admins criam jogo.
- Criador entra confirmado automaticamente.

## R2 — Fila de espera e cancelamento

**Q2.1 Substituição com vários cancelantes tardios (RN05).** Qual cobrança é isentada quando uma pessoa da espera confirma?
- (Recomendada) A do cancelante tardio mais antigo ainda `pendente`, uma isenção por substituto.
- A do mais recente.
- Todas as de cancelamento tardio, até o número de vagas ocupadas.

**Q2.2 Vaga livre e fila (RN08).** Um recém-chegado pode pegar vaga livre antes de quem espera?
- (Recomendada) Sim: a vaga é de quem confirmar primeiro, da fila ou não (coerente com "anunciada a todos").
- Não: com fila não vazia, quem chega entra na fila.

**Q2.3 Saída da lista de espera e `posicao_espera`.** Status ao cancelar estando em `lista_espera` e renumeração.
- (Recomendada) Vira `cancelou_no_prazo`, sem cobrança; as posições seguintes são recalculadas (ordem de entrada, só exibição).
- Mantém buracos nas posições.

**Q2.4 Cobrança no cancelamento no prazo e RN25.**
- (Recomendada) Cancelar no prazo leva a cobrança a `cancelada`; reconfirmar depois reabre a mesma cobrança como `pendente`/`parte` com o valor atual (estende a RN25 a `cancelou_no_prazo`).
- Apagar a cobrança ao cancelar no prazo (exige exceção à unicidade/histórico — desaconselhada).

## R3 — Ciclo do jogo, falta, retenção e idempotência

**Q3.1 Encerrar à mão (RN17, RN13, RF33).** "A partir desse fim" e quem pode.
- (Recomendada) A partir do fim do horário reservado (`inicio + duração`), por criador **e admins do grupo** (RN13 vence, RN17 é corrigida).
- A partir do encerramento previsto (+1 h), só o criador.

**Q3.2 Quando marcar falta (RN04, B7).**
- (Recomendada) Só com o jogo `encerrado`, até `encerramento_previsto + 24 h`.
- A partir do início do jogo.

**Q3.3 Âncora da retenção do comprovante (RN19, RNF03).** Falta carimbo de "deixou de estar ativa".
- (Recomendada) Contar de `cobranca.atualizado_em`, com a regra de que nenhuma função toca cobrança inativa (documentar no modelo e testar no passo 4).
- Campo novo anulável em `cobranca` (ex.: `inativada_em`), preenchido em toda saída de ativa.

**Q3.4 Idempotência (RNF10).**
- (Recomendada) Idempotência por estado (unicidades + checagem de status); documentar o limite: toque repetido não duplica, e o reenvio atrasado de `confirmar` após cancelamento é uma reconfirmação válida.
- Chave de requisição enviada pelo app (campo/tabela novos).

## R4 — Plano do `stack.md`

**Q4.1 Avisos no passo 4.**
- (Recomendada) As funções do passo 4 já inserem em `notificacao` (são `security definer`); o passo 7 acrescenta só gatilho, Edge Function e FCM. Ajustar o texto do passo 7.
- Passo 4 não avisa; avisos entram todos no passo 7.

**Q4.2 Encerramento automático antes do passo 8.**
- (Recomendada) Função interna única em `privado` (encerrar, liberar pagamento, avisar), chamada por `encerrar_jogo` no passo 4 e pela rotina no passo 8.
- Cenários do passo 4 simulam o tempo mudando `inicio` por SQL.

**Q4.3 Funções e telas sem passo.** (multiSelect do que entra no passo 4 vs depois)
- `excluir_conta` (RF36) — sugerido: passo 4, migração `rpc_conta`, ou junto de `rpc_cobranca` porque depende de cobrança pendente.
- Busca de locais por proximidade (RF28) — função SQL; sugerido: passo 5.
- Feed e painéis: declarar como consulta direta/visão no passo 5.
- Migração de `marcar_falta`, `encerrar_jogo`, `cancelar_jogo`: `rpc_jogo` / `rpc_cobranca`.

**Q4.4 Concorrência da RN15.**
- (Recomendada) Lock consultivo por quadra/local dentro de `criar_jogo`/`editar_jogo`, além da trava do jogo (RNF09).
- Restrição de exclusão (`btree_gist`) na quadra; capacidade continua por lock.

## R5 — Pequenos desencontros

Pergunta única de confirmação em bloco (multiSelect), cada item com a correção proposta:
- `README.md` só com título → escrever descrição curta.
- `plan-tasks/plan-tasks-10/README.md` diz "cinco migrações" → seis; e remover a pasta em commit próprio.
- Primeiro cadastro de local no remoto exige `pessoa` sem `auth.users` → documentar o procedimento em `supabase/CLAUDE.md`.
- `privado.encerramento_previsto` declarada `immutable` → trocar para `stable` e `tocar_atualizado_em` sem `search_path` fixo → migração `ajustes_funcoes` (só se o usuário aprovar; é código, não documento).

## R6 — Aplicar e fechar

1. Editar na ordem: `docs/prd.md` (regras RN05, RN08, RN13, RN17, RN19, RN20, RN24/RN25 conforme as respostas) → `docs/modelo-de-dados.md` (campos/invariantes novos, se houver) → `docs/stack.md` (passos, funções, concorrência, avisos) → `docs/progresso.md` (seção "Decisões de produto antes do passo 4" com data e motivo).
2. Se alguma resposta criar campo, registrar também em `docs/design/telas/<grupo>/implementacao.md` quando afetar tela (ex.: B4, C4).
3. Conferir consistência cruzada: `grep` das RNs alteradas nos três documentos; contagens (RF/RN) intactas.
4. Commit só de documentação, em português, com a atribuição exigida. Migração/código eventual (R5) fica para task do passo 4, não deste commit.
5. Marcar este plano como feito e liberar o passo 4.

## Arquivos críticos

- `docs/prd.md`, `docs/modelo-de-dados.md`, `docs/stack.md`, `docs/progresso.md`
- `plan-tasks/resolve-before-step4.md` (este plano)
- `supabase/CLAUDE.md` (procedimento do local no remoto), `README.md`

## Verificação

- Cada rodada termina com um resumo das respostas, mostrado ao usuário antes de gravar.
- Depois de R6: `git diff --stat` mostra só `.md`; `grep -n "RN05\|RN08\|RN17\|RN19\|RN20" docs/*.md` não mostra texto contraditório entre os três documentos.
- Nenhuma suíte precisa rodar (sem código); se R5 aprovar migração, vale `supabase db reset` e as três suítes SQL no passo 4.
