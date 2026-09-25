//! Access grant/revoke dispatch handlers.
//!
//! Grants and revocations are tracked with a swap-and-pop index for
//! O(1) enumeration and O(1) removal. Grant is idempotent (granting
//! twice is a silent no-op); revoke on a non-grantee is also a silent
//! no-op.

use super::*;

impl KipioIdentityContent {
    #[inline(never)]
    pub(crate) fn dispatch_grant_access(&mut self, args: &[u8]) -> ArbResult {
        let call = grantAccessCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;
        if call.grantee == Address::ZERO {
            return Err(ZeroGrantee {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        {
            let mut vault = self.vaults.setter(sender);

            if vault.contents.getter(call.content_id).tx_commitment.get() == B256::ZERO {
                return Err(NotFound {}.abi_encode());
            }

            let mut content_map = vault.access.permissions.setter(call.content_id);
            let mut permission_slot = content_map.setter(call.grantee);

            if permission_slot.get() {
                return Ok(Vec::new());
            }
            permission_slot.set(true);

            let existing_pos = vault
                .access
                .grantee_positions
                .getter(call.content_id)
                .getter(call.grantee)
                .get();
            if existing_pos == U256::ZERO {
                let mut index = vault.access.grantee_index.setter(call.content_id);
                let new_pos = index.len() as u64;
                index.grow().set(call.grantee);
                vault
                    .access
                    .grantee_positions
                    .setter(call.content_id)
                    .setter(call.grantee)
                    .set(U256::from(new_pos + 1));
            }
        }

        self.vm().log(AccessGranted {
            owner: sender,
            grantee: call.grantee,
            contentHash: call.content_id,
        });

        Ok(Vec::new())
    }

    #[inline(never)]
    pub(crate) fn dispatch_revoke_access(&mut self, args: &[u8]) -> ArbResult {
        let call = revokeAccessCall::abi_decode(args).map_err(|_| Vec::new())?;

        self.require_not_paused()?;
        if call.grantee == Address::ZERO {
            return Err(ZeroGrantee {}.abi_encode());
        }

        let sender = self.vm().msg_sender();

        {
            let mut vault = self.vaults.setter(sender);

            let pos = vault
                .access
                .grantee_positions
                .getter(call.content_id)
                .getter(call.grantee)
                .get();
            if pos == U256::ZERO {
                return Ok(Vec::new());
            }

            {
                let mut content_map = vault.access.permissions.setter(call.content_id);
                let mut permission_slot = content_map.setter(call.grantee);
                if !permission_slot.get() {
                    return Ok(Vec::new());
                }
                permission_slot.set(false);
            }

            let idx = (pos.as_limbs()[0] - 1) as usize;

            let last_addr: Option<Address>;
            let last_idx: usize;
            {
                let index = vault.access.grantee_index.getter(call.content_id);
                last_idx = index.len() - 1;
                if idx != last_idx {
                    last_addr = index.getter(last_idx).map(|g| g.get());
                } else {
                    last_addr = None;
                }
            }

            {
                let mut index = vault.access.grantee_index.setter(call.content_id);
                if let Some(addr) = last_addr {
                    index.setter(idx).unwrap().set(addr);
                }
                index.pop();
            }

            if let Some(addr) = last_addr {
                vault
                    .access
                    .grantee_positions
                    .setter(call.content_id)
                    .setter(addr)
                    .set(U256::from(idx as u64 + 1));
            }
            vault
                .access
                .grantee_positions
                .setter(call.content_id)
                .setter(call.grantee)
                .set(U256::ZERO);
        }

        self.vm().log(AccessRevoked {
            owner: sender,
            grantee: call.grantee,
            contentHash: call.content_id,
        });

        Ok(Vec::new())
    }
}
