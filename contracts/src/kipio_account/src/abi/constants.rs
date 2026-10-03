//! Domain constants for `kipio_account`.

/// `RecoveryEffect.kind = 1`: register a new credential.
/// Payload encoding: `CredentialAbi`.
pub const EFFECT_KIND_REGISTER_CREDENTIAL: u8 = 1;

/// `RecoveryEffect.kind = 2`: revoke an existing credential.
/// Payload encoding: `CredentialAbi`.
pub const EFFECT_KIND_REVOKE_CREDENTIAL: u8 = 2;

/// `RecoveryEffect.kind = 3`: rotate a credential (revoke old, register new).
/// Payload encoding: `(CredentialAbi, CredentialAbi)`.
pub const EFFECT_KIND_ROTATE_CREDENTIAL: u8 = 3;

/// Credential lifecycle status: active.
pub const CREDENTIAL_STATUS_ACTIVE: u8 = 1;

/// Credential lifecycle status: revoked.
pub const CREDENTIAL_STATUS_REVOKED: u8 = 3;
