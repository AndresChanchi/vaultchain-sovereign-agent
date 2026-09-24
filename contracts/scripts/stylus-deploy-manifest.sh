#!/usr/bin/env bash
#
# stylus-deploy-manifest.sh
#
# Parses a cargo-stylus deploy log and emits a structured JSON manifest
# describing the deployment. Consumed by the Makefile to persist a rich
# record under deployments/<timestamp>/manifest.json.
#
# Usage:
#   scripts/stylus-deploy-manifest.sh <logfile> <project-name> <contract-name> \
#       [deployer-address] [endpoint]
#
# Design notes:
#   - ANSI escapes are stripped first: cargo-stylus can emit colors even
#     when piped through tee, and those sequences break naive greps.
#   - Field extraction anchors on the exact log prefix rather than
#     grabbing "any 40-hex-char run", which previously caused the
#     deployment tx hash's first 40 chars to be mistaken for the
#     contract address.
#   - Missing fields degrade to empty strings / zeros. Output is always
#     valid JSON so downstream jq is safe.

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 <logfile> <project-name> <contract-name> [deployer] [endpoint]" >&2
    exit 1
fi

LOG="$1"
PROJECT="$2"
CONTRACT="$3"
DEPLOYER="${4:-}"
ENDPOINT="${5:-}"

[ -f "$LOG" ] || { echo "Log not found: $LOG" >&2; exit 1; }

CLEAN=$(mktemp)
trap 'rm -f "$CLEAN"' EXIT
perl -pe 's/\e\[[0-9;]*[a-zA-Z]//g' "$LOG" > "$CLEAN"

extract_last() { grep -oE "$1" "$CLEAN" 2>/dev/null | tail -n1 || true; }

# Address is anchored to the specific prefix line.
addr=$(extract_last 'deployed code at address: 0x[a-fA-F0-9]{40}')
addr=$(printf '%s' "$addr" | grep -oE '0x[a-fA-F0-9]{40}' || true)

tx_deploy=$(extract_last 'deployment tx hash: 0x[a-fA-F0-9]{64}')
tx_deploy=$(printf '%s' "$tx_deploy" | grep -oE '0x[a-fA-F0-9]{64}' || true)

tx_activate=$(extract_last 'activation tx hash: 0x[a-fA-F0-9]{64}')
tx_activate=$(printf '%s' "$tx_activate" | grep -oE '0x[a-fA-F0-9]{64}' || true)

fragments=$(grep -oE '\([0-9]+ fragments?\)' "$CLEAN" 2>/dev/null | grep -oE '[0-9]+' | tail -n1 || true)
compressed=$(grep -oE 'contract size: [0-9.]+ KB \([0-9]+ bytes\)' "$CLEAN" 2>/dev/null | grep -oE '\([0-9]+ bytes\)' | grep -oE '[0-9]+' | tail -n1 || true)
uncompressed=$(grep -oE 'wasm size: [0-9.]+ KB \([0-9]+ bytes\)' "$CLEAN" 2>/dev/null | grep -oE '\([0-9]+ bytes\)' | grep -oE '[0-9]+' | tail -n1 || true)
project_hash=$(grep -oE 'project metadata hash computed on deployment: "[a-f0-9]+"' "$CLEAN" 2>/dev/null | sed -E 's/.*"([a-f0-9]+)".*/\1/' | tail -n1 || true)
wasm_opt=$(grep -oE 'wasm-opt [0-9]+' "$CLEAN" 2>/dev/null | grep -oE '[0-9]+' | tail -n1 || true)
wasm_fee=$(grep -oE 'wasm data fee: [0-9.]+ ETH' "$CLEAN" 2>/dev/null | grep -oE '[0-9.]+' | tail -n1 || true)

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

explorer=""
if [ -n "$addr" ]; then
    explorer="https://sepolia.arbiscan.io/address/$addr"
fi

jq -n \
    --arg project "$PROJECT" \
    --arg contract "$CONTRACT" \
    --arg ts "$ts" \
    --arg endpoint "$ENDPOINT" \
    --arg addr "$addr" \
    --arg deployer "$DEPLOYER" \
    --arg txd "$tx_deploy" \
    --arg txa "$tx_activate" \
    --arg fr "${fragments:-}" \
    --arg cb "${compressed:-}" \
    --arg ub "${uncompressed:-}" \
    --arg ph "$project_hash" \
    --arg wo "$wasm_opt" \
    --arg fee "${wasm_fee:-}" \
    --arg explorer "$explorer" \
    '{
        project_info: {
            name: $project,
            compiler: "Cargo Stylus (Rust)",
            timestamp: $ts,
            network: "Arbitrum Sepolia (Testnet)",
            rpc_endpoint: $endpoint
        },
        deployment_fingerprint: {
            project_metadata_hash: $ph,
            compressed_bytes: ($cb | tonumber? // 0),
            uncompressed_bytes: ($ub | tonumber? // 0),
            fragments: ($fr | tonumber? // 1),
            wasm_opt_version: $wo
        },
        contract_details: {
            contract_name: $contract,
            contract_address: $addr,
            deployer_address: $deployer,
            deployment_tx_hash: $txd
        },
        activation_details: {
            activation_tx_hash: $txa,
            wasm_data_fee_eth: $fee,
            explorer_url: $explorer
        }
    }'
