# Quickstart: Grupos (fatia 3)

## Servidor (sessão 2)

```bash
# na raiz
supabase start
supabase db reset          # migrações e o seed com os dois grupos
supabase test db           # B, G e K
supabase db lint

# em supabase/functions/ (Edge Function servida pelo próprio supabase start)
export PATH="$HOME/.deno/bin:$PATH"
eval "$(supabase status -o env | grep -E '^(API_URL|PUBLISHABLE_KEY)=')"
SUPABASE_URL="$API_URL" SUPABASE_PUBLISHABLE_KEY="$PUBLISHABLE_KEY" \
  deno test --allow-net --allow-env   # A, Q e C
deno fmt --check && deno lint
```

## Conferência rápida pela API

Com o seed, Diego (`diego@voleiin.test`, senha `voleiin123`) chama `preview-invite` com `{ "code": "VoleiQuinta1", "kind": "group" }` e recebe o Vôlei de Quinta com `is_member` e `has_pending_request` falsos (Q01).

## App (sessão 3)

```bash
# em app/
dart analyze
flutter test
```

Fluxos L12 a L14 pelos `scripts/`, um comando pesado por vez (`docs/setup.md`, 3.1), na sessão 4.
