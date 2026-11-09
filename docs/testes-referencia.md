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

**Ficam para o ciclo de cada fatia:** a máquina de estados do jogo (RN40 a RN45) e do valor a pagar (RN80 a RN94), as regras de conta (RN103, RN105), o RLS de cada tabela e os comprovantes.

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
| B05 | Como `postgres`, o teste cria uma tabela e uma função novas em `public` | Consulta os privilégios delas | `anon`, `authenticated` e `public` sem privilégio algum, inclusive sem `execute` na função |
| B06 | Banco após reset | Lista as funções de `public`, fora as de extensões, que `anon` ou `authenticated` podem executar | Igual à lista esperada. Na fatia 1, vazia |
| B07 | Idem | Consulta `usage` de `anon` e `authenticated` no esquema `private` e `execute` em `private.emit_notification` | Falso em todos |
| B08 | Usuário autenticado (`role authenticated` com o `sub` de um usuário de teste) | `select` em `profiles` e `insert` em `notifications` | Erro `42501` nos dois |
| B09 | Banco após reset | Lê `storage.buckets` | `avatars` e `receipts` existem, com `public = false` e os tamanhos e tipos da `rls-matriz.md` (seção 3) |
| B10 | Usuário autenticado | `insert` em `storage.objects`, bucket `avatars`, caminho `profiles/<uid>/x.png` | Recusado pelo RLS. Nenhuma política de `storage.objects` cita `avatars` ou `receipts` |

### 9.2 Estrutura e *triggers*

pgTAP, em `supabase/tests/database/base_schema.test.sql` e `base_triggers.test.sql`. Os testes das invariantes de admin usam `set constraints all immediate` para disparar na hora a checagem adiada para o fim da transação.

**Tipos (RN01, RN02, RN04)**

| ID | Regra | Quando | Então |
|----|-------|--------|-------|
| B11 | RN04 | Lista as colunas de `public` do tipo `real`, `double precision`, `numeric` ou `money` | Lista vazia |
| B12 | RN04 | Lista as colunas de `public` terminadas em `_cents` | Todas `integer` |
| B13 | RN01 | Lista as colunas de `public` do tipo `timestamp without time zone`, `time` ou `timetz` | Lista vazia |
| B14 | RN02 | Lista as colunas `created_at` de `public` | Todas `not null`, com padrão `now()` |

**Perfil.** O perfil e o `profile_private` nascem juntos quando o e-mail fica confirmado: na confirmação do link (cadastro por e-mail) ou no próprio cadastro (Google, que já chega confirmado). O nome vem de `name` e, sem ele, de `full_name` nos metadados. Sem nenhum dos dois, vem do início do e-mail (`modelo-dados.md`, `profiles`).

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
| E06 | `AuthException` com um código que a fatia 1 não mapeia (`weak_password`) | `internalError` |
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

## 10. Rastreabilidade

| Regra | Cenários |
|-------|----------|
| RN01 | B13, D09 a D15 |
| RN02 | B14 |
| RN04 | B11, B12, D01 a D08 |
| RN13 | B29 a B33 |
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
