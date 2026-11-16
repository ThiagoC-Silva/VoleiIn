# Casos de Teste de Referência

> Decisões de 06/11/2026. Base: `regras-negocio.md`, `modelo-dados.md` e `contratos-api.md`.
> Os resultados esperados vêm das regras, nunca do código. Se um teste falhar, a primeira hipótese é erro no código. Só se muda um valor daqui com uma mudança na regra correspondente.
> Revisados pelo responsável do produto em 06/11/2026: I04, I09, I10, V02, V04, V05 e V06.

## 1. Escopo e execução

Esta é a versão da Fase 0, com os cenários de maior risco. Antes de cada fatia, eles viram testes executáveis, e todos devem falhar antes da implementação (`plan-docs.md`, seção 8.4).

| Seção | Tema | Fatia | Onde roda |
|-------|------|-------|-----------|
| 3 | Limites de tempo | 4 e 5 | pgTAP, `supabase/tests/` |
| 4 | Rateio | 5 | pgTAP |
| 5 | Isenção automática (RN62) | 5 | pgTAP |
| 6 | Faltas e multas | 5 | pgTAP |
| 7 | Troca de recebedor (RN31) | 5 | pgTAP |
| 8 | Concorrência | 4, 5 e 6 | Deno test com conexões separadas |
| 9 | Fundação: segurança da base, estrutura, *triggers*, formatação, erros e login | 1 | pgTAP, `flutter_test` e `integration_test` |
| 10 | Conta e perfil: RLS da conta, chave Pix e RN105, fotos (RN106), validações, telas e fluxos | 2 | pgTAP, Deno test, `flutter_test` e `integration_test` |
| 11 | Grupos: funções, RLS e contexto (RN107), fotos do grupo, prévia do convite, concorrência, telas e fluxos | 3 | pgTAP, Deno test, `flutter_test` e `integration_test` |
| 12 | Jogo e lista: criar, editar, cancelar, admins, lista, espera e status, saída do grupo com jogos, RLS e visibilidade (RN102), concorrência, telas e fluxos | 4 | pgTAP, Deno test, `flutter_test` e `integration_test` |

**Ficam para o ciclo de cada fatia:** a máquina de estados do jogo (RN40 a RN43 na seção 12; RN44 e RN45 na fatia 5) e do valor a pagar (RN80 a RN94), a exclusão de conta (RN103), o RLS de cada tabela e os comprovantes.

**Como controlar o tempo nos testes:** dentro de uma transação, `now()` não muda. Para testar um instante exato, o teste insere o jogo direto na tabela, com `starts_at = now()`, por exemplo, e chama a função na mesma transação. Para simular uma ordem de cancelamentos ou uma mudança de limite, grava `left_at` e `effective_from` direto.

**Como testar concorrência:** um teste pgTAP roda em uma única conexão e por isso não reproduz uma disputa real. Os cenários da seção 8 usam conexões separadas, disparadas ao mesmo tempo, e repetem cada cenário 50 vezes.

## 2. Base dos cenários

Salvo indicação em contrário:
- **Horários** do mesmo dia: prazo às 18h, início às 20h, fim às 22h.
- **Recebedora:** Ana, com chave Pix, que fica na lista e conta como um dos participantes.
- **Valores** em centavos e, onde ajuda, em reais.
- **"Por conta"** é o valor por conta do recebedor (RN74). **"Sobra"** é parte × limite − total (RN75).

## 3. Limites de tempo (RN02, RN03, RN57)

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| T01 | `cancellation_deadline = now()` | Participante sai | `cancelled`, `late_cancellation = false`, `outcome = cancelled_on_time` |
| T02 | `cancellation_deadline` 1 µs antes de `now()`, início no futuro | Participante sai | `cancelled`, `late_cancellation = true`, `outcome = cancelled_late` |
| T03 | `starts_at` 1 µs depois de `now()`, com vaga | Usuário entra na lista | Entra |
| T04 | `starts_at = now()`, com vaga | Usuário entra na lista | `GAME_STARTED` |
| T05 | `starts_at = now()`, jogo cheio | Usuário entra na espera | `GAME_STARTED` |
| T06 | `starts_at` 1 µs depois de `now()` | Participante sai | `cancelled`, libera a vaga |
| T07 | `starts_at = now()` | Participante sai | `left_after_start`, com falta, não libera a vaga |
| T08 | `cancellation_deadline = starts_at = now()` | Participante sai | `left_after_start`. O início prevalece, porque o cancelamento exige instante < início |
| T09 | `ends_at` 1 µs depois de `now()`, jogo iniciado | Participante sai | `left_after_start` |
| T10 | `ends_at = now()` | Participante sai | `LIST_LOCKED` |
| T11 | `ends_at` 1 µs depois de `now()` | Admin conclui | `GAME_NOT_ENDED` |
| T12 | `ends_at = now()` | Admin conclui | Conclui, `completion_mode = manual` |
| T13 | `ends_at + 1h` 1 µs depois de `now()` | Roda `auto_complete_due_games` | O jogo não muda |
| T14 | `ends_at + 1h = now()` | Roda `auto_complete_due_games` | Conclui, `completion_mode = automatic` |
| T15 | Jogo já concluído manualmente | Roda `auto_complete_due_games` | Nada muda: nenhum valor novo |
| T16 | Prazo mudou de 18h para 19h depois de um cancelamento às 18h30, classificado como fora do prazo | Conclusão | O cancelamento continua fora do prazo (RN35) |

## 4. Rateio (RN71 a RN75)

Os participantes incluem Ana. Ninguém faltou, salvo indicação.

| ID | Cenário | Total | Limite | Participantes | Parte | Valores criados | Soma | Por conta | Sobra |
|----|---------|-------|--------|---------------|-------|-----------------|------|-----------|-------|
| R01 | Exemplo do `regras-negocio.md`, com 2 multas mantidas | 25.000 | 12 | 10 | 2.084 | 11 | 22.924 | 2.076 | 8 |
| R02 | Divide exato | 24.000 | 12 | 12 | 2.000 | 11 | 22.000 | 2.000 | 0 |
| R03 | Limite 1 | 10.000 | 1 | 1 | 10.000 | 0 | 0 | 10.000 | 0 |
| R04 | Total pequeno | 1 | 10 | 10 | 1 | 9 | 9 | **−8** | 9 |
| R05 | Arredonda para cima | 10.000 | 3 | 3 | 3.334 | 2 | 6.668 | 3.332 | 2 |
| R06 | Vagas não cobertas (6) | 25.000 | 12 | 6 | 2.084 | 5 | 10.420 | 14.580 | 8 |
| R07 | Total editado de 25.000 para 30.000 na conclusão | 30.000 | 12 | 12 | 2.500 | 11 | 27.500 | 2.500 | 0 |
| R08 | R01 com uma multa isentada depois da conclusão | 25.000 | 12 | 10 | 2.084 | 11 (10 ativos) | 22.924 (20.840 ativos) | 4.160 | 8 |
| R09 | Maior total em `integer` | 2.147.483.647 | 12 | 12 | 178.956.971 | 11 | 1.968.526.681 | 178.956.966 | 5 |
| R10 | Sobra mínima | 1.000 | 7 | 7 | 143 | 6 | 858 | 142 | 1 |

**Notas:**
- **R01** deve dar exatamente **R$ 20,84** por vaga, **R$ 229,24** a receber e **R$ 20,76** por conta de Ana, como no exemplo do `regras-negocio.md`.
- **R03:** nenhum valor é criado, e o jogo nasce Confirmado (RN40).
- **R04:** o por conta é negativo porque a sobra (9) passa da vaga da recebedora (1). O contrato devolve o número com sinal. A forma de exibir fica no catálogo de textos.
- **R06:** `uncovered_slots = 6`, e o valor aparece no aviso ao admin antes de concluir (RF41, RN48).
- **R07:** as multas usam a parte final, 2.500 (RN64).
- **R09:** o cálculo intermediário `total + limite − 1` estoura o tipo `integer`, então precisa rodar em `bigint`.
- **Em todos:** o cálculo usa só inteiros (RN04), todos os valores começam Pendentes e são devidos a Ana (RN73), e Ana não tem valor a pagar (RF71).
- **`preview_complete_game`:** para qualquer cenário acima, devolve os mesmos números de `complete_game`, sem gravar nada.

## 5. Isenção automática (RN62)

Todos com limite 10, total R$ 100,00 (parte 1.000) e cancelamentos fora do prazo, salvo indicação. `L` é o menor limite vigente entre o prazo e o início.

| ID | Dado | `L` | Ociosas | Mantidas | Pagam multa | Isentos |
|----|------|-----|---------|----------|-------------|---------|
| I01 | Exemplo do `regras-negocio.md`: Ana (18h10), Bruno (18h30) e Davi (19h20) cancelam. Carla entra às 19h. 8 no início | 10 | 2 | 2 | Bruno, Davi | Ana |
| I02 | Lista cheia no início: 10 participantes. Ana, Bruno e Davi cancelaram | 10 | 0 | 0 | Ninguém | Ana, Bruno, Davi |
| I03 | 5 no início. Ana e Bruno cancelaram | 10 | 5 | 2 | Ana, Bruno | Ninguém |
| I04 | Limite subiu de 10 para 12 às 19h. 10 no início. Ana e Bruno cancelaram antes | 10 | 0 | 0 | Ninguém | Ana, Bruno |
| I05 | Limite caiu de 10 para 8 às 19h. 8 no início. Ana e Bruno cancelaram antes | 8 | 0 | 0 | Ninguém | Ana, Bruno |
| I06 | Limite caiu de 12 para 10 às 17h, antes do prazo. 9 no início. Ana cancelou | 10 | 1 | 1 | Ana | Ninguém |
| I07 | Limite foi de 10 para 8 e voltou a 10, tudo depois do prazo. 8 no início. Ana cancelou | 8 | 0 | 0 | Ninguém | Ana |
| I08 | Ana cancela às 18h10. Bruno cancela às 18h30 e volta às 19h (anulado, RN56). 9 no início | 10 | 1 | 1 | Ana | Ninguém |
| I09 | Ana cancela às 19h. Bruno cancela às 18h30, volta às 18h50 e cancela de novo às 19h30. 9 no início | 10 | 1 | 1 | Bruno | Ana |
| I10 | 9 ativos e 1 que saiu após o início (a saída não libera a vaga). Ana cancelou | 10 | 0 | 0 | Ninguém | Ana |
| I11 | Davi é removido por um admin às 19h. 9 no início. Ana cancelou | 10 | 1 | 1 | Ana | Ninguém |
| I12 | Cancelamento só dentro do prazo. 9 no início | 10 | 1 | 0 | Ninguém | Ninguém |

**Notas:**
- Nos cenários I01 a I12, "Ana" é quem cancela e a recebedora é outra pessoa, porque a recebedora não pode cancelar (RN29).
- **I04:** a isenção usa `L = 10`, mas a parte usa o limite final, 12 (RN71). Com total de R$ 120,00, a parte é 1.000, há 9 valores (9.000) e 3.000 ficam por conta da recebedora, incluindo as 2 vagas não cobertas.
- **I05:** com total de R$ 100,00 e limite 8, a parte é 1.250, há 7 valores (8.750) e 1.250 ficam por conta da recebedora.
- **I08 e I09:** só a passagem mais recente conta. Na I09, o instante de Bruno é 19h30.
- **I11:** Davi não recebe multa nem entra na conta dos cancelamentos (RN58). O mesmo vale para quem sai do grupo (RN14) e para quem exclui a conta (RN104).
- **Empate:** se dois cancelamentos tiverem o mesmo `left_at`, o desempate é pelo `id` da linha, para que o resultado seja sempre o mesmo.
- **Efeitos:** quem tem multa mantida recebe um valor `late_cancellation_penalty` igual à parte. Quem é isento fica com `late_cancellation_exempt = true`, sem valor a pagar, e recebe `penalty_waived`.

## 6. Faltas e multas (RN47, RN49, RN63 a RN66)

Limite 10, total R$ 100,00 (parte 1.000), lista cheia, recebedora Ana.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| F01 | Edu sai às 20h30 | Admin conclui com Edu em `p_absent_user_ids` | Edu fica com `absence_penalty` de 1.000. Os outros 8 ficam com `share` de 1.000 |
| F02 | Edu sai às 20h30 | Admin conclui sem Edu na lista | A falta é desmarcada. Edu fica com `share` de 1.000 (RN47) |
| F03 | Edu sai às 20h30 | Conclusão automática | Edu mantém a falta, com `absence_penalty` (RN49) |
| F04 | Ninguém saiu | Conclusão automática | Ninguém fica com falta. O total não muda. 9 valores `share` |
| F05 | Carla está na lista | Admin conclui com Carla em `p_absent_user_ids` | `absence_penalty` para Carla, com `absence_source = marked_by_admin` |
| F06 | Ana está na lista | Admin conclui com Ana em `p_absent_user_ids` | `RECEIVER_CANNOT_BE_ABSENT`. Nada é gravado |
| F07 | Ana é a recebedora, jogo iniciado | Ana sai da lista | `RECEIVER_LOCKED` (RN29) |
| F08 | Zeca não está na lista | Admin conclui com Zeca em `p_absent_user_ids` | `ABSENT_NOT_PARTICIPANT`. Nada é gravado |
| F09 | Edu tem multa Pendente | Admin isenta | `waived`, `manual_waiver`. Sai dos totais |
| F10 | Carla tem `share` Pendente | Admin tenta isentar | `NOT_A_PENALTY` |
| F11 | Edu tem multa Paga | Admin tenta isentar | `CHARGE_NOT_PENDING` |
| F12 | Bruno, admin, cancela às 19h | Bruno chama `remove_participant` sobre si mesmo | `CANNOT_REMOVE_SELF` (RN58) |
| F13 | Bruno cancela às 19h, com vaga ociosa no início | Conclusão | Multa mantida, como a de qualquer participante |
| F14 | Davi é removido por outro admin às 19h | Conclusão | Davi não tem multa nem valor (RF59) |

## 7. Troca de recebedor após a conclusão (RN31)

**Base:** jogo concluído, total R$ 100,00, limite 5 (parte 2.000), recebedora Ana.

| Pessoa | Valor | Status | Devido a |
|--------|-------|--------|----------|
| Bruno | `share` | Pago | Ana |
| Carla | `share` | Pendente | Ana |
| Davi | `share` | Pendente | Ana |
| Edu | `absence_penalty` | Pendente | Ana |

Todos têm chave Pix.

| ID | Troca | Resultado | Pendente a receber | Pago |
|----|-------|-----------|--------------------|------|
| V01 | Ana → Carla, com o valor de Davi Em análise | `RECEIVER_CHANGE_BLOCKED`. Nada muda | — | — |
| V02 | Ana → Carla | Carla: Isento. Davi e Edu: devidos a Carla. Ana: novo `share` Pendente a Carla. Bruno: sem mudança | Carla: 6.000 | Ana: 2.000 |
| V03 | Ana → Bruno | Bruno continua Pago a Ana. Carla, Davi e Edu: devidos a Bruno. Ana: novo `share` Pendente a Bruno | Bruno: 8.000 | Ana: 2.000 |
| V04 | Ana → Bruno → Ana | O valor de Ana vira Isento. Carla, Davi e Edu voltam a Ana. **Bruno não ganha novo valor**, porque já tem um Pago | Ana: 6.000 | Ana: 2.000 |
| V05 | Ana → Carla → Davi | Davi: Isento. Ana e Edu: devidos a Davi. Carla, com valor Isento, ganha novo `share` Pendente a Davi | Davi: 6.000 | Ana: 2.000 |
| V06 | Ana → Edu, com Edu na lista | A multa de Edu vira Isento. Carla e Davi: devidos a Edu. Ana: novo `share` Pendente a Edu | Edu: 6.000 | Ana: 2.000 |
| V07 | Ana → Edu, que saiu após o início | `RECEIVER_MUST_BE_PARTICIPANT` | — | — |
| V08 | Ana → Zeca, fora da lista | `RECEIVER_MUST_BE_PARTICIPANT` | — | — |
| V09 | Ana → Carla, sem chave Pix | `RECEIVER_NEEDS_PIX_KEY` | — | — |
| V10 | Ana → Ana | `RECEIVER_UNCHANGED` | — | — |
| V11 | Em jogo cancelado | `GAME_CANCELLED` | — | — |

**Em todos os cenários com troca:**
- nenhum valor fica com pagador igual ao recebedor;
- há no máximo um valor não Isento por pessoa no jogo;
- `share_cents` e `total_cents` do jogo não mudam (RN36);
- `receiver_changes`, `charge_events` e `audit_log` registram a troca, e as notificações seguem a RN115.

**Antes da conclusão (RN30):** Ana → Carla só troca o recebedor, sem criar valores. Na conclusão, os valores são devidos a Carla, e Ana paga a própria parte como qualquer participante.

## 8. Concorrência

Cada cenário dispara as chamadas ao mesmo tempo, em conexões separadas, e repete 50 vezes. O resultado vale em todas as repetições.

| ID | Fatia | Dado | Quando | Então |
|----|-------|------|--------|-------|
| C01 | 4 | Limite 10, 9 ocupadas | 2 usuários entram | Um entra, o outro recebe `GAME_FULL`. 10 ocupadas, status Confirmado |
| C02 | 4 | Limite 10, 7 ocupadas | 20 usuários entram | Exatamente 3 entram, 17 recebem `GAME_FULL`. 10 ocupadas |
| C03 | 4 | Lista cheia, 5 na espera | O admin aumenta o limite em 1, e os 5 entram | Um entra e sai da espera. Os outros 4 recebem `GAME_FULL` e continuam na espera (RN53, RN54) |
| C04 | 4 | Limite 10, 5 ocupadas | O mesmo usuário entra 2 vezes | Uma passagem criada. A outra chamada recebe `ALREADY_PARTICIPANT` |
| C05 | 4 | Limite 10, 9 ocupadas | Um usuário entra, e o admin reduz o limite para 9 | Ou a entrada vence (10 ocupadas, redução recebe `SLOT_LIMIT_BELOW_PARTICIPANTS`), ou a redução vence (9 ocupadas, entrada recebe `GAME_FULL`). Nunca ocupadas > limite |
| C06 | 4 | Lista cheia | Um participante sai, e outro usuário entra | Ocupadas nunca passam do limite. O status final corresponde às vagas |
| C07 | 4 | Jogo Aberto | Um usuário entra, e o admin cancela o jogo | Se a entrada vier depois, recebe `GAME_NOT_OPEN`. O jogo termina Cancelado |
| C08 | 5 | Jogo a partir de `ends_at + 1h` | Admin conclui, e `auto_complete_due_games` roda | Uma única conclusão, com valores criados uma vez. A outra chamada recebe `GAME_NOT_OPEN` ou ignora o jogo |
| C09 | 5 | Valor de Carla Pendente | Admin isenta, e o recebedor marca como pago | Só uma transição vale. A outra recebe `CHARGE_NOT_PENDING` |
| C10 | 6 | 2 valores Pendentes e 2 comprovantes com o mesmo ID de transação | `process-receipt` nos dois | Um é gravado. O outro fica `rejected` com `duplicate_transaction` (RN89) |
| C11 | 6 | Um valor Pendente | `process-receipt` 2 vezes, com a API simulada | Só um comprovante decide o valor. O segundo recebe `CHARGE_NOT_PENDING` se o valor já tiver mudado |
| C12 | 6 | Valor Pendente e troca de recebedor em curso | `change_receiver` e `process-receipt` | A comparação do destinatário usa o recebedor gravado no valor no momento do bloqueio (RN32). Nenhuma das duas perde dados |

## 9. Fundação (fatia 1)

Decisões de 09/11/2026. Nenhuma tabela está liberada ao app nesta fatia (`rls-matriz.md`, seção 3). Por isso, os testes de banco conferem o catálogo do Postgres e chamam as *triggers* direto, como `postgres`.

### 9.1 Segurança da base

pgTAP, em `supabase/tests/database/base_security.test.sql`. B03, B04 e B06 comparam com uma lista esperada, que cada fatia acrescenta no mesmo PR em que concede o acesso (`rls-matriz.md`, seção 5).

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| B01 | Banco após `supabase db reset` | Lista as tabelas de `public` (tipos `r` e `p` em `pg_class`) com RLS desligado | Lista vazia. É o teste "tabela sem RLS" do CI |
| B02 | Idem | Lista as tabelas de `public` | Exatamente as 20 da seção 4 do `modelo-dados.md` |
| B03 | Idem | Lista as políticas de `public` (`pg_policies`) | Igual à lista esperada. Na fatia 1, vazia |
| B04 | Idem | Lista os privilégios de tabela e de coluna de `anon` e `authenticated` em `public` | Igual à lista esperada. Na fatia 1, vazia |
| B05 | Como `postgres`, o teste cria uma tabela e uma função novas em `public` | Consulta os privilégios delas | A **tabela** nasce sem privilégio algum para `anon`, `authenticated` e `public`. A **função** nasce com o `execute` que o Postgres dá a `public`, que nenhuma configuração remove (`rls-matriz.md`, seção 1): o teste registra esse comportamento e falha se ele mudar. Quem cobra o fechamento de cada função é o B06 |
| B06 | Banco após reset | Lista as funções de `public`, fora as de extensões, que `anon` ou `authenticated` podem executar | Igual à lista esperada. Na fatia 1, vazia. É o teste que cobra o `revoke execute ... from public, anon` de toda função nova (B05) |
| B07 | Idem | Consulta `usage` de `anon` e `authenticated` no esquema `private` e `execute` em `private.emit_notification` | Falso em todos |
| B08 | Usuário autenticado (`role authenticated` com o `sub` de um usuário de teste) | `insert` em `groups` e em `notifications` | Erro `42501` nos dois. Até a fatia 1, o primeiro era um `select` em `profiles`, que a fatia 2 libera para a própria linha (seção 10.1); até a fatia 2, um `select` em `groups`, que a fatia 3 libera aos membros (seção 11) |
| B09 | Banco após reset | Lê `storage.buckets` | `avatars` e `receipts` existem, com `public = false` e os tamanhos e tipos da `rls-matriz.md` (seção 3) |
| B10 | Usuário autenticado | `insert` em `storage.objects`, bucket `receipts`, caminho `<uuid>/x.png` | Recusado pelo RLS. As políticas de `storage.objects` são exatamente as da lista esperada: nenhuma na fatia 1; as três de `avatars` da fatia 2 (`rls-matriz.md`). Até a fatia 1, o caminho testado era `avatars/profiles/<uid>/x.png`, que a fatia 2 libera ao próprio usuário |

### 9.2 Estrutura e *triggers*

pgTAP, em `supabase/tests/database/base_schema.test.sql` e `base_triggers.test.sql`. Os testes das invariantes de admin usam `set constraints all immediate` para disparar na hora a checagem adiada para o fim da transação.

**Tipos (RN01, RN02, RN04)**

| ID | Regra | Quando | Então |
|----|-------|--------|-------|
| B11 | RN04 | Lista as colunas de `public` do tipo `real`, `double precision`, `numeric` ou `money` | Lista vazia |
| B12 | RN04 | Lista as colunas de `public` terminadas em `_cents` | Todas `integer` |
| B13 | RN01 | Lista as colunas de `public` do tipo `timestamp without time zone`, `time` ou `timetz` | Lista vazia |
| B14 | RN02 | Lista as colunas `created_at` de `public` | Todas `not null`, com padrão `now()` |

**Perfil.** O perfil e o `profile_private` nascem juntos quando o e-mail fica confirmado: na confirmação do código (cadastro por e-mail, ADR 0017) ou no próprio cadastro (Google, que já chega confirmado). O nome vem de `name` e, sem ele, de `full_name` nos metadados. Sem nenhum dos dois, vem do início do e-mail (`modelo-dados.md`, `profiles`).

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| B15 | Insert em `auth.users` com `email_confirmed_at` nulo e metadados `{"name": "Carla Souza"}` | — | Nenhuma linha em `profiles` nem em `profile_private` |
| B16 | O usuário de B15 | `email_confirmed_at` passa a `now()` | `profiles` com `name = 'Carla Souza'`, `nickname` nulo e `display_name = 'Carla Souza'`. `profile_private` com `phone_visible = false` e o resto nulo |
| B17 | Insert com `email_confirmed_at = now()` e metadados `{"full_name": "Carla Souza"}`, sem `name` | — | Perfil com `name = 'Carla Souza'`, criado no próprio insert |
| B18 | Metadados `{"name": "Carla", "full_name": "Carla Souza"}` | Confirmação | `name = 'Carla'` |
| B19 | Metadados `{"name": "  Carla Souza  "}` | Confirmação | `name = 'Carla Souza'` |
| B20 | `name` com 100 caracteres | Confirmação | Os 80 primeiros caracteres, sem espaço nas pontas |
| B21 | Sem `name` nem `full_name`, ou os dois só com espaços. E-mail `carla.souza@gmail.com` | Confirmação | `name = 'carla.souza'` |
| B22 | Usuário confirmado, com perfil | `email_confirmed_at` muda de novo | O perfil não muda, e não há erro |
| B23 | Insert não confirmado com e-mail `carla@voleiin.test` e `{"name": "Bruno"}` (Bruno digitou o e-mail da Carla) | Na mesma atualização, os metadados viram `{"name": "Carla Souza"}` e `email_confirmed_at` é preenchido (o que o Supabase faz quando a Carla entra pelo Google) | Perfil com `name = 'Carla Souza'`. Nunca existiu perfil "Bruno" |

**`updated_at` e histórico do limite**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| B24 | Tabelas de `public` com coluna `updated_at` | Lista as que não têm a *trigger* de `updated_at` | Lista vazia |
| B25 | Linha de `groups` com `updated_at` gravado 1 dia antes | `update` do nome | `updated_at = now()` |
| B26 | — | Insert de jogo com limite 10 | Uma linha em `game_limit_history`: limite 10, `effective_from = now()` |
| B27 | Jogo com limite 10 | `update` do limite para 12 | Uma segunda linha, com 12 |
| B28 | Jogo com limite 10 | `update` do local, ou do limite para o mesmo 10 | Nenhuma linha nova |

**Invariantes de admin (RN13, RN25).** As *triggers* são a rede de segurança. As funções das fatias 3 e 4 validam antes e devolvem o mesmo código.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| B29 | Grupo ativo com um admin, Ana | Apaga a linha de Ana em `group_members` | `LAST_ADMIN` |
| B30 | Idem | Muda o papel de Ana para `member` | `LAST_ADMIN` |
| B31 | Grupo ativo com Ana admin e Bruno membro | Na mesma transação, promove Bruno e rebaixa Ana | Aceito |
| B32 | — | Insert de um grupo ativo sem membros | `LAST_ADMIN` |
| B33 | Grupo ativo com Ana admin | Na mesma transação, grava `archived_at`, deixa `invite_code` nulo e apaga todos os membros | Aceito |
| B34 | — | Insert de um jogo sem admin | `LAST_GAME_ADMIN` |
| B35 | Jogo com um admin | Apaga a linha dele em `game_admins` | `LAST_GAME_ADMIN` |
| B36 | Jogo com dois admins | Apaga um | Aceito |

**`emit_notification`**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| B37 | Usuário com perfil | Como `postgres`, `private.emit_notification('game_confirmed', <uid>, '{"game_id": "<id>"}')` | Uma linha em `notifications` com o tipo, o usuário e o `data` informados. Texto provisório até a fatia 7: `title` é o tipo (`game_confirmed`) e `body` fica vazio. `read_at` e `push_sent_at` nulos. A função devolve o `id` da linha |

### 9.3 Formatação (RN01, RN04)

Testes unitários em `app/test/core/format/`. Nos valores em dinheiro, o espaço depois de `R$` é o espaço sem quebra (U+00A0, `docs/copy.md`, seção 3).

| ID | Entrada | Função | Resultado |
|----|---------|--------|-----------|
| D01 | 2084 | `formatCents` | `R$ 20,84` |
| D02 | 22924 | `formatCents` | `R$ 229,24` |
| D03 | 123456 | `formatCents` | `R$ 1.234,56` |
| D04 | 0 | `formatCents` | `R$ 0,00` |
| D05 | 5 | `formatCents` | `R$ 0,05` |
| D06 | 100 | `formatCents` | `R$ 1,00` |
| D07 | 100000000 | `formatCents` | `R$ 1.000.000,00` |
| D08 | 2147483647 (maior `integer`, cenário R09) | `formatCents` | `R$ 21.474.836,47` |
| D09 | `2026-11-09T23:00:00Z` | `formatDate` e `formatTime` | `09/11/2026` e `20:00` |
| D10 | `2026-11-10T02:30:00Z` | `formatDate` e `formatTime` | `09/11/2026` e `23:30`: ainda é dia 9 em Fortaleza |
| D11 | `2026-11-10T03:00:00Z` | `formatDate` e `formatTime` | `10/11/2026` e `00:00` |
| D12 | `2026-10-22T23:00:00Z` | `formatShortDate` | `qui, 22/10` |
| D13 | `2026-10-25T02:59:00Z` | `formatShortDate` | `sáb, 24/10` (23h59 em Fortaleza) |
| D14 | Data 09/11/2026 e hora 20:00 escolhidas na tela | Conversão para envio | `2026-11-09T23:00:00.000Z` |
| D15 | D09 a D14, com o processo de teste no fuso `Asia/Tokyo` (variável `TZ`) | As mesmas funções | Os mesmos resultados: o fuso do aparelho não entra na conta |

O formato de valor negativo fica para a fatia 5 (cenário R04).

### 9.4 Erros e login

**Conversão de erros**, testes unitários em `app/test/core/errors/` (`arquitetura-app.md`, seção 7):

| ID | Exceção recebida | `ErrorCode` |
|----|------------------|-------------|
| E01 | `PostgrestException` com `code = 'P0001'` e `message = 'NOT_FOUND'` | `notFound` |
| E02 | `PostgrestException` com `code = 'P0001'` e um código que o app não conhece | `internalError` |
| E03 | `PostgrestException` com `code = '42501'` | `internalError` |
| E04 | `FunctionException` 401 com `{"error": {"code": "NOT_AUTHENTICATED"}}` | `notAuthenticated` |
| E05 | `AuthException` com `code = 'invalid_credentials'` | `authInvalidCredentials` |
| E06 | `AuthException` com um código que o app não mapeia (`unexpected_failure`). Até a fatia 1, o exemplo era `weak_password`, que a fatia 2 mapeia (seção 10.4) | `internalError` |
| E07 | `SocketException`, `ClientException` e `TimeoutException` | `noConnection` |
| E08 | Cada valor de `ErrorCode` | O texto vem do `app_pt.arb` e não é vazio |

**Login e navegação**, testes de widget com o repositório trocado por um dublê e testes de integração no emulador contra o Supabase local com o seed (`docs/ui/telas.md`, seção 4):

| ID | Tipo | Dado | Quando | Então |
|----|------|------|--------|-------|
| L01 | Widget | Login com os campos vazios | Toca em Entrar | Erros `authEmailRequired` e `authPasswordRequired` nos campos. O repositório não é chamado |
| L02 | Widget | O repositório responde `authInvalidCredentials` | Toca em Entrar | `SnackBar` com `errorAuthInvalidCredentials`. Os campos mantêm o que foi digitado |
| L03 | Widget | O repositório responde `noConnection` | Toca em Entrar | `SnackBar` com `errorNoConnection` |
| L04 | Widget | Fonte do sistema em 150% | Abre o login e cada aba | Nenhum *overflow* |
| L05 | Widget | Usuário logado | Abre o app | Barra com Jogos, Grupos, Cobranças e Perfil, nesta ordem, na aba Jogos. Trocar de aba não empilha telas |
| L06 | Integração, API 29 e 36 | Sem sessão | Abre o app, entra com `ana@voleiin.test` e `voleiin123`, fecha e reabre | Vai do login para a aba Jogos e, ao reabrir, continua logado na aba Jogos |
| L07 | Integração, API 29 e 36 | Ana logada | Toca em Sair, na aba Perfil, e depois no voltar do Android | Volta ao login, e o voltar não retorna às abas |

## 10. Conta e perfil (fatia 2)

Decisões de 12/11/2026. Base: `rls-matriz.md` (fatia 2), `modelo-dados.md` (4.1), `docs/ui/telas.md` (seção 5) e `docs/copy.md` (seção 6). Personagens do seed: Ana (`...00a`) e Bruno (`...00b`), criados pelo próprio teste quando faltarem (`arquitetura-app.md`, 14.4). "Ana logada" é `role authenticated` com o `sub` da Ana.

Os resultados de B03, B04, B06 e B10 passam a ser as listas da fatia 2 da `rls-matriz.md`.

### 10.1 RLS da conta

pgTAP, em `supabase/tests/database/account_security.test.sql`.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| P01 | Ana logada. Ana e Bruno têm perfil | `select` em `profiles` | Só a linha da Ana |
| P02 | Ana logada, sem apelido | `update` do próprio `nickname` para `'Aninha'` e depois para nulo | O `display_name` vira `'Aninha'` e depois volta ao `name` (RN100) |
| P03 | Ana logada | `update` do `name` do Bruno | Nenhuma linha alterada. O perfil do Bruno não muda |
| P04 | Ana logada | `update` do próprio `deleted_at`, e depois do próprio `id` | `42501` nos dois |
| P05 | Ana logada | `update` do próprio `photo_path` para `profiles/<bruno>/x.png`; para `profiles/<ana>/x.png`; para nulo | O primeiro é recusado pelo RLS (`42501`). Os outros dois são aceitos |
| P06 | Ana logada, com `deleted_at` preenchido | `update` do próprio `name` | Nenhuma linha alterada |
| P07 | Ana logada | `insert` em `profiles` e em `profile_private` | `42501` nos dois |
| P08 | Ana logada | `select` em `profile_private`; `update` do próprio `phone` para `'+5586999991234'`; `update` do `phone` do Bruno | Só a linha da Ana; o próprio `update` é aceito; o do Bruno não altera nenhuma linha |
| P09 | Ana logada | `update` do próprio `user_id` em `profile_private` | `42501` |
| P10 | Ana logada | `select * from current_terms_versions()` | Duas linhas: `terms_of_use` e `privacy_policy`, ambas `'1.0'` |
| P11 | Ana logada, sem aceite | `insert` em `terms_acceptances` de `(ana, 'terms_of_use', '1.0')`; e outro com `accepted_at` informado | O primeiro é aceito, com `accepted_at = now()`. O segundo dá `42501` |
| P12 | Ana logada | `insert` com a versão `'0.9'`; e com o `user_id` do Bruno e a versão `'1.0'` | `42501` nos dois |
| P13 | Ana e Bruno com aceites | Ana logada lê `terms_acceptances` | Só as linhas da Ana |
| P14 | `role anon` | `select` nas três tabelas e `current_terms_versions()` | `42501` em todos |
| P15 | Ana logada | `insert` em `storage.objects`, bucket `avatars`, em `profiles/<ana>/<uuid>.png`, em `profiles/<bruno>/<uuid>.png` e em `groups/<uuid>/<uuid>.png` | Só o primeiro é aceito |
| P16 | Um arquivo da Ana e um do Bruno em `avatars` | Ana logada faz `select`, `update` e `delete` em `storage.objects` | O `select` vê só o arquivo da Ana. O `update` não altera nenhuma linha. O `delete` apaga o da Ana e não altera o do Bruno |

### 10.2 Chave Pix e RN105

pgTAP, em `supabase/tests/database/account_pix.test.sql`. Os formatos rodam como `postgres`, direto em `profile_private`. A RN105 roda como Ana logada, para provar que a *trigger* vale também para a escrita do app.

**Formato** (`modelo-dados.md`, 4.1). "Recusado" é a violação de constraint (`23514`).

| ID | Tipo | Chave | Então |
|----|------|-------|-------|
| X01 | `cpf` | `52998224725` | Aceito |
| X02 | `cpf` | `52998224724` (último dígito trocado) | Recusado |
| X03 | `cpf` | `11111111111` (passa na conta, mas é sequência repetida) | Recusado |
| X04 | `cnpj` | `11222333000181` | Aceito |
| X05 | `cnpj` | `11222333000180` | Recusado |
| X06 | `cnpj` | `00000000000000` | Recusado |
| X11 | `cnpj` | `12ABC34501DE35` (alfanumérico, exemplo da Receita Federal) | Aceito |
| X12 | `cnpj` | `12ABC34501DE36` (último dígito trocado) | Recusado |
| X13 | `cnpj` | `12abc34501de35` (letras minúsculas) | Recusado: a chave é gravada em maiúsculas |
| X14 | `cnpj` | `12ABC34501DEA5` (letra no dígito verificador) | Recusado |
| X07 | `email` | `Ana@Exemplo.com`; `ana@exemplo.com` | Recusado; aceito |
| X08 | `phone` | `+5586999991234`; `86999991234` | Aceito; recusado |
| X09 | `random` | `123e4567-e89b-12d3-a456-426614174000`; a mesma em maiúsculas | Aceito; recusado |
| X10 | `cpf` | nulo | Recusado (`profile_private_pix_pair`) |

**Remoção da chave (RN105).** Ana tem chave Pix. "Remover" é `update` de `pix_key_type` e `pix_key` para nulo.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| N01 | Ana é recebedora de um jogo `open` | Remove a chave | `PIX_KEY_IN_USE`. A chave continua |
| N02 | Ana é recebedora de um jogo `confirmed` | Remove a chave | `PIX_KEY_IN_USE` |
| N03 | Ana é recebedora só de jogos `cancelled` e `completed`, sem valor a receber | Remove a chave | Aceito |
| N04 | Ana é o `receiver_id` de um valor `pending` | Remove a chave | `PIX_KEY_IN_USE` |
| N05 | Ana é o `receiver_id` de um valor `under_review` | Remove a chave | `PIX_KEY_IN_USE` |
| N06 | Ana é o `receiver_id` só de valores `paid` e `waived` | Remove a chave | Aceito |
| N07 | Como N01 | Troca a chave por outra válida, de outro tipo | Aceito: a troca é livre |
| N08 | Bruno é participante, não recebedor, de um jogo `open` | Bruno remove a própria chave | Aceito |
| N09 | Como N01 | Ana troca só o telefone, sem mexer na chave | Aceito: a *trigger* só olha a remoção da chave |

### 10.3 Fotos (RN106)

Deno test, em `supabase/functions/_tests/avatars_test.ts`, contra a API do Storage local, com a Ana e o Bruno logados por e-mail e senha. Roda no job do CI que sobe o Supabase. O Storage confere o tipo declarado no envio e o tamanho: o app garante o tipo real ao redimensionar.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| A01 | Ana logada | Envia um PNG de 100 KB para `profiles/<ana>/<uuid>.png` | Aceito |
| A02 | Ana logada | Envia um JPEG de 2.097.153 bytes (2 MB mais 1 byte) | Recusado pelo tamanho |
| A03 | Ana logada | Envia um JPEG de exatamente 2.097.152 bytes | Aceito |
| A04 | Ana logada | Envia um GIF (`image/gif`) | Recusado pelo tipo |
| A05 | Ana logada | Envia um PNG para `profiles/<bruno>/<uuid>.png` | Recusado pelo RLS |
| A06 | Um arquivo da Ana e um do Diego | Ana pede a URL assinada de cada um | Recebe a do próprio arquivo. A do Diego é recusada. Até a fatia 2, o outro arquivo era do Bruno; desde o seed da fatia 3, Bruno e Ana estão no mesmo grupo e compartilham contexto (RN107). Troca decidida pelo responsável em 15/11/2026: o Diego é a pessoa sem contexto do seed (`setup.md`, seção 8) |

### 10.4 App

**Validações e formatação**, testes unitários em `app/test/`:

| ID | Entrada | Função | Resultado |
|----|---------|--------|-----------|
| U01 | `52998224725`, `529.982.247-25`, `52998224724`, `11111111111` | Validação de CPF | Verdadeiro, verdadeiro, falso, falso. A mesma regra do banco (X01 a X03) |
| U02 | `11222333000181`, `11.222.333/0001-81`, `11222333000180`, `00000000000000`, `12ABC34501DE35`, `12.ABC.345/01DE-35`, `12abc34501de35`, `12ABC34501DE36`, `12ABC34501DEA5` | Validação de CNPJ | Verdadeiro, verdadeiro, falso, falso, verdadeiro, verdadeiro, verdadeiro (o app passa para maiúsculas antes de conferir), falso, falso. A mesma regra do banco (X04 a X06, X11 a X14) |
| U03 | `(86) 99999-1234`, `(86) 3322-1234`, `(86) 9999-123` | Telefone digitado para E.164 | `+5586999991234`, `+558633221234`, inválido |
| U04 | `+5586999991234`, `+558633221234` | E.164 para exibição | `(86) 99999-1234`, `(86) 3322-1234` |
| U05 | CPF `52998224725`, CNPJ `11222333000181`, CNPJ `12ABC34501DE35`, telefone `+5586999991234` | Chave Pix para exibição | `529.982.247-25`, `11.222.333/0001-81`, `12.ABC.345/01DE-35`, `(86) 99999-1234` |
| U06 | E-mail ` Ana@Exemplo.com `, aleatória em maiúsculas, CNPJ `12.abc.345/01de-35` | Normalização da chave | `ana@exemplo.com`, a mesma em minúsculas, `12ABC34501DE35` |
| U07 | Identidades `[email]`, `[google]`, `[email, google]` | Tem acesso por e-mail e senha | Verdadeiro, falso, verdadeiro |

**Conversão de erros**, em `app/test/core/errors/`:

| ID | Exceção recebida | `ErrorCode` |
|----|------------------|-------------|
| E09 | `AuthException` com cada código da tabela da seção 6.8 do `docs/copy.md` | O `ErrorCode` da mesma linha |
| E10 | `PostgrestException` `P0001` com `PIX_KEY_IN_USE` | `pixKeyInUse` |
| E11 | `StorageException` com HTTP 413; e com `invalid_mime_type` | `photoTooLarge`; `photoInvalidType` |
| E12 | O `google_sign_in` devolve nulo (seletor fechado) | Nenhum erro, e nada é mostrado |

**Telas**, testes de widget com os repositórios trocados por dublês (`docs/ui/telas.md`, seção 5):

| ID | Tela | Quando | Então |
|----|------|--------|-------|
| S01 | Cadastro | Toca em Criar conta com os campos vazios; depois com senha de 7 caracteres | Erros nos campos (`authNameRequired`, `authEmailRequired`, `authPasswordRequired`; depois `authPasswordTooShort`). O repositório não é chamado |
| S02 | Cadastro | Cadastro aceito | Abre a `/confirm-email` com o e-mail na frase. O voltar não retorna ao cadastro |
| S03 | Confirmar e-mail | Digita o sexto dígito; o repositório responde `authInvalidCode` | O `verifyOTP` é chamado sem tocar no botão. Erro `errorAuthInvalidCode` no campo, que é limpo |
| S04 | Confirmar e-mail | Abre a tela; passam 60 s | **Reenviar código** desabilitado com a contagem (`authResendCodeIn`), e habilitado depois |
| S05 | Confirmar e-mail | Rota aberta sem e-mail em memória | Vai para o login |
| S06 | Login | O repositório responde `authEmailNotConfirmed`; a pessoa toca em **Confirmar** no `SnackBar` | O `resend` é chamado com o e-mail digitado e a `/confirm-email` abre |
| S07 | Login | O Google devolve nulo; depois falha | Nada na primeira vez. `SnackBar` `errorAuthGoogleFailed` na segunda |
| S08 | Recuperar senha | Envia o código; o `verifyOTP` vale, e o `updateUser` responde `authSamePassword`; toca de novo em Salvar | Passa à etapa 2. Depois, só o campo de senha, com o erro. O novo toque chama só o `updateUser` |
| S09 | Aceite dos termos | Abre sem aceite; marca a caixa; toca em Aceitar | Botão desabilitado até marcar. Insere uma linha por documento que falta. Frase `termsSubtitleFirst` |
| S10 | Roteador | Sessão sem aceite; sessão com aceite da versão vigente; vigente `1.1` e aceite `1.0`; sessão abrindo `/signup` | `/terms`; `/games`; `/terms` com `termsSubtitleUpdated`; `/games` |
| S11 | Meu perfil | Conta só com Google; conta com e-mail; conta só com Google abrindo `/profile/email` | Sem as linhas Trocar e-mail e Trocar senha; com as duas; volta ao perfil |
| S12 | Editar perfil | Telefone vazio; apaga o telefone com o interruptor ligado; telefone com 9 dígitos; Salvar com foto nova no lugar da antiga | Interruptor desabilitado; interruptor desliga; erro `profilePhoneInvalid`; chamadas nesta ordem: envio da foto, `profiles`, `profile_private`, remoção da foto antiga |
| S13 | Chave Pix | CPF `52998224724`; troca de CPF para E-mail; Remover, confirmar, e o repositório responde `pixKeyInUse` | Erro `pixInvalidCpf` sem chamar o servidor; o campo é limpo; `SnackBar` `errorPixKeyInUse`, e a chave continua na tela |
| S14 | Trocar e-mail | Novo e-mail igual ao atual; o repositório responde `authEmailInUse` | Erro `emailSameAsCurrent` sem chamar o servidor; erro `errorAuthEmailInUse` no campo |
| S15 | Trocar senha | O `signInWithPassword` responde `authInvalidCredentials` | Erro `passwordCurrentWrong` no campo Senha atual. O `updateUser` não é chamado |
| S16 | Todas as telas da seção 5 do `telas.md` | Fonte do sistema em 150% | Nenhum *overflow* |
| S17 | Meu perfil | Perfil com `name = 'Ana Souza'` e `nickname = 'Aninha'` | O cabeçalho mostra `Aninha` (RN100) |

**Fluxos**, testes de integração no emulador (API 29 e 36) contra o Supabase local com o seed. O código chega pelo Mailpit, lido pela API dele em `http://10.0.2.2:54324`. Cada fluxo deixa o seed como encontrou, para poder rodar de novo sem `db reset`: o L08 usa um e-mail novo a cada execução, e L09 a L11 devolvem, no fim, a senha, o apelido, o telefone e o e-mail originais:

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| L08 | Sem sessão, e-mail novo | Cria a conta com o nome `Carla Souza`, lê o código no Mailpit, confirma e aceita os termos | Chega à aba Jogos. O perfil mostra `Carla Souza` |
| L09 | Bruno sem sessão | Recupera a senha com o código do Mailpit e uma senha nova; sai e entra com a senha nova | Entra nas duas vezes. A senha antiga não entra mais |
| L10 | Ana logada | Muda o apelido para `Aninha` e o telefone, salva e reabre o app | O perfil mostra `Aninha`, e Editar perfil mostra o telefone formatado (a tela Meu perfil não mostra telefone, `telas.md`, 5.7) |
| L11 | Diego logado | Troca o e-mail com o código do Mailpit, sai e entra com o e-mail novo | Entra com o novo. O antigo não entra mais |

**Conferência manual**, no emulador e na produção, porque depende de conta Google real e do Resend (`plano-implementacao.md`, fatia 2, "Pronto quando"):

| ID | O que conferir |
|----|----------------|
| M01 | Conta nova pelo Google: o perfil nasce com o nome do Google e a `/terms` aparece |
| M02 | Google com o e-mail de uma conta criada por e-mail e senha (RF108): entra na mesma conta, sem criar outra, e as linhas Trocar e-mail e Trocar senha continuam aparecendo |
| M03 | Na produção, os três e-mails chegam pelo Resend com o remetente `nao-responda@mail.voleiin.com.br` e o código no assunto |
| M04 | Na produção, o cadastro por e-mail, o Google e a vinculação funcionam, ainda sem usuários reais |

## 11. Grupos (fatia 3)

Decisões de 15/11/2026. Base: `contratos-api.md` (seção 3 e `preview-invite`), `rls-matriz.md` (fatia 3), `docs/ui/telas.md` (seção 6) e `docs/copy.md` (seção 7). "Ana logada" é `role authenticated` com o `sub` da Ana.

**Base dos cenários pgTAP**, inserida como `postgres` no começo de cada teste, sem depender do seed (`arquitetura-app.md`, 14.4): o grupo **Quinta**, com o código `VoleiQuinta1`, Ana como admin e Bruno como membro. Carla e Diego não estão em nenhum grupo, salvo quando o cenário diz. Os resultados de B03, B04, B06 e B10 passam a ser as listas da fatia 3 da `rls-matriz.md`. O B08 troca o `select` em `groups`, que agora devolve zero linhas a quem não é membro em vez de `42501`, por um `insert` em `groups`, que continua sem privilégio (seção 9.1).

"Notifica" é conferido em `notifications`: o tipo, o `user_id` e o `data` da tabela "Dados das notificações de grupo" do `contratos-api.md` (seção 3).

### 11.1 Funções de grupo

pgTAP, em `supabase/tests/database/groups_functions.test.sql`.

**Criar e editar (RF14, RF18, RN10, RN11)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| G01 | Ana logada | `create_group('  Vôlei de Sábado  ')` | Retorna `group_id` e um `invite_code` de 12 caracteres base62. O grupo tem o nome `Vôlei de Sábado`, `created_by` = Ana, e Ana é a única linha em `group_members`, com o papel `admin` |
| G02 | Ana logada | `create_group` com `''`, com `'   '` e com 61 caracteres; depois com 60 | `INVALID_INPUT` nos três primeiros. O de 60 é aceito |
| G03 | `role authenticated` sem `sub` | `create_group('Teste')` | `NOT_AUTHENTICATED` |
| G04 | Ana logada | `update_group(quinta, 'Quinta à noite', 'groups/<quinta>/<uuid>.png')`; depois com a foto nula | Nome e foto gravados; depois `photo_path` nulo |
| G05 | Ana logada | `update_group` com a foto em `groups/<outro grupo>/x.png`, em `profiles/<ana>/x.png` e com o nome vazio | `INVALID_INPUT` nos três. Nada muda |
| G06 | Bruno logado; Diego logado | `update_group(quinta, ...)` | Bruno: `NOT_GROUP_ADMIN`. Diego: `NOT_FOUND` |

**Convite (RF15, RN11)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| G07 | Ana logada; Diego tem solicitação pendente no Quinta | `regenerate_group_invite(quinta)` | Retorna um código novo, diferente de `VoleiQuinta1`, e grava `invite_code_updated_at = now()`. A solicitação do Diego continua `pending` |
| G08 | Depois do G07 | Carla logada chama `request_group_join('VoleiQuinta1')`; depois com o código novo | `INVITE_INVALID`; depois aceito |
| G09 | Ana logada | `invalidate_group_invite(quinta)`; Carla pede com `VoleiQuinta1`; Ana chama `regenerate_group_invite` | `invite_code` nulo; `INVITE_INVALID`; um código novo |
| G10 | Bruno logado; Diego logado | `regenerate_group_invite(quinta)` e `invalidate_group_invite(quinta)` | Bruno: `NOT_GROUP_ADMIN` nos dois. Diego: `NOT_FOUND` nos dois |

**Solicitações (RF16, RF17, RN12)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| G11 | Diego logado | `request_group_join('VoleiQuinta1')` | Retorna `request_id` e o `group_id` do Quinta. A solicitação fica `pending`. Notifica Ana (`group_join_requested`), e só ela: Bruno não é admin |
| G12 | Depois do G11 | Diego pede de novo | `JOIN_REQUEST_PENDING` |
| G13 | Bruno logado | `request_group_join('VoleiQuinta1')` | `ALREADY_MEMBER` |
| G14 | Diego logado | Pede com `voleiquinta1` (outra caixa), com `VoleiQuinta2` (não existe) e com o código que o grupo **Antigo** tinha antes de ser arquivado | `INVITE_INVALID` nos três. O código diferencia maiúsculas de minúsculas |
| G15 | Diego com solicitação pendente; Ana logada | `decide_join_request(<req>, true)` | `status = approved`, `decided_by` = Ana, `decided_at = now()`. Diego entra em `group_members` como `member`. Notifica Diego (`group_join_decided`, `approved: true`) |
| G16 | Idem | `decide_join_request(<req>, false)`; depois Diego pede de novo | `status = rejected`, e Diego não vira membro. Notifica Diego (`approved: false`). O novo pedido é aceito (RN12) |
| G17 | Solicitação já aprovada | Ana decide de novo | `REQUEST_NOT_PENDING` |
| G18 | Diego com solicitação pendente | Bruno logado decide; Diego decide a própria; Carla decide | Bruno: `NOT_FOUND` (não vê a solicitação). Diego: `NOT_GROUP_ADMIN`. Carla: `NOT_FOUND` |

**Papéis (RF23, RF24, RN10, RN13)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| G19 | Ana logada | `set_group_role(quinta, bruno, 'admin')`; depois Bruno logado chama `set_group_role(quinta, ana, 'member')` | Os dois aceitos. No fim, Bruno é o único admin |
| G20 | Ana é a única admin | Ana chama `set_group_role(quinta, ana, 'member')` | `LAST_ADMIN`. Ana continua admin |
| G21 | Ana logada | `set_group_role(quinta, ana, 'admin')` (o papel que ela já tem) | Aceito, sem mudança |
| G22 | — | Ana: `set_group_role(quinta, diego, 'admin')`. Bruno: `set_group_role(quinta, ana, 'member')`. Diego: `set_group_role(quinta, bruno, 'admin')` | Ana: `TARGET_NOT_MEMBER`. Bruno: `NOT_GROUP_ADMIN`. Diego: `NOT_FOUND` |

**Saída, remoção e exclusão (RF20, RF21, RF103, RN13, RN17)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| G23 | Bruno logado | `leave_group(quinta)` | Retorna `games_left` vazio. Bruno sai de `group_members`. Nenhuma notificação |
| G24 | Ana é a única admin, com Bruno no grupo | Ana chama `leave_group(quinta)` | `LAST_ADMIN` |
| G25 | Grupo **Solo**, só com a Ana | Ana chama `leave_group(solo)` | `LAST_ADMIN`: o único membro exclui o grupo (RN13) |
| G26 | Diego logado | `leave_group(quinta)` | `NOT_FOUND` |
| G27 | Ana logada | `remove_group_member(quinta, bruno)` | Bruno sai de `group_members`. Notifica Bruno (`removed_from_group`, `reason: removed`) |
| G28 | Bruno promovido a admin | Ana remove Bruno | Aceito: Ana continua admin, e o grupo não fica sem admin |
| G29 | — | Ana remove a si mesma; Ana remove Diego; Bruno remove Ana; Diego remove Bruno | `CANNOT_REMOVE_SELF`; `TARGET_NOT_MEMBER`; `NOT_GROUP_ADMIN`; `NOT_FOUND` |
| G30 | Quinta com Bruno membro e Diego com solicitação pendente | Ana chama `archive_group(quinta)` | `archived_at = now()`, `archived_by` = Ana, `invite_code` nulo, `group_members` vazio. A solicitação do Diego fica `cancelled`, com `decided_at = now()` e `decided_by` nulo. Notifica Bruno (`reason: archived`) e não Ana. Uma linha `group_archived` em `audit_log`, com `actor_id` = Ana |
| G31 | Jogo do Quinta `open`, inserido direto; depois só `confirmed`; depois só `cancelled` e `completed` | Ana chama `archive_group(quinta)` | `GROUP_HAS_ACTIVE_GAMES` nos dois primeiros. Aceito no terceiro (RN17) |
| G32 | — | Bruno chama `archive_group(quinta)`; Diego chama | `NOT_GROUP_ADMIN`; `NOT_FOUND` |
| G33 | Depois do G30 | Ana chama `update_group(quinta, ...)` e `regenerate_group_invite(quinta)` | `NOT_FOUND` nos dois: o grupo arquivado não tem mais membros |

### 11.2 RLS e contexto (RN107)

pgTAP, em `supabase/tests/database/groups_security.test.sql`. Os jogos usados para contexto são inseridos direto, como `postgres`, com o admin na mesma transação (`modelo-dados.md`, 4.3).

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| K01 | Base | Bruno lê `groups`; Diego lê `groups` | Bruno vê o Quinta, com o `invite_code`. Diego não vê nenhuma linha |
| K02 | Base | Bruno lê `group_members`; Diego lê | Bruno vê Ana e Bruno. Diego, nenhuma linha |
| K03 | Bruno saiu do Quinta (`leave_group`) | Bruno lê `groups` e `group_members` | Nenhuma linha |
| K04 | Quinta arquivado | Ana lê `groups` | Nenhuma linha |
| K05 | Diego com solicitação pendente e uma recusada no Quinta | Diego, Ana, Bruno e Carla leem `group_join_requests` | Diego vê as duas dele. Ana vê as duas. Bruno e Carla, nenhuma |
| K06 | Ana logada | `insert`, `update` e `delete` em `groups`, `group_members` e `group_join_requests` | `42501` em todos |
| K07 | Base | Bruno lê `profiles`; Diego lê `profiles` | Bruno vê a própria linha e a da Ana. Diego vê só a própria (RN107, negativo) |
| K08 | Carla e Diego com linhas no mesmo jogo avulso: Carla `cancelled` na lista e Diego com `left_at` preenchido na espera | Diego lê `profiles` | Vê a Carla: jogo passado e espera contam como contexto |
| K09 | Diego com solicitação pendente no Quinta | Ana lê o perfil do Diego; Bruno lê | Ana vê (RN107, exceção 2). Bruno não vê |
| K10 | Depois do K09, Ana recusa a solicitação | Ana lê o perfil do Diego | Não vê |
| K11 | Depois do K09, Ana aprova a solicitação | Bruno lê o perfil do Diego | Vê, pelo contexto do grupo |
| K12 | Bruno sai do Quinta, sem jogo em comum com a Ana | Ana lê o perfil do Bruno | Não vê: o contexto acaba com a saída |
| K13 | Quinta arquivado | Ana lê o perfil do Bruno | Não vê |
| K14 | Base | Bruno lê `profile_private` | Só a própria linha. A da Ana não aparece, mesmo com contexto |
| K15 | `role anon` | `select` em `groups`, `group_members` e `group_join_requests` | `42501` nas três |

### 11.3 Fotos do grupo e de outras pessoas

Deno test, em `supabase/functions/_tests/avatars_test.ts`, junto da seção 10.3, com as contas e os grupos do seed (`setup.md`, seção 8): o Quinta, com Ana admin e Bruno e Carla membros, e o Domingo, só com o Bruno admin e a solicitação pendente do Diego.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| A07 | Ana logada | Envia um PNG para `groups/<quinta>/<uuid>.png` | Aceito |
| A08 | Bruno logado; Diego logado | Enviam um PNG para `groups/<quinta>/<uuid>.png` | Recusado pelo RLS nos dois |
| A09 | Foto do A07 | Bruno pede a URL assinada; Diego pede | Bruno recebe. Diego é recusado |
| A10 | Ana com foto de perfil | Bruno pede a URL assinada da foto da Ana; Diego pede | Bruno recebe (contexto). Diego é recusado (RN107) |
| A11 | Diego envia a própria foto de perfil | Bruno pede a URL assinada dela; Ana pede | Bruno recebe: Diego tem solicitação pendente no Domingo, que Bruno administra. Ana é recusada |
| A12 | Foto do A07 | Bruno apaga; Ana apaga | O de Bruno não remove o arquivo. O da Ana remove |
| A13 | Ana logada | Envia um PNG para `groups/nao-e-uuid/x.png` | Recusado, sem erro de conversão no banco |

### 11.4 Prévia do convite

Deno test, em `supabase/functions/preview-invite/index_test.ts`, contra o Supabase local com o seed. "Chama" é `functions.invoke('preview-invite', { code, kind: 'group' })`.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| Q01 | Diego logado | Chama com `VoleiQuinta1` | HTTP 200: `kind = group`, o `group_id` e o nome do Quinta, `photo_url` nulo, `is_member` e `has_pending_request` falsos |
| Q02 | Bruno logado | Chama com `VoleiQuinta1` | `is_member` verdadeiro |
| Q03 | Diego logado | Chama com `VoleiDomingo` | `has_pending_request` verdadeiro, `is_member` falso |
| Q04 | Diego logado | Chama com `voleiquinta1` e com `VoleiQuinta2` | HTTP 404, `INVITE_INVALID`, nos dois |
| Q05 | Sem login; Diego logado sem `code`; Diego logado com `kind: game` | Chama | HTTP 401 `NOT_AUTHENTICATED`; HTTP 422 `INVALID_INPUT`; HTTP 422 `INVALID_INPUT` (jogos só na fatia 8) |
| Q06 | Ana põe uma foto no Quinta | Diego chama com `VoleiQuinta1` | `photo_url` é uma URL assinada que baixa a foto, mesmo com o Diego sem acesso ao bucket |
| Q07 | Diego logado | Chama com `VoleiQuinta1` | Nenhuma linha nova em `group_join_requests` nem em `notifications`: a prévia não grava nada |

### 11.5 Concorrência

Deno test, em `supabase/functions/_tests/concurrency/groups_test.ts`, com conexões separadas e cada cenário repetido 50 vezes, como na seção 8.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| C13 | Diego sem solicitação no Quinta | Duas chamadas simultâneas de `request_group_join('VoleiQuinta1')` pelo Diego | Uma cria a solicitação. A outra recebe `JOIN_REQUEST_PENDING`. Sempre uma só pendente (RN12) |
| C15 | Diego com solicitação pendente; Ana e Bruno admins | Ao mesmo tempo, Ana aprova e Bruno recusa | Uma decisão vale e a outra recebe `REQUEST_NOT_PENDING`. Diego é membro se, e só se, a aprovação venceu |

O C14 (dois admins que rebaixam um ao outro ao mesmo tempo) foi retirado em 15/11/2026, por decisão do responsável: é uma situação pouco provável. As funções de grupo bloqueiam a linha do grupo, então as chamadas simultâneas ficam em fila (research R2 de `specs/002-grupos`).

### 11.6 App

**Validação**, teste unitário em `app/test/`:

| ID | Entrada | Função | Resultado |
|----|---------|--------|-----------|
| U08 | ` VoleiQuinta1 `, `Volei Quinta1`, `VoleiQuinta`, `VoleiQuinta1!`, `voleiquinta1` | Código de convite digitado | `VoleiQuinta1`, `VoleiQuinta1`, inválido (11 caracteres), inválido, `voleiquinta1` (a caixa é mantida) |

**Conversão de erros**, em `app/test/core/errors/`:

| ID | Exceção recebida | `ErrorCode` |
|----|------------------|-------------|
| E13 | `PostgrestException` `P0001` com cada código da seção 7.7 do `docs/copy.md` | O `ErrorCode` da mesma linha |
| E14 | `FunctionException` da `preview-invite` com HTTP 404 e `{ "error": { "code": "INVITE_INVALID" } }` | `inviteInvalid` |

**Telas**, testes de widget com os repositórios trocados por dublês (`docs/ui/telas.md`, seção 6):

| ID | Tela | Quando | Então |
|----|------|--------|-------|
| S18 | Meus grupos | Nenhum grupo | Estado vazio com `groupsEmptyTitle` e os botões **Criar grupo** e **Entrar com código** |
| S19 | Meus grupos | Grupos `Vôlei de Quinta` (Ana admin, 3 integrantes, 2 solicitações) e `Areia` (Ana membro, 1 integrante) | Ordem: `Areia`, `Vôlei de Quinta`. O Quinta tem o selo **Admin** e o subtítulo "3 integrantes · 2 solicitações". O Areia, "1 integrante", sem selo |
| S20 | Criar grupo | Nome vazio; nome com 61 caracteres; criar sem foto | Erro `groupNameRequired`; erro `groupNameTooLong`, sem chamar o servidor; `create_group` chamado e `update_group` não, abre o detalhe, e o voltar não retorna à criação |
| S21 | Criar grupo | Criar com foto; depois, outro caso em que o envio da foto falha | Chamadas nesta ordem: `create_group`, envio para `groups/<id>/...`, `update_group`. Na falha, abre o detalhe do mesmo jeito, com o `SnackBar` `groupCreatedPhotoFailed` |
| S22 | Entrar com código | Campo vazio; `VoleiQuinta` (11); prévia responde `INVITE_INVALID` | `groupJoinCodeRequired`; `groupJoinCodeInvalid`, sem chamar a prévia; `errorInviteInvalid` no campo |
| S23 | Entrar com código | Prévia com `is_member`; com `has_pending_request`; nos dois falsos | **Abrir o grupo**; o aviso `groupJoinPending`, sem **Pedir para entrar**; **Pedir para entrar** |
| S24 | Entrar com código | Pedir é aceito; pedir responde `JOIN_REQUEST_PENDING`; responde `ALREADY_MEMBER`; responde `INVITE_INVALID` | Estado pendente; estado pendente, sem `SnackBar`; estado "Já é membro"; volta à etapa 1 com o erro no campo |
| S25 | Detalhe do grupo | Membro comum; admin com 2 pendentes; único membro | Sem **Solicitações** e **Editar grupo**, com **Sair do grupo**; com as duas linhas e "2 solicitações pendentes"; sem **Sair do grupo** |
| S26 | Detalhe do grupo | Sair, confirmar, aceito; depois `leave_group` responde `LAST_ADMIN`; o repositório não acha o grupo | Volta a Meus grupos com `groupLeft`; `SnackBar` `errorLastAdmin`; estado "não encontrado" |
| S27 | Convite | Membro com código; admin com código; Gerar novo código e confirmar; membro com convite desativado; admin com convite desativado | Código, **Compartilhar** e **Copiar código**, sem as ações de admin; com **Gerar novo código** e **Desativar convite**; `regenerate_group_invite` e o código novo na sheet; `groupInviteAskAdmin`, sem botão; **Gerar código**, que chama `regenerate_group_invite` sem confirmação |
| S28 | Convite | Copiar código; Compartilhar | O `Clipboard` recebe só o código, com `groupInviteCopied`; o compartilhamento recebe `groupInviteShareText` com o nome e o código |
| S29 | Integrantes | Ana (admin) e Bruno e Carla (membros), com Ana logada | Ordem: Ana (você), com o selo; depois Bruno e Carla. Tocar em Bruno abre a sheet com **Ver perfil**, **Tornar admin** e **Remover do grupo**. Tocar em si abre **Deixar de ser admin** |
| S30 | Integrantes | Bruno logado (membro) toca em Ana; toca em si | Abre `/people/<ana>`; nada acontece |
| S31 | Integrantes | Tornar Bruno admin; remover Carla e confirmar; Ana, única admin, deixa de ser admin e o repositório responde `LAST_ADMIN` | `set_group_role` e `groupMemberNowAdmin`; `remove_group_member` e `groupMemberRemoved`; `SnackBar` `errorLastAdmin` |
| S32 | Solicitações | Duas pendentes; aprovar a primeira; recusar a segunda; uma terceira responde `REQUEST_NOT_PENDING`; Bruno (membro) abre a rota | Ordem por `created_at`; `decide_join_request(true)`, a linha sai, `groupRequestApproved`; `decide_join_request(false)`, `groupRequestRejected`; `SnackBar` e a lista relê; estado "não encontrado" |
| S33 | Editar grupo | Salvar com foto nova no lugar da antiga; Excluir, confirmar, aceito; Excluir com `GROUP_HAS_ACTIVE_GAMES`; Bruno (membro) abre a rota | Chamadas nesta ordem: envio da foto, `update_group`, remoção da antiga; volta a Meus grupos com `groupDeleted`; `SnackBar` `errorGroupHasActiveGames`; estado "não encontrado" |
| S34 | Perfil de outra pessoa | Bruno com `name = 'Bruno Lima'` e `nickname = 'Brunão'`; Diego sem apelido; o repositório não acha o perfil | `Brunão` no título e `Bruno Lima` embaixo; só o nome; estado "não encontrado" |
| S35 | Todas as telas da seção 6 do `telas.md` e a sheet do convite | Fonte do sistema em 150% | Nenhum *overflow* |

**Fluxos**, testes de integração no emulador (API 29 e 36) contra o Supabase local com o seed, pelos `scripts/` (`setup.md`, 3.1). Cada fluxo deixa o seed como encontrou:

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| L12 | Diego logado | Entra com o código `VoleiQuinta1` e pede para entrar; sai e entra como Ana, aprova em Solicitações do Quinta; sai e entra como Diego; no fim, Diego sai do grupo | Diego vê o Vôlei de Quinta em Meus grupos e Ana, Bruno e Carla em Integrantes. Depois de sair, o grupo some da lista |
| L13 | Ana logada | Cria o grupo `L13 <data e hora>`, abre o convite, gera um código novo e exclui o grupo em Editar grupo | O código muda na sheet. Depois da exclusão, o grupo não aparece em Meus grupos |
| L14 | Ana logada | No Quinta, torna a Carla admin e depois a deixa como membro | O selo **Admin** aparece e some na linha da Carla |

**Conferência manual**, no emulador:

| ID | O que conferir |
|----|----------------|
| M05 | **Compartilhar** abre o seletor do Android, e o texto chega ao WhatsApp com o nome do grupo e o código no fim, que dá para copiar sozinho e colar em **Entrar com código** |

## 12. Jogo e lista de presença (fatia 4)

Decisões de 16/11/2026. Base: `contratos-api.md` (seção 4 e a extensão de `leave_group`), `rls-matriz.md` (fatia 4), `docs/ui/telas.md` (seção 7) e `docs/copy.md` (seção 8). Os cenários T01 a T10 (seção 3) e C01 a C07 (seção 8) também são da fatia 4 e rodam junto destes.

**Base dos cenários pgTAP**, inserida como `postgres` no começo de cada teste, sem depender do seed: a base da seção 11 (o grupo **Quinta**, com Ana admin e Bruno membro), mais **Carla** e **Edu** como membros do Quinta. Diego continua sem grupo. Ana e Bruno têm chave Pix; Carla e Edu, não, salvo quando o cenário diz. Ana tem telefone visível; Bruno, telefone oculto.

**Jogo base**, inserido direto, como `postgres`: do Quinta, com prazo em `now() + 1 dia`, início 2 h depois do prazo e fim 2 h depois do início; total 9.000 e limite 3 (estimativa de 3.000); Ana como admin, recebedora e primeira da lista. "Jogo iniciado" é o mesmo jogo com o início em `now()` ou antes, e "jogo depois do fim", com o fim em `now()` ou antes, sempre respeitando prazo ≤ início < fim. "Prazo vencido" é o prazo 1 h antes de `now()` e o início 1 h depois.

"Notifica" é conferido em `notifications`: o tipo, o `user_id` e o `data` da tabela "Dados das notificações de jogo" do `contratos-api.md` (seção 4). Os resultados de B03, B04 e B06 passam a ser as listas da fatia 4 da `rls-matriz.md`.

**Cenários por etapa.** A fatia 4 roda em três etapas, cada uma com a sua especificação e as suas sessões 2 a 4 (`plano-implementacao.md`, fatia 4; `trabalho-com-agente.md`, 3.1). A divisão segue as etapas sugeridas pelo plano, com o limite de vagas junto da edição, na etapa A, para a tela de edição nascer inteira. Um cenário que precisa de dado de uma etapa seguinte o insere direto, como `postgres` (por exemplo, a linha da espera no O20). As listas do B03, B04 e B06 crescem a cada etapa, só com o que ela cria:

| Etapa | Escopo | Cenários |
|-------|--------|----------|
| **A** | Criar, ver e editar o jogo, inclusive o limite de vagas, com entrada na lista; Meus jogos, detalhe e chave Pix do recebedor | J01 a J13, O01 a O07, O20 a O23, T03 a T05, C01, C02, C04, C05, W01 a W11, W13 a W15, U09 a U11, S36 a S42, S50 a S53, L15 (sem o cancelamento), M06 |
| **B** | Saídas, remoção e lista de espera, com a concorrência | O08 a O19, T01, T02, T06 a T10, C03, C06, S43 a S47, L16, L17 |
| **C** | Admins do jogo, cancelamento, saída do grupo com jogos e telefone visível | J14 a J21, H01 a H10, C07, C16, W12, U12, S48, S49, S54 a S58, L15 (o cancelamento), L18, L19, M07 |

S59 e S60 crescem a cada etapa, com as telas dela. E15 também: cada etapa acrescenta os códigos das funções que cria. E16 entra na etapa C.

### 12.1 Criar, editar, cancelar e admins

pgTAP, em `supabase/tests/database/games_functions.test.sql`.

**Criar (RF26 a RF32, RN05, RN06, RN20 a RN23, RN40)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| J01 | Ana logada | `create_game(quinta, '  Quadra do Sesc  ', null, prazo, início, fim, 9000, 3)` | Retorna `game_id`, `status = open` e um `invite_code` de 12 caracteres base62. O jogo tem o local `Quadra do Sesc` e `created_by` e `receiver_id` = Ana. `game_admins` tem só a Ana, com `added_by` nulo. `game_participants` tem uma passagem `active` da Ana, com `joined_at = now()`. `game_limit_history` tem uma linha com 3. Nenhuma notificação |
| J02 | Bruno logado | `create_game(null, ...)` (avulso) | Aceito, com `group_id` nulo e Bruno admin, recebedor e primeiro da lista (RN20) |
| J03 | Ana logada | `create_game` com limite 1 | `status = confirmed` (RN40) |
| J04 | Carla logada, sem chave Pix | `create_game(quinta, ...)` | `RECEIVER_NEEDS_PIX_KEY`. Nenhuma linha em `games` (RN22) |
| J05 | Diego logado; Ana com um `uuid` que não é grupo; Ana com o grupo **Antigo**, arquivado | `create_game` | `NOT_FOUND` nos três |
| J06 | Ana logada | Prazo 1 µs depois do início; início igual ao fim; início em `now()`; início 1 h antes de `now()` (prazo antes dele); prazo igual ao início | `INVALID_GAME_DATES`; `INVALID_GAME_DATES`; `START_IN_PAST`; `START_IN_PAST`; aceito (RN23: prazo ≤ início) |
| J07 | Ana logada | Local `''`, `'   '` e com 121 caracteres; link `http://maps.app.goo.gl/x`; total 0; limite 0 | `INVALID_INPUT` em todos. Com local de 120 caracteres, link `https://maps.app.goo.gl/x`, total 1 e limite 1, aceito |
| J08 | `role authenticated` sem `sub` | `create_game` | `NOT_AUTHENTICATED` |

**Editar (RF36, RN23, RN33 a RN35)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| J09 | Jogo base com Bruno na lista e Edu na espera | Ana chama `update_game` com outro local e o início 1 h mais tarde | Dados gravados. Notifica Bruno (`game_updated`), e não Ana nem Edu |
| J10 | Jogo base com Bruno na lista | Bruno chama `update_game`; Diego chama | `NOT_GAME_ADMIN`; `NOT_FOUND` |
| J11 | Jogo iniciado; jogo cancelado | Ana chama `update_game` | `GAME_STARTED`; `GAME_NOT_OPEN` |
| J12 | Jogo base | Ana chama `update_game` com o início no passado; com o prazo depois do início | `START_IN_PAST`; `INVALID_GAME_DATES`. Nada muda |
| J13 | Prazo vencido; Bruno cancelou fora do prazo (`late_cancellation = true`) | Ana chama `update_game` com o prazo igual ao início, depois do cancelamento do Bruno | A passagem do Bruno continua com `late_cancellation = true` (RN35) |

**Cancelar (RF39, RN43, RN67, RN114)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| J14 | Jogo base com Bruno e Carla na lista (cheio) e Edu na espera | Ana chama `cancel_game`; depois chama de novo; depois Edu chama `join_waitlist` | `status = cancelled`, `cancelled_at = now()`, `cancelled_by` = Ana. Notifica Bruno, Carla e Edu (`game_cancelled`), e não Ana. Depois, `GAME_NOT_OPEN` nas duas chamadas |
| J15 | Jogo iniciado; jogo depois do fim | Ana chama `cancel_game` | Aceito nos dois (RN43: até a conclusão) |
| J16 | Jogo base | Bruno chama `cancel_game`; Diego chama | `NOT_GAME_ADMIN`; `NOT_FOUND` |

**Admins do jogo (RF34, RF35, RN25 a RN27)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| J17 | Jogo base com Bruno na lista e Edu na espera | Ana chama `add_game_admin` com Bruno; de novo com Bruno; com Edu; com Diego | Bruno vira admin, com `added_by` = Ana; `ALREADY_GAME_ADMIN`; `ADMIN_MUST_BE_PARTICIPANT` (RN27); `ADMIN_MUST_BE_PARTICIPANT`. Nenhuma notificação |
| J18 | Ana é a única admin | Ana chama `remove_game_admin` com ela mesma; com Carla, que não é admin | `LAST_GAME_ADMIN`; `NOT_GAME_ADMIN_TARGET` |
| J19 | Depois do J17 | Ana chama `remove_game_admin` com ela mesma | Aceito. Ana continua na lista e recebedora. Bruno fica como único admin |
| J20 | Bruno admin (J17) | Bruno sai da lista antes do prazo; depois chama `update_game` | Bruno continua em `game_admins` (RN26), e o `update_game` é aceito |
| J21 | Jogo base | Bruno, membro e não admin, chama `add_game_admin`; Diego chama | `NOT_GAME_ADMIN`; `NOT_FOUND` |

### 12.2 Lista, espera e status

pgTAP, em `supabase/tests/database/games_list.test.sql`, junto dos cenários T01 a T10.

**Entrar e encher (RF47, RF51, RF55, RN03, RN41, RN50 a RN52)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| O01 | Jogo base, só com a Ana | Bruno chama `join_game` | Retorna `participant_id` e `status = open`. Passagem `active` com `joined_at = now()`. 2 vagas ocupadas. Nenhuma notificação |
| O02 | Ana e Bruno na lista | Carla chama `join_game` | `status = confirmed` (RN41). Notifica Ana e Bruno (`game_confirmed`), e não Carla |
| O03 | Lista cheia (Ana, Bruno e Carla) | Edu chama `join_game`; `join_waitlist`; `join_waitlist` de novo; Bruno chama `join_waitlist` | `GAME_FULL`; linha na espera com `joined_at = now()` e `left_at` nulo; `ALREADY_ON_WAITLIST`; `ALREADY_PARTICIPANT` |
| O04 | Jogo base, Aberto | Edu chama `join_waitlist` | `GAME_NOT_FULL` (RN51) |
| O05 | Bruno na lista | Bruno chama `join_game` | `ALREADY_PARTICIPANT` |
| O06 | Jogo base; jogo avulso do Bruno | Diego chama `join_game` e `join_waitlist` no jogo base; Carla chama `join_game` no avulso | `NOT_FOUND` nos três: nenhum deles vê o jogo |
| O07 | Jogo iniciado, com vaga; jogo cheio iniciado; jogo cancelado | Edu chama `join_game`; `join_waitlist`; `join_game` | `GAME_STARTED` (T04); `GAME_STARTED` (T05); `GAME_NOT_OPEN` |

**Sair (RF50, RN29, RN57, RN60, RN61)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| O08 | Lista cheia, Edu na espera | Bruno chama `leave_game` antes do prazo | `outcome = cancelled_on_time`. Passagem `cancelled`, com `left_at = now()` e `late_cancellation = false`. 2 ocupadas e `status = open` (RN42). Notifica Edu (`waitlist_slot_opened`, `reason: slot_freed`). Edu continua na espera (RN51) |
| O09 | Prazo vencido, Bruno na lista | Bruno chama `leave_game` | `outcome = cancelled_late`, `late_cancellation = true` |
| O10 | Jogo iniciado e ainda não terminado, lista cheia, Edu com linha na espera | Bruno chama `leave_game` | `outcome = left_after_start`. Passagem `left_after_start`, `absent = true`, `absence_source = left_after_start`. 3 ocupadas, `status = confirmed`. Nenhuma notificação |
| O11 | Jogo base; jogo iniciado | Ana, a recebedora, chama `leave_game` | `RECEIVER_LOCKED` nos dois (RN29, F07) |
| O12 | Jogo depois do fim; jogo cancelado | Bruno chama `leave_game` | `LIST_LOCKED` (T10); `GAME_NOT_OPEN` |
| O13 | Carla fora da lista | Carla chama `leave_game`; Diego chama | `NOT_PARTICIPANT`; `NOT_FOUND` |
| O14 | Prazo vencido; Bruno cancelou fora do prazo | Bruno chama `join_game`; depois `leave_game` | A passagem antiga ganha `cancellation_voided_at = now()`, e a nova é `active`, no fim da ordem (RN56). A nova saída é `cancelled_late`, e a passagem antiga continua anulada |

**Espera (RF49, RN51, RN53, RN54)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| O15 | Edu na espera, e o jogo voltou a Aberto (O08) | Edu chama `join_game` | Entra na lista. A linha da espera fica com `left_at = now()` (RN54) |
| O16 | Edu na espera, lista cheia | Edu chama `leave_waitlist`; de novo; depois `join_waitlist` | `left_at = now()`; `NOT_ON_WAITLIST`; `left_at` nulo e `joined_at = now()`, no fim da ordem |

**Remover (RF54, RF59, RN58)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| O17 | Lista cheia, Edu na espera | Ana chama `remove_participant` com Bruno | Retorna `status = open`. Passagem `removed`, com `removal_reason = by_admin` e `late_cancellation` nulo. Notifica Bruno (`removed_from_game`) e Edu (`waitlist_slot_opened`) |
| O18 | Jogo base com Bruno na lista | Ana remove a si mesma; Ana remove a Carla, fora da lista; Bruno remove a Ana; Ana remove o Bruno com o jogo iniciado | `CANNOT_REMOVE_SELF` (F12); `NOT_PARTICIPANT`; `NOT_GAME_ADMIN`; `GAME_STARTED` |
| O19 | Bruno admin e na lista | Bruno remove a Ana, a recebedora | `RECEIVER_LOCKED` (RN29) |

**Limite de vagas (RF52, RF53, RN41, RN42, RN59)**

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| O20 | Lista cheia (3), Edu na espera | Ana chama `set_slot_limit(4)` | Retorna `slot_limit = 4` e `status = open`. Linha nova em `game_limit_history`, com `effective_from = now()`. Notifica Edu (`waitlist_slot_opened`, `reason: limit_increased`) e Bruno e Carla (`game_updated`), e não Ana |
| O21 | 3 na lista, limite 4 | Ana chama `set_slot_limit(3)`; depois `(2)`; depois `(0)` | `status = confirmed`, notifica Bruno e Carla (`game_updated` e `game_confirmed`); `SLOT_LIMIT_BELOW_PARTICIPANTS`; `INVALID_INPUT` |
| O22 | Limite 3 | Ana chama `set_slot_limit(3)` | Aceito, sem linha nova no histórico e sem notificação |
| O23 | Jogo iniciado; jogo cancelado; jogo base | Ana chama `set_slot_limit(5)` nos dois primeiros; Bruno chama no terceiro | `GAME_STARTED` (RN34); `GAME_NOT_OPEN`; `NOT_GAME_ADMIN` |

### 12.3 Saída do grupo com jogos (RF22, RF102, RN14, RN16)

pgTAP, em `supabase/tests/database/groups_games.test.sql`. Estende a seção 11.1, em que `games_left` voltava vazio.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| H01 | Prazo vencido, com Bruno na lista; um segundo jogo do Quinta, cheio e não iniciado, com Bruno na espera e Edu na espera | Bruno chama `leave_group(quinta)` | A passagem do Bruno fica `removed`, com `removal_reason = left_group` e `late_cancellation` nulo: sem multa candidata, mesmo depois do prazo (RN14). A linha dele na espera fica com `left_at = now()`. `games_left` traz os dois jogos. O status de cada jogo é recalculado |
| H02 | Bruno com passagem `active` num jogo do Quinta iniciado e com passagem num jogo concluído, inseridos direto | Bruno chama `leave_group(quinta)` | As duas passagens não mudam, e `games_left` não traz esses jogos (RN14, item 3) |
| H03 | Bruno admin, junto da Ana, de um jogo do Quinta Aberto, de um iniciado e de um cancelado | Bruno chama `leave_group(quinta)` | Bruno sai de `game_admins` nos dois primeiros e continua no cancelado (RN14, item 2) |
| H04 | Bruno único admin de um jogo Aberto do Quinta, com a Ana como recebedora | Bruno chama `leave_group(quinta)` | `MEMBER_IS_ONLY_GAME_ADMIN`, com `detail.game_ids` = esse jogo. Nada muda |
| H05 | Bruno criou um jogo Aberto do Quinta: é recebedor e único admin | Bruno chama `leave_group(quinta)` | `MEMBER_IS_RECEIVER`, com `detail.game_ids` = esse jogo: ser recebedor vem antes. Nada muda |
| H06 | Bruno recebedor de um jogo do Quinta iniciado | Bruno chama `leave_group(quinta)` | `MEMBER_IS_RECEIVER` (RN16 vale para `open` e `confirmed`, iniciados ou não) |
| H07 | Os dados do H01; depois os do H05 | Ana chama `remove_group_member(quinta, bruno)` | Os mesmos efeitos do H01, mais a notificação `removed_from_group` ao Bruno; depois, `MEMBER_IS_RECEIVER` |
| H08 | Bruno recebedor de um jogo avulso Aberto e na lista de outro avulso | Bruno chama `leave_group(quinta)` | Aceito. Os jogos avulsos não mudam |
| H09 | Bruno único admin de um jogo do Quinta cancelado | Bruno chama `leave_group(quinta)` | Aceito: só os jogos `open` e `confirmed` bloqueiam |
| H10 | Depois do H01 | Bruno lê `games`; chama `join_game` e `join_waitlist` no primeiro jogo | Vê os dois jogos em que teve passagem e nenhum outro do Quinta; `NO_GAME_ACCESS` nas duas chamadas |

### 12.4 RLS e visibilidade (RN101, RN102, RN107)

pgTAP, em `supabase/tests/database/games_security.test.sql`.

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| W01 | Jogo base com Ana e Bruno na lista; Carla membro, fora da lista | Ana, Bruno, Carla e Diego leem `games` | Os três primeiros veem o jogo, com o `invite_code`. Diego, nenhuma linha |
| W02 | Jogo base com Bruno na lista e Edu na espera | Os mesmos leem `game_admins`, `game_participants` e `game_waitlist` | Ana, Bruno e Carla veem todas as linhas. Diego, nenhuma |
| W03 | Jogo avulso do Bruno, com uma linha do Diego na espera, com `left_at` preenchido | Ana lê `games`; Diego lê | Ana não vê o avulso. Diego vê: passar pela espera conta (`can_view_game`) |
| W04 | Edu saiu do Quinta com uma passagem `removed` no jogo base; outro jogo do Quinta sem passagem dele | Edu lê `games` | Vê só o jogo base |
| W05 | Jogo base com Bruno na lista | Ana lê `game_limit_history`; Bruno lê | Ana vê a linha. Bruno, nenhuma |
| W06 | Ana logada | `insert`, `update` e `delete` em `games`, `game_admins`, `game_participants`, `game_waitlist` e `game_limit_history` | `42501` em todos |
| W07 | `role anon` | `select` nas cinco tabelas | `42501` em todas |
| W08 | Jogo base: Ana recebedora, com chave CPF e telefone visível; Bruno na lista, Carla na espera, Edu com passagem `cancelled` | Bruno, Carla, Edu e Diego chamam `get_profile_contact(ana)` | Bruno: telefone e chave. Carla e Edu: telefone (contexto) e chave nula (RN102). Diego: tudo nulo |
| W09 | Jogo iniciado, com Bruno `left_after_start` | Bruno chama `get_profile_contact(ana)` | Recebe a chave |
| W10 | Jogo base cancelado, com Bruno ainda `active` | Bruno chama `get_profile_contact(ana)` | Chave nula: o jogo foi cancelado (RN102) |
| W11 | Jogo concluído, inserido direto, com Edu `cancelled` e um valor `pending` dele devido à Ana; depois o valor passa a `paid` | Edu chama `get_profile_contact(ana)` | Recebe a chave; depois, chave nula |
| W12 | Bruno com telefone oculto | Ana chama `get_profile_contact(bruno)`; Ana chama `get_profile_contact(ana)` | Telefone nulo (RN101); o próprio telefone e a própria chave |
| W13 | Os dados do W04, mais o avulso do Bruno | Edu chama `get_game_groups` com o jogo base, o outro jogo do Quinta, o avulso e um `uuid` qualquer | Uma linha só: o jogo base, com o `group_id` e o nome do Quinta |
| W14 | Depois do W13, o jogo base cancelado e o Quinta arquivado | Edu chama `get_game_groups` com o jogo base | Continua recebendo o nome do Quinta (RN17) |
| W15 | — | Catálogo `pg_publication_tables` da publicação `supabase_realtime` | Exatamente `games`, `game_participants` e `game_waitlist` |

### 12.5 Concorrência

Deno test, em `supabase/functions/_tests/concurrency/games_test.ts`, com conexões separadas e cada cenário repetido 50 vezes, como na seção 8. Roda os cenários C01 a C07 e mais:

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| C16 | Jogo Aberto do Quinta, sem o Bruno | Ao mesmo tempo, Bruno chama `join_game` e `leave_group(quinta)` | Bruno nunca fica com passagem `active` sem ser membro: ou a entrada vence e a saída o retira (o jogo vem em `games_left`), ou a saída vence e a entrada recebe `NO_GAME_ACCESS` |

### 12.6 App

**Formatação e entrada**, testes unitários em `app/test/`:

| ID | Entrada | Função | Resultado |
|----|---------|--------|-----------|
| U09 | Digitar `1`; `1`, `2`, `0`, `0`, `0`; `0`; apagar tudo; digitar além de `2147483647` | Campo de dinheiro (`docs/ui/telas.md`, 7.2) | `R$ 0,01` e 1; `R$ 120,00` e 12000; `R$ 0,00` e 0 (erro `gameTotalRequired` ao criar); vazio; o dígito a mais é ignorado (R09) |
| U10 | 28/11/2026 (sáb), início 20:00, fim 22:00; início 23:00, fim 01:00; início 20:00, fim 20:00; prazo 28/11 18:00 | Instantes do formulário, de `America/Fortaleza` para UTC | `2026-11-28T23:00:00Z` e `2026-11-29T01:00:00Z`; fim `2026-11-29T04:00:00Z`, com a dica "Termina dom, 29/11."; erro `gameEndSameAsStart`; `2026-11-28T21:00:00Z` |
| U11 | (9000, 3), (10000, 3), (1, 10), (2147483647, 12) | Estimativa por pessoa | 3000, 3334, 1, 178956971, só com inteiros |
| U12 | `+5586999998888`; `+558633224455` | `formatPhone` e os links | `(86) 99999-8888`, `tel:+5586999998888` e `https://wa.me/5586999998888`; `(86) 3322-4455` |

**Conversão de erros**, em `app/test/core/errors/`:

| ID | Exceção recebida | `ErrorCode` |
|----|------------------|-------------|
| E15 | `PostgrestException` `P0001` com cada código da seção 8.8 do `docs/copy.md` | O `ErrorCode` da mesma linha |
| E16 | `PostgrestException` `P0001` `MEMBER_IS_RECEIVER`, com `details` `{"game_ids":["<id1>","<id2>"]}` | `memberIsReceiver`, com os dois IDs |

**Telas**, testes de widget com os repositórios e o relógio trocados por dublês (`docs/ui/telas.md`, seção 7):

| ID | Tela | Quando | Então |
|----|------|--------|-------|
| S36 | Meus jogos | Próximos com um jogo Aberto do Quinta com a Ana na lista, um Confirmado com a Ana em 2º na espera e um avulso; um cancelado | Ordem pelo início. Cards com "Vôlei de Quinta" ou "Avulso", vagas "2/12" e os selos "Na lista" e "2º na espera". O cancelado só aparece no chip **Anteriores** |
| S37 | Meus jogos | Nenhum jogo | Estado vazio com `gamesEmptyUpcomingTitle` e o botão **Criar jogo** |
| S38 | Criar jogo | Sem chave Pix; tocar em **Cadastrar chave Pix** | Aviso `gamePixNeededBody` e **Criar jogo** desabilitado; abre `/profile/pix` |
| S39 | Criar jogo | Aberta pelo Quinta; por Meus jogos com um grupo só; com dois grupos, e criar sem escolher | Grupo Quinta escolhido; o grupo escolhido; erro `gameGroupRequired`, sem chamar o servidor |
| S40 | Criar jogo | Campos vazios; prazo depois do início; link `http://`; fim igual ao início; início 23:00 e fim 01:00 | Erros nos campos (`gameLocationRequired` etc.); `gameDeadlineAfterStart`; `gameMapsInvalid`; `gameEndSameAsStart`; a dica `gameEndsNextDay`. O servidor não é chamado nos quatro primeiros |
| S41 | Criar jogo | Tudo válido, com **Avulso** | A dica `gameGroupStandaloneHint`. `create_game` com `p_group_id` nulo e os instantes do U10. Abre o detalhe, o voltar não retorna à criação, e aparece `gameCreated` |
| S42 | Detalhe | Bruno, membro fora da lista, num jogo Aberto; num Confirmado; num avulso de outra pessoa em que ele tem passagem cancelada | **Entrar na lista**; **Entrar na lista de espera** com `gameFullHint`; `gameNeedsInvite`, sem botão. Nos três, `gamePixOnlyParticipants` no lugar da chave |
| S43 | Detalhe | Bruno na lista, antes do prazo pelo relógio; Sair e confirmar, com o servidor devolvendo `cancelled_on_time`; outro caso com `cancelled_late` | Confirmação com `gameLeaveOnTimeBody`; `leave_game` e `gameLeftOnTime`; `gameLeftLate`, porque o resultado vem do servidor |
| S44 | Detalhe | Ana, recebedora, na lista; tocar em **Copiar chave** | Aviso `gameReceiverCannotLeave`, sem **Sair da lista**. A chave aparece formatada; o `Clipboard` recebe a chave sem formatação, com `gamePixCopied` |
| S45 | Detalhe | Bruno em 2º na espera, jogo Confirmado; o mesmo com o jogo Aberto | `gameWaitlistNotice` com "2º" e **Sair da lista de espera**; **Entrar na lista** e **Sair da lista de espera** |
| S46 | Detalhe | `join_game` responde `GAME_FULL` | `SnackBar` `errorGameFull`, a tela relê, e o pé passa a **Entrar na lista de espera** |
| S47 | Detalhe | Relógio entre o início e o fim, Bruno na lista, Sair; relógio depois do fim | Selo `gameInProgress` e confirmação com `gameLeaveAfterStartBody`; selo `gameAwaitingCompletion` e aviso `gameListLocked`, sem botão |
| S48 | Detalhe | Ana admin antes do início; depois do início; antes do início, tocar no Bruno, Remover e confirmar; tocar na própria linha | Menu com **Editar jogo**, **Admins do jogo** e **Cancelar jogo**; sem **Editar jogo**; `remove_participant` e `gameParticipantRemoved`; nada acontece |
| S49 | Detalhe | **Cancelar jogo** e confirmar | `cancel_game`, `gameCancelled`, a tela relê, o topo diz "Cancelado" e o pé fica vazio |
| S50 | Detalhe | Lista com Ana (recebedora e admin), Bruno (saiu após o início) e Carla; espera com Edu e Diego | Numeração 1 a 3 pela entrada; selos **Recebedor** e **Admin** na Ana e "Saiu após o início" no Bruno; "Lista · 3 de 3"; espera com "1º na espera" e "2º na espera" |
| S51 | Detalhe | O dublê do Realtime emite um evento | O repositório é lido de novo, sem `SnackBar` |
| S52 | Detalhe | O repositório não acha o jogo | Estado "não encontrado" |
| S53 | Editar jogo | 3 ocupadas e limite 4; mudar o limite e o local e salvar; mudar só o local; `set_slot_limit` aceito e `update_game` com erro; Bruno, não admin, abre a rota | − desabilitado no 3, com `gameSlotsOccupiedHint`; `set_slot_limit` antes de `update_game`, e `gameSaved`; só `update_game`; `SnackBar` com a tela aberta; estado "não encontrado" |
| S54 | Admins do jogo | Ana e Bruno admins, Bruno fora da lista; **Adicionar admin**; adicionar a Carla; remover o Bruno; Ana deixa de ser admin e confirma | Subtítulos "Na lista" e "Fora da lista"; a sheet lista a Carla (na lista) e não o Edu (na espera); `add_game_admin` e `gameAdminAdded`; `remove_game_admin` e `gameAdminRemoved`; volta ao detalhe com `gameAdminSteppedDown` |
| S55 | Detalhe do grupo | Dois jogos Abertos e um cancelado do grupo; tocar em **Criar jogo**; grupo sem jogos | **Próximos jogos** com os dois cards; abre `/games/new` com o grupo; `groupGamesEmpty` |
| S56 | Detalhe do grupo | Sair e confirmar, com `games_left` de dois jogos; outro caso com `MEMBER_IS_RECEIVER` e dois `game_ids`; tocar num card da sheet | A confirmação tem `groupLeaveGamesBody`, e o `SnackBar` é `groupLeftWithGames` com "2 jogos"; sheet com `groupLeaveBlockedTitle`, `groupBlockedReceiverBody` e os dois cards; abre o detalhe do jogo |
| S57 | Integrantes | Remover o Bruno, com `MEMBER_IS_ONLY_GAME_ADMIN` | Sheet com `groupRemoveBlockedTitle` e `groupRemoveBlockedOnlyAdminBody`, com "Brunão" |
| S58 | Perfil de outra pessoa | `get_profile_contact` devolve `+5586999998888`; tocar em **Ligar** e em **WhatsApp**; devolve nulo | Linha **Telefone** com `(86) 99999-8888`; o dublê do `url_launcher` recebe `tel:+5586999998888` e `https://wa.me/5586999998888`; sem a linha |
| S59 | Todas as telas da seção 7 do `telas.md` e as sheets | Fonte do sistema em 150% | Nenhum *overflow* |
| S60 | Meus jogos, detalhe, criação e Admins do jogo | Leitura pelo TalkBack (`Semantics`) | Card com `gameCardLabel`; botões `gameMenuLabel`, `gameOpenMaps`, `gameSlotLimitDecrease` e `gameSlotLimitIncrease` com rótulo e área de 48 × 48 |

**Fluxos**, testes de integração no emulador (API 29 e 36) contra o Supabase local com o seed, pelos `scripts/` (`setup.md`, 3.1). Cada fluxo deixa o que se vê no seed como encontrou:

| ID | Dado | Quando | Então |
|----|------|--------|-------|
| L15 | Ana logada | No Vôlei de Quinta, toca em **Criar jogo**, cria o jogo `L15 <data e hora>` para depois de amanhã, com limite 2; abre o detalhe; cancela o jogo | O jogo aparece em **Próximos jogos** do grupo e em Meus jogos. O detalhe mostra a Ana na lista, com os selos **Recebedor** e **Admin**, e a chave Pix dela. Depois de cancelado, o jogo sai de Próximos e aparece em **Anteriores** |
| L16 | Bruno logado | No Quinta Aberto do seed, entra na lista e sai antes do prazo; no Quinta Confirmado, em que ele está na espera, sai da espera e entra de novo | O Brunão aparece e some da lista, com `gameJoined` e `gameLeftOnTime`; a lista de espera some e volta como "Lista de espera · 1" |
| L17 | Ana logada, no detalhe do Quinta Aberto do seed | O teste, com um cliente Supabase separado logado como Carla, chama `join_game` e depois `leave_game` | A Carlinha aparece na lista em até 5 s sem puxar a tela, e some depois (Realtime) |
| L18 | Ana logada | Edita o local e o limite do Quinta Confirmado do seed (de 2 para 3) e depois devolve os valores; em **Admins do jogo**, torna a Carla admin e depois a remove | O detalhe mostra o local novo e "Lista · 2 de 3", com o status Aberto; depois, os valores do seed e o status Confirmado. A Carlinha aparece e some na lista de admins |
| L19 | Carla logada | Tenta sair do Vôlei de Quinta; toca no card da sheet | Sheet de bloqueio com `groupBlockedReceiverBody` e o jogo da Carla; abre o detalhe dele. Carla continua no grupo |

**Conferência manual**, no celular, com o build da produção:

| ID | O que conferir |
|----|----------------|
| M06 | RNF04: do toque no card de um jogo até a lista visível, em até 2 s em ao menos 9 de 10 medições, com a internet 4G do celular |
| M07 | **Abrir no Maps** abre o Google Maps no local do link; **Ligar** abre o discador com o número; **WhatsApp** abre a conversa com o número |

## 13. Rastreabilidade

| Regra | Cenários |
|-------|----------|
| RN01 | B13, D09 a D15 |
| RN02 | B14 |
| RN04 | B11, B12, D01 a D08 |
| RN13 | B29 a B33, G20, G24, G25, S26, S31 |
| RN25 | B34 a B36 |
| RN02, RN03 | T01 a T10 |
| RN35 | T16 |
| RN44, RN45, RN46 | T11 a T15, C08 |
| RN47, RN49 | F01 a F05 |
| RN53, RN54 | C01 a C07 |
| RN56 | I08, I09 |
| RN58, RN59 | F12, F14, I11 |
| RN62 | I01 a I12 |
| RN63 a RN66 | F01 a F11, C09 |
| RN71 a RN75 | R01 a R10 |
| RN30, RN31, RN32, RN94 | V01 a V11, C12 |
| RN89 | C10 |
| RN100 | P02, S17 |
| RN101 | S12 |
| RN105 | N01 a N09, S13 |
| RN106 | A01 a A06, S12, G04, G05, A07, A08, A12, A13, S21, S33 |
| RF105 | P10 a P13, S09, S10, L08 |
| RN10 | G01, G19, G28, S31, L14 |
| RN11 | G01, G07 a G10, S27 |
| RN12 | G11 a G18, C13, C15, Q03, S23, S24, S32, L12 |
| RN17 | G30 a G33, S33, L13 |
| RN107 | K07 a K14, A09 a A11, Q01, Q06, S34, W01 a W08, W12 |
| RN14, RN16 | H01 a H10, C16, S56, S57, L19 |
| RN20 a RN23 | J01 a J08, J12, S38 a S41, L15 |
| RN25 a RN27 | J17 a J21, S54, L18 |
| RN29 | O11, O19, S44, L19 |
| RN33, RN34 | J09 a J12, O23, S53, L18 |
| RN40 a RN43 | J03, J14, J15, O02, O08, O20, O21, S49, L15 |
| RN50 a RN54 | O01 a O07, O15, O16, C01 a C07, S42, S45, S46, L16, L17 |
| RN57 a RN59 | O08 a O13, O17 a O23, S43, S47, S48 |
| RN101, RN102 | W08 a W12, S44, S58, M07 |
