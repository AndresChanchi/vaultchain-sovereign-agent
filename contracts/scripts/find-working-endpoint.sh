#!/usr/bin/env bash
#
# Finds a Sepolia RPC endpoint that accepts Stylus activation simulation.
#
# Caches the result in a file. On subsequent invocations, tries the cached
# endpoint first; if it still works, returns immediately. Only when the
# cached endpoint stops working does the full list get re-probed.
#
# Usage:
#   find-working-endpoint.sh <probe-contract> <cache-file> <ep1> [<ep2> ...]
#
# Exit codes:
#   0  Working endpoint found. Printed on stdout (single line, no trailing spaces).
#   1  No endpoint accepts activation.
#   2  The probe contract itself fails to compile — this is NOT an endpoint
#      problem. The compile log is dumped to stderr.
#
# Progress is written to stderr; stdout carries only the endpoint URL.

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "usage: $0 <probe-contract> <cache-file> <ep1> [<ep2> ...]" >&2
    exit 2
fi

PROBE_CONTRACT="$1"
CACHE_FILE="$2"
shift 2
ENDPOINTS=("$@")

mkdir -p "$(dirname "$CACHE_FILE")"

probe_one() {
    # $1: endpoint URL
    # Echoes the log path on stdout; exit code 0 = success, 1 = endpoint
    # rejected activation, 2 = compile error, 3 = other error.
    local ep="$1"
    local log
    log=$(mktemp)
    ( cd "src/$PROBE_CONTRACT" && \
        cargo stylus check --endpoint "$ep" --verbose ) > "$log" 2>&1 || true

    if grep -q 'wasm data fee' "$log"; then
        echo "$log"
        return 0
    fi
    if grep -qE 'error\[E[0-9]+\]|could not compile' "$log"; then
        echo "$log"
        return 2
    fi
    if grep -q 'stylus activations not allowed' "$log"; then
        echo "$log"
        return 1
    fi
    echo "$log"
    return 3
}

# --- Try cached endpoint first ---
if [ -f "$CACHE_FILE" ]; then
    CACHED=$(cat "$CACHE_FILE" | tr -d '[:space:]')
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
            echo "  ✗ Cached endpoint no longer works, invalidating cache" >&2
            rm -f "$LOG"
            rm -f "$CACHE_FILE"
        fi
    fi
fi

# --- Iterate all endpoints ---
echo "  Probing endpoints for Stylus activation support..." >&2
for ep in "${ENDPOINTS[@]}"; do
    echo "    Trying: $ep" >&2
    if LOG=$(probe_one "$ep"); then
        echo "    ✓ Works: $ep" >&2
        echo "$ep" > "$CACHE_FILE"
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
        elif [ "$RC" -eq 1 ]; then
            echo "    ✗ Activation rejected" >&2
        else
            LAST=$(tail -1 "$LOG" 2>/dev/null || echo "unknown")
            echo "    ✗ Other error: $LAST" >&2
        fi
        rm -f "$LOG"
    fi
done

echo "ERROR: no endpoint accepts Stylus activation simulation." >&2
echo "Override with a keyed provider:" >&2
echo "  make <target> ENDPOINT_SEPOLIA_ALL='https://arb-sepolia.g.alchemy.com/v2/KEY'" >&2
exit 1
