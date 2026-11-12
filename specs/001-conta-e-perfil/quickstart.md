# Quickstart: conferir a fatia 2

Roteiro para provar que a fatia funciona de ponta a ponta. Ambiente e primeira execução: `docs/setup.md`.

## Pré-requisitos

- Docker rodando, Supabase CLI, Flutter e Deno (`docs/setup.md`, seção 3).
- `supabase/.env` com `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` e `app/env/local.json` com as três variáveis (`docs/setup.md`, seção 5).
- Para o login com Google: SHA-1 da chave de debug cadastrado (`docs/setup.md`, 6.2) e uma conta Google no emulador.

## Comandos (os mesmos do CI)

```bash
# na raiz
supabase stop && supabase start   # relê o config.toml (código por e-mail, modelos, Google)
supabase db reset
supabase db lint
supabase test db                  # B, P, X e N

# em supabase/functions, com a URL e a chave pública de `supabase status`
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave> \
  deno test --allow-net --allow-env   # A01 a A06
deno fmt --check && deno lint

# em app/
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
dart analyze
flutter test                      # U, E e S
flutter test integration_test -d emulator-5554 --dart-define-from-file=env/local.json   # L06 a L11
```

## "Pronto quando" da fatia (`docs/plano-implementacao.md`)

| Item | Como conferir |
|------|---------------|
| Cadastro por e-mail com código, no local | L08. À mão: criar a conta no emulador, ler o código em `http://127.0.0.1:54324` e confirmar |
| Login com Google e vinculação (RF108) | M01 e M02, no emulador com conta Google |
| O e-mail chega pelo Resend | M03, na produção |
| Novo aceite quando a versão muda | S10. À mão: recriar `current_terms_versions()` com `1.1` no banco local e reabrir o app |
| RN105 recusa a remoção da chave Pix | N01 a N09 e S13 |
| Fotos fora do formato ou acima de 2 MB recusadas no servidor | A02 e A04 |
| Na produção, ainda sem usuários reais | M04, depois de o responsável publicar as migrações e ajustar o painel (abaixo) |

## Produção (feito pelo responsável)

O agente não executa nada disto (`docs/trabalho-com-agente.md`, seção 7).

1. Migrações: `supabase db push`, com os passos de `docs/setup.md`, 9.2.
2. Painel do Supabase, Authentication (`docs/setup.md`, 6.1):
   - confirmação de e-mail ligada, troca de e-mail sem dupla confirmação, código de 6 dígitos com 1 hora, senha mínima de 8;
   - os três modelos de e-mail com os assuntos e os corpos de `supabase/templates/`;
   - limite de 30 e-mails por hora;
   - Google: o mesmo cliente web, com *skip nonce check* ligado.
3. M01 a M04 de `docs/testes-referencia.md`, seção 10.4.
