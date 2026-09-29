//! Events emitted by `kipio_economics`.
//!
//! Every mutating state transition emits an indexed event so that off-chain
//! indexers, auditors, and the runtime can reconstruct the economic history
//! of the protocol without touching storage.

use stylus_sdk::alloy_sol_types::sol;

sol! {
    // --- ECONOMIC EVENTS ---
    event SettlementExecuted(
        address indexed funder,
        uint256 allocated_capacity,
        uint256 fee_paid,
        bytes32 indexed payment_id,
        uint256 nonce
    );
    event CreditDeposited(address indexed account, uint256 amount, uint64 expires_at);
    event CreditWithdrawn(address indexed account, uint256 amount);
    event CreditExpired(address indexed account, uint256 amount);
    event TreasuryFunded(address indexed sponsor, uint256 amount);
    event RefundIssued(address indexed account, uint256 amount);

    // --- FEE AUDIT EVENTS ---
    event ProtocolFeeCollected(
        address indexed funder,
        uint256 fee_amount,
        uint8 indexed service_id,
        bytes32 indexed payment_id
    );
    event ProtocolFeePolicyUpdated(uint256 fee_amount);
    event MaxProtocolFeeUpdated(uint256 max_fee);
    event CreForwarderUpdated(address indexed old_forwarder, address indexed new_forwarder);
    event CreWorkflowUpdated(bytes32 indexed old_workflow_id, bytes32 indexed new_workflow_id);

    // --- ACCOUNTING AUDIT EVENTS ---
    event TreasuryConsumed(address indexed beneficiary, uint256 amount);
    event GrantCreated(bytes32 indexed grant_id, uint256 amount, uint64 expires_at);
    event GrantConsumed(bytes32 indexed grant_id, address indexed beneficiary, uint256 amount);
    event GrantExpired(bytes32 indexed grant_id, uint256 remaining_amount);
    event SponsorRegistered(bytes32 indexed sponsor_id, address indexed sponsor, uint256 amount);
    event SponsorConsumed(bytes32 indexed sponsor_id, address indexed beneficiary, uint256 amount);
    event SponsoredExecution(address indexed beneficiary, uint8 source_id, uint256 amount);
    event BootstrapSponsored(address indexed beneficiary, uint256 amount);
    event BootstrapDepleted();

    // --- GOVERNANCE & REGISTRY EVENTS ---
    event ServiceRegistryUpdated(uint8 indexed service_id, address provider_address);
    event EconomicsDeployed(address indexed owner, address indexed cre_forwarder);
    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event MaxCreditUpdated(uint256 max_credit);

    // --- BOOTSTRAP CAMPAIGN EVENTS ---
    event BootstrapCampaignCreated(
        bytes32 indexed campaign_id,
        uint256 amount_per_beneficiary,
        uint32 max_beneficiaries,
        uint64 expires_at
    );
    event BootstrapCampaignConsumed(
        bytes32 indexed campaign_id,
        address indexed beneficiary,
        uint256 amount
    );
    event BootstrapCampaignClosed(bytes32 indexed campaign_id, uint256 remaining);

    // --- CRE EVENTS ---
    event SettlementDeposited(bytes32 indexed payment_id, uint256 amount);
    event StaleSettlementReclaimed(
        bytes32 indexed payment_id,
        address indexed depositor,
        uint256 amount
    );
    event CreSettlementProcessed(
        address indexed funder,
        bytes32 indexed payment_id,
        uint256 amount,
        uint8 service_id,
        bytes32 indexed workflow_id,
        uint256 nonce
    );

    // --- REFUND EVENTS (PULL-BASED) ---
    event RefundCredited(address indexed account, uint256 amount);
    event RefundWithdrawn(address indexed account, uint256 amount);

    // --- NONCE EVENTS ---
    event NonceConsumed(address indexed account, uint256 nonce);
}
