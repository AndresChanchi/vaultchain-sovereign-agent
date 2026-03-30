# Frontend

A privacy-first, decentralized upload interface designed for permanent data storage.

Built for users who want full control over their files — without subscriptions, without lock-in, and without compromising ownership.

---

## 📦 Installation

To install dependencies:

```bash
bun install
````

Build styles:

```bash
bun run build:styles
```

## 🚀 Development

To start the development server:

```bash
bun run dev
```

---

This project was created using `bun init` in bun v1.3.10. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.

---

## ✅ Current Status (MVP)

* Fully functional on **desktop environments**
* Supports users familiar with crypto wallets
  (e.g. interacting with Arbitrum Sepolia and managing tokens)
* Core upload, encryption, and sharing flows are operational on tesnet

⚠️ **Known Issues (Mobile)**

* Some image uploads may fail in edge cases on mobile devices
* Likely caused by **price fluctuations during upload execution**
* This issue does not typically occur on desktop
* Improvements are planned to handle volatility more reliably

---

## ⛓️ Infrastructure (Integrated)

This frontend is already connected to a production-ready stack:

* Irys (data layer) ✅
* Arbitrum Stylus contracts (Rust) ✅
* WASM-based optimizations ✅
* Client-side encryption & decryption ✅

> ℹ️ This repository focuses on the frontend layer only.
> For detailed information about infrastructure and smart contracts, see the corresponding README files in their respective folders.

---

## 🔮 Roadmap (Post-MVP)

### 🔐 Security & Session Management

* **Inactivity Timer**
  Automatically lock sessions after inactivity (Paranoid privacy even down to the hardware...)

* **"Lock Vault" Button**
  Let users manually close their cryptographic session without closing the tab

---

### ⚠️ Error Handling

* **Global Error Handling (Toasts)**
  Clear feedback for failed actions (e.g. rejected signatures)

---

### 👤 User Experience & Onboarding

* **Account Abstraction (AA)**
  Make the app usable for non-crypto-native users:

  * Social login (Google and alternatives)
  * Smart accounts instead of traditional wallets

* **Paymaster Integration**
  Enable gasless or sponsored transactions

* **Privacy-Respecting Options**
  Reduce reliance on centralized providers and prioritize user privacy

---

### 🔗 Sharing & Privacy

* **Private Sharing (Invite Links)**
  Share securely with selected users and restrict unwanted access

* **Public Sharing Option**
  Share files publicly without encryption when desired

* **ZK-based Hybrid Model (Exploration)**
  Combine privacy and usability for flexible sharing modes

---

### 🖼️ Media & Upload Improvements

* Improve handling of:

  * Small images
  * Edge-case upload failures
  * Market volatility during upload execution

---

### 🧩 Content Expansion (Beyond Photos)

Current MVP is focused on **images**, inspired by a real need:

* Backing up large personal photo collections (e.g. 10GB–20GB+)
* Avoiding subscription-based storage models

Future direction expands beyond that:

* **Private “Google Photos”-like experience (but decentralized)**
* Support for:

  * Documents
  * Development files
  * Arbitrary data uploads

Goal:

> A general-purpose, permanent, user-owned storage layer — not just a photo app.

---

### 🔬 Research

* **Asymmetric Encryption**
  Continued improvements in secure key management and data sharing
