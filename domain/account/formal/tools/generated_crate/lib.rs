//! kipio_account_generated
//!
//! Rust crate assembled by tools/export_rust.py from the Dafny
//! formal model of Kipio Account.
//!
//! Layout:
//!
//!   - `kipio_domain_externs` provides the concrete Rust types for
//!     every abstract type declared with `{:extern}` in Dafny.
//!   - The generated modules live in `src/generated/` and are
//!     included below.
//!
//! The re-exports at the crate root exist because `dafny translate rs`
//! emits references of the form `crate::<Module>::<Type>` inside the
//! generated code. Those references must resolve to a name that
//! exists at the crate root, and the only way to satisfy that
//! without duplicating the modules is to re-export them here.

#![allow(warnings, unconditional_panic)]
#![allow(nonstandard_style)]
#![cfg_attr(any(), rustfmt::skip)]

pub use kipio_domain_externs::KipioAccountChain;
pub use kipio_domain_externs::KipioAccountDomainAction;
pub use kipio_domain_externs::KipioAccountExecutionTarget;
pub use kipio_domain_externs::KipioAccountExecutionConstraints;
pub use kipio_domain_externs::KipioAccountExecutionSemantics;

// Generated modules. The export script will emit one line per
// generated .rs file under src/generated/.
//
// include!("generated/foundation/Chain.rs");
// include!("generated/foundation/DomainPrimitives.rs");
// include!("generated/authority/Credential.rs");
// ...
