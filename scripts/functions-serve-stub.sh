#!/usr/bin/env bash
# Sobe o `supabase functions serve` dos fluxos L24 e L25, com a process-receipt
# falando com o dublê da Claude API (supabase/functions/_tests/claude_stub.ts)
# pelo ANTHROPIC_BASE_URL do SDK (docs/testes-referencia.md, 14.8). Não lê o
# supabase/functions/.env: nenhuma chave real entra, e nada gasta crédito.
#
# Uso: scripts/functions-serve-stub.sh [porta do dublê, padrão 54399]
#      (o Supabase local precisa estar de pé; Ctrl+C derruba os dois)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
port="${1:-54399}"
export PATH="$HOME/.deno/bin:$PATH"

env_file="$(mktemp)"
cleanup() {
  rm -f "$env_file"
  [ -n "${stub_pid:-}" ] && kill "$stub_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# O Edge Runtime roda num contêiner: o host é o host.docker.internal.
cat >"$env_file" <<EOF
ANTHROPIC_API_KEY=dubla-sem-credito
ANTHROPIC_BASE_URL=http://host.docker.internal:$port
RECEIPT_MODEL=claude-haiku-5-5
EOF

deno run --allow-net=0.0.0.0 "$root/supabase/functions/_tests/claude_stub.ts" "$port" &
stub_pid=$!

cd "$root"
supabase functions serve --env-file "$env_file"
