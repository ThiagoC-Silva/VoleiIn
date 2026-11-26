# Tasks: Pagamentos, etapa A (fatia 6)

**Input**: `specs/009-pagamentos-etapa-a/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 8 e 14, linha A.

## Sessão 2 — Servidor

- [x] T001 [P] B06 com `mark_charge_paid(uuid)` e `revert_charge(uuid)`
- [x] T002 [P] [US1] PG01 a PG03 em `payment_functions.test.sql`
- [x] T003 [P] [US2] PG04 a PG07 em `payment_functions.test.sql`
- [x] T004 [P] [US1] C09 em `concurrency/payments_test.ts`
- [x] T005 Saída da falha e *commit* só de testes
- [x] T006 Migração `create_manual_payment` (research R1 a R5)
- [x] T007 Seed com o valor Pago da Carla (R6)
- [x] T008 Comandos verdes, documentos e PR

**Sessão 2 concluída em 24/11/2026** no *branch* `fatia-6/servidor-a`, criado a partir do `fatia-6/docs` (PR #31, ainda aberto): `supabase test db` (813 testes), `supabase db lint`, `deno fmt --check`, `deno lint` e `deno test` (16 testes) verdes. Testes antes no *commit* "Testes da etapa A da fatia 6 no servidor, antes do código", com a saída da falha. Depois dele, só um ajuste de estrutura, sem resultado esperado alterado: o PG07, último do arquivo, saiu do *savepoint*, porque o `finish()` do pgTAP recusa um arquivo em que todos os testes voltam atrás.

- **Decisão do responsável (24/11/2026):** `revert_charge` recusa o pagador que virou o recebedor do jogo (research R4). RN85, contrato e PG07 atualizados.
- **Auxiliares novos**, em `private` e sem `execute` para o app: `lock_charge`, que a `review_receipt` da etapa B pode usar, e `payment_notification_data`.
- **Seed:** o `share` da Carla no Quinta concluído fica Pago (R6).

## Sessão 3 — App

Precisa do `charge.png` em `docs/ui/referencias/fatia-6/`.

- [x] T009 Testes antes: S77 (sem comprovantes), S84 (sem **Conferir comprovante**), S85 (sem **Para conferir**), S88, S89, E15, L23
- [x] T010 Valor a pagar e ações no Rateio (`docs/ui/telas.md`, seção 9)
- [x] T011 `dart format`, `dart analyze` e `flutter test` verdes

**Sessão 3 concluída em 25/11/2026** no *branch* `fatia-6/app-a`: `dart analyze` e `flutter test` (591 testes) verdes. Testes antes no *commit* `5e12dab`, com a saída da falha. Os testes novos estão em `charge_screen_test.dart` (S77, S88, S89), `game_payments_test.dart` (S84, S88, S89), `charges_screen_test.dart` (S85) e nos de `core/errors` (E15). O L23 está em `integration_test/payments_flow_test.dart` e roda na sessão 4.

- **Decisões do responsável (25/11/2026):** o S77 espera **Pagar para** com "Ana", e do S84 **Conferir comprovante** fica para a etapa B (`docs/testes-referencia.md`, seção 14). Os PNGs da fatia inteira chegaram. A fonte dos números neles é outra: vale a do `design-system.md` (Bebas Neue).
- **Testes da fatia 5 substituídos:** o caso "Ana toca num `share`" do S70, pelo S84 (o teste passou a usar o Edu, admin que não recebe), e o toque na linha de A pagar do S74, pelo S85.
- **Valor a pagar:** `features/payments/presentation/charge_screen.dart`, com `fetchCharge` no `GamesRepository`, que filtra pelo pagador: o RLS também mostra o valor ao recebedor e aos admins do jogo.
- **Rateio:** a sheet de isentar virou a das ações do valor (9.5). **Devidos a você** mostra todos os valores devidos ao antigo recebedor, inclusive os Isentos. Na linha da própria pessoa, a sheet não tem **Ver perfil**.
- **Compartilhado:** o botão circular e a pílula do grupo do topo foram para `shared/widgets/hero_parts.dart`, e o selo **Em análise** ganhou a ampulheta do `design-system.md` (seção 4).
- **Divergência a resolver:** o `design-system.md` (seção 5) diz que o valor no topo usa `number.hero` (84). A seção 7.8 e o `telas.md` (9.2) dizem `number.xl` (56), que é o que a tela usa.

## Sessão 4 — Validação

- [x] T012 L23 nas APIs 29 e 36
- [x] T013 Ensaio e `supabase db push`; advisors

**Sessão 4 concluída em 25/11/2026** no *branch* `fatia-6/validacao-a`.

- **Máquina de 20 GB:** com o OK do responsável, ganhou o JDK 21 e o SDK do Android sem `sudo`, em `~/development` e `~/Android/Sdk`, com os AVDs `voleiin_api29` e `voleiin_api36` do `setup.md` (seção 3). O primeiro build passou do `timeout 900` do script, e o `local.json` dela não tinha o `GOOGLE_WEB_CLIENT_ID` (`setup.md`, seção 11, com as duas linhas novas).
- **L23:** verde na primeira rodada válida, com um `db reset` antes de cada uma: API 36 (34 s) e API 29 (29 s). Nenhum código mudou.
- **Ensaio e produção:** `docs/setup.md`, 9.12.
- **Decisão do responsável (25/11/2026):** o valor no topo do valor a pagar fica em `number.xl` (56), como estão a tela, a seção 7.8 e o `telas.md` (9.2). A tabela da seção 5 do `design-system.md` foi corrigida, e `number.hero` (84) ficou para o valor da própria pessoa no bloco do Rateio, como no `gameSplit.png` e no código.
- **Divergência a resolver:** o `telas.md` (8.3) diz que esse valor do Rateio usa `number.md` (26). O PNG e o código usam 84.
