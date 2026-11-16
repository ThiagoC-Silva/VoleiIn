# Quickstart: Jogo e lista de presença, etapa A (fatia 4)

Como conferir a etapa de ponta a ponta. Comandos e ambiente: `docs/setup.md`.

## Servidor (sessão 2)

```bash
# na raiz
supabase start
supabase db reset          # migrações e o seed com os sete jogos
supabase test db           # B03, B04, B06, J01 a J13, O01 a O07, O20 a O23, T03 a T05, W01 a W11, W13 a W15
supabase db lint

# em supabase/functions/
deno fmt --check && deno lint
eval "$(supabase status -o env | grep -E '^(API_URL|PUBLISHABLE_KEY|SECRET_KEY|JWT_SECRET)=')"
SUPABASE_URL="$API_URL" SUPABASE_PUBLISHABLE_KEY="$PUBLISHABLE_KEY" \
  SUPABASE_SECRET_KEY="$SECRET_KEY" SUPABASE_JWT_SECRET="$JWT_SECRET" \
  deno test --allow-net --allow-env   # C01, C02, C04, C05
```

Esperado: tudo verde, sem nenhum resultado de `docs/testes-referencia.md` alterado.

## App (sessão 3)

```bash
# em app/
dart analyze
flutter test               # U09 a U11, E15, S36 a S42, S50 a S53, S59 e S60 da etapa
```

## Validação (sessão 4)

- Emulador pelos `scripts/` (API 29 e 36), um comando pesado por vez: L15 sem o cancelamento.
- No celular, com o build da produção: M06 (lista em até 2 s).
- Migrações na produção depois do ensaio de `docs/setup.md`, 9.2, e `get_advisors` sem alerta.
