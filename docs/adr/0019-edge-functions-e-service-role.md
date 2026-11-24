# 0019. Edge Functions chamam funções de `public` abertas só a `service_role`

- **Status:** Aceito
- **Data:** 2026-11-24

## Contexto
O ADR 0015 deixou para a fatia 6 a forma como as Edge Functions chamam as funções internas, que ficam no esquema `private`, fora da API. `process-receipt` precisa gravar o comprovante, mudar o valor e notificar numa transação só, com o valor bloqueado, e a conferência do destinatário usa o recebedor gravado no momento do bloqueio (C12). Uma Edge Function que fala pela API não mantém uma transação entre duas chamadas.

## Decisão
- A escrita fica numa função SQL de `public`, `security definer`, com `execute` **só para `service_role`**: `record_receipt`, `list_storage_cleanup` e `mark_receipts_file_deleted`. A Edge Function confere o JWT de quem chama e usa a chave de serviço para chamá-la.
- **As condições da RN88 são conferidas em SQL**, dentro de `record_receipt`, depois do bloqueio. A Edge Function só lê o arquivo, chama a Claude API e normaliza o que veio dela.
- As funções de `private` continuam sem acesso pela API. `record_receipt` chama `private.emit_notification` por dentro.

## Alternativas descartadas
- **Conexão direta ao Postgres (`SUPABASE_DB_URL`)**, para chamar `private.*` numa transação aberta pela Edge Function: prende uma conexão do plano grátis durante a chamada e espalha a regra entre TypeScript e SQL.
- **Conferir a RN88 em TypeScript e mandar só o resultado:** o recebedor ou a chave podem mudar entre a conferência e a gravação (C12).
- **Expor o esquema `private` a `service_role` pela API:** abre o esquema inteiro por causa de três funções.

## Consequências
- O teste B06 passa a conferir também que essas três funções não têm `execute` para `anon` nem `authenticated`.
- A RN88 é testada em pgTAP, sem rede. O teste Deno cobre a leitura, com a Claude API simulada.
- A fatia 7 (`send-push`) segue a mesma forma.
