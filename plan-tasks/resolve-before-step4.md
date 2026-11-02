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
| R1 | Dinheiro, remarcação e acesso ao jogo | feita (2026-11-01) |
| R2 | Fila de espera e cancelamento | feita (2026-11-01) |
| R3 | Ciclo do jogo, falta, retenção e idempotência | feita (2026-11-01) |
| R4 | Plano do `stack.md` | feita (2026-11-01) |
| R5 | Pequenos desencontros | feita (2026-11-01) |
| R6 | Aplicar nos documentos e fechar | feita (2026-11-01) |

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

### Respostas da R1 — 2026-11-01

- **Q1.1 Remarcação:** campo novo anulável `jogo.cancelamento_livre_ate`, gravado por `editar_jogo` ao mudar data, horário, local ou quadra (= novo `inicio`); vale o maior entre ele e o prazo normal. **Além disso, a multa anterior é cancelada:** as cobranças `cancelamento_tardio` existentes no momento da remarcação passam a `cancelada`, porque a vaga deixada era a do horário antigo.
- **Q1.2 Recebedor joga:** sim, confirma e ocupa vaga, mas não gera cobrança (`check devedor_id <> credor_id`). Na troca de recebedor, a cobrança do novo recebedor que já é participante passa a `cancelada`; o antigo recebedor, se confirmado, ganha cobrança. Ex.: R$ 100 / 10 vagas com o recebedor jogando → 9 cobranças de R$ 10, R$ 90 a receber.
- **Q1.3 Convidado:** `aplicar_convite` de jogo cria a participação (confirmada ou em espera) pela mesma função interna de `confirmar_presenca`; `confirmar_presenca` só aceita membro do grupo, criador, recebedor ou quem já tem participação.
- **Q1.4 Criação** (resposta "Outra", texto do usuário): *"Qualquer membro (recomendado) mas o criador já é considerada confirmado"*. Qualquer membro cria no grupo; jogo avulso, qualquer pessoa; o criador nasce `confirmado`.
  - Desdobramento: o criador cancela a própria presença como qualquer um (RN02/RN03; sem cobrança se for o recebedor) e segue criador.
  - Desdobramento: na duplicação (RN28), quem duplica também nasce `confirmado`; a RN28 ganha a ressalva de que só a participação do criador nasce.

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

### Respostas da R2 — 2026-11-01

- **Q2.1 Isenção:** isenta a multa do cancelante tardio mais antigo ainda `pendente`; cada confirmação nova isenta uma multa, na ordem do cancelamento.
- **Q2.2 Vaga livre:** a vaga é de quem confirmar primeiro, da fila ou não; qualquer confirmação que ocupe a vaga isenta a multa — a RN05 troca "alguém da lista de espera" por "alguém".
- **Q2.3 Sair da fila:** quem sai de `lista_espera` vira `cancelou_no_prazo`, sem cobrança e sem multa em qualquer momento; as posições seguintes são renumeradas (só exibição).
- **Q2.4 Cancelar no prazo:** a cobrança passa a `cancelada`; reconfirmando, a mesma cobrança volta a `pendente` de origem `parte` com o valor atual — a RN25 passa a valer também para `cancelou_no_prazo`.

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

### Respostas da R3 — 2026-11-01

- **Q3.1 Encerrar à mão:** a partir do fim do horário reservado (`inicio + duracao_minutos`), pelo criador e pelos admins do grupo; no avulso, só o criador. A RN13 vence e a RN17 é corrigida.
- **Q3.2 Falta:** só com o jogo `encerrado`, até `encerramento_previsto + 24 h`.
- **Q3.3 Retenção:** o mês conta de `cobranca.atualizado_em`. Comprovante só existe após o encerramento e, daí em diante, nada altera cobrança inativa, exceto marcar falta numa cobrança já paga dentro das 24 h, o que atrasa o descarte em até um dia. Documentar no modelo e testar no passo 4.
- **Q3.4 Idempotência:** por estado (unicidades + checagem de status); documentar o limite: toque repetido não duplica, e o reenvio atrasado de `confirmar` após cancelamento vale como reconfirmação.

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

### Respostas da R4 — 2026-11-01

- **Q4.1 Avisos:** já no passo 4 — as funções inserem em `notificacao` na mesma transação, e os cenários conferem; o passo 7 acrescenta só gatilho, Edge Function, FCM, `registrar_dispositivo` e o sino. Ajustar o texto do passo 7.
- **Q4.2 Encerramento:** função interna única em `privado` (status, liberação do pagamento, aviso), chamada por `encerrar_jogo` no passo 4 e pela rotina de minuto no passo 8; os cenários simulam o tempo movendo `inicio` por SQL.
- **Q4.3a Conta:** `excluir_conta` no passo 4, em migração própria `rpc_conta` depois de `rpc_cobranca`; as telas H1, H2 e H4 entram no passo 5.
- **Q4.3b Busca de locais (RF28):** no app, passo 5 — filtra pelo nome e ordena pela distância da localização do aparelho; sem função SQL.
- **Q4.3c Feed e painéis:** leitura direta com política de linha; uma visão `security_invoker`, criada no passo 5, devolve a marca `vencida` calculada com a hora do servidor. Sem RPC.
- **Q4.3d Migrações:** `cancelar_jogo`, `encerrar_jogo` e a função interna de encerramento em `rpc_jogo`; `marcar_falta` em `rpc_presenca`.
- **Q4.4 Trava da RN15:** lock consultivo por local (`pg_advisory_xact_lock` com o `local_id`) em `criar_jogo`, `duplicar_jogo` e `editar_jogo`, antes de checar; cobre quadra e capacidade.

## R5 — Pequenos desencontros

Pergunta única de confirmação em bloco (multiSelect), cada item com a correção proposta:
- `README.md` só com título → escrever descrição curta.
- `plan-tasks/plan-tasks-10/README.md` diz "cinco migrações" → seis; e remover a pasta em commit próprio.
- Primeiro cadastro de local no remoto exige `pessoa` sem `auth.users` → documentar o procedimento em `supabase/CLAUDE.md`.
- `privado.encerramento_previsto` declarada `immutable` → trocar para `stable` e `tocar_atualizado_em` sem `search_path` fixo → migração `ajustes_funcoes` (só se o usuário aprovar; é código, não documento).

### Respostas da R5 — 2026-11-01

- `README.md`: escrever descrição curta (o que é, as três peças, onde estão os documentos).
- `plan-tasks/plan-tasks-10/`: já removida no commit `081e743`; item sem efeito.
- Locais no remoto: documentar em `supabase/CLAUDE.md` que o desenvolvedor cria a própria conta pelo app e usa o próprio id em `local.criado_por`, inserindo pelo editor SQL do painel; nenhuma pessoa sem conta no remoto.
- Migração `ajustes_funcoes` (`encerramento_previsto` para `stable`, `search_path` fixo em `tocar_atualizado_em`): aprovada como primeira tarefa do passo 4, fora do commit de documentação.

### Decisões tomadas durante a R6 — 2026-11-01

- A reconfirmação do próprio cancelante tardio converte a multa dele em parte e **não** isenta a multa de outro cancelante.
- Texto da B4: "Se outra pessoa confirmar presença depois de você, sua cobrança pode ser isenta." (registrado em `docs/design/telas/02-jogos/implementacao.md`).
- Aberto para o passo 5: o que a B3 mostra em "Sua parte" para o recebedor confirmado.

### Pendências achadas na conferência final — 2026-11-01

- O passo 4 do `stack.md` não listava as mudanças de schema decididas: entra a migração `ajustes_schema` (coluna `jogo.cancelamento_livre_ate`, `check` de `devedor_id <> credor_id`), logo depois de `ajustes_funcoes`.
- Avisos das transições novas (respondido em rodada curta): a isenção automática da RN05 avisa o isento com `cobranca_isenta`; a remarcação manda `jogo_editado` também a quem teve a multa cancelada; a troca de recebedor não avisa na hora (o `pagamento_liberado` do encerramento já chega com o credor novo).

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
