# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
	include .env
	export $(shell sed 's/=.*//' .env)
endif

# Configuration
ENDPOINT_SEPOLIA = https://sepolia-rollup.arbitrum.io/rpc
CONTRACT_PATH = ./contracts
INTERFACES_DIR = interfaces

# Optional contract selector (WORKSPACE vs SINGLE CRATE)
ifdef contract
	CONTRACT_DIR = src/$(contract)
	CARGO_CMD = cd $(CONTRACT_DIR) &&
	STYLUS_CMD = cd $(CONTRACT_DIR) && cargo stylus
else
	CARGO_CMD = cargo
	STYLUS_CMD = cargo stylus
endif

# ABI output names
KIPIO_CORE_ABI = $(INTERFACES_DIR)/IKipioCore.sol
KIPIO_REGISTRY_ABI = $(INTERFACES_DIR)/IKipioRegistry.sol
KIPIO_ACCESS_ABI = $(INTERFACES_DIR)/IKipioAccess.sol
KIPIO_AUTH_ABI = $(INTERFACES_DIR)/IKipioAuthP256.sol
KIPIO_AUTH_VERIFIER_ABI = $(INTERFACES_DIR)/IKipioAuthVerifier.sol
KIPIO_RECOVERY_ABI = $(INTERFACES_DIR)/IKipioRecovery.sol

# ==========================================
# 1. DEVELOPMENT & COMPILATION
# ==========================================

## @dev Compiles the smart contract into WASM target for Arbitrum Stylus.
build:
	$(STYLUS_CMD) build

## @dev Generates the Solidity-compatible ABI. Required for frontend integration (ethers/viem).
abi:
	@mkdir -p foundry/src/interfaces
ifdef contract
	@echo "📦 Exporting ABI for $(contract)"
	@set -e; \
	cd src/$(contract) && cargo stylus export-abi --output ../../foundry/src/interfaces/I$$(printf '%s' "$(contract)" | sed 's/_\([a-z]\)/\U\1/g; s/^/Kipio/; s/^\(Kipio\)\(.*\)/\1\2/').sol
else
	@echo "📦 Exporting ABI: KipioCore"
	@cd src/kipio_core && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioCore.sol

	@echo "📦 Exporting ABI: KipioRegistry"
	@cd src/kipio_registry && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioRegistry.sol

	@echo "📦 Exporting ABI: KipioAccess"
	@cd src/kipio_access && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioAccess.sol

	@echo "📦 Exporting ABI: KipioAuth"
	@cd src/kipio_auth && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioAuth.sol

	@echo "📦 Exporting ABI: KipioAuthP256"
	@cd src/kipio_auth_verifier_p256 && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioAuthVerifierP256.sol

	@echo "📦 Exporting ABI: KipioRecovery"
	@cd src/kipio_recovery && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioRecovery.sol

	@echo ""
	@echo "✅ All ABIs generated in ./foundry/src/interfaces"
endif

## @dev Reconstructs the Cargo.lock file. Essential after manual deletions or deep cleaning.
lock:
	$(CARGO_CMD) generate-lockfile

# ==========================================
# 2. TESTING & QUALITY ASSURANCE
# ==========================================

## @dev Runs unit tests using the Motsu framework. Targets the library to optimize cache usage.
test:
	$(CARGO_CMD) test

## @dev Executes code coverage analysis. Note: This will trigger a full recompilation.
coverage:
	cargo tarpaulin

# ==========================================
# 3. ON-CHAIN VALIDATION & DEPLOYMENT
# ==========================================

## @dev Performs a dry-run activation check against the Arbitrum Sepolia RPC.
## @notice This validates contract size (max 24KB) and WASM compatibility.
check:
ifdef contract
	@echo "🧪 Checking single contract: $(contract)"
	@set -e; \
	cd src/$(contract) && cargo stylus check --endpoint $(ENDPOINT_SEPOLIA)
else
	@set -e; \
	for dir in src/*; do \
		if [ -f $$dir/Cargo.toml ]; then \
			echo "\n🧪 Checking $$dir ..."; \
			if ! (cd $$dir && cargo stylus check --endpoint $(ENDPOINT_SEPOLIA)); then \
				echo ""; \
				echo "❌ CHECK FAILED IN: $$dir"; \
				exit 1; \
			fi \
		fi \
	done; \
	echo "\n✅ ALL CONTRACTS PASSED CHECK"
endif

## @dev Deploys the contract to Arbitrum Sepolia using the PRIVATE_KEY from .env.
deploy:
ifdef contract
	@echo "🚀 Deploying single contract: $(contract)"
	cd src/$(contract) && cargo stylus deploy \
		--endpoint $(ENDPOINT_SEPOLIA) \
		--private-key $(PRIVATE_KEY)
else
	@echo "🚀 Deploying ALL contracts"
	@set -e; \
	for dir in src/*; do \
		if [ -f $$dir/Cargo.toml ]; then \
			echo "\n🚀 Deploying $$dir ..."; \
			(cd $$dir && cargo stylus deploy \
				--endpoint $(ENDPOINT_SEPOLIA) \
				--private-key $(PRIVATE_KEY)) || exit 1; \
		fi \
	done
endif

# ==========================================
# 4. MAINTENANCE
# ==========================================

## @dev Removes build artifacts and the target directory.
clean:
	$(CARGO_CMD) clean

## @dev Displays help information for each available command.
help:
	@echo ""
	@echo "==================== MAKE HELP ===================="
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [contract=<name>]"
	@echo ""
	@echo "---------------------------------------------------"
	@echo "BUILD / COMPILATION"
	@echo "  build     -> Compile Stylus WASM contracts"
	@echo "  abi       -> Generate Solidity ABI"
	@echo "  lock      -> Regenerate Cargo.lock"
	@echo ""
	@echo "TESTING"
	@echo "  test      -> Run Rust unit tests"
	@echo "  coverage  -> Run test coverage (tarpaulin)"
	@echo ""
	@echo "ON-CHAIN"
	@echo "  check     -> Validate contracts on Arbitrum Sepolia"
	@echo "              (detects size + WASM compatibility)"
	@echo "  deploy    -> Deploy contracts to Sepolia"
	@echo ""
	@echo "MAINTENANCE"
	@echo "  clean     -> Remove build artifacts"
	@echo ""
	@echo "---------------------------------------------------"
	@echo "EXAMPLES"
	@echo "  make build"
	@echo "  make build contract=kipio_access"
	@echo "  make test contract=kipio_core"
	@echo "  make check contract=kipio_registry"
	@echo "  make deploy contract=kipio_auth"
	@echo ""
	@echo "BEHAVIOR"
	@echo "  without contract=  -> workspace (all contracts)"
	@echo "  with contract=     -> single contract"
	@echo ""
	@echo "==================================================="
