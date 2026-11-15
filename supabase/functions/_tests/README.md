# Testes contra o Supabase local

Testes Deno que falam com o Supabase de pé (`docs/arquitetura-app.md`, seção 14.4), com as contas e
os grupos do seed (`docs/setup.md`, seção 8):

- `avatars_test.ts`: fotos no bucket `avatars` (A01 a A13);
- `concurrency/`: chamadas simultâneas por clientes separados, cada uma numa conexão própria do
  banco (C13 e C15 na fatia 3; research R4 de `specs/002-grupos`).

```bash
# em supabase/functions/
eval "$(supabase status -o env | grep -E '^(API_URL|PUBLISHABLE_KEY|SECRET_KEY)=')"
SUPABASE_URL="$API_URL" SUPABASE_PUBLISHABLE_KEY="$PUBLISHABLE_KEY" \
  SUPABASE_SECRET_KEY="$SECRET_KEY" deno test --allow-net --allow-env
```

Os testes das Edge Functions ficam na pasta de cada uma (`preview-invite/index_test.ts`) e rodam com
o mesmo comando.
