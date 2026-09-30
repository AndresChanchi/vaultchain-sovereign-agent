//! Read-only getters with non-trivial logic.

use kipio_account_bridge::{
    valid_account_impl, valid_authorization_state_impl,
};
use stylus_sdk::alloy_primitives::B256;

use crate::abi::constants::CREDENTIAL_STATUS_ACTIVE;
use crate::storage::entrypoint::KipioAccount;

pub(crate) fn is_credential_active(this: &KipioAccount, credential_id: B256) -> bool {
    let status: u8 = this
        .credential_statuses
        .getter(credential_id)
        .get()
        .to::<u8>();
    status == CREDENTIAL_STATUS_ACTIVE
}

pub(crate) fn valid_account(this: &KipioAccount) -> bool {
    let state = this.read_authorization_state();
    valid_account_impl(&this.build_account_abi(&state))
}

pub(crate) fn valid_authorization_state(this: &KipioAccount) -> bool {
    valid_authorization_state_impl(&this.read_authorization_state())
}
