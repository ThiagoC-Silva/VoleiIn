# Testes contra o Supabase local

Testes Deno que falam com o Supabase de pé (`docs/arquitetura-app.md`, seção 14.4), com as contas e
os grupos do seed (`docs/setup.md`, seção 8):

- `avatars_test.ts`: fotos no bucket `avatars` (A01 a A13);
- `concurrency/`: chamadas simultâneas por clientes separados, cada uma numa conexão própria do
  banco (C13 e C15 na fatia 3, research R4 de `specs/002-grupos`; C01 a C07 e C16 na fatia 4 (etapas
  A a C), com as contas `conc-00` a `conc-26`, research R7 de `specs/003-jogo-etapa-a`; C08 na fatia
  5, que dispara `auto_complete_due_games` por uma conexão de `postgres`, com `SUPABASE_DB_URL` e,
  sem ela, o banco local, research R6 de `specs/006-conclusao-etapa-a`; C09 na fatia 6, com a
  isenção e a marcação de pagamento, research R7 de `specs/009-pagamentos-etapa-a`; C10 a C12 e C18
  na etapa B da fatia 6, com a `record_receipt` e a `review_receipt`);
- `receipts_test.ts`: o bucket `receipts` (RS06 a RS08).

Os testes da etapa B da fatia 6 usam as contas `rcpt-*@voleiin.test`, criadas por
`process-receipt/test_support.ts` se faltarem, e um jogo concluído novo por cenário (research R10 de
`specs/010-pagamentos-etapa-b`). Antes de cada exemplo do conjunto fixo, os comprovantes ainda
ativos dessas contas viram recusados, para liberar os IDs de transação.

```bash
# em supabase/functions/
eval "$(supabase status -o env | grep -E '^(API_URL|PUBLISHABLE_KEY|SECRET_KEY|JWT_SECRET)=')"
SUPABASE_URL="$API_URL" SUPABASE_PUBLISHABLE_KEY="$PUBLISHABLE_KEY" \
  SUPABASE_SECRET_KEY="$SECRET_KEY" SUPABASE_JWT_SECRET="$JWT_SECRET" \
  deno test --allow-net --allow-env --allow-read
```

A chave secreta e o `JWT_SECRET` são os do Supabase **local**, que o CLI gera para todo projeto. A
concorrência dos jogos cria as próprias contas de teste e as usa com tokens assinados com o
`JWT_SECRET`, sem login por senha: o Auth local aceita só 30 logins a cada 5 minutos. Os jogos e o
grupo "Concorrência" dessas contas ficam no banco até o próximo `supabase db reset`.

Os testes das Edge Functions ficam na pasta de cada uma (`preview-invite/index_test.ts`,
`process-receipt/index_test.ts`) e rodam com o mesmo comando. A `process-receipt` roda no próprio
processo do teste, com a Claude API simulada por um servidor local (research R7 de
`specs/010-pagamentos-etapa-b`).

**Com a API real** (`docs/comprovantes-ia.md`, seções 7 e 9), à parte e fora do CI, porque gasta
crédito: com as mesmas variáveis, `deno task receipts:live <modelo>`, que lê a `ANTHROPIC_API_KEY`
do `supabase/functions/.env`.
