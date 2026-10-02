# Force bash so we can use PIPESTATUS, pipefail, and array semantics.
SHELL := /bin/bash

# ============================================================
# ENV LOADING
# ============================================================
ifneq ("$(wildcard .env)","")
	include .env
	export $(shell sed 's/=.*//' .env | grep -v '^#')
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
E2E_DIR = e2e
REVERSE_ENGINEERING_DIR = .reverse-engineering

WORKING_ENDPOINT_FILE = $(CHECK_REPORTS)/.working-endpoint
ENDPOINT_PROBE_CONTRACT = kipio_protocol_config

SOLIDITY_PRAGMA = pragma solidity ^0.8.37;

# ============================================================
# CONTRACT LISTS
# ============================================================

CONTRACTS = \
	kipio_protocol_config \
	kipio_identity_content \
	kipio_account \
	kipio_recovery \
	kipio_runtime \
	kipio_economics \
	kipio_execution_gateway

SINGLETON_DEPLOYABLES = \
	kipio_protocol_config \
	kipio_runtime \
	kipio_recovery \
	kipio_economics \
	kipio_identity_content

GATEWAY_CONTRACT = kipio_execution_gateway

# ============================================================
# CONSTANTS — external addresses and placeholders
# ============================================================

CRE_FORWARDER_ARB_SEPOLIA = 0x76c9cf548b4179F8901cda1f8623568b58215E62

CRE_WORKFLOW_ID_PLACEHOLDER = 0x0000000000000000000000000000000000000000000000000000000000000000

IDENTITY_STORAGE_PROVIDER = 0x0000000000000000000000000000000000000001
IDENTITY_QUERY_PROVIDER   = 0x0000000000000000000000000000000000000002
IDENTITY_ACCESS_PROVIDER  = 0x0000000000000000000000000000000000000003
IDENTITY_EXPECTED_WORKFLOW_ID = 0x0000000000000000000000000000000000000000000000000000000000000000

# ============================================================
# SOURCE FILES FOR PROJECT HASH
# ============================================================
define source_files_for_hash
$$(find src/$(1)/src -name '*.rs' -type f \
    -not -path '*/tests/*' \
    -not -path '*/examples/*' \
    -not -path '*/benches/*' \
    | sort | tr '\n' ' ') \
src/$(1)/Cargo.toml \
$(wildcard src/$(1)/build.rs) \
$(wildcard src/$(1)/fragments.toml) \
Cargo.lock
endef

# ============================================================
# PER-CONTRACT CONSTRUCTOR ARGUMENTS
# ============================================================

CONSTRUCTOR_ARGS_kipio_protocol_config =
CONSTRUCTOR_ARGS_kipio_runtime = $(CTOR_RUNTIME_PROTOCOL_CONFIG)
CONSTRUCTOR_ARGS_kipio_recovery = $(CTOR_RECOVERY_RUNTIME)
CONSTRUCTOR_ARGS_kipio_economics = $(CTOR_ECONOMICS_PROTOCOL_CONFIG) $(CTOR_ECONOMICS_CRE_FORWARDER) $(CTOR_ECONOMICS_CRE_WORKFLOW_ID)
CONSTRUCTOR_ARGS_kipio_identity_content = $(CTOR_IDENTITY_CONTENT_STORAGE_PROVIDER) $(CTOR_IDENTITY_CONTENT_QUERY_PROVIDER) $(CTOR_IDENTITY_CONTENT_ACCESS_PROVIDER) $(CTOR_IDENTITY_CONTENT_EXPECTED_WORKFLOW_ID)
CONSTRUCTOR_ARGS_kipio_execution_gateway =
CONSTRUCTOR_ARGS_kipio_account = $(KIPIO_ACCOUNT_IDENTITY) $(KIPIO_ACCOUNT_RUNTIME) $(KIPIO_ACCOUNT_RECOVERY)

KIPIO_ACCOUNT_IDENTITY ?= 0x0000000000000000000000000000000000000001
KIPIO_ACCOUNT_RUNTIME  ?= 0x0000000000000000000000000000000000000002
KIPIO_ACCOUNT_RECOVERY ?= 0x0000000000000000000000000000000000000003

CTOR_ARG_VARS := $(filter CONSTRUCTOR_ARGS_%,$(.VARIABLES))
export $(CTOR_ARG_VARS)

# ============================================================
# PER-CONTRACT BUILD FEATURES
# ============================================================
FEATURES_kipio_execution_gateway = production_build

FEATURE_VARS := $(filter FEATURES_%,$(.VARIABLES))
export $(FEATURE_VARS)

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
	@HASH_FILES="$(call source_files_for_hash,$(contract))"; \
	FEATURES_FLAG="$(if $(FEATURES_$(contract)),--features $(FEATURES_$(contract)),)"; \
	echo "  features: $(if $(FEATURES_$(contract)),$(FEATURES_$(contract)),<none>)"; \
	cd src/$(contract) && \
		cargo stylus build $$FEATURES_FLAG --source-files-for-project-hash "$$HASH_FILES"
else
	@set -e; \
	for c in $(CONTRACTS); do \
		echo ""; \
		echo "Building $$c"; \
		HASH_FILES="$(call source_files_for_hash,$$c)"; \
		FEATURES_VAR="FEATURES_$$c"; \
		FEATURES="$${!FEATURES_VAR}"; \
		FEATURES_FLAG=""; \
		if [ -n "$$FEATURES" ]; then FEATURES_FLAG="--features $$FEATURES"; fi; \
		echo "  features: $${FEATURES:-<none>}"; \
		( cd src/$$c && \
			cargo stylus build $$FEATURES_FLAG --source-files-for-project-hash "$$HASH_FILES" ); \
	done; \
	echo ""; \
	echo "All contracts built."
endif

# ============================================================
# ABI EXPORT
# ============================================================
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

test-bridge:
	$(guard_perms)
	cargo test -p kipio_account_bridge

test-unit:
	$(guard_perms)
	cargo test -p kipio_tests --test unit

test-integration:
	$(guard_perms)
	cargo test -p kipio_tests --test e2e

test-fork:
	$(guard_perms)
	cargo test -p kipio_tests --test fork -- --ignored

test-e2e-ts:
	@if [ ! -d "$(E2E_DIR)" ]; then \
		echo "ERROR: $(E2E_DIR)/ does not exist."; \
		exit 1; \
	fi
	@cd $(E2E_DIR) && pnpm vitest run

test-all: test-bridge test-unit test-integration
	@echo ""
	@echo "============================================================"
	@echo "  test-all completed (bridge + unit + integration)"
	@echo "============================================================"
	@echo "  Fork tests are NOT included. Run separately:"
	@echo "    make test-fork"
	@echo "  E2E TypeScript is NOT included. Run separately:"
	@echo "    make test-e2e-ts"
	@echo "============================================================"

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

# ============================================================
# BASE FEE PROBE
# ============================================================

MAX_FEE_PER_GAS_GWEI ?= 1

print-base-fee:
	@echo ""
	@echo "============================================================"
	@echo "  BASE FEE PROBE — Arbitrum Sepolia (chain ID 421614)"
	@echo "============================================================"
	@ENDPOINTS='$(ENDPOINT_SEPOLIA_ALL)'; \
	FOUND=0; \
	USED_EP=""; \
	BASE_FEE_WEI=""; \
	for ep in $$ENDPOINTS; do \
		printf "  Trying: %-70s " "$$ep"; \
		FEE=$$(cast base-fee --rpc-url "$$ep" 2>/dev/null); \
		if [ -n "$$FEE" ] && [ "$$FEE" != "0" ]; then \
			FOUND=1; \
			USED_EP="$$ep"; \
			BASE_FEE_WEI="$$FEE"; \
			echo "OK"; \
			break; \
		else \
			echo "FAIL (no response or zero)"; \
		fi; \
	done; \
	echo ""; \
	if [ $$FOUND -eq 0 ]; then \
		echo "============================================================"; \
		echo "  NO ENDPOINT RETURNED A VALID BASE FEE"; \
		echo "============================================================"; \
		echo "  Tried endpoints:"; \
		for ep in $$ENDPOINTS; do echo "    - $$ep"; done; \
		echo ""; \
		echo "  This is an RPC limitation, not a contract bug."; \
		echo "============================================================"; \
		exit 1; \
	fi; \
	BASE_FEE_GWEI=$$(cast --to-unit "$$BASE_FEE_WEI" gwei 2>/dev/null || echo "unknown"); \
	echo "  Endpoint used:    $$USED_EP"; \
	echo "  Base fee (wei):   $$BASE_FEE_WEI"; \
	echo "  Base fee (gwei):  $$BASE_FEE_GWEI"; \
	echo "  Max fee in Make:  $(MAX_FEE_PER_GAS_GWEI) gwei"; \
	echo ""; \
	if [ "$$BASE_FEE_GWEI" != "unknown" ]; then \
		CMP=$$(awk "BEGIN {print ($$BASE_FEE_GWEI > $(MAX_FEE_PER_GAS_GWEI)) ? 1 : 0}"); \
		if [ "$$CMP" = "1" ]; then \
			echo "  WARNING: base fee ($$BASE_FEE_GWEI gwei) exceeds"; \
			echo "           MAX_FEE_PER_GAS_GWEI ($(MAX_FEE_PER_GAS_GWEI) gwei)."; \
			echo "           Deploy may fail. Update MAX_FEE_PER_GAS_GWEI or"; \
			echo "           pass --max-fee-per-gas-gwei with a higher value."; \
		else \
			echo "  OK: base fee is within MAX_FEE_PER_GAS_GWEI."; \
		fi; \
	fi; \
	echo "============================================================"

# ============================================================
# check — Endpoint probe once, then cargo stylus check per contract
# ============================================================

check:
	$(guard_perms)
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
ifdef contract
	@WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	LOG="$(CHECK_REPORTS)/$(contract).log"; \
	echo ""; \
	echo "============================================================"; \
	echo "Checking $(contract)"; \
	echo "============================================================"; \
	echo "  Endpoint: $$WORKING_EP"; \
	echo "  Log:      $$LOG"; \
	echo "------------------------------------------------------------"; \
	(cd src/$(contract) && cargo stylus check --endpoint "$$WORKING_EP" --verbose) > "$$LOG" 2>&1; \
	RC=$$?; \
	echo ""; \
	echo "  --- cargo stylus check output ---"; \
	cat "$$LOG"; \
	echo "  --- end ---"; \
	if [ $$RC -ne 0 ]; then \
		echo ""; \
		echo "  CHECK FAILED (exit $$RC)"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "  ✓ $(contract) passed check"
else
	@WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	FAILED=""; \
	mkdir -p $(CHECK_REPORTS); \
	REPORT="$(CHECK_REPORTS)/sizes.tsv"; \
	printf "contract\tcompressed_bytes\tuncompressed_bytes\tfragments\n" > "$$REPORT"; \
	for c in $(CONTRACTS); do \
		LOG="$(CHECK_REPORTS)/$$c.log"; \
		echo ""; \
		echo "============================================================"; \
		echo "Checking $$c"; \
		echo "============================================================"; \
		echo "  Endpoint: $$WORKING_EP"; \
		echo "  Log:      $$LOG"; \
		echo "------------------------------------------------------------"; \
		(cd src/$$c && cargo stylus check --endpoint "$$WORKING_EP" --verbose) > "$$LOG" 2>&1; \
		RC=$$?; \
		echo ""; \
		echo "  --- cargo stylus check output ---"; \
		cat "$$LOG"; \
		echo "  --- end ---"; \
		if [ $$RC -ne 0 ]; then \
			echo "  FAILED: $$c (exit $$RC)"; \
			FAILED="$$FAILED $$c"; \
			printf "%s\t%s\t%s\t%s\n" "$$c" "0" "0" "-1" >> "$$REPORT"; \
			continue; \
		fi; \
		line=$$(grep 'contract size:' "$$LOG" | head -1); \
		cb=$$(echo "$$line" | grep -oE '\([0-9]+ bytes\)' | head -1 | grep -oE '[0-9]+'); \
		fr=$$(echo "$$line" | grep -oE '\([0-9]+ fragments?\)' | head -1 | grep -oE '[0-9]+'); \
		wline=$$(grep 'wasm size:' "$$LOG" | head -1); \
		ub=$$(echo "$$wline" | grep -oE '\([0-9]+ bytes\)' | head -1 | grep -oE '[0-9]+'); \
		cb=$${cb:-0}; ub=$${ub:-0}; fr=$${fr:-1}; \
		printf "%s\t%s\t%s\t%s\n" "$$c" "$$cb" "$$ub" "$$fr" >> "$$REPORT"; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "SIZE SUMMARY"; \
	echo "============================================================"; \
	printf "%-30s %16s %20s %11s\n" "CONTRACT" "COMPRESSED" "UNCOMPRESSED" "FRAGMENTS"; \
	printf "%-30s %16s %20s %11s\n" "------------------------------" "----------------" "--------------------" "-----------"; \
	tail -n +2 "$$REPORT" | while IFS=$$'\t' read -r c cb ub fr; do \
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
	$(guard_perms)
	@mkdir -p $(DEPLOYMENTS_DIR)
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
	@WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	DIR="$(DEPLOYMENTS_DIR)/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	LOG="$$DIR/$(contract).log"; \
	ARGS="$(CONSTRUCTOR_ARGS_$(contract))"; \
	read -ra CTOR_ARGS <<< "$$ARGS"; \
	HASH_FILES="$(call source_files_for_hash,$(contract))"; \
	FEATURES_FLAG="$(if $(FEATURES_$(contract)),--features $(FEATURES_$(contract)),)"; \
	echo ""; \
	echo "============================================================"; \
	echo "  Deploying $(contract)"; \
	echo "============================================================"; \
	printf "  %-22s %s\n" "Endpoint (rpc):"  "$$WORKING_EP"; \
	printf "  %-22s %s\n" "Features:"        "$(if $(FEATURES_$(contract)),$(FEATURES_$(contract)),<none>)"; \
	printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
	printf "  %-22s %s\n" "Args count:"       "$${#CTOR_ARGS[@]}"; \
	printf "  %-22s %s\n" "Hash files:"      "$$(echo $$HASH_FILES | wc -w) entries"; \
	printf "  %-22s %s\n" "Log file:"         "$$LOG"; \
	echo "------------------------------------------------------------"; \
	set -o pipefail; \
	if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
		( cd src/$(contract) && \
			cargo stylus deploy \
			$$FEATURES_FLAG \
			--endpoint "$$WORKING_EP" \
			--private-key $(PRIVATE_KEY) \
			--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
			--source-files-for-project-hash "$$HASH_FILES" \
			--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
	else \
		( cd src/$(contract) && \
			cargo stylus deploy \
			$$FEATURES_FLAG \
			--endpoint "$$WORKING_EP" \
			--private-key $(PRIVATE_KEY) \
			--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
			--source-files-for-project-hash "$$HASH_FILES" ) 2>&1 | tee "$$LOG"; \
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
	bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$(contract)" "$$DEPLOYER" "$$WORKING_EP" > "$$DIR/manifest.json"; \
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

# ============================================================
# deploy-full — Fase 1 + Fase 2 + Fase 3 + Fase 4
# ============================================================
#
# NOTE: cargo stylus deploy uses --max-fee-per-gas-gwei (cargo-stylus
# specific flag). cast send uses --gas-price, which accepts a unit
# suffix like '1gwei'. They are not interchangeable.
# ------------------------------------------------------------

deploy-full:
	$(guard_perms)
	@mkdir -p $(DEPLOYMENTS_DIR)
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
	@set -o pipefail; \
	WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	PKEY="$(PRIVATE_KEY)"; \
	if [ -z "$$PKEY" ]; then echo "ERROR: PRIVATE_KEY is not set in .env"; exit 1; fi; \
	echo ""; \
	echo "============================================================"; \
	echo "  PRE-DEPLOY BASE FEE CHECK"; \
	echo "============================================================"; \
	$(MAKE) --no-print-directory print-base-fee || true; \
	echo ""; \
	DIR="$(DEPLOYMENTS_DIR)/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	echo "{}" > "$$DIR/addresses.json"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	TIMESTAMP=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	jq -n \
		--arg project "$(PROJECT_NAME)" \
		--arg ts "$$TIMESTAMP" \
		--arg endpoint "$$WORKING_EP" \
		'{project_info: {name: $$project, compiler: "Cargo Stylus (Rust)", timestamp: $$ts, network: "Arbitrum Sepolia (Testnet)", rpc_endpoint: $$endpoint}, contracts: {}}' \
		> "$$DIR/manifest.json"; \
	echo "Deployment directory: $$DIR"; \
	echo "  Using RPC: $$WORKING_EP"; \
	echo ""; \
	echo "############################################################"; \
	echo "#  FASE 1 — Deploy de singletons                            #"; \
	echo "############################################################"; \
	PROTOCOL_CONFIG=""; \
	RUNTIME=""; \
	RECOVERY=""; \
	ECONOMICS=""; \
	IDENTITY_CONTENT=""; \
	for c in $(SINGLETON_DEPLOYABLES); do \
		echo ""; \
		echo "============================================================"; \
		echo "  Deploying $$c (phase 1)"; \
		echo "============================================================"; \
		LOG="$$DIR/$$c.log"; \
		case "$$c" in \
			kipio_protocol_config) ARGS="" ;; \
			kipio_runtime) ARGS="$$PROTOCOL_CONFIG" ;; \
			kipio_recovery) ARGS="$$RUNTIME" ;; \
			kipio_economics) ARGS="$$PROTOCOL_CONFIG $(CRE_FORWARDER_ARB_SEPOLIA) $(CRE_WORKFLOW_ID_PLACEHOLDER)" ;; \
			kipio_identity_content) ARGS="$(IDENTITY_STORAGE_PROVIDER) $(IDENTITY_QUERY_PROVIDER) $(IDENTITY_ACCESS_PROVIDER) $(IDENTITY_EXPECTED_WORKFLOW_ID)" ;; \
			*) echo "  ERROR: no ARGS policy for $$c"; exit 1 ;; \
		esac; \
		read -ra CTOR_ARGS <<< "$$ARGS"; \
		HASH_FILES="$(call source_files_for_hash,$$c)"; \
		FEATURES_VAR="FEATURES_$$c"; \
		FEATURES="$${!FEATURES_VAR}"; \
		FEATURES_FLAG=""; \
		if [ -n "$$FEATURES" ]; then FEATURES_FLAG="--features $$FEATURES"; fi; \
		printf "  %-22s %s\n" "Features:"        "$${FEATURES:-<none>}"; \
		printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
		printf "  %-22s %s\n" "Hash files:"      "$$(echo $$HASH_FILES | wc -w) entries"; \
		echo "------------------------------------------------------------"; \
		if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
			( cd src/$$c && \
				cargo stylus deploy \
				$$FEATURES_FLAG \
				--endpoint "$$WORKING_EP" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
				--source-files-for-project-hash "$$HASH_FILES" \
				--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
		else \
			( cd src/$$c && \
				cargo stylus deploy \
				$$FEATURES_FLAG \
				--endpoint "$$WORKING_EP" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
				--source-files-for-project-hash "$$HASH_FILES" ) 2>&1 | tee "$$LOG"; \
		fi; \
		PIPE_RC=$${PIPESTATUS[0]}; \
		if [ $$PIPE_RC -ne 0 ]; then \
			echo "FAILED: $$c (exit $$PIPE_RC)"; \
			echo "Partial deployment kept at: $$DIR"; \
			echo "Resume with: make deploy-resume"; \
			exit 1; \
		fi; \
		bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$$c" "$$DEPLOYER" "$$WORKING_EP" > "$$DIR/$$c.manifest.json"; \
		addr=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/$$c.manifest.json"); \
		if [ -z "$$addr" ]; then echo "FAILED: $$c (no address)"; exit 1; fi; \
		echo "  $$c → $$addr"; \
		jq --arg a "$$addr" --arg k "$$c" '. + {($$k): $$a}' "$$DIR/addresses.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
		jq --slurpfile m "$$DIR/$$c.manifest.json" --arg k "$$c" '.contracts[$$k] = $$m[0]' "$$DIR/manifest.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
		rm -f "$$DIR/$$c.manifest.json"; \
		case "$$c" in \
			kipio_protocol_config) PROTOCOL_CONFIG="$$addr" ;; \
			kipio_runtime) RUNTIME="$$addr" ;; \
			kipio_recovery) RECOVERY="$$addr" ;; \
			kipio_economics) ECONOMICS="$$addr" ;; \
			kipio_identity_content) IDENTITY_CONTENT="$$addr" ;; \
		esac; \
	done; \
	echo ""; \
	echo "############################################################"; \
	echo "#  FASE 2 — Registro de módulos en protocol_config          #"; \
	echo "############################################################"; \
	echo "  protocol_config: $$PROTOCOL_CONFIG"; \
	echo "  runtime:         $$RUNTIME"; \
	echo "  recovery:        $$RECOVERY"; \
	echo "  economics:       $$ECONOMICS"; \
	echo "  identity:        $$IDENTITY_CONTENT"; \
	echo ""; \
	echo "  Setting runtime address..."; \
	cast send "$$PROTOCOL_CONFIG" "setRuntimeAddress(address)" "$$RUNTIME" \
		--rpc-url "$$WORKING_EP" --private-key $$PKEY --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo "  Setting recovery address..."; \
	cast send "$$PROTOCOL_CONFIG" "setRecoveryAddress(address)" "$$RECOVERY" \
		--rpc-url "$$WORKING_EP" --private-key $$PKEY --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo "  Setting economics address..."; \
	cast send "$$PROTOCOL_CONFIG" "setEconomicsAddress(address)" "$$ECONOMICS" \
		--rpc-url "$$WORKING_EP" --private-key $$PKEY --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo "  Setting identity_content address..."; \
	cast send "$$PROTOCOL_CONFIG" "setIdentityContentAddress(address)" "$$IDENTITY_CONTENT" \
		--rpc-url "$$WORKING_EP" --private-key $$PKEY --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo ""; \
	echo "  ✓ Módulos registrados"; \
	echo ""; \
	echo "############################################################"; \
	echo "#  FASE 3 — Gateway: inject + rebuild + deploy              #"; \
	echo "############################################################"; \
	echo "  [3.1] Inyectando constantes en constants.rs..."; \
	bash $(SCRIPTS_DIR)/inject-gateway-constants.sh "$$RUNTIME" "$$ECONOMICS" "$$RECOVERY" || exit 1; \
	echo ""; \
	echo "  [3.2] Rebuild del Gateway con production_build..."; \
	HASH_FILES="$(call source_files_for_hash,$(GATEWAY_CONTRACT))"; \
	FEATURES_FLAG="--features $(FEATURES_$(GATEWAY_CONTRACT))"; \
	( cd src/$(GATEWAY_CONTRACT) && \
		cargo stylus build \
		$$FEATURES_FLAG \
		--source-files-for-project-hash "$$HASH_FILES" ) || exit 1; \
	echo ""; \
	echo "  [3.3] Deploy del Gateway..."; \
	GW_LOG="$$DIR/$(GATEWAY_CONTRACT).log"; \
	( cd src/$(GATEWAY_CONTRACT) && \
		cargo stylus deploy \
		$$FEATURES_FLAG \
		--endpoint "$$WORKING_EP" \
		--private-key $$PKEY \
		--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
		--source-files-for-project-hash "$$HASH_FILES" ) 2>&1 | tee "$$GW_LOG"; \
	GW_PIPE_RC=$${PIPESTATUS[0]}; \
	if [ $$GW_PIPE_RC -ne 0 ]; then \
		echo "FAILED: $(GATEWAY_CONTRACT) (exit $$GW_PIPE_RC)"; \
		exit 1; \
	fi; \
	bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$GW_LOG" "$(PROJECT_NAME)" "$(GATEWAY_CONTRACT)" "$$DEPLOYER" "$$WORKING_EP" > "$$DIR/$(GATEWAY_CONTRACT).manifest.json"; \
	GATEWAY=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/$(GATEWAY_CONTRACT).manifest.json"); \
	if [ -z "$$GATEWAY" ]; then echo "FAILED: gateway (no address)"; exit 1; fi; \
	echo "  gateway → $$GATEWAY"; \
	jq --arg a "$$GATEWAY" --arg k "$(GATEWAY_CONTRACT)" '. + {($$k): $$a}' "$$DIR/addresses.json" > "$$DIR/tmp.json"; \
	mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
	jq --slurpfile m "$$DIR/$(GATEWAY_CONTRACT).manifest.json" --arg k "$(GATEWAY_CONTRACT)" '.contracts[$$k] = $$m[0]' "$$DIR/manifest.json" > "$$DIR/tmp.json"; \
	mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
	rm -f "$$DIR/$(GATEWAY_CONTRACT).manifest.json"; \
	echo ""; \
	echo "############################################################"; \
	echo "#  FASE 4 — Registro del Gateway en protocol_config         #"; \
	echo "############################################################"; \
	cast send "$$PROTOCOL_CONFIG" "setExecutionGatewayAddress(address)" "$$GATEWAY" \
		--rpc-url "$$WORKING_EP" --private-key $$PKEY --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo "  ✓ Gateway registrado"; \
	echo ""; \
	echo "============================================================"; \
	echo "Deployment complete: $$DIR"; \
	echo "============================================================"; \
	cat "$$DIR/addresses.json"; \
	echo ""; \
	echo "  NOTE: cargo stylus deploy runs inside Docker as root."; \
	echo "  Run 'make fix-perms' before the next local build or ABI export."

# ============================================================
# register-modules — Fase 2 standalone (idempotente)
# ============================================================
register-modules:
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
	@set -o pipefail; \
	WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	DIR="$$(ls -d $(DEPLOYMENTS_DIR)/*/ 2>/dev/null | sort | tail -1)"; \
	if [ -z "$$DIR" ]; then echo "No previous deployment found."; exit 1; fi; \
	PROTOCOL_CONFIG=$$(jq -r '.["kipio_protocol_config"] // empty' "$$DIR/addresses.json"); \
	RUNTIME=$$(jq -r '.["kipio_runtime"] // empty' "$$DIR/addresses.json"); \
	RECOVERY=$$(jq -r '.["kipio_recovery"] // empty' "$$DIR/addresses.json"); \
	ECONOMICS=$$(jq -r '.["kipio_economics"] // empty' "$$DIR/addresses.json"); \
	IDENTITY_CONTENT=$$(jq -r '.["kipio_identity_content"] // empty' "$$DIR/addresses.json"); \
	if [ -z "$$PROTOCOL_CONFIG" ]; then echo "ERROR: no protocol_config in $$DIR"; exit 1; fi; \
	echo "Registering modules from $$DIR via $$WORKING_EP"; \
	cast send "$$PROTOCOL_CONFIG" "setRuntimeAddress(address)" "$$RUNTIME" \
		--rpc-url "$$WORKING_EP" --private-key $(PRIVATE_KEY) --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	cast send "$$PROTOCOL_CONFIG" "setRecoveryAddress(address)" "$$RECOVERY" \
		--rpc-url "$$WORKING_EP" --private-key $(PRIVATE_KEY) --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	cast send "$$PROTOCOL_CONFIG" "setEconomicsAddress(address)" "$$ECONOMICS" \
		--rpc-url "$$WORKING_EP" --private-key $(PRIVATE_KEY) --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	cast send "$$PROTOCOL_CONFIG" "setIdentityContentAddress(address)" "$$IDENTITY_CONTENT" \
		--rpc-url "$$WORKING_EP" --private-key $(PRIVATE_KEY) --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo "✓ Modules registered"

# ============================================================
# deploy-gateway — Fase 3+4 standalone (idempotente)
# ============================================================
deploy-gateway:
	$(guard_perms)
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
	@set -o pipefail; \
	WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	DIR="$$(ls -d $(DEPLOYMENTS_DIR)/*/ 2>/dev/null | sort | tail -1)"; \
	if [ -z "$$DIR" ]; then echo "No previous deployment found."; exit 1; fi; \
	PROTOCOL_CONFIG=$$(jq -r '.["kipio_protocol_config"] // empty' "$$DIR/addresses.json"); \
	RUNTIME=$$(jq -r '.["kipio_runtime"] // empty' "$$DIR/addresses.json"); \
	RECOVERY=$$(jq -r '.["kipio_recovery"] // empty' "$$DIR/addresses.json"); \
	ECONOMICS=$$(jq -r '.["kipio_economics"] // empty' "$$DIR/addresses.json"); \
	if [ -z "$$PROTOCOL_CONFIG" ] || [ -z "$$RUNTIME" ] || [ -z "$$RECOVERY" ] || [ -z "$$ECONOMICS" ]; then \
		echo "ERROR: missing one of protocol_config/runtime/recovery/economics"; \
		echo "  protocol_config=$$PROTOCOL_CONFIG"; \
		echo "  runtime=$$RUNTIME"; \
		echo "  recovery=$$RECOVERY"; \
		echo "  economics=$$ECONOMICS"; \
		exit 1; \
	fi; \
	PKEY="$(PRIVATE_KEY)"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	echo "Deploying Gateway from addresses in $$DIR via $$WORKING_EP"; \
	echo "  runtime   = $$RUNTIME"; \
	echo "  economics = $$ECONOMICS"; \
	echo "  recovery  = $$RECOVERY"; \
	echo ""; \
	echo "[1] Injecting constants..."; \
	bash $(SCRIPTS_DIR)/inject-gateway-constants.sh "$$RUNTIME" "$$ECONOMICS" "$$RECOVERY" || exit 1; \
	echo ""; \
	echo "[2] Rebuilding..."; \
	HASH_FILES="$(call source_files_for_hash,$(GATEWAY_CONTRACT))"; \
	FEATURES_FLAG="--features $(FEATURES_$(GATEWAY_CONTRACT))"; \
	( cd src/$(GATEWAY_CONTRACT) && \
		cargo stylus build \
		$$FEATURES_FLAG \
		--source-files-for-project-hash "$$HASH_FILES" ) || exit 1; \
	echo ""; \
	echo "[3] Deploying..."; \
	GW_LOG="$$DIR/$(GATEWAY_CONTRACT).log"; \
	( cd src/$(GATEWAY_CONTRACT) && \
		cargo stylus deploy \
		$$FEATURES_FLAG \
		--endpoint "$$WORKING_EP" \
		--private-key $$PKEY \
		--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
		--source-files-for-project-hash "$$HASH_FILES" ) 2>&1 | tee "$$GW_LOG"; \
	GW_PIPE_RC=$${PIPESTATUS[0]}; \
	if [ $$GW_PIPE_RC -ne 0 ]; then echo "FAILED: gateway (exit $$GW_PIPE_RC)"; exit 1; fi; \
	bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$GW_LOG" "$(PROJECT_NAME)" "$(GATEWAY_CONTRACT)" "$$DEPLOYER" "$$WORKING_EP" > "$$DIR/$(GATEWAY_CONTRACT).manifest.json"; \
	GATEWAY=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/$(GATEWAY_CONTRACT).manifest.json"); \
	if [ -z "$$GATEWAY" ]; then echo "FAILED: gateway (no address)"; exit 1; fi; \
	echo "  gateway → $$GATEWAY"; \
	jq --arg a "$$GATEWAY" --arg k "$(GATEWAY_CONTRACT)" '. + {($$k): $$a}' "$$DIR/addresses.json" > "$$DIR/tmp.json"; \
	mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
	jq --slurpfile m "$$DIR/$(GATEWAY_CONTRACT).manifest.json" --arg k "$(GATEWAY_CONTRACT)" '.contracts[$$k] = $$m[0]' "$$DIR/manifest.json" > "$$DIR/tmp.json"; \
	mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
	rm -f "$$DIR/$(GATEWAY_CONTRACT).manifest.json"; \
	echo ""; \
	echo "[4] Registering gateway in protocol_config..."; \
	cast send "$$PROTOCOL_CONFIG" "setExecutionGatewayAddress(address)" "$$GATEWAY" \
		--rpc-url "$$WORKING_EP" --private-key $$PKEY --gas-price $(MAX_FEE_PER_GAS_GWEI)gwei || exit 1; \
	echo "✓ Gateway deployed and registered"

deploy-resume:
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
	@set -o pipefail; \
	WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE)); \
	DIR="$$(ls -d $(DEPLOYMENTS_DIR)/*/ 2>/dev/null | sort | tail -n 1)"; \
	if [ -z "$$DIR" ]; then echo "No previous deployment found."; exit 1; fi; \
	echo "Resuming phase-1 deployment: $$DIR"; \
	PKEY="$(PRIVATE_KEY)"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	PROTOCOL_CONFIG=$$(jq -r '.["kipio_protocol_config"] // empty' "$$DIR/addresses.json"); \
	RUNTIME=$$(jq -r '.["kipio_runtime"] // empty' "$$DIR/addresses.json"); \
	RECOVERY=$$(jq -r '.["kipio_recovery"] // empty' "$$DIR/addresses.json"); \
	for c in $(SINGLETON_DEPLOYABLES); do \
		addr=$$(jq -r --arg k "$$c" '.[$$k] // empty' "$$DIR/addresses.json"); \
		if [ -n "$$addr" ]; then echo "Skipping $$c (already at $$addr)"; continue; fi; \
		echo ""; \
		echo "============================================================"; \
		echo "  Deploying $$c"; \
		echo "============================================================"; \
		LOG="$$DIR/$$c.log"; \
		case "$$c" in \
			kipio_protocol_config) ARGS="" ;; \
			kipio_runtime) ARGS="$$PROTOCOL_CONFIG" ;; \
			kipio_recovery) ARGS="$$RECOVERY" ;; \
			kipio_economics) ARGS="$$PROTOCOL_CONFIG $(CRE_FORWARDER_ARB_SEPOLIA) $(CRE_WORKFLOW_ID_PLACEHOLDER)" ;; \
			kipio_identity_content) ARGS="$(IDENTITY_STORAGE_PROVIDER) $(IDENTITY_QUERY_PROVIDER) $(IDENTITY_ACCESS_PROVIDER) $(IDENTITY_EXPECTED_WORKFLOW_ID)" ;; \
		esac; \
		read -ra CTOR_ARGS <<< "$$ARGS"; \
		HASH_FILES="$(call source_files_for_hash,$$c)"; \
		if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
			( cd src/$$c && \
				cargo stylus deploy \
				--endpoint "$$WORKING_EP" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
				--source-files-for-project-hash "$$HASH_FILES" \
				--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
		else \
			( cd src/$$c && \
				cargo stylus deploy \
				--endpoint "$$WORKING_EP" \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=$(MAX_FEE_PER_GAS_GWEI) \
				--source-files-for-project-hash "$$HASH_FILES" ) 2>&1 | tee "$$LOG"; \
		fi; \
		PIPE_RC=$${PIPESTATUS[0]}; \
		if [ $$PIPE_RC -ne 0 ]; then echo "FAILED: $$c"; exit 1; fi; \
		bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$$c" "$$DEPLOYER" "$$WORKING_EP" > "$$DIR/$$c.manifest.json"; \
		addr=$$(jq -r '.contract_details.contract_address // empty' "$$DIR/$$c.manifest.json"); \
		if [ -z "$$addr" ]; then echo "FAILED: $$c (no address)"; exit 1; fi; \
		echo "  $$c → $$addr"; \
		jq --arg a "$$addr" --arg k "$$c" '. + {($$k): $$a}' "$$DIR/addresses.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
		jq --slurpfile m "$$DIR/$$c.manifest.json" --arg k "$$c" '.contracts = ((.contracts // {}) + {($$k): $$m[0]})' "$$DIR/manifest.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
		rm -f "$$DIR/$$c.manifest.json"; \
		case "$$c" in \
			kipio_protocol_config) PROTOCOL_CONFIG="$$addr" ;; \
			kipio_runtime) RUNTIME="$$addr" ;; \
			kipio_recovery) RECOVERY="$$addr" ;; \
		esac; \
	done; \
	echo "Phase-1 resume complete: $$DIR"

verify:
ifndef contract
	@echo "ERROR: verify requires contract=<name>"; exit 1
endif
ifndef tx
	@echo "ERROR: verify requires tx=0x<deployment-tx-hash>"; exit 1
endif
	@WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE) 2>/dev/null || echo "$(ENDPOINT_SEPOLIA)"); \
	FEATURES_FLAG="$(if $(FEATURES_$(contract)),--features $(FEATURES_$(contract)),)"; \
	cd src/$(contract) && cargo stylus verify \
		$$FEATURES_FLAG \
		--deployment-tx $(tx) \
		--endpoint "$$WORKING_EP"

# ============================================================
# 5. FRAGMENTED INITCODE REVERSE-ENGINEERING
# ============================================================

install-brotli:
	@echo ""
	@echo "============================================================"
	@echo "  BROTLI INSTALLATION"
	@echo "============================================================"
	@if command -v brotli >/dev/null 2>&1; then \
		echo "  ✓ CLI 'brotli' is already installed:"; \
		brotli --version; \
		exit 0; \
	fi; \
	echo "  CLI 'brotli' not found. Trying apt..."; \
	if sudo -n true 2>/dev/null; then \
		sudo apt-get update -qq && sudo apt-get install -y brotli && { \
			echo "  ✓ Installed via apt"; \
			brotli --version; \
			exit 0; \
		}; \
	else \
		echo "  (sudo requires a password, skipping apt)"; \
	fi; \
	echo "  Trying pip --user..."; \
	if python3 -m pip install --user brotli 2>/dev/null; then \
		if python3 -c "import brotli" 2>/dev/null; then \
			echo "  ✓ Python 'brotli' module installed via pip --user"; \
			exit 0; \
		fi; \
	fi; \
	echo ""; \
	echo "  ✗ Could not install Brotli automatically."; \
	echo "  Install manually with one of:"; \
	echo "    sudo apt-get install brotli"; \
	echo "    pip3 install --user brotli"; \
	echo "    cargo install brotli"; \
	echo "============================================================"; \
	exit 1

reverse-eng-deploy:
	$(guard_perms)
	@mkdir -p $(REVERSE_ENGINEERING_DIR)
	@mkdir -p $(CHECK_REPORTS)
	@echo "============================================================"
	@echo "  ENDPOINT RESOLUTION"
	@echo "============================================================"
	@WORKING_EP=$$(bash $(SCRIPTS_DIR)/find-working-endpoint.sh $(ENDPOINT_PROBE_CONTRACT) $(WORKING_ENDPOINT_FILE) $(ENDPOINT_SEPOLIA_ALL)) || exit 1; \
	echo "  Using endpoint: $$WORKING_EP"
	@set -x; \
	set -o pipefail; \
	echo ""; \
	echo "============================================================"; \
	echo "  REVERSE-ENG STEP 1 — Deploy kipio_account (fragmented)"; \
	echo "============================================================"; \
	echo ""; \
	echo "  Constructor args (override with"; \
	echo "    KIPIO_ACCOUNT_IDENTITY / RUNTIME / RECOVERY):"; \
	echo "    identity = $(KIPIO_ACCOUNT_IDENTITY)"; \
	echo "    runtime  = $(KIPIO_ACCOUNT_RUNTIME)"; \
	echo "    recovery = $(KIPIO_ACCOUNT_RECOVERY)"; \
	echo ""; \
	$(MAKE) --no-print-directory deploy contract=kipio_account ENDPOINT_SEPOLIA="$$(cat $(WORKING_ENDPOINT_FILE))"

reverse-eng-capture:
	@if [ -z "$(ROOT_TX)" ]; then \
		echo "ERROR: ROOT_TX is required."; \
		echo "Usage: make reverse-eng-capture ROOT_TX=0x<tx_hash>"; \
		exit 1; \
	fi
	@mkdir -p $(REVERSE_ENGINEERING_DIR)
	@set -x; \
	set -o pipefail; \
	RAW="$(REVERSE_ENGINEERING_DIR)/root_tx_input.hex"; \
	OUT="$(REVERSE_ENGINEERING_DIR)/root_initcode.hex"; \
	WORKING_EP=$$(cat $(WORKING_ENDPOINT_FILE) 2>/dev/null || echo "$(ENDPOINT_SEPOLIA)"); \
	echo "  Using endpoint: $$WORKING_EP"; \
	INPUT=$$(cast rpc eth_getTransactionByHash "$(ROOT_TX)" --rpc-url "$$WORKING_EP" 2>/dev/null | jq -r '.input // empty'); \
	if [ -z "$$INPUT" ] || [ "$$INPUT" = "null" ] || [ "$$INPUT" = "0x" ]; then \
		echo "ERROR: could not retrieve tx input from $$WORKING_EP"; \
		exit 1; \
	fi; \
	echo "$$INPUT" | sed 's/^0x//' > "$$RAW"; \
	python3 $(SCRIPTS_DIR)/decode_stylus_calldata.py "$$RAW" "$$OUT" || exit 1; \
	echo "Endpoint: $$WORKING_EP"; \
	head -c 96 "$$OUT"; echo ""

reverse-eng-structure:
	@IN="$(REVERSE_ENGINEERING_DIR)/root_initcode.hex"; \
	if [ ! -f "$$IN" ]; then echo "ERROR: run reverse-eng-capture first"; exit 1; fi; \
	HEX=$$(cat "$$IN"); \
	BYTES=$$(( $${#HEX} / 2 )); \
	HEADER=$$(echo "$$HEX" | cut -c87-94); \
	echo "Total: $$BYTES bytes"; \
	echo "Header: 0x$$HEADER"; \
	[ "$$HEADER" = "eff00200" ] && echo "Kind: FRAGMENTED" || echo "Kind: NON-FRAGMENTED"

reverse-eng-extract-payload:
	@IN="$(REVERSE_ENGINEERING_DIR)/root_initcode.hex"; \
	PAYLOAD="$(REVERSE_ENGINEERING_DIR)/root_payload.bin"; \
	if [ ! -f "$$IN" ]; then echo "ERROR: run reverse-eng-capture first"; exit 1; fi; \
	HEX=$$(cat "$$IN"); \
	echo "$$HEX" | cut -c95- | python3 -c "import sys; sys.stdout.buffer.write(bytes.fromhex(sys.stdin.read().strip()))" > "$$PAYLOAD"; \
	echo "Payload: $$(wc -c < "$$PAYLOAD") bytes"; \
	xxd -l 64 "$$PAYLOAD"

reverse-eng-decode-payload:
	@PAYLOAD="$(REVERSE_ENGINEERING_DIR)/root_payload.bin"; \
	if [ ! -f "$$PAYLOAD" ]; then echo "ERROR: run reverse-eng-extract-payload first"; exit 1; fi; \
	python3 $(SCRIPTS_DIR)/decode_fragment_table.py "$$PAYLOAD"

reverse-eng-addresses:
	@if [ -z "$(FRAGMENT_ADDRS)" ]; then echo "FRAGMENT_ADDRS required"; exit 1; fi
	@PAYLOAD="$(REVERSE_ENGINEERING_DIR)/root_payload.bin"; \
	if [ ! -f "$$PAYLOAD" ]; then echo "ERROR: run reverse-eng-extract-payload first"; exit 1; fi; \
	python3 $(SCRIPTS_DIR)/find_fragment_addresses.py "$$PAYLOAD" "$(FRAGMENT_ADDRS)"

reverse-eng-summary:
	@IN="$(REVERSE_ENGINEERING_DIR)/root_initcode.hex"; \
	PAYLOAD="$(REVERSE_ENGINEERING_DIR)/root_payload.bin"; \
	if [ ! -f "$$IN" ]; then echo "ERROR: run reverse-eng-capture first"; exit 1; fi; \
	HEX=$$(cat "$$IN"); \
	echo "Init code size:  $$(( $${#HEX} / 2 )) bytes"; \
	echo "Header:          0x$$(echo "$$HEX" | cut -c87-94)"; \
	[ -f "$$PAYLOAD" ] && echo "Payload:         $$(wc -c < "$$PAYLOAD") bytes"

reverse-eng-clean:
	@rm -rf $(REVERSE_ENGINEERING_DIR)
	@echo "Removed $(REVERSE_ENGINEERING_DIR)/"

# ============================================================
# 6. CACHE
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
# 7. DIAGNOSTICS
# ============================================================

print-private-key:
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "PRIVATE_KEY is NOT set in .env"; \
		exit 1; \
	fi
	@echo "PRIVATE_KEY is available inside the Makefile context."
	@echo "  Length: $$(echo -n "$(PRIVATE_KEY)" | wc -c) chars"
	@echo "  Prefix: $$(echo "$(PRIVATE_KEY)" | head -c 10)..."
	@echo "  Suffix: ...$$(echo "$(PRIVATE_KEY)" | tail -c 6)"

env-check:
	@echo "============================================================"
	@echo "  ENV CHECK"
	@echo "============================================================"
	@echo "  PRIVATE_KEY:                  $$(if [ -n "$(PRIVATE_KEY)" ]; then echo "set ($$(echo -n "$(PRIVATE_KEY)" | wc -c) chars)"; else echo "MISSING"; fi)"
	@echo "  --- deploy defaults ---"
	@echo "  CRE_FORWARDER_ARB_SEPOLIA:    $(CRE_FORWARDER_ARB_SEPOLIA)"
	@echo "  CRE_WORKFLOW_ID_PLACEHOLDER:  $(CRE_WORKFLOW_ID_PLACEHOLDER)"
	@echo "  IDENTITY_STORAGE_PROVIDER:    $(IDENTITY_STORAGE_PROVIDER)"
	@echo "  IDENTITY_QUERY_PROVIDER:      $(IDENTITY_QUERY_PROVIDER)"
	@echo "  IDENTITY_ACCESS_PROVIDER:     $(IDENTITY_ACCESS_PROVIDER)"
	@echo "  IDENTITY_EXPECTED_WORKFLOW_ID: $(IDENTITY_EXPECTED_WORKFLOW_ID)"
	@echo "  --- endpoint cache ---"
	@echo "  WORKING_ENDPOINT_FILE:        $(WORKING_ENDPOINT_FILE)"
	@echo "  Cached endpoint:              $$(cat $(WORKING_ENDPOINT_FILE) 2>/dev/null || echo '<none>')"
	@echo "  --- legacy CTOR overrides (from .env) ---"
	@echo "  CTOR_RUNTIME_PROTOCOL_CONFIG: $${CTOR_RUNTIME_PROTOCOL_CONFIG:-<unset>}"
	@echo "  CTOR_RECOVERY_RUNTIME:        $${CTOR_RECOVERY_RUNTIME:-<unset>}"
	@echo "  CTOR_ECONOMICS_PROTOCOL_CONFIG: $${CTOR_ECONOMICS_PROTOCOL_CONFIG:-<unset>}"
	@echo "  CTOR_ECONOMICS_CRE_FORWARDER:   $${CTOR_ECONOMICS_CRE_FORWARDER:-<unset>}"
	@echo "  CTOR_ECONOMICS_CRE_WORKFLOW_ID: $${CTOR_ECONOMICS_CRE_WORKFLOW_ID:-<unset>}"
	@echo "  CTOR_IDENTITY_CONTENT_STORAGE_PROVIDER: $${CTOR_IDENTITY_CONTENT_STORAGE_PROVIDER:-<unset>}"
	@echo "  CTOR_IDENTITY_CONTENT_QUERY_PROVIDER:   $${CTOR_IDENTITY_CONTENT_QUERY_PROVIDER:-<unset>}"
	@echo "  CTOR_IDENTITY_CONTENT_ACCESS_PROVIDER:  $${CTOR_IDENTITY_CONTENT_ACCESS_PROVIDER:-<unset>}"
	@echo "  CTOR_IDENTITY_CONTENT_EXPECTED_WORKFLOW_ID: $${CTOR_IDENTITY_CONTENT_EXPECTED_WORKFLOW_ID:-<unset>}"
	@echo "  --- features ---"
	@for c in $(CONTRACTS); do \
		f_var="FEATURES_$$c"; \
		f="$${!f_var}"; \
		if [ -n "$$f" ]; then echo "    $$c: $$f"; fi; \
	done
	@echo "  --- tools ---"
	@echo "  brotli CLI:                   $$(command -v brotli >/dev/null 2>&1 && brotli --version || echo '<not installed>')"
	@echo "============================================================"

print-constructor-args:
ifndef contract
	@echo "ERROR: print-constructor-args requires contract=<name>"; exit 1
endif
	@echo "Constructor args for $(contract):"
	@echo "  Raw (space-separated): $(CONSTRUCTOR_ARGS_$(contract))"

print-deploy-order:
	@echo "Deploy order (phase 1 singletons):"
	@n=1; \
	for c in $(SINGLETON_DEPLOYABLES); do \
		printf "  %2d. %s\n" "$$n" "$$c"; \
		n=$$((n+1)); \
	done
	@echo ""
	@echo "Phase 3:"
	@echo "   1. inject-gateway-constants.sh"
	@echo "   2. rebuild $(GATEWAY_CONTRACT)"
	@echo "   3. deploy $(GATEWAY_CONTRACT)"
	@echo "   4. setExecutionGatewayAddress"

print-working-endpoint:
	@echo "Working endpoint cache: $(WORKING_ENDPOINT_FILE)"
	@echo "  Cached value: $$(cat $(WORKING_ENDPOINT_FILE) 2>/dev/null || echo '<not set>')"
	@echo ""
	@echo "To force a fresh probe: rm $(WORKING_ENDPOINT_FILE)"

print-hash-files:
ifndef contract
	@echo "ERROR: print-hash-files requires contract=<name>"; exit 1
endif
	@echo "Source files in the project hash for $(contract):"
	@echo ""
	@HASH_FILES="$(call source_files_for_hash,$(contract))"; \
	for f in $$HASH_FILES; do echo "  $$f"; done
	@echo ""
	@HASH_FILES="$(call source_files_for_hash,$(contract))"; \
	echo "Total: $$(echo $$HASH_FILES | wc -w) files"

# ============================================================
# 8. PERMISSION RECOVERY
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
	@if [ -d target ]; then \
		if [ -n "$$(find target -user root -print -quit 2>/dev/null)" ]; then \
			sudo rm -rf target; \
		else \
			rm -rf target; \
		fi; \
	fi
	@docker ps -a --filter "ancestor=cargo-stylus-base-0.10.9-toolchain-nightly-2025-09-23-binaryen-132" --format '{{.ID}}' 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1 || true
	@docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep '^cargo-stylus-base-' | xargs -r docker rmi -f >/dev/null 2>&1 || true
	@echo "Nuke complete."

# ============================================================
# 9. MAINTENANCE
# ============================================================

clean:
	cargo clean
	rm -rf $(CHECK_REPORTS)

clean-deployments:
	rm -rf $(DEPLOYMENTS_DIR)

clean-abi:
	@rm -f $(FOUNDRY_INTERFACES)/*.sol
	@echo "Done. Run 'make abi' to regenerate."

clean-endpoint-cache:
	@rm -f $(WORKING_ENDPOINT_FILE)
	@echo "Removed $(WORKING_ENDPOINT_FILE). Next 'check'/'deploy' will re-probe."

# ============================================================
# HELP
# ============================================================

help:
	@echo ""
	@echo "==================== MAKE HELP ===================="
	@echo ""
	@echo "WORKFLOW 1 — FIRST-TIME SETUP"
	@echo "  probe-rpc                 Verify RPC endpoints are up"
	@echo "  env-check                 Show loaded env + endpoint cache + features"
	@echo "  install-brotli            Install Brotli (apt or pip --user)"
	@echo "  build                     Compile all Stylus WASM contracts"
	@echo "  abi                       Export Solidity interfaces"
	@echo "  check                     Compile + activation sim on Sepolia"
	@echo ""
	@echo "WORKFLOW 2 — DEPLOY PROTOCOL"
	@echo "  print-base-fee            Query current base fee across endpoints"
	@echo "  print-deploy-order        Show phase-1 + phase-3 order"
	@echo "  print-working-endpoint    Show cached endpoint + how to reset"
	@echo "  deploy-full               Fase 1 + Fase 2 + Fase 3 + Fase 4"
	@echo "  deploy contract=<name>    Deploy a single contract"
	@echo "  deploy-resume             Resume phase-1 after a failure"
	@echo "  register-modules          Re-run phase-2 (idempotent)"
	@echo "  deploy-gateway            Re-run phase-3 + phase-4 (idempotent)"
	@echo "  verify contract=<name> tx=0x..."
	@echo "                            Reproducible verification"
	@echo ""
	@echo "  IMPORTANT — cast send uses --gas-price, not --max-fee-per-gas-gwei."
	@echo "  The latter is specific to cargo stylus deploy."
	@echo ""
	@echo "WORKFLOW 3 — FRAGMENTED INITCODE (COMPLETED)"
	@echo "  reverse-eng-deploy        Deploy kipio_account"
	@echo "  reverse-eng-capture       ROOT_TX=0x...  Fetch tx, decode"
	@echo "  reverse-eng-structure     Dump prelude/version/header"
	@echo "  reverse-eng-extract-payload   Extract 64-byte payload"
	@echo "  reverse-eng-decode-payload    Parse fragment table"
	@echo "  reverse-eng-addresses     FRAGMENT_ADDRS='0xa,0xb,0xc'"
	@echo "  reverse-eng-summary       Consolidated report"
	@echo "  reverse-eng-clean         Remove .reverse-engineering/"
	@echo ""
	@echo "WORKFLOW 4 — TESTING"
	@echo "  test-bridge               Bridge semantic tests (104)"
	@echo "  test-unit                 Pure Rust logic"
	@echo "  test-integration          Rust TestVM, cross-contract mocked"
	@echo "  test-fork                 Rust TestVM + rpc_url, Sepolia"
	@echo "  test-e2e-ts               TypeScript + viem"
	@echo "  test-all                  bridge + unit + integration"
	@echo ""
	@echo "WORKFLOW 5 — CACHE (ArbOS CacheManager)"
	@echo "  cache-suggest addr=0x...  Suggested minimum bid"
	@echo "  cache-bid addr=0x... bid=<wei>"
	@echo "  cache-status addr=0x...   Read cache status"
	@echo ""
	@echo "WORKFLOW 6 — RECOVERY & MAINTENANCE"
	@echo "  fix-perms                 Reclaim target/ ownership"
	@echo "  nuke                      Hard reset target/ + Docker"
	@echo "  clean                     Remove target/ + .check-reports/"
	@echo "  clean-deployments         Remove deployments/"
	@echo "  clean-abi                 Remove foundry interfaces"
	@echo "  clean-endpoint-cache      Force fresh endpoint probe"
	@echo "  reverse-eng-clean         Remove .reverse-engineering/"
	@echo ""
	@echo "DIAGNOSTICS"
	@echo "  print-private-key         Verify PRIVATE_KEY (redacted)"
	@echo "  print-deploy-order        Show deploy order"
	@echo "  print-working-endpoint    Show cached endpoint"
	@echo "  print-constructor-args contract=<name>"
	@echo "  print-hash-files contract=<name>"
	@echo ""
	@echo "==================================================="

.PHONY: build abi lock test-bridge test-unit test-integration test-fork test-e2e-ts test-all \
        probe-rpc print-base-fee check deploy deploy-full deploy-resume verify \
        register-modules deploy-gateway \
        install-brotli \
        reverse-eng-deploy reverse-eng-capture reverse-eng-structure \
        reverse-eng-extract-payload reverse-eng-decode-payload \
        reverse-eng-addresses reverse-eng-summary reverse-eng-clean \
        cache-suggest cache-bid cache-status \
        print-private-key env-check print-constructor-args print-deploy-order \
        print-working-endpoint print-hash-files \
        fix-perms nuke \
        clean clean-deployments clean-abi clean-endpoint-cache help
