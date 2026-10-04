# Kipio: Sovereign Digital Property

Kipio is a decentralized protocol and consumer application for permanent, private ownership of digital content. It replaces the rental model of cloud storage with something closer to digital property: users encrypt their files before they ever leave the device, the encrypted payload is written to Irys for permanent availability, and an on-chain registry on Arbitrum keeps the ownership record in the user's own hands. No recurring subscription, no centralized custodian, no silent deletion.

I have been building Kipio for about six months. It is not a weekend prototype. I use it myself. My own gigabytes of family photos and personal archives are already encrypted and stored this way. **The goal now is to make that same capability available to anyone who wants it, not just to me.**

Kipio is built for two audiences at once. For people who have never touched a crypto wallet, it works like a private photo album: nothing extra to install, no seed phrase to write down, sign in the way you already sign in to everything else, and your files stay yours. For crypto-native users, it adds something the ecosystem has been missing for years: a sovereign account model where every authorization is verified on-chain, every state transition is atomic, and no admin key can move someone else's data. Both audiences get the same protocol. The difference is only which door they walk through.

The protocol itself never sees who you are. The smart contracts only see cryptographic commitments and signatures. How a user authenticates to the app is a frontend concern, and the contracts do not care. This means Kipio can be accessed through Google login, an email magic link, a passkey, a hardware wallet, a seed phrase, or anything else a frontend chooses to support. The contract layer stays the same. Adding a new credential type, or moving to zero-knowledge proofs for identity later, does not require touching the on-chain protocol.

---

## 🏆 Arbitrum Open House Singapore 2026

Kipio is submitted to the [Arbitrum Open House Singapore](https://www.hackquest.io/projects/Kipio) Buildathon. The submission is a working project with an existing on-chain history, not a from-scratch demo.

The previous six months produced a functional MVP on Arbitrum Sepolia, a formal domain model written and verified in Dafny, and a modular multi-crate Stylus workspace. The Buildathon work focused on taking that foundation further: adapting the verified domain model to Rust, building the cross-chain settlement foundations, and documenting the architectural reasoning behind the registry pattern and the immutable contract design.

The full technical documentation lives in [contracts/README.md](contracts/README.md). It covers the deployment phases, the formal verification pipeline, the fragmented init code reverse-engineering, and the diagnosis of a real bug found during testing.

### ⚠️ Current network condition: Stylus activation pause

On October 2, 2026, the Arbitrum Security Council executed an emergency action that temporarily paused new Stylus contract activations on Arbitrum One and Arbitrum Nova. The reason was a security concern: AI-assisted tooling has made it easier to craft hand-written WASM programs that bypass the standard Stylus compiler and can degrade chain performance for everyone else. No user funds were ever at risk. The full report is on the Arbitrum governance forum: [Security Council Emergency Action – 2/10/2026](https://forum.arbitrum.foundation/t/security-council-emergency-action-2-10-2026/31530). The Arbitrum Foundation has also published a builder-facing summary in the [Arbitrum Docs notice](https://docs.arbitrum.io/notices/stylus-activation-pause-notice).

What this means for Kipio:

- **Existing, active Stylus contracts continue to run normally.** Calls remain permissionless. Contracts can be renewed before expiry through the keepalive mechanism.
- **New activations are paused.** Deploying a new version of a Stylus contract, including a fixed version of an existing one, requires activation, and activation is what the Security Council paused.
- **Solidity and EVM contract deployment are unaffected.**

Kipio already had a complete deployment on Sepolia before the pause. That deployment remains live. The newer modular protocol, fully developed and tested on a local Nitro devnode, is ready for activation as soon as the pause is lifted. The Arbitrum Foundation has stated it is working with the ArbitrumDAO on a path to reopen activations in a way that preserves legitimate Stylus use while restricting hand-crafted WASM programs. I do not expect that process to stretch into 2027, and I am preparing the deployment so it can go out the moment the network reopens.

I am not waiting for that to be resolved in order to keep building. The work continues on the frontend, on the formal model, and on the parts of the protocol that do not require new activations.

---

## 🗺️ How the pieces fit together

The protocol is split into small, single-purpose contracts. This diagram shows the runtime picture: what a user action flows through, and which contract owns which part of the decision.

```
                          User intent
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Execution Gateway   │   entry point
                    │  (immutable)         │   CREATE2 bootstrap
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Runtime             │   orchestrator
                    │  (stateless)         │   single atomic tx
                    └──────────┬───────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Account    │      │  Economics   │      │  Identity &  │
│  (per user)  │      │  settlement  │      │   Content    │
│  CREATE2     │      │  treasury    │      │   anchor     │
└──────┬───────┘      └──────────────┘      └──────────────┘
       │
       ▼
┌──────────────┐      ┌──────────────────────────────────┐
│  Recovery    │      │  Protocol Config (registry)      │
│  guardians   │      │  resolves every module address   │
└──────────────┘      └──────────────────────────────────┘
```

Two contracts deserve special attention for anyone evaluating the design:

**`kipio_runtime`** is the only contract in the system that initiates cross-contract calls during a user flow. It reads the user's account state, runs the authorization pipeline in memory, settles the economic obligation, and forwards the target call, all inside a single transaction. If any step fails, the entire flow reverts and the user pays nothing. That atomicity guarantee is the reason the account, the settlement layer, and the content layer never talk to each other directly.

**`kipio_account`** is deployed once per user through CREATE2, and its address is derived from the user's identity. It stores the authorization state that decides what the user has allowed and what they have revoked, and it accepts calls only from the runtime address recorded at construction time. There is no admin key that can move a user's state, no upgrade slot that can rewrite the account's behavior, and no delegatecall that hides who is acting. The account is a sovereign kernel, and it stays one.

---

## ✨ What Kipio does

- **Client-side encryption.** Every file is encrypted before it leaves the browser. The keys stay with the user.
- **Permanent decentralized storage.** Encrypted payloads are written to Irys, a datachain designed for permanent data. The user pays once for storage, not monthly.
- **On-chain ownership.** An Arbitrum Stylus registry anchors the content metadata on-chain. The contract stores pointers and commitments, never the files themselves.
- **Sovereign access control.** The owner decides who can see what. Visibility is a user-controlled toggle, not a platform policy.
- **Atomic multi-contract flows.** Every user action that spans more than one contract executes as a single transaction. Either everything succeeds or nothing does.
- **Hardware-backed signing.** The dApp supports Ledger devices through the Device Management Kit. Both physical devices over WebHID and the Speculos emulator are supported.
- **Credential-agnostic identity.** The contract only sees pseudonymous commitments and signatures, never a real-world identity. Any frontend can authenticate users however it wants — Google login, email, passkeys, hardware wallets, social recovery — without touching the protocol. Curve support is pluggable through the verifier registry in `kipio_protocol_config`. `secp256r1` (passkeys, FaceID, TouchID) is supported today through the EIP-7951 precompile; other curves can be added later without redeploying anything.

## 🛠 Tech stack

- **Smart contracts:** Rust (Stylus SDK 0.10.9), Solidity (Foundry).
- **Formal verification:** Dafny 4.11.0, with a translation pipeline that produces the Rust crate used by the bridge.
- **Storage:** Irys L1 Datachain.
- **Frontend:** Next.js 16, React 19, viem, wagmi v3, TypeScript 7.
- **Runtime:** Bun v1.4.x.

## 📦 Repository layout

```
.
├── contracts/                    # Stylus workspace, Foundry interfaces, deployment tooling
├── domain/                       # Dafny formal model: account domain, laws, adversarial proofs
├── emulator-ledger-backend/      # Speculos Docker setup and compiled Ethereum app ELF
├── frontend/                     # Next.js dApp: upload, encryption, sharing, Ledger signing
└── docs/                         # Domain reference notes
```

Each folder has its own README with setup instructions and architecture details for that layer.

## ✅ Current status

### The MVP on Arbitrum Sepolia

The MVP runs end-to-end with browser wallets on Arbitrum Sepolia and Irys devnet. Upload, client-side encryption, permanent storage, and sharing all work. The contract that powers it is:

| Contract | Address | Network |
|---|---|---|
| `KipioEconomics` (MVP) | [`0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452`](https://sepolia.arbiscan.io/address/0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452) | Arbitrum Sepolia |

This contract was deployed several months ago and remains fully functional. It is the version currently integrated with the frontend.

### The modular protocol

The contracts workspace was rewritten as a multi-crate Stylus project with a clear separation of concerns. Every contract is immutable. Upgrades happen through `kipio_protocol_config`, an on-chain registry that resolves the current address of each module. There is no proxy, no delegatecall, no upgrade admin with the power to swap implementation under a user's feet. When a module changes, a new instance is deployed and the registry is updated. The old version stays at its address forever, callable and inspectable.

The seven contracts are:

| Contract | Sepolia address | Status |
|---|---|---|
| `kipio_protocol_config` | [`0x1e08d50c7bb524ea03371804d5c223e9557e926c`](https://sepolia.arbiscan.io/address/0x1e08d50c7bb524ea03371804d5c223e9557e926c) | Deployed |
| `kipio_runtime` | [`0x387e5745e49de0fb0cfc49b39a437d6fe1339dab`](https://sepolia.arbiscan.io/address/0x387e5745e49de0fb0cfc49b39a437d6fe1339dab) | Deployed |
| `kipio_recovery` | [`0x31f2253b1a95b936e2b4adb59a456125cb3e2b08`](https://sepolia.arbiscan.io/address/0x31f2253b1a95b936e2b4adb59a456125cb3e2b08) | Deployed |
| `kipio_economics` | [`0x47b765294efc205a1e95bc865215f2d71f83f558`](https://sepolia.arbiscan.io/address/0x47b765294efc205a1e95bc865215f2d71f83f558) | Deployed |
| `kipio_identity_content` | [`0x0d203d8169b37deb2f77da1c116febc841b0d907`](https://sepolia.arbiscan.io/address/0x0d203d8169b37deb2f77da1c116febc841b0d907) | Bugged, fix ready |
| `kipio_execution_gateway` | [`0xe2fac8809593159824e29c5d63b25cb0c93b6cdb`](https://sepolia.arbiscan.io/address/0xe2fac8809593159824e29c5d63b25cb0c93b6cdb) | Deployed |
| `kipio_account` | Created per user via CREATE2 | Not a singleton |

The `kipio_identity_content` contract has a bug. The first deployment used a manual `#[fallback]` dispatcher and called `SolCall::abi_decode` on argument slices that no longer contained a selector. Alloy's `abi_decode` validates the selector before decoding, so every call with one or more arguments reverted with empty data. The fix is a mechanical replacement with `abi_decode_raw`, which decodes arguments without expecting a selector. The corrected version was verified on a local Nitro devnode with a full set of 0-argument, 1-argument, and 3-argument calls. It has not yet been redeployed to Sepolia because the Stylus activation pause makes it impossible to activate a new contract right now. The full diagnosis is in [contracts/README.md](contracts/README.md) under **Manual fallback dispatch: the `abi_decode` contract**.

The frontend will switch to the fixed contract as soon as the pause is lifted. The registry update is a single `setIdentityContentAddress` call, and the provider slots are re-applied on the new instance.

### 🔐 Ledger integration

The dApp exposes two Ledger connectors through Wagmi v3. Both share the same signing pipeline, built on the Ledger Device Management Kit. Only the transport differs.

| Connector | Transport | Use case |
|---|---|---|
| `ledger-physical` | WebHID | Users with a physical Ledger device connected over USB |
| `ledger-speculos` | HTTP | Reviewers and demos, backed by an emulated Ledger Nano S Plus |

The Speculos emulator runs the official Ledger Ethereum app in a Docker container and serves its screen through a web UI. During the hackathon it was deployed on Oracle Cloud and exposed over HTTPS through a Cloudflare Tunnel so that reviewers could experience the full signing flow without owning hardware. That deployment has since been taken down. The `emulator-ledger-backend/` folder contains the Docker command and the precompiled ELF if anyone wants to reproduce it locally.

Read-only RPC methods are proxied to a public client built on the chain's HTTP transport. Signing methods (`personal_sign`, `eth_signTypedData_v4`, `eth_sendTransaction`, `eth_signTransaction`) are routed to the DMK signer.

Two limitations are worth noting. Without a Ledger `originToken` issued through the partner program, the device displays only the transaction hash instead of decoded call details. And on physical devices, Arbitrum Sepolia requires Developer Mode enabled in Ledger Wallet.

## 🔮 Roadmap

### Immediate, pending the Stylus activation pause

- Redeploy `kipio_identity_content` with the `abi_decode_raw` fix.
- Update `kipio_protocol_config` to point to the fixed contract.
- Re-apply the Irys storage provider address on the new instance.
- Switch the frontend to the corrected contract and verify the full upload and retrieval flow.

### Frontend, in progress

The frontend is under active development. The current priorities are:

- **Session management.** An inactivity timer and a manual "Lock Vault" button so the cryptographic session can be closed without closing the tab.
- **Error handling.** Clear feedback for failed actions, especially rejected signatures.
- **Mobile edge cases.** Some image uploads fail on mobile devices, likely because of price fluctuations during the upload window. The fix is a more robust retry and quoting flow.
- **Sharing.** Private invite links and a public sharing option for files the user chooses to disclose.
- **Content beyond photos.** Documents, development files, and arbitrary data, not just images.
- **Onboarding paths for non-crypto users.** Google login, email magic links, and other familiar sign-in flows that hide the cryptographic machinery behind the scenes. The protocol already supports this because it only sees commitments and signatures; the work is entirely on the frontend.

### Post-Buildathon, funded or not

- **Multichain settlement.** Expanding the verification hooks so that access fees can be settled in arbitrary currencies and on networks beyond Arbitrum.
- **0G.ai integration.** 0G is a decentralized AI operating system built around four modular layers: an AI-first EVM L1 chain, a scalable data availability network, a modular storage system, and a verifiable compute layer. Its stated goal is to become the trust layer for AI, where inference and agent actions can be verified and audited. The long-term direction for Kipio is to let users run verifiable AI over their own encrypted content, so that the intelligence built on someone's memories belongs to them as much as the memories do. This is not a feature I can ship this month. It is the direction Kipio is pointed at. I am documenting it now so the reasoning is visible.
- **Agentic commerce.** Autonomous treasury management for self-funding data availability, so that a user's content can pay for its own continuation without a monthly invoice. This is post-Buildathon work. The economic primitives are already in `kipio_economics`; the agent layer on top is not.
- **Private metadata layer.** Kipio anchors encrypted content on Arbitrum. The metadata that describes that content, the albums, the memories, the labels, the relationships between items, must also stay private. Exposing it to indexers would leak context even if the payloads remain encrypted. I am exploring Aztec's private execution environment as an encrypted note store, readable only by the owner. Nothing has been built yet. It is a direction, not a claim.
- **Zero-knowledge identity.** The contract already operates on pseudonymous commitments. The next step is to let a user prove a property about themselves, or about their content, without revealing anything else. This opens the door to compliance-friendly flows, private sharing with verifiable conditions, and delegated access that never leaks who is behind an action.
- **Chainlink CRE.** The `kipio_economics` contract is production-ready for CRE reports. The workflow itself is written but not yet deployed because Chainlink approval is pending. Once approved, the settlement path activates without any contract change.
- **Threshold access providers.** The `access_provider` slot in `kipio_identity_content` is a placeholder. TACo is paused and LIT Protocol is the alternative candidate. The setter is ready; the value is not yet set.

### What Kipio is not

Kipio is not trying to be a faster dropbox. The goal is a general-purpose, permanent, user-owned storage layer. The initial use case is personal memories, because that is where the problem is most acute and most personal. But the same protocol applies to any content that someone wants to keep without asking permission and without paying rent.

The long-term vision includes B2C and B2B use. An organization could integrate with the open protocol or subsidize access for its users. Protocol-level fees provide sustainable infrastructure economics without turning the user into a subscriber. But that is the destination, not today's state.

Today the project is a working MVP on testnet, a verified domain model, and a modular protocol waiting for a network pause to lift. It has been developed by one person, bootstrapped, without external funding. The priority for any future funding would be to turn it from a one-person effort into a capable team: product and frontend design, growth, and additional protocol engineering.

**Your photos are yours. The intelligence built on them is yours too.**
