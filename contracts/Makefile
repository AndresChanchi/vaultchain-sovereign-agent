# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
	include .env
	export $(shell sed 's/=.*//' .env)
endif

# ============================================================
# Configuration
# ============================================================

ENDPOINT_SEPOLIA = https://sepolia-rollup.arbitrum.io/rpc
FOUNDRY_INTERFACES = foundry/src/interfaces
CHECK_REPORTS = .check-reports

CONTRACTS = \
	kipio_protocol_config \
	kipio_core \
	kipio_content_access \
	kipio_auth \
	kipio_account \
	kipio_runtime \
	kipio_economics \
	kipio_execution_gateway \
	kipio_recovery

ifdef contract
	CONTRACT_DIR = src/$(contract)
	STYLUS_CMD = cd $(CONTRACT_DIR) && cargo stylus
else
	STYLUS_CMD = cargo stylus
endif

# ============================================================
# 1. DEVELOPMENT & COMPILATION
# ============================================================

build:
ifdef contract
	@echo "Building $(contract)"
	$(STYLUS_CMD) build
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

abi:
	@mkdir -p $(FOUNDRY_INTERFACES)
ifdef contract
	@name=$$(echo "IKipio$$(echo $(contract) | sed 's/^kipio_//; s/_\([a-z]\)/\U\1/g')"); \
	echo "Exporting ABI: $$name"; \
	(cd src/$(contract) && cargo stylus export-abi --output "../../$(FOUNDRY_INTERFACES)/$$name.sol")
else
	@set -e; \
	for c in $(CONTRACTS); do \
		name=$$(echo "IKipio$$(echo $$c | sed 's/^kipio_//; s/_\([a-z]\)/\U\1/g')"); \
		echo "Exporting ABI: $$name"; \
		(cd src/$$c && cargo stylus export-abi --output "../../$(FOUNDRY_INTERFACES)/$$name.sol"); \
	done; \
	echo ""; \
	echo "All ABIs generated in $(FOUNDRY_INTERFACES)/"
endif

lock:
	cargo generate-lockfile

# ============================================================
# 2. TESTING
# ============================================================

test:
	cargo test -p kipio_tests --test unit --test e2e

test-bridge:
	cargo test -p kipio_account_bridge

test-fork:
	cargo test -p kipio_tests --test fork -- --ignored

test-all: test test-bridge test-fork

# ============================================================
# 3. ON-CHAIN VALIDATION & DEPLOYMENT
# ============================================================

## @dev Dry-run activation against Sepolia.
##
## Runs each contract with --verbose so the full trace is preserved:
##   - deployment hash inputs (list of files that contribute to the
##     project metadata hash)
##   - project metadata hash
##   - wasm-opt version and applied flags
##   - compressed and uncompressed size
##   - fragment count
##
## The verbose output is printed to the terminal and saved verbatim
## to .check-reports/<contract>.log. A table summarising sizes is
## printed after every contract so the results are scannable at the
## end of the run. The same table is persisted to
## .check-reports/sizes.tsv.
##
## Failures do not abort the loop; all failing contracts are collected
## and reported at the end, and the target exits non-zero.
check:
ifdef contract
	@echo "Checking $(contract)"
	$(STYLUS_CMD) check --endpoint $(ENDPOINT_SEPOLIA) --verbose
else
	@set +e; \
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
		(cd src/$$c && cargo stylus check --endpoint $(ENDPOINT_SEPOLIA) --verbose) > "$$LOG" 2>&1; \
		RC=$$?; \
		cat "$$LOG"; \
		if [ $$RC -ne 0 ]; then \
			FAILED="$$FAILED $$c"; \
		fi; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "SIZE SUMMARY"; \
	echo "============================================================"; \
	printf "%-30s %16s %20s %11s\n" \
		"CONTRACT" "COMPRESSED" "UNCOMPRESSED" "FRAGMENTS"; \
	printf "%-30s %16s %20s %11s\n" \
		"------------------------------" \
		"----------------" \
		"--------------------" \
		"-----------"; \
	for c in $(CONTRACTS); do \
		LOG="$(CHECK_REPORTS)/$$c.log"; \
		line=$$(grep 'contract size:' "$$LOG" | head -1); \
		if [ -z "$$line" ]; then \
			printf "%-30s %16s %20s %11s\n" "$$c" "FAILED" "-" "-"; \
			continue; \
		fi; \
		ckb=$$(echo "$$line" | grep -o '[0-9.]\+ KB' | head -1); \
		cb=$$(echo "$$line" | grep -o '([0-9]\+ bytes)' | head -1 | grep -o '[0-9]\+'); \
		fr=$$(echo "$$line" | grep -o '([0-9]\+ fragments\?)' | head -1 | grep -o '[0-9]\+'); \
		wline=$$(grep 'wasm size:' "$$LOG" | head -1); \
		ukb=$$(echo "$$wline" | grep -o '[0-9.]\+ KB' | head -1); \
		ub=$$(echo "$$wline" | grep -o '([0-9]\+ bytes)' | head -1 | grep -o '[0-9]\+'); \
		cb=$${cb:-0}; ub=$${ub:-0}; fr=$${fr:-1}; \
		printf "%-30s %16s %20s %11s\n" \
			"$$c" \
			"$${ckb:-?} ($${cb} B)" \
			"$${ukb:-?} ($${ub} B)" \
			"$${fr}"; \
		printf "%s\t%s\t%s\t%s\n" "$$c" "$$cb" "$$ub" "$$fr" >> "$$REPORT"; \
	done; \
	echo ""; \
	if [ -z "$$FAILED" ]; then \
		echo "All contracts passed check."; \
		echo "Size report: $$REPORT"; \
	else \
		echo "FAILED CONTRACTS:"; \
		for c in $$FAILED; do echo "  - $$c"; done; \
		echo ""; \
		echo "Per-contract logs: $(CHECK_REPORTS)/<contract>.log"; \
		exit 1; \
	fi
endif

deploy:
ifdef contract
	@echo "Deploying $(contract)"
	$(STYLUS_CMD) deploy \
		--endpoint $(ENDPOINT_SEPOLIA) \
		--private-key $(PRIVATE_KEY) \
		--max-fee-per-gas-gwei=1
else
	@set -e; \
	for c in $(CONTRACTS); do \
		echo ""; \
		echo "Deploying $$c"; \
		(cd src/$$c && cargo stylus deploy \
			--endpoint $(ENDPOINT_SEPOLIA) \
			--private-key $(PRIVATE_KEY) \
			--max-fee-per-gas-gwei=1); \
	done; \
	echo ""; \
	echo "All contracts deployed."
endif

## @dev Reproducible verification of a deployed contract.
## @notice Requires contract=<name> and tx=0x<deployment-tx-hash>.
verify:
ifndef contract
	@echo "ERROR: verify requires contract=<name>"
	@exit 1
endif
ifndef tx
	@echo "ERROR: verify requires tx=0x<deployment-tx-hash>"
	@exit 1
endif
	$(STYLUS_CMD) verify \
		--deployment-tx $(tx) \
		--endpoint $(ENDPOINT_SEPOLIA)

# ============================================================
# 4. STYLUS CACHE
# ============================================================
#
# ArbOS maintains a contract cache. Cached contracts save ~8,500 gas
# per call. Entry is won by bidding on an auction; bids decay over
# time and must be renewed.
#
# Workflow:
#   1. make cache-suggest addr=0x...     → suggested minimum bid
#   2. make cache-bid addr=0x... bid=... → submit the bid
#
# The bid is paid in ETH. Use `cache suggest-bid` output as the floor.

cache-suggest:
ifndef addr
	@echo "ERROR: cache-suggest requires addr=<contract-address>"
	@exit 1
endif
	cargo stylus cache suggest-bid $(addr) \
		--endpoint $(ENDPOINT_SEPOLIA)

cache-bid:
ifndef addr
	@echo "ERROR: cache-bid requires addr=<contract-address>"
	@exit 1
endif
ifndef bid
	@echo "ERROR: cache-bid requires bid=<amount-in-wei>"
	@exit 1
endif
	cargo stylus cache bid $(addr) $(bid) \
		--endpoint $(ENDPOINT_SEPOLIA) \
		--private-key $(PRIVATE_KEY)

cache-status:
ifndef addr
	@echo "ERROR: cache-status requires addr=<contract-address>"
	@exit 1
endif
	cargo stylus cache status $(addr) \
		--endpoint $(ENDPOINT_SEPOLIA)

# ============================================================
# 5. FULL DEPLOYMENT PIPELINE
# ============================================================

deploy-full:
	@set -e; \
	ENDPOINT="$(ENDPOINT_SEPOLIA)"; \
	PKEY="$(PRIVATE_KEY)"; \
	DIR="deployments/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	echo "{}" > "$$DIR/addresses.json"; \
	echo "{}" > "$$DIR/manifest.json"; \
	echo "Deployment directory: $$DIR"; \
	for c in $(CONTRACTS); do \
		echo ""; \
		echo "Deploying $$c"; \
		LOG="$$DIR/$$c.log"; \
		(cd src/$$c && cargo stylus deploy \
			--endpoint $$ENDPOINT \
			--private-key $$PKEY \
			--max-fee-per-gas-gwei=1) > "$$LOG" 2>&1 || { \
				echo "FAILED: $$c"; \
				cat "$$LOG"; \
				exit 1; \
			}; \
		cat "$$LOG"; \
		addr=$$(grep -o '0x[a-fA-F0-9]\{40\}' "$$LOG" | tail -n 1); \
		tx_deploy=$$(grep -o 'deployment tx hash: 0x[a-fA-F0-9]\{64\}' "$$LOG" | grep -o '0x[a-fA-F0-9]\{64\}' | tail -n 1); \
		tx_activate=$$(grep -o 'with tx "0x[a-fA-F0-9]\{64\}"' "$$LOG" | grep -o '0x[a-fA-F0-9]\{64\}' | tail -n 1); \
		fragments=$$(grep -o '([0-9]\+ fragments\?)' "$$LOG" | grep -o '[0-9]\+' | tail -n 1); \
		compressed=$$(grep -o 'contract size: [0-9.]\+ KB ([0-9]\+ bytes)' "$$LOG" | grep -o '([0-9]\+ bytes)' | grep -o '[0-9]\+' | tail -n 1); \
		uncompressed=$$(grep -o 'wasm size: [0-9.]\+ KB ([0-9]\+ bytes)' "$$LOG" | grep -o '([0-9]\+ bytes)' | grep -o '[0-9]\+' | tail -n 1); \
		project_hash=$$(grep -o 'project metadata hash computed on deployment: "[a-f0-9]\+"' "$$LOG" | grep -o '"[a-f0-9]\+"' | tr -d '"' | tail -n 1); \
		wasm_opt=$$(grep -o 'wasm-opt [0-9]\+' "$$LOG" | grep -o '[0-9]\+' | tail -n 1); \
		echo "  $$c → $$addr"; \
		jq --arg a "$$addr" --arg k "$$c" '. + {($$k): $$a}' \
			"$$DIR/addresses.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
		jq \
			--arg addr "$$addr" \
			--arg txd "$$tx_deploy" \
			--arg txa "$$tx_activate" \
			--arg fr "$${fragments:-}" \
			--arg cb "$${compressed:-}" \
			--arg ub "$${uncompressed:-}" \
			--arg ph "$$project_hash" \
			--arg wo "$$wasm_opt" \
			--arg k "$$c" \
			'. + {($$k): {address: $$addr, deployment_tx: $$txd, activation_tx: $$txa, fragments: ($$fr | tonumber? // 1), compressed_bytes: ($$cb | tonumber? // 0), uncompressed_bytes: ($$ub | tonumber? // 0), project_hash: $$ph, wasm_opt_version: $$wo}}' \
			"$$DIR/manifest.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "Deployment complete: $$DIR"; \
	echo "============================================================"; \
	cat "$$DIR/addresses.json"

deploy-resume:
	@set -e; \
	DIR="$$(ls -d deployments/*/ 2>/dev/null | sort | tail -n 1)"; \
	if [ -z "$$DIR" ]; then \
		echo "No previous deployment found."; \
		exit 1; \
	fi; \
	echo "Resuming deployment: $$DIR"; \
	ENDPOINT="$(ENDPOINT_SEPOLIA)"; \
	PKEY="$(PRIVATE_KEY)"; \
	for c in $(CONTRACTS); do \
		addr=$$(jq -r --arg k "$$c" '.[$$k] // empty' "$$DIR/addresses.json"); \
		if [ -n "$$addr" ]; then \
			echo "Skipping $$c (already at $$addr)"; \
			continue; \
		fi; \
		echo "Deploying $$c"; \
		LOG="$$DIR/$$c.log"; \
		(cd src/$$c && cargo stylus deploy \
			--endpoint $$ENDPOINT \
			--private-key $$PKEY \
			--max-fee-per-gas-gwei=1) > "$$LOG" 2>&1 || { \
				echo "FAILED: $$c"; \
				cat "$$LOG"; \
				exit 1; \
			}; \
		cat "$$LOG"; \
		addr=$$(grep -o '0x[a-fA-F0-9]\{40\}' "$$LOG" | tail -n 1); \
		tx_deploy=$$(grep -o 'deployment tx hash: 0x[a-fA-F0-9]\{64\}' "$$LOG" | grep -o '0x[a-fA-F0-9]\{64\}' | tail -n 1); \
		tx_activate=$$(grep -o 'with tx "0x[a-fA-F0-9]\{64\}"' "$$LOG" | grep -o '0x[a-fA-F0-9]\{64\}' | tail -n 1); \
		echo "  $$c → $$addr"; \
		jq --arg a "$$addr" --arg k "$$c" '. + {($$k): $$a}' \
			"$$DIR/addresses.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/addresses.json"; \
		jq \
			--arg addr "$$addr" \
			--arg txd "$$tx_deploy" \
			--arg txa "$$tx_activate" \
			--arg k "$$c" \
			'. + {($$k): {address: $$addr, deployment_tx: $$txd, activation_tx: $$txa}}' \
			"$$DIR/manifest.json" > "$$DIR/tmp.json"; \
		mv "$$DIR/tmp.json" "$$DIR/manifest.json"; \
	done; \
	echo "Resume complete: $$DIR"

# ============================================================
# 6. MAINTENANCE
# ============================================================

clean:
	cargo clean
	rm -rf $(CHECK_REPORTS)

help:
	@echo ""
	@echo "==================== MAKE HELP ===================="
	@echo ""
	@echo "BUILD"
	@echo "  build         Compile Stylus WASM contracts"
	@echo "  abi           Generate Solidity ABIs"
	@echo "  lock          Regenerate Cargo.lock"
	@echo ""
	@echo "TESTING"
	@echo "  test          Unit + e2e (no network)"
	@echo "  test-bridge   Bridge semantic tests (104, no VM)"
	@echo "  test-fork     Fork tests against Sepolia"
	@echo "  test-all      All three layers"
	@echo ""
	@echo "ON-CHAIN"
	@echo "  check         Dry-run activation + verbose output + size table"
	@echo "  deploy        Deploy single or all"
	@echo "  verify        Reproducible verification"
	@echo "  deploy-full   Deploy all + persist manifest"
	@echo "  deploy-resume Resume last deployment"
	@echo ""
	@echo "CACHE"
	@echo "  cache-suggest addr=0x...      Suggested minimum bid"
	@echo "  cache-bid     addr=0x... bid=...  Submit cache bid"
	@echo "  cache-status  addr=0x...      Read cache status"
	@echo ""
	@echo "MAINTENANCE"
	@echo "  clean         Remove build artifacts and check reports"
	@echo ""
	@echo "==================================================="

.PHONY: build abi lock test test-bridge test-fork test-all \
        check deploy verify deploy-full deploy-resume \
        cache-suggest cache-bid cache-status clean help
