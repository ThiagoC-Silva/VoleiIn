# Validação: Fatia 2 — Conta e perfil

Como provar que a fatia funciona. Primeira execução e variáveis: `docs/setup.md`.

## Pré-requisitos

- Docker, Supabase CLI, Flutter estável e Deno 2.x (`setup.md`, seção 3).
- `app/env/local.json` com `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e `GOOGLE_WEB_CLIENT_ID`.
- `supabase/.env` com `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` (só para o Google no local).

## Servidor

```bash
supabase start
supabase db reset          # migrações + seed
supabase db lint
supabase test db           # B01..B36, P01..P16, X01..X10, N01..N09
cd supabase/functions
deno fmt --check && deno lint
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave de supabase status> \
  deno test --allow-net --allow-env --allow-read _tests/   # A01..A06
```

Esperado: tudo verde. Os IDs aparecem no nome de cada asserção.

## App

```bash
cd app
flutter pub get && flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
dart analyze
flutter test                                 # U01..U07, E09..E12, S01..S17
flutter test integration_test -d emulator-5554 --dart-define-from-file=env/local.json   # L08..L11
```

## No emulador (conferência do responsável)

1. Criar conta com um e-mail novo, ler o código no Mailpit (`http://127.0.0.1:54324`), confirmar, aceitar os termos e chegar à aba Jogos.
2. No perfil: editar apelido, telefone e foto; cadastrar a chave CPF `52998224725`; tentar `52998224724` (erro no campo).
3. Trocar a senha e o e-mail; sair e entrar com os dados novos.
4. Esquecer a senha no login e recuperar pelo código.
5. Com o `GOOGLE_WEB_CLIENT_ID` e o SHA-1 cadastrados: M01 e M02 (`testes-referencia.md`, 10.4).

## Produção (responsável)

Migrações pelo roteiro do `setup.md` (9.2); Auth no painel (`setup.md`, 6.1: confirmação, `double_confirm_changes`, senha 8, modelos, SMTP do Resend, limite de 30 e-mails por hora); depois M03 e M04.
