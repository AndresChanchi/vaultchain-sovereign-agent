#!/usr/bin/env bash
#
# Injects runtime, economics, and recovery addresses into the Gateway's
# compile-time constants. Idempotent: replaces the `Address::new([...])`
# expression regardless of its previous contents.
#
# Usage:
#   inject-gateway-constants.sh <runtime> <economics> <recovery>
#
# Rejects invalid addresses so that a typo in the Makefile fails fast
# instead of silently producing a broken Gateway.

set -euo pipefail

if [ $# -ne 3 ]; then
    echo "usage: $0 <runtime> <economics> <recovery>" >&2
    exit 2
fi

RUNTIME="$1"
ECONOMICS="$2"
RECOVERY="$3"

CONSTANTS="src/kipio_execution_gateway/src/config/constants.rs"

for name_val in "runtime=$RUNTIME" "economics=$ECONOMICS" "recovery=$RECOVERY"; do
    name="${name_val%%=*}"
    val="${name_val##*=}"
    if ! [[ "$val" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        echo "ERROR: invalid $name address: $val" >&2
        exit 1
    fi
done

if [ ! -f "$CONSTANTS" ]; then
    echo "ERROR: $CONSTANTS not found" >&2
    exit 1
fi

# "0x1234...abcd" -> "0x12, 0x34, ..., 0xab, 0xcd"
to_byte_array() {
    local hex="${1#0x}"
    local result=""
    local i
    for ((i=0; i<${#hex}; i+=2)); do
        result+="0x${hex:$i:2}, "
    done
    echo "${result%, }"
}

RUNTIME_BYTES="$(to_byte_array "$RUNTIME")"
ECONOMICS_BYTES="$(to_byte_array "$ECONOMICS")"
RECOVERY_BYTES="$(to_byte_array "$RECOVERY")"

# Match the line `pub const KIPIO_X: Address = Address::new([...]);` and
# replace the bracket contents. Anchored to the const name to avoid
# touching unrelated declarations.
sed -i -E \
    "s|(pub const KIPIO_RUNTIME: Address = Address::new\\(\\[)[^]]*(\\]\\);)|\\1${RUNTIME_BYTES}\\2|" \
    "$CONSTANTS"
sed -i -E \
    "s|(pub const KIPIO_ECONOMICS: Address = Address::new\\(\\[)[^]]*(\\]\\);)|\\1${ECONOMICS_BYTES}\\2|" \
    "$CONSTANTS"
sed -i -E \
    "s|(pub const KIPIO_RECOVERY: Address = Address::new\\(\\[)[^]]*(\\]\\);)|\\1${RECOVERY_BYTES}\\2|" \
    "$CONSTANTS"

echo "Injected gateway constants:"
echo "  KIPIO_RUNTIME   = $RUNTIME"
echo "  KIPIO_ECONOMICS = $ECONOMICS"
echo "  KIPIO_RECOVERY  = $RECOVERY"
