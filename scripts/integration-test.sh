#!/usr/bin/env bash
# Roda os testes de integração no emulador aberto, sem nada pesado em paralelo
# (docs/setup.md, seção 3.1). O Supabase local precisa estar de pé.
#
# Uso: scripts/integration-test.sh [arquivo ou pasta] [opções do flutter test]
#      (padrão: integration_test; ex.: integration_test/x_test.dart --plain-name L08)
set -euo pipefail
source "$(dirname "$0")/_android.sh"
root="$(cd "$(dirname "$0")/.." && pwd)"

device="$(running_emulator)"
if [ -z "$device" ]; then
  echo "Nenhum emulador aberto. Rode antes: scripts/emulator.sh [29|36]" >&2
  exit 1
fi

# Testes de unidade rodando ao mesmo tempo que o build do Gradle foram o que
# esgotou a memória em 13/11/2026.
if pgrep -f flutter_tester >/dev/null; then
  echo "Há um 'flutter test' de unidade rodando. Espere ele terminar." >&2
  exit 1
fi

# O build do Gradle usa até uns 4 GB (3 GB de heap mais o metaspace).
require_memory_mb 4500 "compilar e rodar os testes de integração"

target="${1:-integration_test}"
[ "$#" -gt 0 ] && shift
cd "$root/app"
exec timeout 900 flutter test "$target" "$@" \
  -d "$device" --dart-define-from-file=env/local.json
