//! Account state reads and ABI synthesis.
//!
//! Runtime does not own any account state. It reads the persisted
//! AuthorizationState via cross-contract calls and reconstructs the
//! synthetic `AccountAbi` consumed by the Dafny entrypoints.

use alloc::vec::Vec;

use kipio_account_bridge::{AccountAbi, AuthorizationStateAbi, IdentityAbi, SubjectAbi};
use stylus_sdk::{abi::Bytes, alloy_primitives::Address, alloy_sol_types::SolError, prelude::*};

use crate::abi::errors::AccountStateReadFailed;
use crate::abi::interfaces::IKipioAccount;
use crate::storage::entrypoint::KipioRuntime;

impl KipioRuntime {
    /// Reads the AuthorizationState from a deployed Account contract.
    ///
    /// This is the raw cross-contract read used by the public endpoint
    /// and by every internal validator that needs account state. It does
    /// not go through the `#[public]` wrapper, keeping the cross-call
    /// budget minimal when several validators run in the same dispatch.
    pub(crate) fn read_account_state_raw(
        &self,
        account_addr: Address,
    ) -> Result<AuthorizationStateAbi, Vec<u8>> {
        let account = IKipioAccount::new(account_addr);
        let call = Call::new();
        account
            .get_authorization_state(self.vm(), call)
            .map_err(|_| AccountStateReadFailed {}.abi_encode())
    }

    /// Builds an `AccountAbi` from a cross-contract read.
    ///
    /// The synthetic account uses the account's on-chain address as both
    /// the `id` and the identity reference. This is the convention
    /// established by `kipio_account` for every account it owns.
    pub(crate) fn build_account_abi(
        &self,
        account_addr: Address,
        state: AuthorizationStateAbi,
    ) -> AccountAbi {
        let id_bytes = Bytes::from(account_addr.to_vec());
        AccountAbi {
            id: id_bytes.clone(),
            identity: IdentityAbi {
                id: id_bytes.clone(),
                subject: SubjectAbi {
                    reference: id_bytes,
                },
            },
            authorizationState: state,
        }
    }
}
