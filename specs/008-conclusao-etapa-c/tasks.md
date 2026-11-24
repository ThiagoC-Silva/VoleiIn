# Tasks: Conclusão, multas e rateio, etapa C (fatia 5)

**Input**: `specs/008-conclusao-etapa-c/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 7 e 13, linha C.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `change_receiver(uuid,uuid)`
- [x] T002 [P] [US1] [US2] Z10 a Z15 em `completion_functions.test.sql`
- [x] T003 [P] [US1] [US2] V01 a V11 em `completion_split.test.sql`, com as notas de "Em todos" da seção 7
- [x] T004 [P] [US2] Y04 em `completion_security.test.sql`
- [x] T005 Saída da falha e *commit* só de testes
- [x] T006 Migração `create_change_receiver` (research R1 a R5)
- [x] T007 Seed com o jogo "Quinta com troca" (R7)
- [x] T008 Comandos verdes, documentos e PR

**Sessão 2 concluída em 19/11/2026** no *branch* `fatia-5/servidor-c`: `supabase test db` (779 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` (15 testes) verdes. Testes antes no *commit* `24c31d0`, com a saída da falha; o Y04 já passava, porque o recorte vem das políticas da etapa A (FR-003). Depois dele, só ajustes de estrutura, sem resultado esperado alterado: nomes de coluna no `set_eq` do Z15d (o pgTAP recusa coluna sem nome repetida) e `delete from public.receiver_changes` na limpeza do seed de sete arquivos das fatias 2 a 4, porque o seed passou a ter uma troca de recebedor.

- **Seed:** a research R7 dizia que o seed não mudava, mas a tabela de dados do `setup.md` (seção 8) pede uma troca de recebedor na etapa C. Ganhou o jogo "Quinta com troca" (`...0211`), no local "Quadra da Lagoa", para não repetir a "Arena Delta" que o L19 procura pelo texto.
- **Y04:** o Isento da Carla continua devido à Ana, e ela o vê (research R8). A linha foi acrescentada ao Y04 do `testes-referencia.md`.
- **`setup.md`:** a dica do `deno test` passou a citar o `SUPABASE_JWT_SECRET`, que os testes de concorrência pedem.

## Sessão 3 — App

- [x] T009 Testes antes: S72 a S76, E15, L22
- [x] T010 Troca de recebedor e aba Cobranças (`docs/ui/telas.md`, seção 8)
- [x] T011 `dart format`, `dart analyze` e `flutter test` verdes

**Sessão 3 concluída em 19/11/2026** no *branch* `fatia-5/app-c`: `dart analyze` e `flutter test` (552 testes) verdes. Testes antes no *commit* `de3918c`, com a saída da falha (22 testes vermelhos). Depois dele, só ajustes de forma no `charges_screen_test.dart`, sem resultado esperado alterado: os valores passaram a vir do `formatCents` (o espaço depois do `R$` é sem quebra), o teste rola até a seção A receber, que fica abaixo da dobra, e saiu a conferência de que o texto provisório sumiu, porque a chave saiu do ARB. Os testes novos estão em `app/test/features/games/presentation/game_receiver_test.dart`, `app/test/features/splits/presentation/charges_screen_test.dart` e nos testes de erro (E15).

- **Troca de recebedor:** a sheet fica em `receiver_change_sheet.dart`, aberta pela opção **Trocar recebedor** do menu do admin, que aparece com o jogo Aberto, Confirmado ou Concluído. A confirmação tem só o título, como no briefing, e o `confirmAction` ganhou o corpo opcional.
- **Cobranças:** `fetchMyCharges` lê os valores `pending` e `under_review` em que a pessoa é o pagador ou o recebedor; o `ChargesOverview` (`charge_models.dart`) agrupa e soma, só com inteiros. "de {n} pessoas" conta as pessoas diferentes em todos os jogos. As linhas abrem o Rateio pela aba Jogos.
- **Contador da aba:** a barra inferior lê o mesmo `myChargesProvider`, que relê ao tocar na aba e junto com Meus jogos. O TalkBack lê `chargesTabBadgeLabel` junto com o nome da aba.
- **Textos da fatia 5:** `gameReceiverCannotLeave`, `groupBlockedReceiverBody` e `groupRemoveBlockedReceiverBody` (`docs/copy.md`, 8.3 e 8.6). As chaves provisórias `placeholderTitle` e `placeholderBody` e o `PlaceholderTab` saíram, porque Cobranças era a última aba vazia (`docs/ui/telas.md`, 4.2).
- **L22:** em `integration_test/receiver_flow_test.dart`. Como o L20 e o L21, usa o jogo do seed "Quinta aguardando conclusão" (`...0209`): a Ana o conclui pela API antes de abrir o app, se o `pg_cron` ainda não o concluiu. Rode logo depois de um `supabase db reset`, sem o L20 e o L21. Na API 36, a primeira rodada falhou depois da troca, que já tinha sido gravada, sem a causa guardada; as três seguintes, cada uma depois de um `db reset`, passaram. A rodada das APIs 29 e 36 é a T012.

## Sessão 4 — Validação

- [x] T012 L22 nas APIs 29 e 36
- [x] T013 Ensaio e `supabase db push`; advisors

**Sessão 4 concluída em 24/11/2026** no *branch* `fatia-5/validacao-c`.

- **L22:** a primeira rodada na API 36 falhou como na sessão 3, desta vez com a causa: depois do `change_receiver`, o app não relia nada. `gameActionsControllerProvider` é `autoDispose`, e no jogo concluído, sem rodapé, ninguém o observava: ele era descartado durante a chamada, e as releituras eram puladas. Só o Realtime atualizava o detalhe, quando estava conectado. A tela do jogo passou a observá-lo, como o Rateio já fazia. Teste que reproduz o bug: "a troca relê o detalhe e Cobranças, sem o Realtime", em `game_receiver_test.dart`, vermelho antes da correção. `flutter test`: 553 verdes.
- Depois da correção, com um `db reset` antes de cada rodada: 3 verdes na API 36 (uma quarta não chegou a começar, com `Connecting to the VM Service timed out`, `docs/setup.md`, seção 11) e 2 verdes na API 29.
- **Ensaio e produção:** `docs/setup.md`, 9.11, com o M08.
- **Em aberto:** o C16 (fatia 4) falhou em 1 de 2 rodadas completas do `deno test` e passou em 35 isoladas. Quando a saída do grupo vence a corrida, `join_game` devolve `NOT_FOUND`, como diz `contratos-api.md` (quem não pode ver o jogo), e o C16 espera `NO_GAME_ACCESS`. Os documentos divergem: a decisão é do responsável.
