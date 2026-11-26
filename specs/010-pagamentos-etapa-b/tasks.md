# Tasks: Pagamentos, etapa B (fatia 6)

**Input**: `specs/010-pagamentos-etapa-b/`. **Tests**: antes do código, com os resultados de `docs/testes-referencia.md`, seções 8 e 14, linha B, e da seção 7 do `docs/comprovantes-ia.md`.

## Sessão 2 — Servidor

- [x] T001 [P] B03, B04, B06 e B10 com as linhas da etapa B
- [x] T002 [P] [US1] CP01 a CP24 em `receipt_rules.test.sql`
- [x] T003 [P] [US2] RV01 a RV06 em `receipt_rules.test.sql`
- [x] T004 [P] [US3] RS01 a RS05 e RS09 em `receipt_security.test.sql`; RS06 a RS08 em `_tests/receipts_test.ts`
- [x] T005 [P] [US1] NM01 a NM05 em `process-receipt/normalize_test.ts`
- [x] T006 [US1] `scripts/receipt-fixtures.py` e os arquivos de CF01 a CF26 (research R10)
- [x] T007 [US1] PR01 a PR10 e CF01 a CF26 em `process-receipt/index_test.ts`, com o dublê da Claude API
- [x] T008 [P] [US1, US2] C10 a C12 e C18 em `concurrency/payments_test.ts`
- [x] T009 Saída da falha e *commit* só de testes
- [x] T010 Migração `receipts_rls` (research R6)
- [x] T011 Migração `create_receipt_functions` (research R1 a R5)
- [x] T012 `process-receipt`: prompt, schema, normalização, handler e `index.ts` (research R7 a R9)
- [x] T013 Seed com o jogo de comprovantes (research R12)
- [x] T014 `deno task receipts:live` e a medição dos três modelos, com o OK do responsável para o gasto (research R11)
- [x] T015 Comandos verdes, documentos e PR

**Sessão 2 concluída em 25/11/2026** no *branch* `fatia-6/servidor-b`: `supabase test db` (905 testes), `supabase db lint`, `deno fmt --check`, `deno lint`, `deno check` e `deno test --allow-net --allow-env --allow-read` (28 testes, 60 passos) verdes. Testes antes no *commit* "Testes da etapa B da fatia 6 no servidor, antes do código", com a saída da falha. Depois dele, sem resultado esperado alterado, um ajuste de montagem: o RS01b e o RS02 deixaram de comparar arrays de arrays vazios, que o Postgres reduz a `{}`. Antes do *commit*, o B06c já tinha passado a conferir só a `record_receipt`, porque a `service_role` executa também a `auto_complete_due_games()` pelos privilégios padrão.

- **Migrações:** `receipts_rls` e `create_receipt_functions` (research R1 a R6).
- **Edge Function** `process-receipt`, com `handler.ts`, `prompt.ts` (versão 1), `normalize.ts` e o `index.ts`, `verify_jwt = false` no `config.toml` e o SDK `@anthropic-ai/sdk@1.14.0`. O CI passou a rodar o `deno test` com `--allow-read`, para ler o conjunto fixo, e a checar os tipos da função.
- **Conjunto fixo:** os 26 comprovantes sintéticos de `scripts/receipt-fixtures.py`, sem nome nem logotipo de banco.
- **Medição (T014):** com o OK do responsável para medir só o Haiku 5.5, três execuções seguidas com a API real, as três no critério da seção 7: nenhuma aprovação indevida, e só o CF09 (ID quebrado em duas linhas) para análise. Mediana de 1,8 s, máximo de 5,3 s e US$ 0,00057 por leitura, US$ 0,04 no total. `RECEIPT_MODEL=claude-haiku-5-5` no `supabase/functions/.env`. O Opus e o Sonnet ficam sem medição (`comprovantes-ia.md`, seção 9).
- **Alerta de gasto:** a Console ofereceu a notificação por valor, ativa em US$ 4 (`comprovantes-ia.md`, seção 10).
- **Seed:** "Quinta com comprovantes" (`...0212`, `JogoCompr001`), com comprovantes nos três status (research R12). Os testes pgTAP que limpam o seed apagam também `receipts`.
- **Para a sessão 4:** a chave `voleiin-prod` (responsável), `RECEIPT_MODEL` na produção, o ensaio, o `db push` e o deploy da `process-receipt`. Nos fluxos L24 e L25, o `supabase functions serve` precisa de `ANTHROPIC_BASE_URL` apontando para um dublê da API, que ainda não existe fora do teste Deno.

## Sessão 3 — App

Os PNGs de comprovante já estão em `docs/ui/referencias/fatia-6/` (`charge-enviar*`, `charge-analise`, `charges-conferir`, `receipt*`).

- [x] T016 Testes antes: U14, S77 a S83, S84 (**Conferir comprovante**), S85 (**Para conferir**), S88, S89, E15, L24, L25
- [x] T017 Telas de comprovante (`docs/ui/telas.md`, seção 9)
- [x] T018 `dart format`, `dart analyze` e `flutter test` verdes

**Sessão 3 concluída em 26/11/2026** no *branch* `fatia-6/app-b`: `dart format`, `dart analyze` e `flutter test` (668 testes) verdes. Testes antes no *commit* "Testes da etapa B da fatia 6 no app, antes do código", com a saída da falha. Depois dele, sem resultado esperado alterado, dois ajustes de montagem: o S85 rola até o título de A pagar, que o `ListView` não monta fora da tela, e o compara com a última linha de **Para conferir**; o S77 "Em análise" procura o selo dentro do `ReceiptStatusBadge`, porque o selo do valor no topo tem o mesmo texto. As consultas novas foram conferidas contra o Supabase local, com o seed "Quinta com comprovantes" (Ana, Bruno e Carla).

- **App:** `ReceiptsRepository` (leitura de `receipts`, URL assinada de 10 min, envio ao bucket, `process-receipt` com 45 s de espera e `review_receipt`), `ReceiptPicker` (`image_picker` a 2.576 px e `file_picker` 13.4.1, só `.pdf`), a sheet Enviar comprovante, a tela Comprovante (`/receipts/:receiptId`, na aba Cobranças), os comprovantes e **Enviar comprovante** no valor a pagar, **Para conferir** em Cobranças e **Conferir comprovante** no Rateio. Tipo e tamanho do arquivo são conferidos antes do envio (`ReceiptFile.fromPicked`); o conteúdo, pelo servidor.
- **Decisões de montagem:** a sheet de envio desliga o arrasto e desenha a alça, porque o arrasto da alça fecha a sheet sem passar pelo `PopScope` da leitura (RN86). A tela do comprovante relê, ao voltar, Cobranças, o valor a pagar e o Rateio. O gerador de UUID das fotos virou `core/uuid.dart`, usado também no caminho do comprovante. `chargeProvider` e `gameSplitProvider` foram para `games_providers.dart`.
- **Textos novos** no `copy.md` (10.2 e 10.3): `receiptReadDateTime` e o formato do tamanho do PDF.
- **Para a sessão 4 (L24 e L25):** os dois fluxos usam o jogo "Quinta aguardando conclusão" (`...0209`), cada um logo depois de um `db reset`, como o L20 a L23. O dublê da Claude API do `functions serve` (`ANTHROPIC_BASE_URL`) responde pela imagem enviada: a `legibleReceipt` do teste (PNG branco de 2 × 2) tem a leitura boa do valor do Bruno (R$ 30,00, a chave da Ana, a hora atual e um código do Pix novo a cada chamada); a `illegibleReceipt` (PNG preto de 2 × 2), os seis campos nulos.

## Sessão 4 — Validação

- [ ] T019 L24 e L25 nas APIs 29 e 36
- [ ] T020 M09 com a API real e o build da produção
- [ ] T021 Chave `voleiin-prod`, `RECEIPT_MODEL` na produção, ensaio, `supabase db push`, deploy da `process-receipt`; advisors
