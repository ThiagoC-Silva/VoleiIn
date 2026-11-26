# Research: etapa B da fatia 6

## R1. Quem confere o quê entre `process-receipt` e `record_receipt`

**Problema:** o PR03 espera `NOT_FOUND` para "outra pessoa do jogo, sem ver o valor", e o CP22 espera `NOT_CHARGE_PAYER` para `record_receipt` chamada com o Bruno, que também não vê o valor do Fábio.

**Decisão:** a visibilidade é conferida na Edge Function, que lê o valor com o JWT de quem chama, pelo RLS de `charges` (fatia 5). Sem a linha, `NOT_FOUND`. `record_receipt` roda como `service_role` e recebe o pagador como parâmetro: confere só a existência (`NOT_FOUND`), o pagador (`NOT_CHARGE_PAYER`), o estado (`CHARGE_NOT_PENDING`) e a entrada (`INVALID_INPUT`), nessa ordem (`contratos-api.md`, seção 1). Os dois cenários ficam como estão.

## R2. Bloqueio e ordem de `record_receipt`

**Decisão:** lê o `game_id` do valor sem bloquear, bloqueia o jogo (`for update`) e depois o valor, e relê tudo depois do bloqueio, como `private.lock_charge` (etapa A). Não usa `lock_charge` nem `lock_game`, que conferem quem chama pelo `auth.uid()`. O recebedor usado é o `charges.receiver_id` relido (RN32, C12), com o nome e a chave **atuais** dele.

**Entrada** (`INVALID_INPUT`): o caminho no formato `{charge_id}/{uuid}.{ext}`, com a pasta igual ao valor e sem subpasta; o caminho sem comprovante (índice único parcial em `storage_path`, também capturado na corrida); o `mime_type` e o tamanho da RN87; `outcome` entre os quatro; e, na leitura, os campos já no formato da normalização (`paid_at` `AAAA-MM-DDTHH:MM` com data que existe, `transaction_id` da RN88d, valor positivo). A Edge Function só manda o que normalizou: um campo fora disso é erro de programa, e não leitura nula.

## R3. Conferência e resultado

**Decisão:** como o `comprovantes-ia.md`, seção 5, em funções `private` `immutable`:
- `private.normalize_pix_key(p_type, p_key)`: CPF e CNPJ sem nada além de letras e números e em maiúsculas; e-mail e aleatória em minúsculas, com `trim`; telefone só com os dígitos, com `+55` à frente quando ficam 10 ou 11, e com `+` nos outros casos.
- `private.name_words(p_name)`: maiúsculas, sem acentos (`normalize(..., NFD)` sem as marcas `U+0300` a `U+036F`), o que não é letra vira espaço, e as palavras.
- **ID repetido primeiro**, com o comprovante `approved` ou `under_review` de outro valor (RN89): `rejected`, `duplicate_transaction`, `decided_at = now()`. O valor não muda e não há evento nem notificação. Em `validation`, `transaction_id` fica `false`: o ID foi lido e não está livre. As outras três chaves são as da conferência.
- Depois, as quatro `true` dão `approved`. Qualquer `false` ou nula dá `under_review`.
- **Sem leitura** (`failed`, `skipped_limit`, `skipped_file`): as quatro chaves nulas e `skipped` (`api_failed`, `read_limit`, `file_not_supported`).

## R4. Leituras usadas e corrida do ID

**Decisão:**
- `outcome = read` soma 1 a `auto_reads_used`, até 3, mesmo na recusa por ID repetido (RN86, CP15). Os outros não somam.
- **Corrida (C10):** a gravação do comprovante, do valor, do evento e das notificações fica num bloco `begin ... exception when unique_violation`. Se `receipts_transaction_id_idx` recusa, o bloco volta atrás, e a função grava o comprovante `rejected` por ID repetido, como na conferência. Se quem recusa é o índice de `storage_path`, devolve `INVALID_INPUT`.

## R5. `review_receipt`

**Decisão:** lê o valor do comprovante, bloqueia o jogo, o valor e o comprovante, nessa ordem, e relê. A ordem das validações:
1. autenticação;
2. existência: o comprovante existe e quem chama é o pagador ou o `receipts.receiver_id` dele, senão `NOT_FOUND` (RF87: os admins não o veem);
3. papel: não é o `receiver_id`, `NOT_CHARGE_RECEIVER`;
4. estado: não está `under_review`, `RECEIPT_NOT_UNDER_REVIEW`;
5. entrada: a observação com `trim`. Na recusa, vazia ou nula é `RECEIPT_NOTE_REQUIRED`. Com mais de 200 caracteres, `INVALID_INPUT`, nos dois casos. Na aprovação, vazia vira nula.

A troca de recebedor fica bloqueada enquanto houver valor Em análise (`RECEIVER_CHANGE_BLOCKED`, fatia 5), então o `receiver_id` do comprovante é o do valor.

## R6. RLS e Storage

**Decisão:** como a `rls-matriz.md`, fatia 6, só as linhas da etapa B: `private.is_active_account`, `private.can_upload_receipt`, `private.can_read_receipt_file`, `grant select on receipts`, `receipts_select_party`, e as políticas `receipts_insert_payer` e `receipts_select_party` em `storage.objects`. O nome do arquivo segue `^{uuid}/{uuid}\.(jpg|jpeg|png|webp|heic|pdf)$`, e só então a pasta vira `uuid`. As auxiliares têm `execute` para `authenticated`, porque as políticas rodam com o papel de quem chama, como as das fatias anteriores. B03, B04, B06 e B10 ganham as linhas da etapa. O B06 confere que `record_receipt` não é executável por `anon` nem `authenticated`, e que é por `service_role`.

## R7. Edge Function: forma e dublê

**Decisão:**
- `process-receipt/handler.ts` exporta `createHandler(deps)`, com o cliente do Supabase com a chave de serviço, o cliente da Claude API (`@anthropic-ai/sdk`, versão exata no `deno.json`), o modelo e o relógio. `index.ts` monta os dois pelo ambiente e chama `Deno.serve`. Sem `ANTHROPIC_API_KEY` ou `RECEIPT_MODEL`, a leitura é `failed`, com log de erro.
- **Dublê:** um servidor HTTP local que imita `/v1/messages` e `/v1/messages/count_tokens`, em `process-receipt/test_support.ts`. Os testes criam o cliente do SDK com o `baseURL` dele. É o mesmo caminho do `ANTHROPIC_BASE_URL` dos fluxos L24 e L25 (`testes-referencia.md`, 14.8): a função não tem leitura falsa, e o PR01 confere o pedido que chegou à API.
- `verify_jwt = false` no `config.toml`, como a `preview-invite`: o JWT é conferido dentro (`auth.getUser`), e o PR02 espera a resposta de erro do contrato. Conta com `profiles.deleted_at` preenchido é `NOT_AUTHENTICATED`.

## R8. Ordem da Edge Function

**Decisão:**
1. `POST`; JWT (`401 NOT_AUTHENTICATED`); corpo com `charge_id` `uuid` e `storage_path` texto (`422 INVALID_INPUT`).
2. O valor lido com o JWT de quem chama (R1): sem linha, `404 NOT_FOUND`; outro pagador, `403 NOT_CHARGE_PAYER`; fora de Pendente, `409 CHARGE_NOT_PENDING`, sem baixar o arquivo nem chamar a API (PR04).
3. Caminho fora do formato ou de outro valor, `422 INVALID_INPUT`. Caminho já usado, também, por `record_receipt`.
4. Baixa o arquivo com a chave de serviço. Sem arquivo, `422 RECEIPT_FILE_NOT_FOUND`. Acima de 10 MB, `422 RECEIPT_TOO_LARGE`. O tipo gravado fora da RN87, ou os primeiros bytes de outro tipo, `422 RECEIPT_TYPE_INVALID` (PR06).
5. `auto_reads_used >= 3`: `skipped_limit`. HEIC: `skipped_file`. PDF: contagem de tokens; acima de 20.000, `skipped_file`. Senão, a leitura.
6. `record_receipt`, com os erros dela convertidos no HTTP do catálogo.

**Primeiros bytes:** JPEG `FF D8 FF`; PNG `89 50 4E 47 0D 0A 1A 0A`; WebP `RIFF` e `WEBP` no byte 8; PDF `%PDF-`; HEIC `ftyp` no byte 4 com a marca `heic`, `heix`, `hevc`, `hevx`, `heim`, `heis`, `mif1` ou `msf1`.

## R9. Pedido, tempo e tentativas

**Decisão:** o pedido da seção 3 do `comprovantes-ia.md`, com o SDK em `maxRetries: 0` e a repetição feita pela função: um prazo de 25 s para a contagem, a leitura e a repetição juntas, por um `AbortSignal`, e uma repetição só para 429, 5xx ou erro de conexão, com pelo menos 12 s restantes. A resposta: `stop_reason` primeiro (`refusal` e `max_tokens` são falha); depois o primeiro bloco `text`, lido como JSON e conferido contra o schema (os seis campos, tipos, enum, nada a mais). O resultado do JSON entra em `raw.response`, com `model`, `prompt_version` e `usage`.

O log leva `charge_id`, `receipt_id`, `outcome`, `result`, `duration_ms` e os tokens (PR10).

## R10. Conjunto fixo

**Decisão:**
- `scripts/receipt-fixtures.py`, com Pillow e a fonte Noto Sans do sistema, gera os arquivos em `supabase/functions/process-receipt/fixtures/`: *prints* de 1080 × 2400 em PNG ou JPEG, e PDFs de páginas A4 em imagem. O cabeçalho diz só "Comprovante de transferência" ou parecido, sem nome nem logotipo de banco: o leiaute imita a ordem e os rótulos. O HEIC do CF25 é só o cabeçalho `ftyp` de um HEIC, porque o arquivo não vai à API.
- `<id>.json` traz o arquivo, o tipo, a leitura esperada (os seis campos do schema, ou nula no CF25), a contagem de tokens do dublê no CF26 e o resultado esperado da seção 7.
- `process-receipt/fixtures_runner.ts` roda cada exemplo de ponta a ponta contra o Supabase local: um jogo e um valor novos na base da seção 7, o arquivo no bucket e o handler. Com o dublê, é o teste do CI. Com a API real, é a `deno task receipts:live`, que compara campo a campo, confere o resultado e imprime tempo, tokens e custo.
- Contas próprias dos testes (`rcpt-*@voleiin.test`, criadas se faltarem, como as `conc-*`), para não mexer nas do seed. Antes de cada execução, os comprovantes ainda ativos dessas contas viram recusados, para liberar os IDs dos exemplos.

## R11. Medição e modelo

**Decisão:** a ordem que gasta menos: o Haiku 5.5 três vezes; o Sonnet 5.5 e o Opus 5.5 uma vez cada, para a tabela da seção 9; e mais duas do Sonnet só se o Haiku não passar, e assim por diante. Cada execução com a API real só roda depois do OK do responsável, com o custo estimado. O resultado entra na seção 9 do `comprovantes-ia.md`, e o modelo escolhido vai para o `RECEIPT_MODEL` do `supabase/functions/.env`. Na produção, ele é gravado na sessão 4.

## R12. Seed

**Decisão:** um jogo novo, "Quinta com comprovantes" (`...0212`, `JogoCompr001`), dia −4, com Ana, Bruno e Carla e R$ 60,00 (parte de R$ 20,00), concluído pela Ana. A Carla tem um comprovante aprovado automaticamente, com o valor Pago. O Bruno tem um comprovante recusado pela Ana, com observação, e depois um Em análise, com o valor Em análise. Os comprovantes são gravados pela própria `record_receipt`, e os decididos ficam com o arquivo apagado (`docs/setup.md`, seção 8). Os testes pgTAP que limpam os dados do seed passam a apagar também `receipts`, antes de `charges`.
