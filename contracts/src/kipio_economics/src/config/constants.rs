//! Protocol-wide constants for `kipio_economics`.

/// Timeout after which a pending CRE settlement can be reclaimed by anyone.
///
/// The Chainlink CRE workflow has up to eight hours of automatic retries on
/// the DON side. A seven-day timeout sits well above any realistic retry
/// window while keeping the window short enough that depositors are not
/// forced to wait a long time to recover funds when a workflow is revoked
/// or a DON stalls.
pub const SETTLEMENT_RECLAIM_TIMEOUT: u64 = 7 * 24 * 60 * 60;
