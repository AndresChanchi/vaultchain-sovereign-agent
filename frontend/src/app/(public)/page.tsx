import { Navbar } from "@components/landing/navbar";
import { Hero } from "@components/landing/hero";
import { JourneyStage } from "@components/landing/journey-stage";
import { LiveStats } from "@components/landing/live-stats";
import { NotOnServers } from "@components/landing/not-on-servers";
import { AnyDevice } from "@components/landing/any-device";
import { OpenByDesign } from "@components/landing/open-by-design";
import { Pricing } from "@components/landing/pricing";
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
 *   [x] Pricing       → components/landing/pricing.tsx (+ pricing-card.tsx)
 *   [x] Sovereign     → components/landing/sovereign.tsx
 *   [x] AnyDevice     → components/landing/any-device.tsx
 *   [x] OpenByDesign  → components/landing/open-by-design.tsx
 *   [x] Economy       → components/landing/economy.tsx
 *   [x] SignIn        → components/landing/sign-in.tsx
 *   [x] Footer        → components/landing/footer.tsx
 *   [x] Background    → components/ui/page-background.tsx
 *
 * Landing composition complete. Remaining work, tracked elsewhere:
 *
 *   - i18n pass for `not-on-servers.tsx` and `network-viz.tsx`
 *     (the two components that still render hardcoded English).
 *   - Route restructure (`(default)/` for `en`, `[locale]/` for the
 *     rest) — the current build serves `/` only; locales switch
 *     client-side via `I18nProvider`. The URL-level locales and
 *     `generateMetadata` + hreflang follow in that phase.
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
 *   Every section that reads `useI18n()` is necessarily a client
 *   component — the provider runs only on the client (static export
 *   cannot read cookies at request time, so the initial locale comes
 *   from the server as `en` and gets swapped on hydration when a
 *   stored preference exists). That covers `Navbar`, `Pricing`,
 *   `Sovereign`, `AnyDevice`, `OpenByDesign`, `Economy`, `SignIn`,
 *   `Footer`. `Hero` and `JourneyStage` are client for interactivity
 *   independent of i18n. `PricingCard` is client for TanStack Query
 *   and slider state.
 *
 *   `LiveStats` and `NotOnServers` are the only sections still
 *   server-rendered today. `LiveStats` calls `useStats()` which is a
 *   plain function returning an object literal; despite the `use`
 *   prefix, it contains no React hooks. `NotOnServers` will become
 *   client when its i18n pass lands. `PageBackground` is a server
 *   component — pure markup, no interactivity.
 *
 *   The page itself remains a Server Component. The boundary is
 *   per-island.
 */
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
