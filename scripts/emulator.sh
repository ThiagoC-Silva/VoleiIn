#!/usr/bin/env bash
# Abre o emulador do VoleiIn com a memória limitada e espera o boot terminar
# (docs/setup.md, seção 3.1).
#
# Uso: scripts/emulator.sh [29|36]     (padrão: 36)
set -euo pipefail
source "$(dirname "$0")/_android.sh"

api="${1:-36}"
case "$api" in
  29 | 36) ;;
  *) echo "Uso: $0 [29|36]" >&2; exit 2 ;;
esac

if [ -n "$(running_emulator)" ]; then
  echo "Já há um emulador aberto ($(running_emulator)). Use um por vez: dois somam uns 7 GB." >&2
  exit 1
fi

# O emulador ocupa uns 3 GB (2 GB do Android mais o processo do QEMU). A folga
# cobre o build do Gradle que vem em seguida.
require_memory_mb 5000 "abrir o emulador e compilar o app"

log="${TMPDIR:-/tmp}/voleiin-emulator-api$api.log"
# -memory 2048: a RAM do Android, independente do que o AVD tiver salvo.
# -gpu swiftshader_indirect: com a GPU do computador, o emulador caiu durante
#   o build do Gradle por falta de memória (setup.md, seção 11).
# -no-snapshot: boot limpo, sem gravar estado em disco.
nohup "$emulator_bin" -avd "voleiin_api$api" \
  -memory 2048 \
  -gpu swiftshader_indirect \
  -no-snapshot -no-audio -no-boot-anim \
  >"$log" 2>&1 &

echo "Abrindo voleiin_api$api (log em $log)..."
"$adb" wait-for-device
until [ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
  sleep 2
done
# Logo depois do boot, o runner do teste às vezes perde a conexão com o
# aparelho (setup.md, seção 11). Uma pausa curta evita isso.
sleep 20
echo "Pronto: $(running_emulator)."
