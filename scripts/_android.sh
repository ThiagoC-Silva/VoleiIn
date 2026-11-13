# Funções comuns de emulator.sh e integration-test.sh (docs/setup.md, seção 3.1).
# Não roda sozinho: é carregado com `source`.

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
adb="$sdk/platform-tools/adb"
emulator_bin="$sdk/emulator/emulator"

# Memória disponível em MB, a mesma conta do "disponível" do `free`.
mem_available_mb() {
  awk '/^MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo
}

# Para com uma mensagem se a memória disponível for menor que $1 MB.
# VOLEIIN_SKIP_MEMORY_CHECK=1 pula a conferência.
require_memory_mb() {
  local needed="$1" what="$2" available
  [ "${VOLEIIN_SKIP_MEMORY_CHECK:-0}" = 1 ] && return 0
  available="$(mem_available_mb)"
  if [ "$available" -lt "$needed" ]; then
    cat >&2 <<EOF
Memória insuficiente para $what: ${available} MB disponíveis, ${needed} MB necessários.
Feche navegadores ou outros programas pesados e tente de novo. Sem folga, o
systemd-oomd encerra a sessão gráfica inteira (docs/setup.md, seção 3.1).
Para ignorar esta conferência: VOLEIIN_SKIP_MEMORY_CHECK=1.
EOF
    exit 1
  fi
}

# Primeiro emulador conectado ao adb, ou vazio.
running_emulator() {
  "$adb" devices | awk '/^emulator-[0-9]+\tdevice$/ { print $1; exit }'
}
