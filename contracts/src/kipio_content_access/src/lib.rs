#![allow(unexpected_cfgs)]
#![cfg_attr(not(feature = "std"), no_std)]

// ============================================================================
// PROVIDER ABSTRACTION BOUNDARY
// ============================================================================
//
// Kipio depends on interfaces, not implementations.
//
//   StorageProvider → Irys today; Arweave, Filecoin, IPFS tomorrow.
//   QueryProvider   → SXT via CRE today; alternative indexers tomorrow.
//   AccessProvider  → Lit Protocol today; TACo (WEDF) tomorrow.
//   ZKVerifier      → UltraHonk/Groth16/halo2 (optional, future).
//
// Each provider is replaceable without modifying protocol logic.
// The contract stores provider addresses and resolves them dynamically.
// It never hard-codes a vendor.
//
// Design principle: depend on the interface, not the implementation.
//
// ============================================================================
// CALLER MODEL
// ============================================================================
//
// This contract is intentionally decoupled. Any address can be the caller:
//
//   - A standard EOA (crypto-native user) calling directly.
//   - `kipio_account` (sovereign smart account) pushing via its own runtime.
//   - `kipio_runtime` orchestrating on behalf of a non-crypto user.
//   - Any future adapter that implements the same interface.
//
// The contract does NOT enforce an operator model, an approval scheme,
// or a signature scheme. It trusts `msg_sender()` as the vault owner.
// Authorization (who may call on whose behalf) belongs to the caller
// layer, not to this bounded context.
//
// ============================================================================
// OWNERSHIP SEMANTICS (PROTOCOL GOVERNANCE vs USER SOVEREIGNTY)
// ============================================================================
//
// IMPORTANT: There are TWO distinct "ownership" concepts in this system:
//
//   1. PROTOCOL GOVERNANCE (this contract's `owner` field):
//      - Sets provider addresses (storage, query, access, zk).
//      - Sets expected CRE workflow ID.
//      - Pauses/unpauses content-side mutators (see CIRCUIT BREAKER).
//      - Can be transferred via `transfer_ownership` (two-step).
//      - Intended to migrate to a Multisig → Timelock → DAO.
//      - This is INFRASTRUCTURE governance, NOT user data.
//
//   2. USER SOVEREIGNTY (implicit via `msg_sender`):
//      - Each caller owns their own vault (`vaults[msg_sender]`).
//      - No contract-level "user ownership" exists.
//      - For EOA users: `msg_sender` is the EOA itself.
//      - For smart-account users: `msg_sender` is the `kipio_account`
//        instance, whose credential model (Dafny-verified) determines
//        who can authorize calls on behalf of the identity.
//
// These roles are SEPARATE. `transfer_ownership` moves protocol
// governance, not user vaults. User vaults move implicitly when
// `kipio_account`'s credentials are rotated (external to this contract).
//
// ============================================================================
// PROVIDER SELECTION IS USER SOVEREIGN
// ============================================================================
//
// This contract stores a single `storage_provider` adapter address, but
// `provider_id` per content is chosen by the USER. The contract NEVER
// decides providers automatically. The user selects:
//
//   provider_id = 0  → Irys
//   provider_id = 1  → IPFS
//   provider_id = 2  → Filecoin
//   provider_id = 3  → Arweave
//
// No automatic fallback, no vendor lock-in, no protocol-side override.
// The frontend is responsible for presenting options and costs to the
// user in an accessible way. The contract enforces only that the chosen
// provider_id is in the supported set.
//
// ============================================================================
// IRYS STORAGE TERMS (Cascade upgrade, August 2026)
// ============================================================================
//
// Irys supports three predefined storage terms, plus a custom escape hatch:
//
//   storage_term = 0  → PERMANENT   (Publish Ledger, highest cost)
//   storage_term = 1  → 30_DAYS     (Term Ledger, lowest cost)
//   storage_term = 2  → 1_YEAR      (Term Ledger, medium cost)
//   storage_term = 3  → CUSTOM      (Term Ledger, user-defined duration)
//
// The `expiry_delta` field stores the number of SECONDS from `created_at`
// until the content expires. It is packed into bytes [28..32) of the
// `packed` U256, preserving the 1-slot-per-content optimization.
//
//   Permanent:  expiry_delta = 0 (no expiry)
//   30 days:    expiry_delta = 2_592_000
//   1 year:     expiry_delta = 31_536_000
//   Custom:     expiry_delta = user-specified
//
// The ABSOLUTE expiry is computed as: `created_at + expiry_delta`.
//
// TERM EXTENSION:
//   Irys allows extending a term ledger before it expires. The user pays
//   only for the extension. `extend_storage_term` records the new term
//   on-chain. Downgrades are rejected: the new absolute delta must be
//   greater than or equal to the old delta.
//
// WHAT HAPPENS WHEN CONTENT EXPIRES:
//   On Irys side, the data is garbage-collected after expiry. On the
//   contract side, the record remains. The frontend is responsible for:
//     1. Calling `get_expiry_status` to detect expiry.
//     2. Hiding/blocking access to the dead txID.
//     3. Optionally calling `delete_content` to clean up (idempotent).
//   The events (`ContentRegistered`, `ContentDeleted`) preserve the
//   historical record for off-chain indexers. No on-chain tombstone
//   is needed because events are the outbox.
//
// MUTABLE REFERENCES:
//   Irys supports mutable references (a static URL that resolves to the
//   latest transaction in a series). The contract treats this opaquely:
//   the `tx_commitment` always points to the latest transaction. The
//   frontend is responsible for using the mutable URL format. No extra
//   on-chain field is needed — `rotate_content` handles pointer updates.
//
// ONCHAIN FOLDERS (manifests):
//   For multi-file uploads, Irys uses a manifest (index) transaction.
//   The frontend registers the manifest ID as a single `content_id`.
//
// RESPONSIBILITY:
//   The contract RECORDS the user's declared intent. It does NOT verify
//   the actual term with Irys. Verification is delegated to the frontend
//   via the Irys SDK. The contract enforces only structural validity.
//
// ============================================================================
// VISIBILITY SEMANTICS (SOVEREIGNTY & IRREVERSIBLE DISCLOSURE)
// ============================================================================
//
// The user is sovereign over their content. This contract exposes a
// simple toggle between PRIVATE and PUBLIC:
//
//   - PRIVATE (default): the content is intended to be visible only to
//     the owner and to explicitly authorized grantees (via `grant_access`).
//   - PUBLIC: the owner has intentionally chosen to expose the content
//     to the world. Any observer can read it.
//
// ONE-WAY DISCLOSURE GUARANTEE:
//   Once content is public, third parties may have copied, indexed, or
//   archived it. Toggling back to PRIVATE does NOT undo disclosure. The
//   contract cannot recall data that has left its perimeter. This is a
//   property of the disclosure event, not a bug: publishing is opt-in
//   and explicitly initiated by the sovereign user.
//
// RESPONSIBILITY:
//   The contract RECORDS the user's declared visibility intent. It does
//   NOT enforce downstream copies. Data-egress control belongs to the
//   user's disclosure decision and to the frontend.
// ----------------------------------------------------------------------------

extern crate alloc;

pub mod abi;
pub mod codec;
pub mod config;
pub mod endpoints;
pub mod internal;
pub mod storage;

pub use storage::entrypoint::KipioContentAccess;
