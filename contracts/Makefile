# Force bash so we can use PIPESTATUS, pipefail, and array semantics.
SHELL := /bin/bash

# Load environment variables from .env file.
ifneq ("$(wildcard .env)","")
	include .env
	export $(shell sed 's/=.*//' .env)
endif

# ============================================================
# CONFIGURATION
# ============================================================

ENDPOINT_SEPOLIA = https://sepolia-rollup.arbitrum.io/rpc

ENDPOINT_SEPOLIA_FALLBACKS = https://arbitrum-sepolia-rpc.publicnode.com https://arbitrum-sepolia.api.onfinality.io/public https://arbitrum-sepolia.gateway.tenderly.co https://arbitrum-sepolia.drpc.org https://arbitrum-sepolia.blockpi.network/v1/rpc/public

ENDPOINT_SEPOLIA_ALL = $(ENDPOINT_SEPOLIA) $(ENDPOINT_SEPOLIA_FALLBACKS)

FOUNDRY_INTERFACES = foundry/src/interfaces
CHECK_REPORTS = .check-reports
DEPLOYMENTS_DIR = deployments
SCRIPTS_DIR = scripts
PROJECT_NAME = kipio-protocol

SOLIDITY_PRAGMA = pragma solidity ^0.8.37;

# ============================================================
# CONTRACT LISTS
# ============================================================
#
# CONTRACTS: every crate in the workspace that produces a deployable
#            artifact. Used by build, abi, and check.
#
# DEPLOYABLES: the ordered list of contracts that deploy-full walks
#              through. The order matters because each contract's
#              constructor arguments may reference the address of a
#              previously deployed one.
#
# WHY kipio_account IS NOT IN DEPLOYABLES:
#
#   It is per-user. Its address is derived deterministically by the
#   Execution Gateway via CREATE2, seeded by the user's identity. There
#   is no singleton account to deploy.
#
# WHY THE ORDER MATTERS:
#
#   1. kipio_protocol_config   (no constructor args)
#   2. kipio_runtime           (needs protocol_config)
#   3. kipio_recovery          (needs runtime)
#   4. kipio_economics         (needs protocol_config + CRE forwarder)
#   5. kipio_identity_content  (needs providers)
#   6. kipio_execution_gateway (no constructor args; compile-time
#                               constants reference deployed modules)
# ------------------------------------------------------------

CONTRACTS = \
	kipio_protocol_config \
	kipio_identity_content \
	kipio_account \
	kipio_recovery \
	kipio_runtime \
	kipio_economics \
	kipio_execution_gateway

DEPLOYABLES = \
	kipio_protocol_config \
	kipio_runtime \
	kipio_recovery \
	kipio_economics \
	kipio_identity_content \
	kipio_execution_gateway

# ============================================================
# PER-CONTRACT CONSTRUCTOR ARGUMENTS
# ============================================================
#
# Constructor arguments are read from environment variables (typically
# set in .env). Names follow the pattern CTOR_<CONTRACT>_<PARAM>.
#
# Example .env entries:
#
#   CTOR_RUNTIME_PROTOCOL_CONFIG=0x...
#   CTOR_RECOVERY_RUNTIME=0x...
#   CTOR_ECONOMICS_PROTOCOL_CONFIG=0x...
#   CTOR_ECONOMICS_CRE_FORWARDER=0x...
#   CTOR_ECONOMICS_CRE_WORKFLOW_ID=0x...
#   CTOR_IDENTITY_CONTENT_STORAGE_PROVIDER=0x...
#   CTOR_IDENTITY_CONTENT_QUERY_PROVIDER=0x...
#   CTOR_IDENTITY_CONTENT_ACCESS_PROVIDER=0x...
#   CTOR_IDENTITY_CONTENT_EXPECTED_WORKFLOW_ID=0x...
#
# Contracts without constructor args have empty entries. The deploy
# recipe checks the expanded array length and skips --constructor-args
# when empty.
# ------------------------------------------------------------

CONSTRUCTOR_ARGS_kipio_protocol_config =
CONSTRUCTOR_ARGS_kipio_runtime = $(CTOR_RUNTIME_PROTOCOL_CONFIG)
CONSTRUCTOR_ARGS_kipio_recovery = $(CTOR_RECOVERY_RUNTIME)
CONSTRUCTOR_ARGS_kipio_economics = $(CTOR_ECONOMICS_PROTOCOL_CONFIG) $(CTOR_ECONOMICS_CRE_FORWARDER) $(CTOR_ECONOMICS_CRE_WORKFLOW_ID)
CONSTRUCTOR_ARGS_kipio_identity_content = $(CTOR_IDENTITY_CONTENT_STORAGE_PROVIDER) $(CTOR_IDENTITY_CONTENT_QUERY_PROVIDER) $(CTOR_IDENTITY_CONTENT_ACCESS_PROVIDER) $(CTOR_IDENTITY_CONTENT_EXPECTED_WORKFLOW_ID)
CONSTRUCTOR_ARGS_kipio_execution_gateway =

CTOR_ARG_VARS := $(filter CONSTRUCTOR_ARGS_%,$(.VARIABLES))
export $(CTOR_ARG_VARS)

# ============================================================
# PERMISSION GUARD
# ============================================================

define guard_perms
	@if [ -e target/debug/.cargo-lock ] && [ "$$(stat -c %U target/debug/.cargo-lock 2>/dev/null)" = "root" ]; then \
		echo ""; \
		echo "============================================================"; \
		echo "  PERMISSION ERROR"; \
		echo "============================================================"; \
		echo "  target/ contains root-owned files (likely from a previous"; \
		echo "  'cargo stylus deploy' that ran inside Docker as root)."; \
		echo ""; \
		echo "  Run one of:"; \
		echo "    make fix-perms   # reclaim ownership of target/"; \
		echo "    make nuke        # hard reset (removes target/ + Docker cache)"; \
		echo ""; \
		echo "  Offending file:"; \
		echo "    $$(ls -la target/debug/.cargo-lock 2>/dev/null || true)"; \
		echo "============================================================"; \
		exit 1; \
	fi
endef

# ============================================================
# 1. DEVELOPMENT & COMPILATION
# ============================================================

build:
	$(guard_perms)
ifdef contract
	@echo "Building $(contract)"
	cd src/$(contract) && cargo stylus build
else
	@set -e; \
	for c in $(CONTRACTS); do \
		echo ""; \
		echo "Building $$c"; \
		(cd src/$$c && cargo stylus build); \
	done; \
	echo ""; \
	echo "All contracts built."
endif

# ============================================================
# ABI EXPORT
# ============================================================
#
# After each export, three post-processing scripts run in this order:
#
#   1. scripts/fix-tuple-abi.sh
#      Rewrites inline tuple parameters into named structs. Solidity
#      rejects inline tuples in external function signatures. SDK
#      issue #368, audit finding M-17.
#
#   2. scripts/fix-abi-structs.sh
#      Injects missing struct declarations from the companion file.
#      The SDK omits structs that are only used as input parameters.
#      Solidity then rejects the interface with Error (7920). The
#      script computes the transitive closure of referenced structs.
#
#   3. scripts/fix-abi-data-locations.sh
#      Adds missing data location keywords (memory / calldata) on
#      struct, bytes and string parameters in external function
#      signatures. The SDK handles arrays correctly but omits the
#      keyword on singular reference types. Solidity rejects this
#      with Error (6651).
#
# All three scripts are idempotent.
# ------------------------------------------------------------

abi:
	$(guard_perms)
	@mkdir -p $(FOUNDRY_INTERFACES)
	@mkdir -p $(CHECK_REPORTS)
ifdef contract
	@name="IKipio$$(echo $(contract) | sed -E 's/^kipio_//; s/(^|_)([a-z])/\U\2/g')"; \
	OUT="$(FOUNDRY_INTERFACES)/$$name.sol"; \
	echo ""; \
	echo "============================================================"; \
	echo "Exporting ABI: $$name"; \
	echo "============================================================"; \
	echo "  pragma: $(SOLIDITY_PRAGMA)"; \
	echo "------------------------------------------------------------"; \
	(cd src/$(contract) && cargo run --features export-abi --quiet -- abi --pragma "$(SOLIDITY_PRAGMA)" > "../../$$OUT"); \
	RC=$$?; \
	if [ $$RC -ne 0 ] || [ ! -s "$$OUT" ]; then \
		echo ""; \
		echo "  EXPORT FAILED (exit $$RC)"; \
		exit 1; \
	fi; \
	bash $(SCRIPTS_DIR)/fix-tuple-abi.sh "$$OUT" || exit 1; \
	bash $(SCRIPTS_DIR)/fix-abi-structs.sh "$$OUT" "$(SCRIPTS_DIR)/abi-structs-companion.sol" || exit 1; \
	bash $(SCRIPTS_DIR)/fix-abi-data-locations.sh "$$OUT" "$(SCRIPTS_DIR)/abi-structs-companion.sol" || exit 1; \
	bytes=$$(stat -c %s "$$OUT"); \
	echo "  $$name.sol ($$bytes B)"; \
	echo "============================================================"; \
	echo ""; \
	echo "  --- Exported interface ---"; \
	cat "$$OUT"; \
	echo "  --- end ---"
else
	@set +e; \
	FAILED=""; \
	REPORT="$(CHECK_REPORTS)/abis.tsv"; \
	printf "contract\tinterface\tbytes\tstatus\n" > "$$REPORT"; \
	for c in $(CONTRACTS); do \
		name="IKipio$$(echo $$c | sed -E 's/^kipio_//; s/(^|_)([a-z])/\U\2/g')"; \
		OUT="$(FOUNDRY_INTERFACES)/$$name.sol"; \
		echo ""; \
		echo "============================================================"; \
		echo "Exporting ABI: $$name"; \
		echo "============================================================"; \
		echo "  pragma: $(SOLIDITY_PRAGMA)"; \
		echo "------------------------------------------------------------"; \
		(cd src/$$c && cargo run --features export-abi --quiet -- abi --pragma "$(SOLIDITY_PRAGMA)" > "../../$$OUT"); \
		RC=$$?; \
		if [ $$RC -ne 0 ] || [ ! -s "$$OUT" ]; then \
			echo "  FAILED (exit $$RC)"; \
			FAILED="$$FAILED $$c"; \
			printf "%s\t%s\t%s\t%s\n" "$$c" "$$name.sol" "0" "FAILED" >> "$$REPORT"; \
			continue; \
		fi; \
		bash $(SCRIPTS_DIR)/fix-tuple-abi.sh "$$OUT" || { \
			echo "  fix-tuple-abi FAILED"; \
			FAILED="$$FAILED $$c"; \
			printf "%s\t%s\t%s\t%s\n" "$$c" "$$name.sol" "0" "TUPLE-FIX-FAILED" >> "$$REPORT"; \
			continue; \
		}; \
		bash $(SCRIPTS_DIR)/fix-abi-structs.sh "$$OUT" "$(SCRIPTS_DIR)/abi-structs-companion.sol" || { \
			echo "  fix-abi-structs FAILED"; \
			FAILED="$$FAILED $$c"; \
			printf "%s\t%s\t%s\t%s\n" "$$c" "$$name.sol" "0" "STRUCT-FIX-FAILED" >> "$$REPORT"; \
			continue; \
		}; \
		bash $(SCRIPTS_DIR)/fix-abi-data-locations.sh "$$OUT" "$(SCRIPTS_DIR)/abi-structs-companion.sol" || { \
			echo "  fix-abi-data-locations FAILED"; \
			FAILED="$$FAILED $$c"; \
			printf "%s\t%s\t%s\t%s\n" "$$c" "$$name.sol" "0" "DATA-LOC-FIX-FAILED" >> "$$REPORT"; \
			continue; \
		}; \
		bytes=$$(stat -c %s "$$OUT"); \
		echo "  $$name.sol ($$bytes B)"; \
		printf "%s\t%s\t%s\t%s\n" "$$c" "$$name.sol" "$$bytes" "OK" >> "$$REPORT"; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "ABI SUMMARY"; \
	echo "============================================================"; \
	printf "%-30s %-40s %12s %8s\n" "CONTRACT" "INTERFACE" "SIZE" "STATUS"; \
	printf "%-30s %-40s %12s %8s\n" "------------------------------" "----------------------------------------" "------------" "--------"; \
	while IFS=$$'\t' read -r c i b s; do \
		[ "$$c" = "contract" ] && continue; \
		printf "%-30s %-40s %10s B %8s\n" "$$c" "$$i" "$$b" "$$s"; \
	done < "$$REPORT"; \
	echo ""; \
	expected=""; \
	for c in $(CONTRACTS); do \
		n="IKipio$$(echo $$c | sed -E 's/^kipio_//; s/(^|_)([a-z])/\U\2/g').sol"; \
		expected="$$expected $$n"; \
	done; \
	orphans=""; \
	for f in $(FOUNDRY_INTERFACES)/*.sol; do \
		[ -e "$$f" ] || continue; \
		base=$$(basename "$$f"); \
		case " $$expected " in \
			*" $$base "*) ;; \
			*) orphans="$$orphans $$base";; \
		esac; \
	done; \
	if [ -n "$$orphans" ]; then \
		echo "  WARNING: orphaned interface files detected:"; \
		for o in $$orphans; do echo "    - $$o"; done; \
		echo "  These do not correspond to any entry in CONTRACTS."; \
		echo "  Run 'make clean-abi' to remove them."; \
		echo ""; \
	fi; \
	if [ -n "$$FAILED" ]; then \
		echo "FAILED CONTRACTS:"; \
		for c in $$FAILED; do echo "  - $$c"; done; \
		echo ""; \
		echo "Report: $$REPORT"; \
		exit 1; \
	fi; \
	echo "All ABIs generated in $(FOUNDRY_INTERFACES)/"; \
	echo "Report: $$REPORT"; \
	echo ""; \
	echo "  To inspect an individual interface:"; \
	echo "    cat $(FOUNDRY_INTERFACES)/IKipioRuntime.sol"; \
	echo ""
endif

lock:
	cargo generate-lockfile

# ============================================================
# 2. TESTING
# ============================================================

test:
	$(guard_perms)
	cargo test -p kipio_tests --test unit --test e2e

test-bridge:
	$(guard_perms)
	cargo test -p kipio_account_bridge

test-fork:
	$(guard_perms)
	cargo test -p kipio_tests --test fork -- --ignored

test-all: test test-bridge test-fork

# ============================================================
# 3. ON-CHAIN VALIDATION
# ============================================================

probe-rpc:
	@echo ""
	@echo "============================================================"
	@echo "  RPC PROBE — Arbitrum Sepolia (chain ID 421614)"
	@echo "============================================================"
	@ENDPOINTS='$(ENDPOINT_SEPOLIA_ALL)'; \
	for ep in $$ENDPOINTS; do \
		printf "  %-70s " "$$ep"; \
		start=$$(date +%s%3N); \
		resp=$$(curl -s -m 5 -X POST -H "Content-Type: application/json" \
			--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
			"$$ep" 2>/dev/null); \
		end=$$(date +%s%3N); \
		latency=$$((end - start)); \
		if echo "$$resp" | grep -q '"result":"0x66eee"'; then \
			echo "OK   ($${latency}ms)  chainId=0x66eee"; \
		elif echo "$$resp" | grep -q '"result"'; then \
			cid=$$(echo "$$resp" | grep -oE '"result":"0x[0-9a-f]+"' | head -1); \
			echo "OK   ($${latency}ms)  $$cid"; \
		elif echo "$$resp" | grep -q '"error"'; then \
			err=$$(echo "$$resp" | head -c 80); \
			echo "ERR  ($${latency}ms)  $$err"; \
		else \
			echo "FAIL ($${latency}ms)  no JSON-RPC response"; \
		fi; \
	done; \
	echo ""
	@echo "  NOTE: chainId OK does not imply the endpoint accepts"
	@echo "        stylus activation simulations. Run 'make check' to"
	@echo "        verify end-to-end."

check:
ifdef contract
	@mkdir -p $(CHECK_REPORTS); \
	LOG="$(CHECK_REPORTS)/$(contract).log"; \
	ENDPOINTS='$(ENDPOINT_SEPOLIA_ALL)'; \
	echo "Checking $(contract)"; \
	echo "------------------------------------------------------------"; \
	SUCCESS=0; \
	LAST_ERR=""; \
	for ep in $$ENDPOINTS; do \
		echo "  Trying: $$ep"; \
		(cd src/$(contract) && cargo stylus check --endpoint "$$ep" --verbose) > "$$LOG" 2>&1; \
		RC=$$?; \
		if [ $$RC -eq 0 ] && ! grep -q 'stylus activations not allowed' "$$LOG"; then \
			SUCCESS=1; \
			echo "$$ep" > $(CHECK_REPORTS)/.active-endpoint; \
			echo "  Endpoint OK: $$ep"; \
			break; \
		fi; \
		if grep -q 'stylus activations not allowed' "$$LOG"; then \
			echo "  Endpoint rejected activation simulation, trying next..."; \
			continue; \
		fi; \
		if grep -qE 'error\[E[0-9]+\]' "$$LOG" || grep -q 'could not compile' "$$LOG"; then \
			echo ""; \
			echo "  COMPILATION ERROR:"; \
			cat "$$LOG"; \
			exit 1; \
		fi; \
		LAST_ERR="$$(tail -1 $$LOG)"; \
		echo "  Unexpected error, stopping."; \
		break; \
	done; \
	echo ""; \
	if [ $$SUCCESS -eq 0 ]; then \
		echo "============================================================"; \
		echo "  NO ENDPOINT ACCEPTED THE ACTIVATION SIMULATION"; \
		echo "============================================================"; \
		echo "  Tried endpoints:"; \
		for ep in $$ENDPOINTS; do echo "    - $$ep"; done; \
		echo ""; \
		echo "  This is a public-RPC limitation, not a contract bug."; \
		echo "  To use a keyed provider, override ENDPOINT_SEPOLIA_ALL:"; \
		echo "    make check contract=$(contract) ENDPOINT_SEPOLIA_ALL='https://arb-sepolia.g.alchemy.com/v2/KEY'"; \
		if [ -n "$$LAST_ERR" ]; then \
			echo ""; \
			echo "  Last error:"; \
			echo "    $$LAST_ERR"; \
		fi; \
		echo "============================================================"; \
		exit 1; \
	fi; \
	echo "  Full trace: $$LOG"; \
	echo ""; \
	echo "  --- cargo stylus check output ---"; \
	cat "$$LOG"; \
	echo "  --- end ---"
else
	@set +e; \
	FAILED=""; \
	mkdir -p $(CHECK_REPORTS); \
	REPORT="$(CHECK_REPORTS)/sizes.tsv"; \
	printf "contract\tcompressed_bytes\tuncompressed_bytes\tfragments\tendpoint\n" > "$$REPORT"; \
	ENDPOINTS='$(ENDPOINT_SEPOLIA_ALL)'; \
	for c in $(CONTRACTS); do \
		LOG="$(CHECK_REPORTS)/$$c.log"; \
		echo ""; \
		echo "============================================================"; \
		echo "Checking $$c"; \
		echo "============================================================"; \
		SUCCESS=0; \
		USED_EP=""; \
		for ep in $$ENDPOINTS; do \
			echo "  Trying: $$ep"; \
			(cd src/$$c && cargo stylus check --endpoint "$$ep" --verbose) > "$$LOG" 2>&1; \
			RC=$$?; \
			if [ $$RC -eq 0 ] && ! grep -q 'stylus activations not allowed' "$$LOG"; then \
				SUCCESS=1; \
				USED_EP="$$ep"; \
				echo "  Endpoint OK: $$ep"; \
				break; \
			fi; \
			if grep -q 'stylus activations not allowed' "$$LOG"; then \
				echo "  Endpoint rejected activation simulation, trying next..."; \
				continue; \
			fi; \
			if grep -qE 'error\[E[0-9]+\]' "$$LOG" || grep -q 'could not compile' "$$LOG"; then \
				echo "  COMPILATION ERROR on $$c:"; \
				cat "$$LOG"; \
				break; \
			fi; \
			break; \
		done; \
		if [ $$SUCCESS -eq 0 ]; then \
			echo "  FAILED: $$c (no endpoint accepted activation simulation)"; \
			FAILED="$$FAILED $$c"; \
			printf "%s\t%s\t%s\t%s\t%s\n" "$$c" "0" "0" "-1" "no-endpoint" >> "$$REPORT"; \
			continue; \
		fi; \
		echo ""; \
		echo "  --- cargo stylus check output ---"; \
		cat "$$LOG"; \
		echo "  --- end ---"; \
		line=$$(grep 'contract size:' "$$LOG" | head -1); \
		cb=$$(echo "$$line" | grep -oE '\([0-9]+ bytes\)' | head -1 | grep -oE '[0-9]+'); \
		fr=$$(echo "$$line" | grep -oE '\([0-9]+ fragments?\)' | head -1 | grep -oE '[0-9]+'); \
		wline=$$(grep 'wasm size:' "$$LOG" | head -1); \
		ub=$$(echo "$$wline" | grep -oE '\([0-9]+ bytes\)' | head -1 | grep -oE '[0-9]+'); \
		cb=$${cb:-0}; ub=$${ub:-0}; fr=$${fr:-1}; \
		printf "%s\t%s\t%s\t%s\t%s\n" "$$c" "$$cb" "$$ub" "$$fr" "$$USED_EP" >> "$$REPORT"; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "SIZE SUMMARY"; \
	echo "============================================================"; \
	printf "%-30s %16s %20s %11s\n" "CONTRACT" "COMPRESSED" "UNCOMPRESSED" "FRAGMENTS"; \
	printf "%-30s %16s %20s %11s\n" "------------------------------" "----------------" "--------------------" "-----------"; \
	tail -n +2 "$$REPORT" | while IFS=$$'\t' read -r c cb ub fr ep; do \
		if [ "$$cb" = "0" ] && [ "$$ub" = "0" ]; then \
			printf "%-30s %16s %20s %11s\n" "$$c" "FAILED" "-" "-"; \
			continue; \
		fi; \
		ckb=$$(awk "BEGIN {printf \"%.1f\", $$cb/1024}"); \
		ukb=$$(awk "BEGIN {printf \"%.1f\", $$ub/1024}"); \
		printf "%-30s %12s KB %16s KB %11s\n" "$$c" "$$ckb" "$$ukb" "$$fr"; \
	done; \
	echo ""; \
	if [ -n "$$FAILED" ]; then \
		echo "FAILED CONTRACTS:"; \
		for c in $$FAILED; do echo "  - $$c"; done; \
		echo ""; \
		echo "Per-contract logs: $(CHECK_REPORTS)/<contract>.log"; \
		exit 1; \
	fi; \
	echo "All contracts passed check."; \
	echo "Size report: $$REPORT"
endif

# ============================================================
# 4. DEPLOY
# ============================================================

deploy:
ifndef contract
	@echo "ERROR: deploy requires contract=<name>. To deploy all, use deploy-full."
	@exit 1
endif
	@mkdir -p $(DEPLOYMENTS_DIR); \
	DIR="$(DEPLOYMENTS_DIR)/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	LOG="$$DIR/$(contract).log"; \
	ARGS="$(CONSTRUCTOR_ARGS_$(contract))"; \
	read -ra CTOR_ARGS <<< "$$ARGS"; \
	echo "============================================================"; \
	echo "  Deploying $(contract)"; \
	echo "============================================================"; \
	printf "  %-22s %s\n" "Endpoint (rpc):"  "$(ENDPOINT_SEPOLIA)"; \
	printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
	printf "  %-22s %s\n" "Args count:"       "$${#CTOR_ARGS[@]}"; \
	printf "  %-22s %s\n" "Log file:"         "$$LOG"; \
	echo "------------------------------------------------------------"; \
	set -o pipefail; \
	if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
		( cd src/$(contract) && cargo stylus deploy \
			--endpoint "$(ENDPOINT_SEPOLIA)" \
			--private-key $(PRIVATE_KEY) \
			--max-fee-per-gas-gwei=1 \
			--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
	else \
		( cd src/$(contract) && cargo stylus deploy \
			--endpoint "$(ENDPOINT_SEPOLIA)" \
			--private-key $(PRIVATE_KEY) \
			--max-fee-per-gas-gwei=1 ) 2>&1 | tee "$$LOG"; \
	fi; \
	PIPE_RC=$${PIPESTATUS[0]}; \
	if [ $$PIPE_RC -ne 0 ]; then \
		echo ""; \
		echo "============================================================"; \
		echo "  DEPLOY FAILED (exit code: $$PIPE_RC)"; \
		echo "  Full log: $$LOG"; \
		echo "============================================================"; \
		exit $$PIPE_RC; \
	fi; \
	DEPLOYER=$$(cast wallet address --private-key "$(PRIVATE_KEY)" 2>/dev/null || echo ""); \
	bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$(contract)" "$$DEPLOYER" "$(ENDPOINT_SEPOLIA)" > "$$DIR/manifest.json"; \
	addr=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/manifest.json"); \
	if [ -z "$$addr" ]; then \
		echo ""; \
		echo "============================================================"; \
		echo "  DEPLOY FAILED — no contract address in manifest."; \
		echo "  Full log: $$LOG"; \
		echo "============================================================"; \
		exit 1; \
	fi; \
	jq -n --arg a "$$addr" --arg k "$(contract)" '{($$k): $$a}' > "$$DIR/addresses.json"; \
	echo ""; \
	echo "============================================================"; \
	echo "  DEPLOY SUMMARY"; \
	echo "============================================================"; \
	printf "  %-22s %s\n" "Contract:"       "$(contract)"; \
	printf "  %-22s %s\n" "Address:"        "$$addr"; \
	echo "------------------------------------------------------------"; \
	printf "  %-22s %s\n" "Log:"            "$$LOG"; \
	printf "  %-22s %s\n" "Addresses:"      "$$DIR/addresses.json"; \
	printf "  %-22s %s\n" "Manifest:"       "$$DIR/manifest.json"; \
	echo "============================================================"; \
	echo ""; \
	echo "  NOTE: cargo stylus deploy runs inside Docker as root."; \
	echo "  Files under target/ may now be root-owned. Run 'make fix-perms'"; \
	echo "  before the next local build or ABI export."; \
	echo "============================================================"

deploy-full:
	@set -o pipefail; \
	PKEY="$(PRIVATE_KEY)"; \
	if [ -z "$$PKEY" ]; then echo "ERROR: PRIVATE_KEY is not set in .env"; exit 1; fi; \
	DIR="$(DEPLOYMENTS_DIR)/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	echo "{}" > "$$DIR/addresses.json"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	TIMESTAMP=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	jq -n \
		--arg project "$(PROJECT_NAME)" \
		--arg ts "$$TIMESTAMP" \
		--arg endpoint "$(ENDPOINT_SEPOLIA)" \
		'{project_info: {name: $$project, compiler: "Cargo Stylus (Rust)", timestamp: $$ts, network: "Arbitrum Sepolia (Testnet)", rpc_endpoint: $$endpoint}, contracts: {}}' \
		> "$$DIR/manifest.json"; \
	echo "Deployment directory: $$DIR"; \
	echo "  Using RPC: $(ENDPOINT_SEPOLIA)"; \
	for c in $(DEPLOYABLES); do \
		echo ""; \
		echo "============================================================"; \
		echo "  Deploying $$c"; \
		echo "============================================================"; \
		LOG="$$DIR/$$c.log"; \
		ARGS_VAR="CONSTRUCTOR_ARGS_$$c"; \
		ARGS="$${!ARGS_VAR}"; \
		read -ra CTOR_ARGS <<< "$$ARGS"; \
		printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
		echo "------------------------------------------------------------"; \
		if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
			( cd src/$$c && cargo stylus deploy \
				--endpoint "$(ENDPOINT_SEPOLIA)" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 \
				--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
		else \
			( cd src/$$c && cargo stylus deploy \
				--endpoint "$(ENDPOINT_SEPOLIA)" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 ) 2>&1 | tee "$$LOG"; \
		fi; \
		PIPE_RC=$${PIPESTATUS[0]}; \
		if [ $$PIPE_RC -ne 0 ]; then \
			echo "FAILED: $$c (exit $$PIPE_RC)"; \
			echo "Partial deployment kept at: $$DIR"; \
			echo "Resume with: make deploy-resume"; \
			exit 1; \
		fi; \
		bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$$c" "$$DEPLOYER" "$(ENDPOINT_SEPOLIA)" > "$$DIR/$$c.manifest.json"; \
		addr=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/$$c.manifest.json"); \
		if [ -z "$$addr" ]; then echo "FAILED: $$c (no address)"; exit 1; fi; \
		echo "  $$c → $$addr"; \
		jq --arg a "$$addr" --arg k "$$c" '. + {($$k): $$a}' "$$DIR/addresses.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
		jq --slurpfile m "$$DIR/$$c.manifest.json" --arg k "$$c" '.contracts[$$k] = $$m[0]' "$$DIR/manifest.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
		rm -f "$$DIR/$$c.manifest.json"; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "Deployment complete: $$DIR"; \
	echo "============================================================"; \
	cat "$$DIR/addresses.json"; \
	echo ""; \
	echo "  NOTE: cargo stylus deploy runs inside Docker as root."; \
	echo "  Run 'make fix-perms' before the next local build or ABI export."

deploy-resume:
	@set -o pipefail; \
	DIR="$$(ls -d $(DEPLOYMENTS_DIR)/*/ 2>/dev/null | sort | tail -n 1)"; \
	if [ -z "$$DIR" ]; then echo "No previous deployment found."; exit 1; fi; \
	echo "Resuming deployment: $$DIR"; \
	echo "  Using RPC: $(ENDPOINT_SEPOLIA)"; \
	PKEY="$(PRIVATE_KEY)"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	for c in $(DEPLOYABLES); do \
		addr=$$(jq -r --arg k "$$c" '.[$$k] // empty' "$$DIR/addresses.json"); \
		if [ -n "$$addr" ]; then echo "Skipping $$c (already at $$addr)"; continue; fi; \
		echo ""; \
		echo "============================================================"; \
		echo "  Deploying $$c"; \
		echo "============================================================"; \
		LOG="$$DIR/$$c.log"; \
		ARGS_VAR="CONSTRUCTOR_ARGS_$$c"; \
		ARGS="$${!ARGS_VAR}"; \
		read -ra CTOR_ARGS <<< "$$ARGS"; \
		printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
		echo "------------------------------------------------------------"; \
		if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
			( cd src/$$c && cargo stylus deploy \
				--endpoint "$(ENDPOINT_SEPOLIA)" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 \
				--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
		else \
			( cd src/$$c && cargo stylus deploy \
				--endpoint "$(ENDPOINT_SEPOLIA)" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 ) 2>&1 | tee "$$LOG"; \
		fi; \
		PIPE_RC=$${PIPESTATUS[0]}; \
		if [ $$PIPE_RC -ne 0 ]; then echo "FAILED: $$c"; exit 1; fi; \
		bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$$c" "$$DEPLOYER" "$(ENDPOINT_SEPOLIA)" > "$$DIR/$$c.manifest.json"; \
		addr=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/$$c.manifest.json"); \
		if [ -z "$$addr" ]; then echo "FAILED: $$c (no address)"; exit 1; fi; \
		echo "  $$c → $$addr"; \
		jq --arg a "$$addr" --arg k "$$c" '. + {($$k): $$a}' "$$DIR/addresses.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
		jq --slurpfile m "$$DIR/$$c.manifest.json" --arg k "$$c" '.contracts = ((.contracts // {}) + {($$k): $$m[0]})' "$$DIR/manifest.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
		rm -f "$$DIR/$$c.manifest.json"; \
	done; \
	echo "Resume complete: $$DIR"

verify:
ifndef contract
	@echo "ERROR: verify requires contract=<name>"; exit 1
endif
ifndef tx
	@echo "ERROR: verify requires tx=0x<deployment-tx-hash>"; exit 1
endif
	@cd src/$(contract) && cargo stylus verify \
		--deployment-tx $(tx) \
		--endpoint "$(ENDPOINT_SEPOLIA)"

# ============================================================
# 5. CACHE (ArbOS CacheManager)
# ============================================================

cache-suggest:
ifndef addr
	@echo "ERROR: cache-suggest requires addr=<contract-address>"; exit 1
endif
	@cargo stylus cache suggest-bid $(addr) --endpoint "$(ENDPOINT_SEPOLIA)"

cache-bid:
ifndef addr
	@echo "ERROR: cache-bid requires addr=<contract-address>"; exit 1
endif
ifndef bid
	@echo "ERROR: cache-bid requires bid=<amount-in-wei>"; exit 1
endif
	@cargo stylus cache bid $(addr) $(bid) \
		--endpoint "$(ENDPOINT_SEPOLIA)" \
		--private-key $(PRIVATE_KEY)

cache-status:
ifndef addr
	@echo "ERROR: cache-status requires addr=<contract-address>"; exit 1
endif
	@cargo stylus cache status $(addr) --endpoint "$(ENDPOINT_SEPOLIA)"

# ============================================================
# 6. DIAGNOSTICS
# ============================================================

print-constructor-args:
ifndef contract
	@echo "ERROR: print-constructor-args requires contract=<name>"; exit 1
endif
	@echo "Constructor args for $(contract):"
	@echo "  Raw (space-separated): $(CONSTRUCTOR_ARGS_$(contract))"
	@echo ""
	@echo "Will expand to argv entries:"
	@ARGS="$(CONSTRUCTOR_ARGS_$(contract))"; \
	read -ra CTOR_ARGS <<< "$$ARGS"; \
	i=0; \
	for arg in "$${CTOR_ARGS[@]}"; do \
		printf "    [%d] %s\n" "$$i" "$$arg"; \
		i=$$((i+1)); \
	done

print-deploy-order:
	@echo "Deploy order (from DEPLOYABLES):"
	@n=1; \
	for c in $(DEPLOYABLES); do \
		printf "  %2d. %s\n" "$$n" "$$c"; \
		n=$$((n+1)); \
	done
	@echo ""
	@echo "Contracts in CONTRACTS but NOT in DEPLOYABLES (per-user or non-singleton):"
	@for c in $(CONTRACTS); do \
		case " $(DEPLOYABLES) " in \
			*" $$c "*) ;; \
			*) echo "    - $$c";; \
		esac; \
	done

# ============================================================
# 7. PERMISSION RECOVERY
# ============================================================

fix-perms:
	@if [ ! -d target ]; then \
		echo "target/ does not exist. Nothing to fix."; \
		exit 0; \
	fi; \
	OWNED_BY_ROOT=$$(find target -user root -print -quit 2>/dev/null); \
	if [ -z "$$OWNED_BY_ROOT" ]; then \
		echo "No root-owned files found under target/. Nothing to fix."; \
		exit 0; \
	fi; \
	echo "Reclaiming ownership of target/ ..."; \
	sudo chown -R $$(id -u):$$(id -g) target/; \
	echo "Done. target/ is now owned by $$(id -un)."

nuke:
	@echo "Nuking build state ..."
	@echo ""
	@echo "  [1/3] Removing target/ ..."
	@if [ -d target ]; then \
		if [ -n "$$(find target -user root -print -quit 2>/dev/null)" ]; then \
			sudo rm -rf target; \
		else \
			rm -rf target; \
		fi; \
	fi
	@echo "  [2/3] Removing cargo-stylus Docker containers ..."
	@docker ps -a --filter "ancestor=cargo-stylus-base-0.10.9-toolchain-nightly-2025-09-23-binaryen-132" --format '{{.ID}}' 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1 || true
	@echo "  [3/3] Removing cargo-stylus-base Docker image ..."
	@docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep '^cargo-stylus-base-' | xargs -r docker rmi -f >/dev/null 2>&1 || true
	@echo ""
	@echo "Nuke complete. Next build will recreate everything from scratch."

# ============================================================
# 8. MAINTENANCE
# ============================================================

clean:
	cargo clean
	rm -rf $(CHECK_REPORTS)

clean-deployments:
	rm -rf $(DEPLOYMENTS_DIR)

clean-abi:
	@echo "Removing $(FOUNDRY_INTERFACES)/*.sol ..."
	@rm -f $(FOUNDRY_INTERFACES)/*.sol
	@echo "Done. Run 'make abi' to regenerate."

help:
	@echo ""
	@echo "==================== MAKE HELP ===================="
	@echo ""
	@echo "BUILD"
	@echo "  build         Compile Stylus WASM contracts"
	@echo "  abi           Generate Solidity ABIs (tuple + struct + data-location fixes)"
	@echo "  lock          Regenerate Cargo.lock"
	@echo ""
	@echo "TESTING"
	@echo "  test          Unit + e2e (no network)"
	@echo "  test-bridge   Bridge semantic tests"
	@echo "  test-fork     Fork tests against Sepolia"
	@echo "  test-all      All three layers"
	@echo ""
	@echo "ON-CHAIN"
	@echo "  probe-rpc     Test all RPC endpoints (diagnostic)"
	@echo "  check         Dry-run activation + retry across endpoints"
	@echo "  deploy        Deploy single (contract=<name>)"
	@echo "  deploy-full   Deploy all in dependency order + manifest"
	@echo "  deploy-resume Resume last incomplete deployment"
	@echo "  verify        Reproducible verification (contract + tx)"
	@echo ""
	@echo "CACHE"
	@echo "  cache-suggest addr=0x...      Suggested minimum bid"
	@echo "  cache-bid     addr=0x... bid=...  Submit cache bid"
	@echo "  cache-status  addr=0x...      Read cache status"
	@echo ""
	@echo "DIAGNOSTICS"
	@echo "  print-constructor-args contract=<name>  Show args for deploy"
	@echo "  print-deploy-order                      Show deploy order"
	@echo ""
	@echo "RECOVERY"
	@echo "  fix-perms          Reclaim ownership of target/ (root -> user)"
	@echo "  nuke               Hard reset target/ + Docker containers/images"
	@echo ""
	@echo "MAINTENANCE"
	@echo "  clean              Remove build artifacts and check reports"
	@echo "  clean-deployments  Remove all deployment records"
	@echo "  clean-abi          Remove generated Solidity interfaces"
	@echo ""
	@echo "==================================================="

.PHONY: build abi lock test test-bridge test-fork test-all \
        probe-rpc check deploy deploy-full deploy-resume verify \
        cache-suggest cache-bid cache-status \
        print-constructor-args print-deploy-order \
        fix-perms nuke \
        clean clean-deployments clean-abi help
