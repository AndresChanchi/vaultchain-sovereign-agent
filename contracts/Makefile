# Force bash so we can use PIPESTATUS, pipefail, and array semantics.
SHELL := /bin/bash

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
DEPLOYMENTS_DIR = deployments
SCRIPTS_DIR = scripts
PROJECT_NAME = kipio-protocol

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
# DOCKER ROOT-OWNERSHIP CAVEAT
# ============================================================
#
# `cargo stylus deploy` (0.10.9) compiles inside a Docker container to
# guarantee reproducibility. The container runs as root and writes to
# target/ via a bind mount, so files under target/ end up owned by
# root:root on the host.
#
# Symptom: `make abi` or `make build` fail with:
#   error: failed to open: .../target/debug/.cargo-lock
#   Caused by: Permission denied (os error 13)
#
# `make check` is unaffected because it uses the release profile, which
# writes to a different subtree that the deploy container never touched.
#
# Fix: run `make fix-perms` after any deploy that used Docker.
# Or `make nuke` for a hard reset (nukes target/, Docker containers, and
# cached images).
# ------------------------------------------------------------

# ============================================================
# PER-CONTRACT CONSTRUCTOR ARGUMENTS
# ============================================================
#
# cargo stylus deploy --constructor-args takes ONE VALUE PER PARAMETER,
# separated by spaces. It then ABI-encodes them internally.
#
# Wired for Arbitrum Sepolia testnet:
#   storage_provider     = 0x0                 (Irys adapter TBD)
#   query_provider       = KeystoneForwarder   (production)
#   access_provider      = 0x0                 (Lit/TACo adapter TBD)
#   expected_workflow_id = 0x0                 (set later via set_expected_workflow_id)
# ------------------------------------------------------------

CONSTRUCTOR_ARGS_kipio_content_access = 0x0000000000000000000000000000000000000000 0x76c9cf548b4179F8901cda1f8623568b58215E62 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000000000000000000000000000

CTOR_ARG_VARS := $(filter CONSTRUCTOR_ARGS_%,$(.VARIABLES))
export $(CTOR_ARG_VARS)

# ============================================================
# PERMISSION GUARD
# ============================================================
#
# Detects root-owned files under target/ and aborts with a clear
# message pointing to `make fix-perms`. Used by build/abi/test as a
# precondition.
# ------------------------------------------------------------

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

# ABI export.
#
# Naming convention: `kipio_content_access` → `IKipioContentAccess.sol`.
# The sed capitalizes the first letter of each segment separated by `_`.
# Bug history: earlier versions used `s/_\([a-z]\)/\U\1/g` which only
# capitalized after underscores, not at the start, producing names like
# `IKipiocontentAccess` for newly-generated files.
abi:
	$(guard_perms)
	@mkdir -p $(FOUNDRY_INTERFACES)
ifdef contract
	@name="IKipio$$(echo $(contract) | sed -E 's/^kipio_//; s/(^|_)([a-z])/\U\2/g')"; \
	echo "Exporting ABI: $$name"; \
	(cd src/$(contract) && cargo stylus export-abi --output "../../$(FOUNDRY_INTERFACES)/$$name.sol")
else
	@set -e; \
	for c in $(CONTRACTS); do \
		name="IKipio$$(echo $$c | sed -E 's/^kipio_//; s/(^|_)([a-z])/\U\2/g')"; \
		echo "Exporting ABI: $$name"; \
		(cd src/$$c && cargo stylus export-abi --output "../../$(FOUNDRY_INTERFACES)/$$name.sol"); \
	done; \
	echo ""; \
	echo "All ABIs generated in $(FOUNDRY_INTERFACES)/"; \
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
		echo ""; \
		echo "  WARNING: orphaned interface files detected:"; \
		for o in $$orphans; do echo "    - $$o"; done; \
		echo "  These do not correspond to any entry in CONTRACTS."; \
		echo "  Run 'make clean-abi' to remove them."; \
	fi
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

check:
ifdef contract
	@echo "Checking $(contract)"
	cd src/$(contract) && cargo stylus check --endpoint $(ENDPOINT_SEPOLIA) --verbose
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
		if [ $$RC -ne 0 ]; then FAILED="$$FAILED $$c"; fi; \
	done; \
	echo ""; \
	echo "============================================================"; \
	echo "SIZE SUMMARY"; \
	echo "============================================================"; \
	printf "%-30s %16s %20s %11s\n" "CONTRACT" "COMPRESSED" "UNCOMPRESSED" "FRAGMENTS"; \
	printf "%-30s %16s %20s %11s\n" "------------------------------" "----------------" "--------------------" "-----------"; \
	for c in $(CONTRACTS); do \
		LOG="$(CHECK_REPORTS)/$$c.log"; \
		line=$$(grep 'contract size:' "$$LOG" | head -1); \
		if [ -z "$$line" ]; then \
			printf "%-30s %16s %20s %11s\n" "$$c" "FAILED" "-" "-"; \
			continue; \
		fi; \
		ckb=$$(echo "$$line" | grep -oE '[0-9.]+ KB' | head -1); \
		cb=$$(echo "$$line" | grep -oE '\([0-9]+ bytes\)' | head -1 | grep -oE '[0-9]+'); \
		fr=$$(echo "$$line" | grep -oE '\([0-9]+ fragments?\)' | head -1 | grep -oE '[0-9]+'); \
		wline=$$(grep 'wasm size:' "$$LOG" | head -1); \
		ukb=$$(echo "$$wline" | grep -oE '[0-9.]+ KB' | head -1); \
		ub=$$(echo "$$wline" | grep -oE '\([0-9]+ bytes\)' | head -1 | grep -oE '[0-9]+'); \
		cb=$${cb:-0}; ub=$${ub:-0}; fr=$${fr:-1}; \
		printf "%-30s %16s %20s %11s\n" "$$c" "$${ckb:-?} ($${cb} B)" "$${ukb:-?} ($${ub} B)" "$${fr}"; \
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

# ============================================================
# 4. DEPLOY
# ============================================================

deploy:
ifdef contract
	@mkdir -p $(DEPLOYMENTS_DIR)
	@DIR="$(DEPLOYMENTS_DIR)/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	LOG="$$DIR/$(contract).log"; \
	ARGS="$(CONSTRUCTOR_ARGS_$(contract))"; \
	read -ra CTOR_ARGS <<< "$$ARGS"; \
	echo "============================================================"; \
	echo "  Deploying $(contract)"; \
	echo "============================================================"; \
	printf "  %-22s %s\n" "Endpoint:"         "$(ENDPOINT_SEPOLIA)"; \
	printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
	printf "  %-22s %s\n" "Args count:"       "$${#CTOR_ARGS[@]}"; \
	printf "  %-22s %s\n" "Log file:"         "$$LOG"; \
	echo "------------------------------------------------------------"; \
	set -o pipefail; \
	if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
		( cd src/$(contract) && cargo stylus deploy \
			--endpoint $(ENDPOINT_SEPOLIA) \
			--private-key $(PRIVATE_KEY) \
			--max-fee-per-gas-gwei=1 \
			--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
	else \
		( cd src/$(contract) && cargo stylus deploy \
			--endpoint $(ENDPOINT_SEPOLIA) \
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
	tx_deploy=$$(jq -r '.contract_details.deployment_tx_hash // "-"' "$$DIR/manifest.json"); \
	tx_activate=$$(jq -r '.activation_details.activation_tx_hash // "-"' "$$DIR/manifest.json"); \
	compressed=$$(jq -r '.deployment_fingerprint.compressed_bytes' "$$DIR/manifest.json"); \
	uncompressed=$$(jq -r '.deployment_fingerprint.uncompressed_bytes' "$$DIR/manifest.json"); \
	fragments=$$(jq -r '.deployment_fingerprint.fragments' "$$DIR/manifest.json"); \
	project_hash=$$(jq -r '.deployment_fingerprint.project_metadata_hash // "-"' "$$DIR/manifest.json"); \
	wasm_opt=$$(jq -r '.deployment_fingerprint.wasm_opt_version // "-"' "$$DIR/manifest.json"); \
	echo ""; \
	echo "============================================================"; \
	echo "  DEPLOY SUMMARY"; \
	echo "============================================================"; \
	printf "  %-22s %s\n" "Contract:"       "$(contract)"; \
	printf "  %-22s %s\n" "Address:"        "$$addr"; \
	printf "  %-22s %s\n" "Deployment tx:"  "$$tx_deploy"; \
	printf "  %-22s %s\n" "Activation tx:"  "$$tx_activate"; \
	printf "  %-22s %s\n" "Compressed:"     "$${compressed} bytes ($${fragments} fragments)"; \
	printf "  %-22s %s\n" "Uncompressed:"   "$${uncompressed} bytes"; \
	printf "  %-22s %s\n" "Project hash:"   "$$project_hash"; \
	printf "  %-22s %s\n" "wasm-opt:"       "$$wasm_opt"; \
	echo "------------------------------------------------------------"; \
	printf "  %-22s %s\n" "Log:"            "$$LOG"; \
	printf "  %-22s %s\n" "Addresses:"      "$$DIR/addresses.json"; \
	printf "  %-22s %s\n" "Manifest:"       "$$DIR/manifest.json"; \
	echo "============================================================"; \
	echo ""; \
	echo "  NOTE: cargo stylus deploy ran inside Docker as root."; \
	echo "  Files under target/ may now be root-owned. If you need to"; \
	echo "  run 'make abi' or 'make build', execute 'make fix-perms'."; \
	echo "============================================================"
else
	@echo "Deploying ALL contracts (use deploy-full for a manifest)"
	@set -e; \
	for c in $(CONTRACTS); do \
		echo ""; \
		echo "============================================================"; \
		echo "  Deploying $$c"; \
		echo "============================================================"; \
		ARGS_VAR="CONSTRUCTOR_ARGS_$$c"; \
		ARGS="$${!ARGS_VAR}"; \
		read -ra CTOR_ARGS <<< "$$ARGS"; \
		printf "  %-22s %s\n" "Constructor args:" "$${CTOR_ARGS[*]:-<none>}"; \
		echo "------------------------------------------------------------"; \
		if [ $${#CTOR_ARGS[@]} -gt 0 ]; then \
			(cd src/$$c && cargo stylus deploy \
				--endpoint $(ENDPOINT_SEPOLIA) \
				--private-key $(PRIVATE_KEY) \
				--max-fee-per-gas-gwei=1 \
				--constructor-args "$${CTOR_ARGS[@]}"); \
		else \
			(cd src/$$c && cargo stylus deploy \
				--endpoint $(ENDPOINT_SEPOLIA) \
				--private-key $(PRIVATE_KEY) \
				--max-fee-per-gas-gwei=1); \
		fi; \
	done; \
	echo ""; \
	echo "All contracts deployed."; \
	echo ""; \
	echo "  NOTE: Deploy containers may have left root-owned files in target/."; \
	echo "  Run 'make fix-perms' before the next local build/abi."
endif

verify:
ifndef contract
	@echo "ERROR: verify requires contract=<name>"; exit 1
endif
ifndef tx
	@echo "ERROR: verify requires tx=0x<deployment-tx-hash>"; exit 1
endif
	cd src/$(contract) && cargo stylus verify --deployment-tx $(tx) --endpoint $(ENDPOINT_SEPOLIA)

# ============================================================
# 5. CACHE (ArbOS CacheManager)
# ============================================================

cache-suggest:
ifndef addr
	@echo "ERROR: cache-suggest requires addr=<contract-address>"; exit 1
endif
	cargo stylus cache suggest-bid $(addr) --endpoint $(ENDPOINT_SEPOLIA)

cache-bid:
ifndef addr
	@echo "ERROR: cache-bid requires addr=<contract-address>"; exit 1
endif
ifndef bid
	@echo "ERROR: cache-bid requires bid=<amount-in-wei>"; exit 1
endif
	cargo stylus cache bid $(addr) $(bid) --endpoint $(ENDPOINT_SEPOLIA) --private-key $(PRIVATE_KEY)

cache-status:
ifndef addr
	@echo "ERROR: cache-status requires addr=<contract-address>"; exit 1
endif
	cargo stylus cache status $(addr) --endpoint $(ENDPOINT_SEPOLIA)

# ============================================================
# 6. FULL DEPLOYMENT PIPELINE
# ============================================================

deploy-full:
	@set -o pipefail; \
	ENDPOINT="$(ENDPOINT_SEPOLIA)"; \
	PKEY="$(PRIVATE_KEY)"; \
	DIR="$(DEPLOYMENTS_DIR)/$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$DIR"; \
	echo "{}" > "$$DIR/addresses.json"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	TIMESTAMP=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	jq -n \
		--arg project "$(PROJECT_NAME)" \
		--arg ts "$$TIMESTAMP" \
		--arg endpoint "$$ENDPOINT" \
		'{project_info: {name: $$project, compiler: "Cargo Stylus (Rust)", timestamp: $$ts, network: "Arbitrum Sepolia (Testnet)", rpc_endpoint: $$endpoint}, contracts: {}}' \
		> "$$DIR/manifest.json"; \
	echo "Deployment directory: $$DIR"; \
	for c in $(CONTRACTS); do \
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
				--endpoint $$ENDPOINT \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 \
				--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
		else \
			( cd src/$$c && cargo stylus deploy \
				--endpoint $$ENDPOINT \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 ) 2>&1 | tee "$$LOG"; \
		fi; \
		PIPE_RC=$${PIPESTATUS[0]}; \
		if [ $$PIPE_RC -ne 0 ]; then echo "FAILED: $$c (exit $$PIPE_RC)"; exit 1; fi; \
		bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$$c" "$$DEPLOYER" "$$ENDPOINT" > "$$DIR/$$c.manifest.json"; \
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
	echo "  NOTE: Deploy containers may have left root-owned files in target/."; \
	echo "  Run 'make fix-perms' before the next local build/abi."

deploy-resume:
	@set -o pipefail; \
	DIR="$$(ls -d $(DEPLOYMENTS_DIR)/*/ 2>/dev/null | sort | tail -n 1)"; \
	if [ -z "$$DIR" ]; then echo "No previous deployment found."; exit 1; fi; \
	echo "Resuming deployment: $$DIR"; \
	ENDPOINT="$(ENDPOINT_SEPOLIA)"; \
	PKEY="$(PRIVATE_KEY)"; \
	DEPLOYER=$$(cast wallet address --private-key "$$PKEY" 2>/dev/null || echo ""); \
	for c in $(CONTRACTS); do \
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
				--endpoint $$ENDPOINT \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 \
				--constructor-args "$${CTOR_ARGS[@]}" ) 2>&1 | tee "$$LOG"; \
		else \
			( cd src/$$c && cargo stylus deploy \
				--endpoint $$ENDPOINT \
				--private-key $$PKEY \
				--max-fee-per-gas-gwei=1 ) 2>&1 | tee "$$LOG"; \
		fi; \
		PIPE_RC=$${PIPESTATUS[0]}; \
		if [ $$PIPE_RC -ne 0 ]; then echo "FAILED: $$c"; exit 1; fi; \
		bash $(SCRIPTS_DIR)/stylus-deploy-manifest.sh "$$LOG" "$(PROJECT_NAME)" "$$c" "$$DEPLOYER" "$$ENDPOINT" > "$$DIR/$$c.manifest.json"; \
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

# ============================================================
# 7. DIAGNOSTICS
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
# 9. MAINTENANCE
# ============================================================

clean:
	cargo clean
	rm -rf $(CHECK_REPORTS)

clean-deployments:
	rm -rf $(DEPLOYMENTS_DIR)

# Remove all Solidity interfaces under foundry/src/interfaces/.
# Use after CONTRACTS changes to clear orphaned files. Regenerate
# with `make abi`.
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
	@echo "  abi           Generate Solidity ABIs"
	@echo "  lock          Regenerate Cargo.lock"
	@echo ""
	@echo "TESTING"
	@echo "  test          Unit + e2e (no network)"
	@echo "  test-bridge   Bridge semantic tests"
	@echo "  test-fork     Fork tests against Sepolia"
	@echo "  test-all      All three layers"
	@echo ""
	@echo "ON-CHAIN"
	@echo "  check         Dry-run activation + verbose output + size table"
	@echo "  deploy        Deploy single (contract=<name>) or all."
	@echo "  verify        Reproducible verification (contract + tx)"
	@echo "  deploy-full   Deploy all + single timestamped manifest"
	@echo "  deploy-resume Resume last deployment"
	@echo ""
	@echo "CACHE"
	@echo "  cache-suggest addr=0x...      Suggested minimum bid"
	@echo "  cache-bid     addr=0x... bid=...  Submit cache bid"
	@echo "  cache-status  addr=0x...      Read cache status"
	@echo ""
	@echo "DIAGNOSTICS"
	@echo "  print-constructor-args contract=<name>  Show args for deploy"
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
        check deploy verify deploy-full deploy-resume \
        cache-suggest cache-bid cache-status \
        print-constructor-args \
        fix-perms nuke \
        clean clean-deployments clean-abi help
