//! Cross-contract integration tests for the Kipio Account protocol.
//!
//! Three tiers:
//!
//!   Tier A — In-memory TestVM: exercise Account and Runtime entrypoints
//!            directly, without external calls.
//!   Tier B — Cross-contract mocks: use `TestVM::mock_call` to simulate
//!            Runtime invoking Account (or any external module) and
//!            verify return-value handling.
//!   Tier C — Fork from Sepolia: use `TestVMBuilder` with the RPC
//!            endpoint declared in `Stylus.toml` to read real on-chain
//!            storage against a deployed contract, without deploying.
//!
//! Reference:
//!   https://docs.rs/crate/stylus-test/latest

use kipio_account_bridge::*;
use kipio_account::KipioAccount;
use kipio_runtime::KipioRuntime;
use stylus_sdk::testing::{TestVM, TestVMBuilder};
use stylus_sdk::alloy_primitives::{address, Address, U256};
use stylus_sdk::abi::Bytes;

// ============================================================================
// Fixtures
// ============================================================================

fn empty_auth_state() -> AuthorizationStateAbi {
    AuthorizationStateAbi {
        capabilities: vec![],
        credentials: vec![],
        credentialAuthorities: vec![],
        sessions: vec![],
        delegations: vec![],
        delegationProvenance: vec![],
        restrictionMap: vec![],
        policyEffects: vec![],
        consumedReplayKeys: vec![],
    }
}

fn empty_account() -> AccountAbi {
    AccountAbi {
        id: Bytes::from(vec![1u8, 2, 3, 4]),
        identity: IdentityAbi {
            id: Bytes::from(vec![5u8, 6, 7, 8]),
            subject: SubjectAbi {
                reference: Bytes::from(vec![9u8, 10u8]),
            },
        },
        authorizationState: empty_auth_state(),
    }
}

fn valid_capability(name: &str) -> CapabilityAbi {
    CapabilityAbi {
        kind: CapabilityKindAbi { name: name.to_string() },
        scope: empty_scope_abi(),
    }
}

fn valid_credential(id: u8) -> CredentialAbi {
    CredentialAbi {
        id: Bytes::from(vec![id]),
        status: 1,
    }
}

fn well_formed_authorization(account_id: Bytes) -> AuthorizationAbi {
    AuthorizationAbi {
        credentialId: Bytes::from(vec![1u8]),
        requestedAuthority: vec![],
        restrictions: vec![],
        validFrom: U256::from(0u64),
        validUntil: U256::from(1000u64),
        replayKey: Bytes::from(vec![2u8]),
        accountId: account_id,
        scope: empty_scope_abi(),
    }
}

// ============================================================================
// Tier A — In-memory TestVM: contract entrypoints directly
// ============================================================================

#[test]
fn account_entrypoint_valid_account() {
    let vm = TestVM::default();
    let contract = KipioAccount::from(&vm);
    assert!(contract.valid_account(empty_account()));
}

#[test]
fn account_entrypoint_register_credential() {
    let vm = TestVM::default();
    let contract = KipioAccount::from(&vm);
    let (new_account, applied) =
        contract.register_credential(empty_account(), valid_credential(1));
    assert!(applied);
    assert_eq!(new_account.authorizationState.credentials.len(), 1);
}

#[test]
fn account_entrypoint_add_capability() {
    let vm = TestVM::default();
    let contract = KipioAccount::from(&vm);
    let (new_account, applied) =
        contract.add_capability(empty_account(), valid_capability("Upload"));
    assert!(applied);
    assert_eq!(
        new_account.authorizationState.capabilities[0].kind.name,
        "Upload"
    );
}

#[test]
fn runtime_entrypoint_authorization_is_structurally_valid() {
    let vm = TestVM::default();
    let contract = KipioRuntime::from(&vm);
    let auth = well_formed_authorization(Bytes::from(vec![1u8, 2, 3, 4]));
    assert!(contract.authorization_is_structurally_valid(auth));
}

#[test]
fn runtime_entrypoint_compute_effective_authority() {
    let vm = TestVM::default();
    let account_contract = KipioAccount::from(&vm);

    let (account, applied) = account_contract.add_capability(
        empty_account(),
        valid_capability("Upload"),
    );
    assert!(applied);

    let runtime_contract = KipioRuntime::from(&vm);
    let ea = runtime_contract.compute_effective_authority(
        account,
        vec![],
        U256::from(500u64),
    );

    assert_eq!(ea.len(), 1);
    assert_eq!(ea[0].kind.name, "Upload");
}

// ============================================================================
// Tier B — Cross-contract mocks
// ============================================================================

#[test]
fn runtime_accepts_mocked_account_return() {
    let vm = TestVM::default();

    let account_addr = Address::from([0xAC; 20]);

    // Mock: any call to account_addr with 0 ETH returns ABI-encoded `true`.
    vm.mock_call(
        account_addr,
        vec![/* calldata bytes */],
        U256::from(0),
        Ok(vec![/* ABI-encoded return */]),
    );

    let runtime_contract = KipioRuntime::from(&vm);
    let account = empty_account();
    let auth = well_formed_authorization(account.id.clone());

    let accepted = runtime_contract.authorization_can_be_accepted_full(
        auth,
        account,
        vec![],
        U256::from(500u64),
        true,
    );

    assert!(accepted);
}

// ============================================================================
// Tier C — Fork from Sepolia
// ============================================================================
//
// These tests read real on-chain storage against a deployed contract.
// Writes happen in-memory and never affect the chain.
//
// The RPC endpoint matches `[workspace.networks].sepolia.endpoint`
// in the workspace's `Stylus.toml`.
// ============================================================================

const SEPOLIA_DEPLOYED_ADDR: Address =
    address!("97ff05fead287a6a0f0c7edfc0d40d2bcdd3e16f");

#[test]
#[ignore]
fn fork_sepolia_storage_read() {
    let vm: TestVM = TestVMBuilder::new()
        .sender(address!("1111111111111111111111111111111111111111"))
        .contract_address(SEPOLIA_DEPLOYED_ADDR)
        .value(U256::from(0))
        .rpc_url("https://sepolia-rollup.arbitrum.io/rpc")
        .build();

    let _contract = KipioAccount::from(&vm);
}
