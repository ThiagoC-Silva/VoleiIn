# Testes contra o Supabase local

Testes Deno que falam com o Supabase de pé (`docs/arquitetura-app.md`, seção 14.4), com as contas e
os grupos do seed (`docs/setup.md`, seção 8):

- `avatars_test.ts`: fotos no bucket `avatars` (A01 a A13);
- `concurrency/`: chamadas simultâneas por clientes separados, cada uma numa conexão própria do
  banco (C13 e C15 na fatia 3, research R4 de `specs/002-grupos`; C01 a C07 e C16 na fatia 4 (etapas
  A a C), com as contas `conc-00` a `conc-26`, research R7 de `specs/003-jogo-etapa-a`).

```bash
# em supabase/functions/
eval "$(supabase status -o env | grep -E '^(API_URL|PUBLISHABLE_KEY|SECRET_KEY|JWT_SECRET)=')"
SUPABASE_URL="$API_URL" SUPABASE_PUBLISHABLE_KEY="$PUBLISHABLE_KEY" \
  SUPABASE_SECRET_KEY="$SECRET_KEY" SUPABASE_JWT_SECRET="$JWT_SECRET" \
  deno test --allow-net --allow-env
```

A chave secreta e o `JWT_SECRET` são os do Supabase **local**, que o CLI gera para todo projeto. A
concorrência dos jogos cria as próprias contas de teste e as usa com tokens assinados com o
`JWT_SECRET`, sem login por senha: o Auth local aceita só 30 logins a cada 5 minutos. Os jogos e o
grupo "Concorrência" dessas contas ficam no banco até o próximo `supabase db reset`.

Os testes das Edge Functions ficam na pasta de cada uma (`preview-invite/index_test.ts`) e rodam com
o mesmo comando.
