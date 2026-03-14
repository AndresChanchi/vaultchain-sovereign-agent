# Load environment variables from .env file
ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

# Configuration
ENDPOINT_SEPOLIA = https://sepolia-rollup.arbitrum.io/rpc
CONTRACT_PATH = ./contracts

# Default target
.PHONY: all
all: build

# ==========================================
# 1. DEVELOPMENT & COMPILATION
# ==========================================

## @dev Compiles the smart contract into WASM target for Arbitrum Stylus.
build:
	cargo stylus build

## @dev Generates the Solidity-compatible ABI. Required for frontend integration (ethers/viem).
abi:
	cargo stylus export-abi

## @dev Reconstructs the Cargo.lock file. Essential after manual deletions or deep cleaning.
lock:
	cargo generate-lockfile

# ==========================================
# 2. TESTING & QUALITY ASSURANCE
# ==========================================

## @dev Runs unit tests using the Motsu framework. Targets the library to optimize cache usage.
test:
	cargo test

## @dev Executes code coverage analysis. Note: This will trigger a full recompilation.
coverage:
	cargo tarpaulin

# ==========================================
# 3. ON-CHAIN VALIDATION & DEPLOYMENT
# ==========================================

## @dev Performs a dry-run activation check against the Arbitrum Sepolia RPC.
## @notice This validates contract size (max 24KB) and WASM compatibility.
check:
	cargo stylus check --endpoint $(ENDPOINT_SEPOLIA)

## @dev Deploys the contract to Arbitrum Sepolia using the PRIVATE_KEY from .env.
deploy:
	cargo stylus deploy \
		--endpoint $(ENDPOINT_SEPOLIA) \
		--private-key $(PRIVATE_KEY)

# ==========================================
# 4. MAINTENANCE
# ==========================================

## @dev Removes build artifacts and the target directory.
clean:
	cargo clean

## @dev Displays help information for each available command.
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build    Compile contract to WASM"
	@echo "  abi      Export Solidity ABI"
	@echo "  lock     Generate Cargo.lock file"
	@echo "  test     Run unit tests"
	@echo "  check    Validate contract against Sepolia"
	@echo "  deploy   Deploy to Sepolia"
	@echo "  clean    Remove build artifacts"
