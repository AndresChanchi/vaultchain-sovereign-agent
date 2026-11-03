import type { ReactNode } from "react";
import type { Metadata } from "next";
import { SpaceShell } from "@components/space/space-shell";

/**
 * Authenticated route group — everything under `(app)/` renders inside
 * the `SpaceShell` chrome (sidebar on desktop, dock on mobile).
 *
 * The `(app)` group does not add a URL segment. `(app)/space/page.tsx`
 * serves `/space`, and future routes (`(app)/library/`, `(app)/moments/`,
 * …) inherit the shell for free.
 *
 * Gate
 *   The shell gates on `WalletContext.status`. `"restoring"` → blank
 *   amb-bg while the session resumes from `sessionStorage`.
 *   `"disconnected"` → `router.replace("/")`. `"connected"` → chrome
 *   + page.
 *
 * `robots: { index: false, follow: false }`
 *   `/space` is an authenticated surface. Crawlers see the shell's
 *   "restoring" state (SSR) and never the real content, so indexing
 *   it produces a useless entry. Next.js App Router applies layout
 *   metadata to every route in the group — one field covers `/space`
 *   and every future `(app)/*` route. Complementary to `robots.ts`
 *   disallow (defense in depth: even if a crawler ignores the
 *   disallow, it honours `<meta name="robots">`).
 *
 * Server component
 *   Thin wrapper — no data, no effects. `<SpaceShell>` handles the
 *   client-side gate.
 */
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default function AppGroupLayout({
  children,
}: {
  children: ReactNode;
}) {
  return <SpaceShell>{children}</SpaceShell>;
}
