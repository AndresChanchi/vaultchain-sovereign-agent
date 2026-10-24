import { Navbar } from "@components/landing/navbar";
import { Hero } from "@components/landing/hero";
import { JourneyStage } from "@components/landing/journey-stage";
import { LiveStats } from "@components/landing/live-stats";
import { NotOnServers } from "@components/landing/not-on-servers";
import { AnyDevice } from "@components/landing/any-device";
import { OpenByDesign } from "@components/landing/open-by-design";
import { PricingCard } from "@components/landing/pricing-card";
import { Sovereign } from "@components/landing/sovereign";
import { Economy } from "@components/landing/economy";
import { SignIn } from "@components/landing/sign-in";
import { Footer } from "@components/landing/footer";
import { PageBackground } from "@components/ui/page-background";

/**
 * Landing page (public).
 *
 * Section-by-section migration status:
 *   [x] Navbar        → components/landing/navbar.tsx
 *   [x] Hero          → components/landing/hero.tsx
 *   [x] Journey       → components/landing/journey-stage.tsx (+ journey-samples.tsx)
 *   [x] LiveStats     → components/landing/live-stats.tsx (+ hooks/protocol/useStats.ts)
 *   [x] NotOnServers  → components/landing/not-on-servers.tsx (+ network-viz.tsx)
 *   [x] Pricing card  → components/landing/pricing-card.tsx
 *   [x] Sovereign     → components/landing/sovereign.tsx
 *   [x] AnyDevice     → components/landing/any-device.tsx
 *   [x] OpenByDesign  → components/landing/open-by-design.tsx
 *   [x] Economy       → components/landing/economy.tsx
 *   [x] SignIn        → components/landing/sign-in.tsx
 *   [x] Footer        → components/landing/footer.tsx
 *   [x] Background    → components/ui/page-background.tsx
 *
 * Remaining inline: `<Pricing>` — the section wrapper that positions
 * `<PricingCard>` with its eyebrow, H2 and copy. Not yet extracted
 * because the split (wrapper vs. card) is worth deciding together
 * with the PricingCard polish (Fase 6.5: feeding real numbers from
 * `useUploadQuote`). Extracting the wrapper alone adds a file without
 * changing behavior; leaving it here for now.
 *
 * Background composition
 *   The page-wide atmosphere (one central glow + two drifting orbs) is a
 *   discrete component rather than a CSS utility on `<main>`, because
 *   it needs three elements. See `components/ui/page-background.tsx`.
 *   `amb-bg` (the earlier approximation baked into a background
 *   shorthand) is no longer used here. It stays defined in globals.css
 *   for the legacy dashboard and will be removed once that page is
 *   migrated.
 *
 * `<main>` requires `relative isolate`
 *   - `relative` anchors `PageBackground`'s `inset-0` to `<main>`
 *     instead of `<body>` (whose coordinate space would otherwise
 *     include the sticky navbar and extend past the section flow).
 *   - `isolate` creates a stacking context so `PageBackground`'s
 *     `-z-10` resolves against `<main>` — not against `<body>`, where
 *     it would land *below* the `bg` paint and disappear.
 *
 * Client islands on this page
 *   `Hero`, `JourneyStage` and `PricingCard` are `"use client"`
 *   (interactive CTA, carousel autoplay + controls, segmented
 *   selection). Everything else — navbar, background, live stats,
 *   not-on-servers, sovereign, any-device, open-by-design, economy,
 *   sign-in, footer, and the `<Pricing>` wrapper — stays
 *   server-rendered. `LiveStats` calls `useStats()` which is a plain
 *   function returning an object literal; despite the `use` prefix,
 *   it contains no React hooks and is safe in a Server Component.
 *   This file remains a Server Component; the boundary is per-island.
 */

function Pricing() {
  return (
    <section id="pricing" className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-center">
        <div>
          <p className="label-mono text-muted">Honest pricing</p>
          <h2 className="mt-4 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            No monthly bill.
          </h2>
          <p className="mt-4 max-w-lg text-[15px] leading-relaxed text-muted">
            Pay once, for the term you choose. Storage is priced by the network,
            plus a Kipio fee we always show.
          </p>
        </div>
        <PricingCard />
      </div>
    </section>
  );
}

export default function LandingPage() {
  return (
    <>
      <Navbar />
      <main className="relative isolate bg-bg">
        <PageBackground />
        <Hero />
        <JourneyStage />
        <LiveStats />
        <NotOnServers />
        <Pricing />
        <Sovereign />
        <AnyDevice />
        <OpenByDesign />
        <Economy />
        <SignIn />
      </main>
      <Footer />
    </>
  );
}
