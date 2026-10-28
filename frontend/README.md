# Kipio Frontend

A privacy-first, decentralized upload interface designed for permanent data storage.

Built for users who want full control over their files — without subscriptions, without lock-in, and without compromising ownership.

The interface now ships a complete visual and international foundation: the landing is built on the Midnight Emerald design system, every visible string is served by a six-layer i18n runtime, and the pricing surface quotes real Irys L1 prices rather than placeholders.

> This folder contains only the Next.js dApp. For the project overview,submission details, architecture, and roadmap, see the [root README](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/main/README.md).

---

## 📦 Installation

To install dependencies:

```bash
bun install
```

Build styles:

```bash
bun run build:styles
```

## 🚀 Development

To start the development server:

```bash
bun run dev
```

Production build:

```bash
bun run build
```

---

This project was created using `bun init` in bun v1.4.2. [Bun](https://bun.sh) is a fast all-in-one JavaScript runtime.

---

## 🛠️ Stack

Runtime and libraries, current as of the visual and i18n rebuild:

* **Runtime**: Bun
* **Framework**: Next.js 16.3.8, React 19.2.8
* **Language**: TypeScript 7.0.2 (strict, `noUncheckedIndexedAccess`)
* **Styles**: Tailwind CSS 4.3.3 via CLI (no PostCSS)
* **Web3**: viem 2.56.3, wagmi 3, ethers 6.17.0 (legacy signers)
* **Storage**: `@irys/sdk` 0.2.11
* **Ledger**: `@ledgerhq/device-management-kit` 1.9.0, `@ledgerhq/device-signer-kit-ethereum` 1.18.0
* **State and data**: TanStack Query 5.102.8
* **Workers**: comlink 4.4.2
* **Linter**: Biome 2.5.12

Zero new dependencies were added for i18n, pricing, theme, or SEO. Those are implemented with TypeScript, CSS and browser APIs.

---

## 🔧 Environment Variables

Create a `.env.local` file at the root of `frontend/`. Every variable is prefixed with `NEXT_PUBLIC_` because they are consumed by client components.

### Blockchain (Arbitrum)

```bash
NEXT_PUBLIC_NETWORK=sepolia

NEXT_PUBLIC_RPC_URL_SEPOLIA=https://sepolia-rollup.arbitrum.io/rpc
NEXT_PUBLIC_CHAIN_ID_SEPOLIA=421614
NEXT_PUBLIC_CONTRACT_ADDRESS_SEPOLIA=0xfe76a53e5cc1cc5136b7da6b6fcf6c593c767452
NEXT_PUBLIC_EXPLORER_SEPOLIA=https://sepolia.arbiscan.io

NEXT_PUBLIC_RPC_URL_MAINNET=https://arb1.arbitrum.io/rpc
NEXT_PUBLIC_CHAIN_ID_MAINNET=42161
NEXT_PUBLIC_CONTRACT_ADDRESS_MAINNET=0x...
NEXT_PUBLIC_EXPLORER_MAINNET=https://arbiscan.io
```

### Irys

```bash
NEXT_PUBLIC_IRYS_GATEWAY=https://gateway.irys.xyz/
NEXT_PUBLIC_IRYS_NODE_DEVNET=https://devnet.irys.xyz/
NEXT_PUBLIC_IRYS_NODE_MAINNET=https://node1.irys.xyz/
```

### Ledger DMK

```bash
# Ordered list of Speculos endpoints. The connector tries each URL in
# order and caches the first one that responds.
#
# Remote endpoint (Oracle Cloud / VPS). Used on Vercel.
# Leave empty during local-only development.
NEXT_PUBLIC_SPECULOS_URL_REMOTE=

# Local endpoint (Docker on the developer machine).
NEXT_PUBLIC_SPECULOS_URL_LOCAL=http://localhost:5000
```

On Vercel, set `NEXT_PUBLIC_SPECULOS_URL_REMOTE` to the HTTPS URL of the deployed Speculos instance and leave `NEXT_PUBLIC_SPECULOS_URL_LOCAL` empty.

---

## ⛓️ Infrastructure (Integrated)

This frontend is already connected to a production-ready stack:

* Irys (data layer) ✅
* Arbitrum Stylus contracts (Rust) ✅
* WASM-based optimizations ✅
* Client-side encryption & decryption ✅
* Ledger DMK signing (Speculos + WebHID) ✅

> For the Ledger integration architecture, signing flow, and known limitations, see the [root README](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/main/README.md#-ledger-integration-overview).

---

## 🎨 Design System

Midnight Emerald v3, defined in `src/app/globals.css` and derived from the project's mockup (Kipio v2, Stitch-aligned). The mockup is the source of truth for layout, spacing and copy; the design system is the implementation.

**Tokens**

* Color: `--color-bg`, `card`, `elevated`, `ink`, `muted`, `muted-soft`, `hairline`, `emerald`, `emerald-text`, `violet`, `violet-text`, `glass`, `on-emerald`, `amber`, `danger`, `danger-text`. Every text token uses `light-dark()` so the palette is theme-aware without a JS switch.
* Radii: `--radius-input`, `button`, `tile`, `card`, `sidebar`, `panel`, `stage`.
* Motion: `--ease-spring`, `--ease-out`, and named animation tokens (`--animate-rise`, `--animate-pulse-ring`, `--animate-chip-pulse`, `--animate-grow`, etc.).
* Fonts: Geist (UI), Geist Mono (addresses, prices, mono labels), Instrument Serif (hero H1 only).

**Utilities**

`@utility` blocks (Tailwind 4 CSS-first, no PostCSS) cover the recurring patterns: `glass`, `label-mono`, `shn-shine`, `chip-pulse`, `grow-bar`, `skeleton`, `prose-measure`, `hero-viewport`.

**Principles**

* **No `!important`.** Every component-level style is composable via `@layer base`, `@layer components`, or `@utility`.
* **Every animation has a reduced-motion override.** `prefers-reduced-motion: reduce` overrides the tokens; utilities that build on them resolve to `animation: none`.
* **WCAG AA contrast is non-negotiable.** De-emphasized text uses `--color-muted-soft` (calibrated to ≥4.5:1 in both themes) — never an opacity modifier like `/70`, which is not a contrast guarantee.
* **Logical properties where RTL is plausible.** `inset-inline-start`, `text-start`. Physical `left`/`right` only where the geometry is LTR-locked and documented (e.g. `AnyDevice` rail).
* **Honest data.** If a value is unknown, render `—` with an accessible label. Never a fake number.
* **Native over framework.** When a browser API exists (WebAuthn, `fetch`, `Intl`, `IntersectionObserver`), prefer it over a library.

---

## 🌐 Internationalization

Six-layer architecture, all in `src/lib/i18n/` plus `src/context/I18nContext.tsx`.

```
lib/i18n/
├── locales.ts           — LOCALES, LOCALE_META, detectLocale, persist, localePath
├── types.ts             — Dictionary (typeof en), Path<T>, TranslateVars
├── translate.ts         — pure t(dictionary, key, vars) with {var} substitution
├── format.ts            — Intl wrappers with per-locale caching + plural categories
└── dictionaries/
    ├── en.ts            — aggregate: { landing } from en/landing.ts
    ├── es.ts            — aggregate: { landing } from es/landing.ts
    ├── _template.ts     — aggregate template
    ├── en/landing.ts    — full English landing, JSDoc per section
    ├── es/landing.ts    — full Spanish, satisfies Dictionary
    └── _template/landing.ts — TODO scaffold for the other 10 locales
```

**How translation is consumed**

* Scalars: `const { t } = useI18n(); t("landing.hero.title")`. TypeScript validates the key against `Path<Dictionary>` — a typo fails the build.
* Arrays: `dictionary.landing.journey.steps`. `t()` only resolves leaf strings; arrays are read directly from the active dictionary so iterating them is a normal `.map()`.
* Numbers, dates, currency: `format.number`, `format.date`, `format.currency`, `format.plural`. All `Intl.*`, no dependencies.

**How to add a locale**

```bash
cp -r src/lib/i18n/dictionaries/_template src/lib/i18n/dictionaries/<code>
```

1. Translate every `TODO` in `dictionaries/<code>/*.ts`.
2. Add `<code>` to `LOCALES` in `locales.ts`.
3. Add an entry to `LOCALE_META` in `locales.ts` (label, native name, direction, BCP47 tag, OG locale).
4. Add `<code>` to `AVAILABLE_LOCALES` in `locales.ts` **only when the translation is complete**. The picker only shows available locales; the roadmap can grow ahead of the shipped set.

The `Dictionary = typeof en` invariant means the build fails if a locale is missing a key. `satisfies Dictionary` is the contract.

**How to add a feature subfolder** (e.g. login, dashboard)

1. Create `dictionaries/en/<feature>.ts` with `export const <feature> = { … }`.
2. Update `dictionaries/en.ts` to `{ landing, <feature> }`. Repeat for `es.ts`, `_template.ts`, and every shipped locale.
3. TypeScript picks up the new keys automatically; every consumer using `t("<feature>.<section>.<key>")` gets validation for free.

**No middleware, no `next-intl`.** Locale detection runs client-side after hydration (`localStorage → NEXT_LOCALE cookie → navigator.languages → default`). `<html lang>` and `<html dir>` are updated by the provider effect. This keeps the build compatible with `output: 'export'` (Fleek-ready) — middleware is not allowed in that mode.

---

## 💰 Pricing

The pricing card shows real Irys L1 quotes with multi-currency conversion. The engine lives in `src/lib/pricing/` (pure calculation + I/O) and `src/hooks/pricing/useUploadQuote.ts` (React glue via TanStack Query).

**Invariants — breaking one of these produces a wrong number**

* **Irys is L1.** The native token is `IRYS`, not `AR`. Arweave is a different network.
* **Endpoint: `uploader.irys.xyz`.** The legacy `node2.irys.xyz` bundler returns prices in a deprecated AR-denominated model that is ~50× off from today's quotes. Never point at it.
* **`arbitrum` means "pay with ETH on Arbitrum".** The endpoint returns wei of ETH on Arbitrum. The scaling reads `ethAtomic / 1e18 × fx.ethUsd`.
* **Reference size = 1 GiB.** Query the price of `IRYS_PRICE_REFERENCE_BYTES` once, scale linearly to the user's byte count. Same math as querying the exact size, but one cache entry per term and independent of what sizes the endpoint accepts.
* **Read `*Display`, never `*Usd`.** `computeQuote` returns every monetary field in two variants: `storageUsd` / `storageDisplay`, `kipioFeeUsd` / `kipioFeeDisplay`, `totalUsd` / `totalDisplay`. The UI must format the `*Display` variants with the picker's currency. Formatting a `*Usd` value with `format.currency(value, "COP")` produces "COP 3" for $3 — this was the last bug fixed and the separation is now the invariant.
* **`KIPIO_FEE_BPS = 0`** while `kipio_economics` is inactive. The card shows `$0.00` with a preview note below the breakdown (`pricing.feePreviewNote`). Do not set a placeholder percentage — a fabricated 2.5% charges nothing but displays everything.
* **Term pricing is unavailable via REST.** The public `?term=` parameter is ignored by the bundler (identical response for `permanent`, `term:30`, `term:365`). Requests fall back to the permanent price with `termFallback: true`, and the UI renders `pricing.termFallbackNote` as an upper-bound disclaimer. When Cascade exposes a documented term endpoint, replace `termPriceUrl` in `lib/pricing/irys.ts` and the fallback flag in one place.

**Configuration** (`src/config/pricing.ts`)

`KIPIO_FEE_BPS`, `GAS_BUFFER_USD`, `IRYS_BUNDLER_URL`, `IRYS_TOKEN`, `IRYS_FREE_UPLOAD_BYTES` (100 KiB), `IRYS_PRICE_REFERENCE_BYTES` (1 GiB), `SUPPORTED_CURRENCIES` (13), `DEFAULT_CURRENCY` (USD), cache TTLs. Data only — no logic, no imports.

---

## 🔍 SEO + AI Discovery

Three files cover both classic search and LLM agents:

* **`src/app/sitemap.ts`** — one entry per route, with `alternates.languages` for every locale in `LOCALES` plus `x-default` → `/`. Ready for the route restructure; today `/` is the only route it lists.
* **`src/app/robots.ts`** — explicit groups for `Googlebot`, `Bingbot`, and the major AI crawlers: `GPTBot` (OpenAI training), `OAI-SearchBot` (ChatGPT answers), `ClaudeBot` (Anthropic), `PerplexityBot`, `Google-Extended` (Gemini training), `CCBot` (Common Crawl). Each can be toggled independently — blocking one stops that crawler without affecting the others. `/api/` and `/dashboard/` are disallowed on every group.
* **`public/llms.txt`** — H1 title, blockquote summary, flat link sections. The [llms.txt convention](https://llmstxt.org/) for LLM agents asking about Kipio. Points back to the landing as the canonical source of truth.

---

## 🔐 Ledger Connector (Implementation)

The signing pipeline is exposed through two Wagmi v3 connectors that share the same DMK-based signer. Only the transport differs.

### Files

| Path | Responsibility |
|---|---|
| `src/lib/ledger/connector.ts` | Custom Wagmi connector. Wraps DMK, exposes a Viem-compatible account, and routes EIP-1193 methods to the Ledger signer. |
| `src/config/wagmi.ts` | Registers `ledger-physical` (WebHID) and `ledger-speculos` (HTTP). Reads Speculos endpoints from environment variables and tries them in order. |
| `src/hooks/useVault.ts` | Detects the active Ledger connector via `connector.id` and extends the retry buffer for hardware signing latency. |

### Speculos endpoints

The `ledger-speculos` connector accepts an ordered list of URLs. It tries each one until a Speculos instance responds, then caches the session for the rest of the tab's lifetime.

* In development: `NEXT_PUBLIC_SPECULOS_URL_LOCAL` (`http://localhost:5000`)
* On Vercel: `NEXT_PUBLIC_SPECULOS_URL_REMOTE` (HTTPS URL of the deployed Speculos)

### Local Speculos (development)

The emulator backend lives in `../emulator-ledger-backend/`. It ships a precompiled Ethereum app ELF and a Docker command. See that folder's README for setup.

### Testing the Ledger flow

1. Start Speculos locally (or verify the deployed one responds).
2. Open the dApp and click **Connect with Ledger Simulator**.
3. When a signature is requested, open the Speculos web UI in another tab and approve on the emulated screen.
4. The dApp receives the signature through the connector and continues.

---

## ✅ Current Status

**Shipped in the current build**

* Landing rebuilt end-to-end: 14 sections isolated under `src/components/landing/`, all consuming `useI18n()`. The page file is a pure composition.
* Internationalization: six-layer architecture with `en` and `es` shipped complete, ten scaffolds for the remaining locales. `Dictionary = typeof en` guarantees compile-time parity.
* Theme toggle: two-state sun/moon in the navbar, `"system"` as the default. The theme-init script applies `data-theme` before first paint.
* Pricing: real Irys L1 quotes, multi-currency conversion, log-scale cost chart, numeric input with KB/MB/GB/TB units, currency picker. `KIPIO_FEE_BPS = 0` with an honest preview note.
* Design system: Midnight Emerald v3 documented in `globals.css`, no `!important`, reduced-motion on every animation, WCAG AA contrast on all text.
* SEO: `sitemap.ts` with hreflang placeholders, `robots.ts` with AI-crawler groups, `public/llms.txt`.

**Intact from the previous build**

* Legacy upload, encryption, and share flow on Arbitrum Sepolia — working on `dashboard/`, `components/vault/`, `hooks/`.
* Legacy dashboard at `/dashboard` (old UI, still functional).
* Two Ledger connectors registered in `config/wagmi.ts` (WebHID + Speculos), consumed by the legacy dashboard. The new login flow will reuse the connectors through a dedicated entry point.
* Signing routed through DMK for both physical and emulated devices.

**Not yet implemented**

* Login flow (Phase 8)
* Route restructure with URL-level locales (Phase 9)
* Upload overlay integrated with the new pricing (Phase 10)
* Library (Phase 11)
* Moments, Shared, Offers, Settings (Phase 12)

---

## 📍 What's Next

Phase 8 — **Login**. Mockup-driven. EIP-6963 discovery via `mipd`, EIP-1193 for the provider, EIP-5792 for capabilities, EIP-7702 for the authorization signature when needed. Wallet picker (MetaMask, Brave, Rabby via `mipd`; Ledger via the existing connector). Email, social and passkey sign-in. `WalletContext` and the discovery hooks.

Phase 9 — **Route restructure**. `(default)/` for English at `/`, `[locale]/` for the rest. `generateStaticParams` + `dynamicParams = false` per group. `generateMetadata` per locale with hreflang. `RootDocument` extracted from the current `layout.tsx`. Sitemap picks up the new routes automatically.

Phase 10 — **Upload overlay**. `/upload` intercepted route, `UploadOrchestrator` refactored, Irys SDK wired for real uploads, `pricing-card` consumed inside the review step for a real quote at upload time.

Phase 11 — **Library**. Photo grid with `content-visibility: auto` for virtualization, `useModuleAddresses` reading the registry, `useKipioAccount` persisting the CREATE2 address with its `createdByGateway`. The `components/vault/` legacy folder is retired at the end of this phase.

Phase 12 — **Moments, Shared, Offers, Settings**. One by one. Each with its own dictionary subfolder (`dictionaries/<code>/moments.ts`, etc.).

Login ships before the route restructure so the biggest remaining visual surface is validated end-to-end before URLs change. Both are compatible with `output: 'export'` — the Fleek migration stays available.

---

## ⚠️ Known Issues (Mobile)

* Some image uploads may fail in edge cases on mobile devices
* Likely caused by **price fluctuations during upload execution**
* This issue does not typically occur on desktop
* Improvements are planned to handle volatility more reliably
