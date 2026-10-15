#!/usr/bin/env bash
#
# Finds a Sepolia RPC endpoint that accepts Stylus activation simulation.
#
# Flow:
#   1. Preflight: read activationGas() from the official Arbitrum Sepolia
#      RPC with a cast call. If it returns uint64::MAX, the network-level
#      activation pause is in effect. That is a network signal, not an
#      RPC failure, and it is reported explicitly.
#   2. Try the cached endpoint first, if one exists.
#   3. Iterate the configured endpoints, running cargo stylus check against
#      each one until one accepts the activation simulation.
#
# A reachable RPC is not necessarily an RPC that can complete the Stylus
# activation simulation. cargo stylus check remains the actual probe.
#
# Usage:
#   find-working-endpoint.sh <probe-contract> <cache-file> <ep1> [<ep2> ...]
#
# Exit codes:
#   0  Working endpoint found. Printed on stdout (single line, no trailing spaces).
#   1  No endpoint accepts activation.
#   2  The probe contract itself fails to compile. This is NOT an endpoint
#      problem. The compile log is dumped to stderr.
#
# Progress is written to stderr; stdout carries only the endpoint URL.

set -euo pipefail

if [ "$#" -lt 3 ]; then
    echo "usage: $0 <probe-contract> <cache-file> <ep1> [<ep2> ...]" >&2
    exit 2
fi

PROBE_CONTRACT="$1"
CACHE_FILE="$2"
shift 2
ENDPOINTS=("$@")

readonly OFFICIAL_SEPOLIA_RPC="https://sepolia-rollup.arbitrum.io/rpc"
readonly ARB_SYS_ADDRESS="0x0000000000000000000000000000000000000071"
readonly ACTIVATION_GAS_MAX="18446744073709551615"

ACTIVATION_PAUSED=0

mkdir -p "$(dirname "$CACHE_FILE")"

# ---------------------------------------------------------------------------
# Preflight: read activationGas() from the official RPC.
# Reports the network-level activation state. Does not block probing.
# ---------------------------------------------------------------------------
preflight_activation_gas() {
    local output value

    echo "  Preflight: activationGas() on $OFFICIAL_SEPOLIA_RPC" >&2
    echo "    cast call --rpc-url $OFFICIAL_SEPOLIA_RPC $ARB_SYS_ADDRESS \"activationGas()(uint64)\"" >&2

    if ! output=$(cast call \
        --rpc-url "$OFFICIAL_SEPOLIA_RPC" \
        "$ARB_SYS_ADDRESS" \
        "activationGas()(uint64)" 2>&1); then
        echo "  ! Could not read activationGas() — network or RPC issue." >&2
        echo "    $output" >&2
        echo "    Continuing with all configured endpoint probes." >&2
        return 0
    fi

    value=$(printf '%s\n' "$output" | awk 'NF { print $1; exit }')
    echo "    activationGas() = $value" >&2

    if [ "$value" = "$ACTIVATION_GAS_MAX" ]; then
        ACTIVATION_PAUSED=1
        echo "  ! Network reports activationGas() = uint64::MAX." >&2
        echo "    Consistent with the Stylus activation pause." >&2
        echo "    Every configured endpoint will still be tested." >&2
    fi
}

# ---------------------------------------------------------------------------
# probe_one <endpoint>
# Echoes the log path. Exit codes:
#   0 = activation simulation passed
#   1 = activation simulation rejected or reverted
#   2 = compile error
#   3 = RPC/transport error or another error
# ---------------------------------------------------------------------------
probe_one() {
    local ep="$1"
    local log

    log=$(mktemp)

    (
        cd "src/$PROBE_CONTRACT" &&
        cargo stylus check --endpoint "$ep" --verbose
    ) >"$log" 2>&1 || true

    if grep -qi 'wasm data fee' "$log"; then
        echo "$log"
        return 0
    fi
    if grep -qE 'error\[E[0-9]+\]|could not compile' "$log"; then
        echo "$log"
        return 2
    fi
    if grep -qiE 'stylus activations not allowed|execution reverted|execution revert' "$log"; then
        echo "$log"
        return 1
    fi
    echo "$log"
    return 3
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
echo "============================================================" >&2
echo "  STYLUS ACTIVATION PREFLIGHT" >&2
echo "============================================================" >&2
preflight_activation_gas
echo >&2

# ---------------------------------------------------------------------------
# Try the cached endpoint first.
# ---------------------------------------------------------------------------
CACHED=""
if [ -f "$CACHE_FILE" ]; then
    CACHED=$(tr -d '[:space:]' < "$CACHE_FILE")
fi

if [ -n "$CACHED" ]; then
    echo "  Cached endpoint: $CACHED" >&2

    if LOG=$(probe_one "$CACHED"); then
        echo "  ✓ Cached endpoint still works" >&2
        rm -f "$LOG"
        echo "$CACHED"
        exit 0
    else
        RC=$?

        if [ "$RC" -eq 2 ]; then
            echo "  ✗ Probe contract fails to compile — not an endpoint issue" >&2
            cat "$LOG" >&2
            rm -f "$LOG"
            exit 2
        fi

        if [ "$RC" -eq 1 ]; then
            echo "  ✗ Cached endpoint rejected activation simulation" >&2
            tail -n 5 "$LOG" >&2
        else
            echo "  ✗ Cached endpoint failed with a transport or other error" >&2
            tail -n 5 "$LOG" >&2
        fi

        echo "    Invalidating cache, probing configured endpoints." >&2
        rm -f "$LOG"
        rm -f "$CACHE_FILE"
    fi
fi

# ---------------------------------------------------------------------------
# Iterate configured endpoints.
# ---------------------------------------------------------------------------
echo "  Probing endpoints for Stylus activation support..." >&2

for ep in "${ENDPOINTS[@]}"; do
    # Skip the cached endpoint: it was already tested above and failed.
    if [ -n "$CACHED" ] && [ "$ep" = "$CACHED" ]; then
        continue
    fi

    echo "    Trying: $ep" >&2

    if LOG=$(probe_one "$ep"); then
        echo "    ✓ Works: $ep" >&2
        printf '%s\n' "$ep" > "$CACHE_FILE"
        rm -f "$LOG"
        echo "$ep"
        exit 0
    else
        RC=$?

        if [ "$RC" -eq 2 ]; then
            echo "    ✗ Probe contract fails to compile — not an endpoint issue" >&2
            cat "$LOG" >&2
            rm -f "$LOG"
            exit 2
        fi

        if [ "$RC" -eq 1 ]; then
            echo "    ✗ Activation rejected" >&2
        else
            LAST=$(tail -n 1 "$LOG" 2>/dev/null || echo "unknown")
            echo "    ✗ Other error: $LAST" >&2
        fi

        rm -f "$LOG"
    fi
done

# ---------------------------------------------------------------------------
# Exhausted: report the diagnosis.
# ---------------------------------------------------------------------------
echo >&2
echo "ERROR: no endpoint accepts Stylus activation simulation." >&2

if [ "$ACTIVATION_PAUSED" -eq 1 ]; then
    echo "NETWORK DIAGNOSIS:" >&2
    echo "  The official Sepolia RPC reported activationGas() = uint64::MAX." >&2
    echo "  Every configured endpoint was tested and none completed the" >&2
    echo "  activation simulation. This is consistent with the network-level" >&2
    echo "  Stylus activation pause, not an RPC or contract problem." >&2
else
    echo "RPC DIAGNOSIS:" >&2
    echo "  No endpoint completed the activation simulation." >&2
    echo "  Review the errors above to distinguish provider failures from" >&2
    echo "  activation rejection." >&2
fi

echo >&2
echo "  To use a keyed provider:" >&2
echo "    make <target> ENDPOINT_SEPOLIA_ALL='https://arb-sepolia.g.alchemy.com/v2/KEY'" >&2
exit 1
