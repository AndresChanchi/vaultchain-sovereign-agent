# IMPORTANTE ES IMPORTANTE LA PARTE DE ACTUALIZAR EL MAKEFILE DANDONLE A LA IA EL CONTEXTO DE MAKE ABI, asi no se inventa firmas...
# con eso ya tendríamos makefile en teoria, incluso hacer persistencia porque el rpc es normal que muchas veces se caiga...
# Es importante que se haga en el orden correcto los deployments, y también que sean todos, vi que nada más habían6 en vez de 11 que son 11 contratos...
# Load environment variables from .env file
#
# Me acabo de dar cuenta que necesito factory, literal incluso esto es bueno para derrotar a particle network
# pero factory (puro no) factory hibrido con usuario indvidual... se que suena raro, pero es para que se cumpla la soberania real y ux con bajo costo
#
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
KIPIO_REGISTRY_CONTENT_ABI = $(INTERFACES_DIR)/IKipioRegistryContent.sol
KIPIO_ACCESS_ABI = $(INTERFACES_DIR)/IKipioAccess.sol
#KIPIO_ACCOUNT_ABI = $(INTERFACES_DIR)/IKipioAccount.sol
KIPIO_AUTH_ABI = $(INTERFACES_DIR)/IKipioAuth.sol
KIPIO_RECOVERY_ABI = $(INTERFACES_DIR)/IKipioRecovery.sol
KIPIO_PROTOCOL_CONFIG_ABI = $(INTERFACES_DIR)/IKipioProtocolConfig.sol
KIPIO_EXECUTION_GATEWAY_ABI = $(INTERFACES_DIR)/IkipioExecutionGateway.sol
KIPIO_ECONOMICS_ABI = $(INTERFACES_DIR)/IkipioEconomics.sol
#KIPIO_RUNTIME_ABI = $(INTERFACES_DIR)/IKipioRuntime.sol

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

	@echo "📦 Exporting ABI: KipioRegistryContent"
	@cd src/kipio_registry_content && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioRegistryContent.sol

	@echo "📦 Exporting ABI: KipioAccess"
	@cd src/kipio_access && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioAccess.sol

#	@echo "📦 Exporting ABI: KipioAccount"
#	@cd src/kipio_account && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioAccount.sol

	@echo "📦 Exporting ABI: KipioAuth"
	@cd src/kipio_auth && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioAuth.sol

	@echo "📦 Exporting ABI: KipioEconomics"
	@cd src/kipio_economics && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioEconomics.sol

	@echo "📦 Exporting ABI: kipio_execution_gateway"
	@cd src/kipio_execution_gateway && cargo stylus export-abi --output ../../foundry/src/interfaces/IkipioExecutionGateway.sol

	@echo "📦 Exporting ABI: KipioProtocolConfig"
	@cd src/kipio_protocol_config && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioProtocolConfig.sol

	@echo "📦 Exporting ABI: KipioRecovery"
	@cd src/kipio_recovery && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioRecovery.sol

#	@echo "📦 Exporting ABI: KipioRuntime"
#	@cd src/kipio_runtime && cargo stylus export-abi --output ../../foundry/src/interfaces/IKipioRuntime.sol

# pueden faltar treasury y payment, en caso de que economics no este bien desacoplado... Pero elara Arbos 61 me ayuda mucho. Si comentarios en español...

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
# FULL DEPLOYMENT PIPELINE (Option 3) - Captura Real de Direcciones
# ==========================================

.PHONY: deploy-full
deploy-full:
	@bash -c '\
	set -e; \
	ENDPOINT="$(ENDPOINT_SEPOLIA)"; \
	PKEY="$(PRIVATE_KEY)"; \
	DEPLOYMENTS_DIR="deployments"; \
	TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	DEPLOYMENT_DIR="$$DEPLOYMENTS_DIR/$$TIMESTAMP"; \
	echo "🚀 Starting Kipio Full Deployment Pipeline..."; \
	echo "📁 Creating directory: $$DEPLOYMENT_DIR"; \
	mkdir -p "$$DEPLOYMENT_DIR"; \
	echo "{}" > "$$DEPLOYMENT_DIR/addresses.json"; \
	\
	echo ""; \
	echo "📦 1. Deploying KipioProtocolConfig..."; \
	cd src/kipio_protocol_config && cargo stylus deploy --endpoint $$ENDPOINT --private-key $$PKEY > "../../$$DEPLOYMENT_DIR/protocol_config.log" 2>&1; \
	PROTOCOL_ADDR=$$(grep -o "0x[a-fA-F0-9]\{40\}" "../../$$DEPLOYMENT_DIR/protocol_config.log" | tail -n 1); \
	echo "ProtocolConfig → $$PROTOCOL_ADDR"; \
	jq --arg addr "$$PROTOCOL_ADDR" ".protocol_config = \$$addr" "../../$$DEPLOYMENT_DIR/addresses.json" > tmp.json && mv tmp.json "../../$$DEPLOYMENT_DIR/addresses.json"; \
	echo "   → Initializing ProtocolConfig..."; \
	cast send $$PROTOCOL_ADDR "initialize(address,address)" $$PROTOCOL_ADDR $$PROTOCOL_ADDR --rpc-url $$ENDPOINT --private-key $$PKEY 2>&1 | tee -a "../../$$DEPLOYMENT_DIR/protocol_init.log"; \
	cd ../..; \
	\
	echo ""; \
	echo "📦 2. Deploying KipioCore..."; \
	cd src/kipio_core && cargo stylus deploy --endpoint $$ENDPOINT --private-key $$PKEY > "../../$$DEPLOYMENT_DIR/core.log" 2>&1; \
	CORE_ADDR=$$(grep -o "0x[a-fA-F0-9]\{40\}" "../../$$DEPLOYMENT_DIR/core.log" | tail -n 1); \
	echo "Core → $$CORE_ADDR"; \
	jq --arg addr "$$CORE_ADDR" ".core = \$$addr" "../../$$DEPLOYMENT_DIR/addresses.json" > tmp.json && mv tmp.json "../../$$DEPLOYMENT_DIR/addresses.json"; \
	echo "   → Initializing Core..."; \
	cast send $$CORE_ADDR "initialize(address,address,address,address,address,address,uint256)" $$PROTOCOL_ADDR 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0 --rpc-url $$ENDPOINT --private-key $$PKEY 2>&1 | tee -a "../../$$DEPLOYMENT_DIR/core_init.log"; \
	cd ../..; \
	\
	echo ""; \
	echo "📦 3. Deploying + Initializing Auth..."; \
	cd src/kipio_auth && cargo stylus deploy --endpoint $$ENDPOINT --private-key $$PKEY > "../../$$DEPLOYMENT_DIR/auth.log" 2>&1; \
	AUTH_ADDR=$$(grep -o "0x[a-fA-F0-9]\{40\}" "../../$$DEPLOYMENT_DIR/auth.log" | tail -n 1); \
	echo "Auth → $$AUTH_ADDR"; \
	jq --arg addr "$$AUTH_ADDR" ".auth = \$$addr" "../../$$DEPLOYMENT_DIR/addresses.json" > tmp.json && mv tmp.json "../../$$DEPLOYMENT_DIR/addresses.json"; \
	cd ../kipio_auth_verifier_p256 && cargo stylus deploy --endpoint $$ENDPOINT --private-key $$PKEY > "../../$$DEPLOYMENT_DIR/auth_verifier.log" 2>&1; \
	cd ..; \
	echo "   → Initializing Auth..."; \
	cd kipio_auth && cast send $$AUTH_ADDR "initialize(address)" $$PROTOCOL_ADDR --rpc-url $$ENDPOINT --private-key $$PKEY 2>&1 | tee -a "../../$$DEPLOYMENT_DIR/auth_init.log"; \
	cd ../..; \
	\
	echo ""; \
	echo "📦 4. Deploying + Initializing KipioAccount..."; \
	cd src/kipio_account && cargo stylus deploy --endpoint $$ENDPOINT --private-key $$PKEY > "../../$$DEPLOYMENT_DIR/account.log" 2>&1; \
	RUNTIME_ADDR=$$(grep -o "0x[a-fA-F0-9]\{40\}" "../../$$DEPLOYMENT_DIR/account.log" | tail -n 1); \
	echo "Runtime (Account) → $$RUNTIME_ADDR"; \
	echo "RUNTIME_TARGET_ADDRESS=$$RUNTIME_ADDR" > .runtime.env; \
	jq --arg addr "$$RUNTIME_ADDR" ".account = \$$addr" "../../$$DEPLOYMENT_DIR/addresses.json" > tmp.json && mv tmp.json "../../$$DEPLOYMENT_DIR/addresses.json"; \
	echo "   → Initializing Account..."; \
	cast send $$RUNTIME_ADDR "initialize(address,address,address)" 0x0000000000000000000000000000000000000000 $$AUTH_ADDR 0x0000000000000000000000000000000000000000 --rpc-url $$ENDPOINT --private-key $$PKEY 2>&1 | tee -a "../../$$DEPLOYMENT_DIR/account_init.log"; \
	cd ../..; \
	\
	echo ""; \
	echo "📦 5. Building + Deploying RuntimeAdapter7702..."; \
	RUNTIME_TARGET_ADDRESS=$$(cat .runtime.env | cut -d= -f2) && cargo stylus build -p kipio_runtime_adapter_7702; \
	cd src/kipio_runtime_adapter_7702 && cargo stylus deploy --endpoint $$ENDPOINT --private-key $$PKEY > "../../$$DEPLOYMENT_DIR/adapter.log" 2>&1; \
	cd ../..; \
	\
	echo ""; \
	echo "✅ Pipeline completed!"; \
	echo "Deployment folder: $$DEPLOYMENT_DIR"; \
	cat "$$DEPLOYMENT_DIR/addresses.json" \
	'

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
