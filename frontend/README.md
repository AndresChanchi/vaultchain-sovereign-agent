# Kipio Frontend

A privacy-first, decentralized upload interface designed for permanent data storage.

Built for users who want full control over their files — without subscriptions, without lock-in, and without compromising ownership.

The interface now ships the full authenticated experience: a Midnight Emerald design system, a session-aware login (OAuth PKCE + EIP-6963 wallets), a five-step upload flow that survives the OAuth redirect via IndexedDB, a reactive space shell, and a per-tile decrypting gallery. Every visible string is served by the six-layer i18n runtime; pricing quotes real Irys L1 prices, not placeholders.

> This folder contains only the Next.js dApp. For the project overview, submission details, contract architecture and roadmap, see the [root README](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/main/README.md).

---

## 📦 Installation

```bash
bun install
```

Build styles (Tailwind 4 CLI, no PostCSS):

```bash
bun run build:styles
```

## 🚀 Development

```bash
bun run dev
```

Production build:

```bash
bun run build
```

Testing on a real device over the local network (WSL2, iOS Safari, Brave iOS):

```bash
# Terminal 1
bun run dev

# Terminal 2 — Cloudflare Quick Tunnel
cloudflared tunnel --url http://localhost:3000
```

`allowedDevOrigins` in `next.config.ts` allows `*.trycloudflare.com` so HMR works through the tunnel. The Quick Tunnel URL is temporary and public while it runs — close it with `Ctrl+C` when done.

---

## 🛠️ Stack

Runtime and libraries, current as of the upload + space rebuild:

* **Runtime**: Bun 1.4.2
* **Framework**: Next.js 16.3.8, React 19.2.8
* **Language**: TypeScript 7.0.2 (strict, `noUncheckedIndexedAccess`)
* **Styles**: Tailwind CSS 4.3.3 via CLI (no PostCSS)
* **Web3**: viem 2.56.3, wagmi 3 (legacy dashboard only), ethers 6.17.0 (Irys signer adapter)
* **Wallet discovery**: `mipd` 0.0.7 (EIP-6963 multi injected provider discovery)
* **Storage**: `@irys/sdk` 0.2.11
* **Ledger**: `@ledgerhq/device-management-kit` 1.9.0, `@ledgerhq/device-signer-kit-ethereum` 1.18.0
* **State and data**: TanStack Query 5.102.8
* **Workers**: comlink 4.4.2
* **Linter**: Biome 2.5.12

Zero new dependencies were added for the login, upload, space or i18n rebuilds beyond `mipd`. Everything else is TypeScript, CSS, and browser APIs (`crypto.subtle`, `IndexedDB`, `history`, `matchMedia`, `<dialog>`, `Intl`).

---

## 🔧 Environment Variables

Create `.env.local` at the root of `frontend/`. Every variable is prefixed with `NEXT_PUBLIC_` because it is consumed by client components.

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

### OAuth (PKCE, no server secret except Google)

The OAuth flow is browser-only (RFC 9700 / RFC 7636 / RFC 10017). Google requires a `client_secret` at the token endpoint even with PKCE — documented deviation from RFC 7636, acceptable because PKCE is the real security (the `code_verifier` never leaves the origin). Microsoft and X honour PKCE-only.

```bash
NEXT_PUBLIC_GOOGLE_CLIENT_ID=
NEXT_PUBLIC_GOOGLE_CLIENT_SECRET=        # Google-only workaround; public by design
NEXT_PUBLIC_MICROSOFT_CLIENT_ID=
NEXT_PUBLIC_X_CLIENT_ID=
```

Redirect URI for every provider: `http://localhost:3000/auth/callback` in development, `https://<host>/auth/callback` in production. No wildcards.

### Ledger DMK

```bash
# Ordered list of Speculos endpoints. The connector tries each URL in
# order and caches the first one that responds.
NEXT_PUBLIC_SPECULOS_URL_REMOTE=
NEXT_PUBLIC_SPECULOS_URL_LOCAL=http://localhost:5000
```

---

## ⛓️ Infrastructure (Integrated)

The frontend is connected to a production-ready stack:

* Irys (data layer) ✅
* Arbitrum Stylus contracts (Rust) ✅
* WASM-based image optimisation ✅
* Client-side AES-GCM-256 encryption & decryption ✅
* Ledger DMK signing (Speculos + WebHID) ✅

> For the Ledger integration architecture, signing flow and known limitations, see the [root README](https://github.com/AndresChanchi/vaultchain-sovereign-agent/blob/main/README.md#-ledger-integration-overview).

---

## 🎨 Design System — Midnight Emerald v3

Defined in `src/app/globals.css`. Derived from the project's mockup (`Kipio v2`, Stitch-aligned). The mockup is the source of truth for layout, spacing and copy; the design system is the implementation.

**Tokens**

* **Colour**: `--color-bg`, `card`, `elevated`, `ink`, `muted`, `muted-soft`, `hairline`, `emerald`, `emerald-text`, `violet`, `violet-text`, `glass`, `on-emerald`, `amber`, `danger`, `danger-text`. Every text token uses `light-dark()` so the palette is theme-aware without a JS switch.
* **Radii**: `--radius-input`, `button`, `tile`, `card`, `sidebar`, `panel`, `stage`.
* **Motion**: `--ease-spring`, `--ease-out`, plus named tokens (`--animate-rise`, `--animate-pulse-ring`, `--animate-chip-pulse`, `--animate-grow`, `--animate-breathe`, `--animate-photo-arrive`, `--animate-lock-reveal`, `--animate-kept-badge`, `--animate-cursor-drag`, `--animate-orb-drift-1/2`, `--animate-shn`).
* **Fonts**: Geist (UI), Geist Mono (addresses, prices, mono labels, counters), Instrument Serif (Hero H1, "space ready" H1, Moment titles, public page name — never body, never controls).

**Utilities** (`@utility` blocks — Tailwind 4 CSS-first, no PostCSS): `glass`, `label-mono`, `shn-shine`, `chip-pulse`, `grow-bar`, `skeleton`, `amb-bg`, `tile-name`, `prose-measure`, `hero-viewport`.

**Principles**

* **No `!important`.** Every component-level style composes via `@layer base`, `@layer components`, or `@utility`.
* **Every animation has a reduced-motion override.** `prefers-reduced-motion: reduce` overrides the `--animate-*` tokens; utilities that build on them resolve to `animation: none`. Reduced transparency is honoured on `.glass`.
* **WCAG AA contrast is non-negotiable.** De-emphasised text uses `--color-muted-soft` (≥4.5:1 in both themes) — never `text-muted/70`.
* **Logical properties where RTL is plausible.** `inset-inline-start`, `text-start`. Physical `left`/`right` only where the geometry is LTR-locked and documented (e.g. the `AnyDevice` rail).
* **Honest data.** Unknown values render `—` with an accessible label. Never a fake number.
* **Native over framework.** WebAuthn, `fetch`, `Intl`, `IntersectionObserver`, `IndexedDB`, `history`, `<dialog>`, `content-visibility`, `animation-timeline` — all natively used where the browser exposes them.

**Mobile performance gates**

The landing was tuned specifically for iOS Safari, where WebKit does not composite SVG children and re-runs the entire SVG filter chain on every frame that touches a filtered element. The rules:

* **No `feTurbulence` on animated SVG.** Replaced by a static `<pattern>` of dots. See `journey-samples.tsx`.
* **No large `blur()` / `backdrop-filter` on animated surfaces.** Orbs use `radial-gradient`; the dock and sidebar drop to `blur(12px)` on mobile (`@media max-width: 767px`).
* **`transform: scaleX()` instead of `width`** for stretch animations (`journey-shrink`, `journey-bar`) — EXCEPT `journey-sweep`, which is a single absolute element whose visual is a `border-right` and cannot be scaled without turning it into a wedge.
* **`transform-gpu` (`translateZ(0)`) on elements that will animate** — forces layer promotion so the first frame does not stutter.
* **No `will-change` on slides** — fights the reduced-motion tokens and keeps the layer alive after the animation ends.

---

## 🧵 Workers & Performance

Kipio runs two Web Workers off the main thread. Both are orchestrated through `comlink`. The `useImageWorker` hook and the crypto worker in `KipioContext` are the only consumers.

**Why workers**

Web Workers are real OS-level threads. The page and the worker do not share memory: data crossing the boundary is copied through structured clone (or transferred zero-copy when the type is `Transferable`). There is no DOM access from a worker, so a worker cannot paint; it can only do CPU work and post results back. This is exactly what a Kipio upload needs:

* **Image optimisation** — `browser-image-compression` inside a worker so the main thread stays responsive during a 30-60 MB photo resize.
* **AES-GCM-256 encryption / decryption** — the master key never leaves the worker, and the ciphertext is produced off the main thread. The `ArrayBuffer` is transferred, not copied, so the original is emptied at the sender side and reconstituted at the worker side — zero-copy at 30-60 MB per photo.

**Structured clone vs. transferable objects**

The default path for `postMessage` is structured clone: the payload is serialised, sent, and deserialised at the other side. For a 40 MB photo buffer this is two full passes over memory. `Transferable` objects (implemented by `ArrayBuffer`, `ImageBitmap`, `MessagePort`, `OffscreenCanvas`, …) skip the copy: ownership of the buffer moves from sender to receiver, and the sender's reference becomes empty. In Kipio both the image worker and the crypto worker use `Comlink.transfer(...)` on their `ArrayBuffer` arguments.

Rule for future worker code: if the payload is an `ArrayBuffer` (or any `Transferable`) and the sender does not need it after the call, always transfer. If the sender needs the buffer again, `slice(0)` it first and transfer the copy. `useImageWorker.compress()` does exactly this so the original survives for the fallback path when the worker is unavailable.

**Embedded worker code**

HTML supports embedding worker code without a `src` attribute via a `<script type="text/plain">` data block (or any non-executable MIME type). The block is not executed as a script; JavaScript reads its `textContent` and constructs a `Blob` URL for the worker. Kipio does not use this pattern — Next.js + Turbopack resolve `new Worker(new URL("./worker.ts", import.meta.url))` into a real asset at build time. The pattern is documented here for completeness in case a future static-export constraint requires inlining a worker.

**Image decoding off the main thread**

The Sentry performance guide on image decoding is the reference the gallery was built against: decoding a large WebP on the main thread causes visible jank on iOS, and `HTMLImageElement.decode()` on the main thread does not help. Kipio's strategy is to keep the raw bytes and the AES-GCM work off the main thread (worker), and only hand the browser the final Blob URL. If the gallery later shows very large originals, the next step is `createImageBitmap(blob)` inside the worker + `ImageBitmapRenderingContext` in the tile — documented under the performance roadmap.

**References**

* [Structured clone algorithm (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm)
* [Transferring data via transferable objects (MDN, es)](https://developer.mozilla.org/es/docs/Web/API/Web_Workers_API/Using_web_workers#pasando_datos_mediante_transferencia_de_propiedades_objetos_transferibles)
* [Using web workers (MDN, es)](https://developer.mozilla.org/es/docs/Web/API/Web_Workers_API/Using_web_workers)
* [Embedded workers (MDN, es)](https://developer.mozilla.org/es/docs/Web/API/Web_Workers_API/Using_web_workers#embedded_workers)
* [`Worker.postMessage` (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Worker/postMessage)
* [Sentry — image decoding on the main thread](https://docs.sentry.io/product/issues/issue-details/performance-issues/image-decoding-main-thread/)

**WASM — where it earns its bytes**

WASM is already in the pipeline through `browser-image-compression` (its internal optimiser is compiled to WASM and shipped with the package). No hand-written WASM exists in the frontend today, and none was added for crypto: `crypto.subtle` already runs AES-GCM, HKDF and SHA-256 natively in the browser, at native speed, with no WASM boundary. Adding a hand-rolled WASM crypto module would be slower than the built-in.

The door stays open for two concrete cases where WASM could still earn its weight later:

1. **Large-batch image processing** — if a future `/library` bulk-import path needs to resize 100+ photos in one shot, a WASM image pipeline (e.g. `libvips` compiled to WASM) could beat the current per-photo `browser-image-compression` loop on total throughput, at the cost of ~2 MB of WASM payload. Evaluate when that batch path exists.
2. **Metadata indexing** — if the gallery ever needs on-device search over encrypted metadata (a Private AI feature, Fase 12), a WASM indexer (e.g. `tantivy` compiled to WASM) would keep the plaintext in the tab. Defer until the feature exists.

Rule: WASM is allowed only when (a) there is a native browser API gap, (b) the WASM payload is paid once and amortised, and (c) the code stays a drop-in module that does not change the calling convention of the surrounding pipeline.

---

## 🌐 Internationalization

Six-layer architecture, all under `src/lib/i18n/` plus `src/context/I18nContext.tsx`.

```
lib/i18n/
├── locales.ts             — LOCALES, LOCALE_META, detectLocale, persist, localePath
├── types.ts               — Dictionary (typeof en), Path<T>, TranslateVars
├── translate.ts           — pure t(dictionary, key, vars) with {var} substitution
├── format.ts              — Intl wrappers with per-locale caching + plural categories
└── dictionaries/
    ├── en.ts              — aggregate: { landing, login, space }
    ├── es.ts              — aggregate: { landing, login, space }
    ├── _template.ts       — aggregate template
    ├── en/landing.ts      — landing strings (14 sections)
    ├── en/login.ts        — login panel, OAuth providers, wallet labels
    ├── en/space.ts        — sidebar, dock, header, welcome, overview, upload flow
    ├── es/…               — mirrors, satisfies Dictionary
    └── _template/…        — TODO scaffold for the remaining 10 locales
```

**How translation is consumed**

* **Scalars**: `const { t } = useI18n(); t("space.overview.greeting")`. TypeScript validates the key against `Path<Dictionary>` — a typo fails the build.
* **Arrays**: read directly from the active dictionary (`dictionary.landing.journey.steps`, `dictionary.space.welcome.starter.*`). `t()` only resolves leaf strings.
* **Numbers, dates, currency**: `format.number`, `format.date`, `format.currency`, `format.plural`. All `Intl.*`, no dependencies.

**How to add a locale**

```bash
cp -r src/lib/i18n/dictionaries/_template src/lib/i18n/dictionaries/<code>
```

1. Translate every `TODO` in `dictionaries/<code>/*.ts`.
2. Add `<code>` to `LOCALES` in `locales.ts`.
3. Add an entry to `LOCALE_META` in `locales.ts` (label, native name, direction, BCP47 tag, OG locale).
4. Add `<code>` to `AVAILABLE_LOCALES` only when the translation is complete. The picker shows only available locales.

`Dictionary = typeof en` means the build fails if a locale is missing a key. `satisfies Dictionary` is the contract.

**No middleware, no `next-intl`.** Locale detection runs client-side after hydration (`localStorage → NEXT_LOCALE cookie → navigator.languages → default`). `<html lang>` and `<html dir>` are updated by the provider effect. This keeps the build compatible with `output: 'export'` (Fleek-ready).

---

## 💰 Pricing

The pricing card and the upload review step both quote real Irys L1 prices with multi-currency conversion. The engine lives in `src/lib/pricing/` (pure calculation + I/O) and `src/hooks/pricing/useUploadQuote.ts` (React glue via TanStack Query).

**Invariants — breaking one produces a wrong number**

* **Irys is L1.** Native token `IRYS`, not `AR`. Arweave is a different network.
* **Endpoint: `uploader.irys.xyz`.** The legacy `node2.irys.xyz` bundler returns prices in a deprecated AR-denominated model ~50× off.
* **`arbitrum` means "pay with ETH on Arbitrum".** The endpoint returns ETH wei.
* **Reference size = 1 GiB.** Query once, scale linearly.
* **Read `*Display`, never `*Usd`.** Every monetary field has both variants; the UI formats the `*Display` variants with the picker's currency. Formatting a `*Usd` value with the target formatter produces the classic "COP 3 for $3" bug.
* **`KIPIO_FEE_BPS = 0`** while `kipio_economics` is inactive. The card shows `$0.00` with `pricing.feePreviewNote`. No placeholder percentage.
* **Term pricing is unavailable via REST.** The public `?term=` parameter is ignored; requests fall back to the permanent price with `termFallback: true`, and the UI renders `pricing.termFallbackNote`.

**Configuration** (`src/config/pricing.ts`): `KIPIO_FEE_BPS`, `GAS_BUFFER_USD`, `IRYS_BUNDLER_URL`, `IRYS_TOKEN`, `IRYS_FREE_UPLOAD_BYTES` (100 KiB), `IRYS_PRICE_REFERENCE_BYTES` (1 GiB), `SUPPORTED_CURRENCIES` (13), `DEFAULT_CURRENCY` (USD), cache TTLs. Data only.

---

## 🔍 SEO + AI Discovery

* **`src/app/sitemap.ts`** — one entry per route, with `alternates.languages` for every locale in `LOCALES` plus `x-default` → `/`. Ready for the route restructure.
* **`src/app/robots.ts`** — explicit groups for `Googlebot`, `Bingbot`, and the major AI crawlers: `GPTBot`, `OAI-SearchBot`, `ClaudeBot`, `PerplexityBot`, `Google-Extended`, `CCBot`. Each can be toggled independently. `/api/` and `/space/` are disallowed on every group.
* **`public/llms.txt`** — H1 title, blockquote summary, flat link sections. Points back to the landing as the canonical source.

---

## 🔐 Ledger Connector (Implementation)

The signing pipeline is exposed through two wagmi v3 connectors that share the same DMK-based signer. Only the transport differs.

| Path | Responsibility |
|---|---|
| `src/lib/ledger/connector.ts` | Custom wagmi connector wrapping DMK, exposing a viem-compatible account. |
| `src/config/wagmi.ts` | Registers `ledger-physical` (WebHID) and `ledger-speculos` (HTTP). |
| `src/hooks/useVault.ts` | Detects the active Ledger connector; extends the retry buffer for hardware signing latency. |

Speculos endpoints are ordered: the connector tries each URL until one responds. In development, `NEXT_PUBLIC_SPECULOS_URL_LOCAL`; on Vercel, `NEXT_PUBLIC_SPECULOS_URL_REMOTE`.

**Status in the new login flow** — the ledger connectors are wired to the legacy dashboard (`/dashboard`). Wiring the DMK signer into `KipioContext.signTypedData` is Fase 10 work; today a Ledger session that tries to sign in the new flow surfaces an honest `unsupported` error.

**Local Speculos** — `../emulator-ledger-backend/` ships a precompiled Ethereum app ELF and a Docker command.

---

## ✅ Current Status

**Shipped**

* **Landing** — 14 sections under `src/components/landing/`, all consuming `useI18n()`. The page file is a pure composition.
* **Login** — Google / Microsoft / X via OAuth PKCE (browser-only, no server); MetaMask / Brave / Rabby via EIP-6963 (`mipd`); session persisted in `sessionStorage`; modal mounted at root via the History API (`/login` deep-link supported); sign-out clears everything.
* **Space shell** — sidebar (collapsible, persisted) + mobile dock + header + account card. `/space` is the authenticated route; the legacy `/dashboard` stays for the old MVP.
* **Welcome state (0 photos)** — ambient glow, 3D journey stage with `photo-arrive → lock-reveal → kept-badge`, starter cards. Both CTAs are live: "Upload your first photos" opens the upload dialog; "Look around first" scrolls to the starters.
* **Overview state (≥1 photo)** — greeting, real photo count, quick actions (disabled placeholders), recent uploads gallery with a dynamic limit derived from `photoCount` (floor 8, cap 48; above the cap the "View all" button is prepared for `/library`).
* **Gallery** — per-tile fetch + decrypt in the crypto worker. Six states (`loading`, `decrypting`, `ready`, `expired`, `network-error`, `decrypt-error`). Irys testnet expiry surfaces as "No longer available" instead of a console error.
* **Upload flow (5 steps)** — `review → login (if no session) → pay (if OAuth) → progress → kept`. Files persist in IndexedDB (1 h TTL) across the OAuth redirect. Duplicate content hashes are caught before any wallet popup. Wallet sessions sign 3–4 transactions (unlock + fund + upload + register); OAuth sessions hit the pay step and can only switch to a wallet.
* **Reactivity** — an upload calls `bump()` on `SpaceRefreshContext`; `useSpaceStats` and `useSpaceGallery` refetch automatically. No manual reload button.
* **Design system** — Midnight Emerald v3 documented in `globals.css`. No `!important`, reduced-motion on every animation, WCAG AA contrast on all text.
* **SEO** — `sitemap.ts` with hreflang placeholders, `robots.ts` with AI-crawler groups, `public/llms.txt`.

**Intact from the previous build**

* Legacy upload, encryption and share flow on Arbitrum Sepolia — still functional on `/dashboard`, `components/vault/`, `hooks/`.
* Two Ledger connectors registered in `config/wagmi.ts`, consumed by the legacy dashboard.

**Deferred — reasons documented in code**

* Fiat payment (Card / Nequi / Bre-B) — needs a serverless relay + the new contracts. Rendered `aria-disabled` with "Coming soon"; not a placeholder to activate.
* Term selection (30 days / 1 year) — the MVP contract has no term concept. Only "Forever" is active.
* Sponsor / universal subsidy — deferred until the new contracts emit the events the frontend would read.
* Ledger signing in the new login flow — needs the DMK signer wired into `KipioContext` (Fase 10).
* Passkey, GitHub, Apple, Twitch — need a serverless relay.
* Route restructure with locale-prefixed URLs (`(default)/`, `[locale]/`) — deferred.

---

## 📍 What's Next

**All remaining phases are visual.** The functional layer is complete and verified; the work that remains is fidelity to the design mockups — layout, motion, typography, spacing, and the still-missing routes.

The user drives the order. The likely surfaces, each mockup-driven and shipped one file per turn with `bun run build` between files:

1. **Polish pass on the shipped surfaces** — whatever the user flags after a mobile + desktop review.
2. **`/library`** — full photo grid with native virtualization (`content-visibility: auto` + `IntersectionObserver`, no library). The overview's "View all" points here.
3. **`/settings`** — access & backup, privacy, language, Private AI, sharing.
4. **`/moments`**, **`/shared`**, **`/offers`** — behind the new contracts.
5. **Public page `/u/[handle]`** — the share surface.
6. **Route restructure with locales** — `(default)/` + `[locale]/`, `generateStaticParams`, `dynamicParams = false`, `generateMetadata` with hreflang.

When the new contracts activate, the deferred states switch on by removing `disabled` flags and enabling the OAuth/fiat branches already gated in `upload-pay-step.tsx` — no rewrite.

---

## ⚠️ Known Issues (Mobile)

**iOS Safari — journey stage frame drops.** On real devices (iOS 15 through the current iOS 27, every browser including Brave iOS since they all run WebKit), the journey stage can drop frames during slide transitions. Three causes were addressed: `feTurbulence` on the SVG symbols (removed, replaced by a static `<pattern>`), missing layer promotion on the slides (`transform-gpu` added), and `width`-based animations on the bars (`transform: scaleX()` where possible). The slide `box-shadow` was reduced on mobile and the dock/sidebar `backdrop-filter` was halved.

Remaining suspects if drops persist: the four `rotateY` + `preserve-3d` slides simultaneously visible, and the infinite CSS animations across the page competing for the compositor. Both are tracked under the performance roadmap below; the fix requires measurement on a real device, not a guess.

**Image upload volatility.** On mobile, a price change between quote and broadcast occasionally produces a `max fee per gas` RPC error (-32000). `useVault.registerUpload` retries up to 3× on mobile with a 30 % buffer on the estimated fee. Not fully eliminated; tracked as future improvement.

---

## 🧭 Performance Roadmap

Items to evaluate, in rough order of expected impact:

1. **Journey stage on iOS** — measure with Safari Web Inspector on the iPhone (the user already does this via `cloudflared`). If drops persist after the current mitigations, the next levers are `content-visibility: hidden` on the far-past/far-future slides during transitions, and reducing the number of infinitely-animated SVGs on the landing.
2. **Gallery decode path** — `createImageBitmap(blob)` inside the crypto worker + `ImageBitmapRenderingContext` in the tile, replacing `<img src={objectUrl}>`. Eliminates main-thread image decode for large originals.
3. **WASM for bulk import** — only when a `/library` bulk path exists. `libvips` → WASM is the candidate; ~2 MB payload, amortised over hundreds of photos.
4. **WASM for on-device metadata search** — only when Private AI (Fase 12) exists. `tantivy` → WASM is the candidate.
5. **Fleek migration** — introduce `output: 'export'` compatible patterns where trivial. No server-only APIs in the landing or space shell; locale detection already client-side; no middleware.

---

## 📚 Reference

* [Structured clone algorithm (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm)
* [Using web workers (MDN, es)](https://developer.mozilla.org/es/docs/Web/API/Web_Workers_API/Using_web_workers)
* [Transferring data via transferable objects (MDN, es)](https://developer.mozilla.org/es/docs/Web/API/Web_Workers_API/Using_web_workers#pasando_datos_mediante_transferencia_de_propiedades_objetos_transferibles)
* [Embedded workers (MDN, es)](https://developer.mozilla.org/es/docs/Web/API/Web_Workers_API/Using_web_workers#embedded_workers)
* [`Worker.postMessage` (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Worker/postMessage)
* [Sentry — image decoding on the main thread](https://docs.sentry.io/product/issues/issue-details/performance-issues/image-decoding-main-thread/)
