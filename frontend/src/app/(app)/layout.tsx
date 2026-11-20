import type { ReactNode } from "react";
import type { Metadata } from "next";
import { SpaceShell } from "@components/space/space-shell";

/**
 * Authenticated route group — every route under `(app)/` renders
 * inside `SpaceShell` (sidebar on desktop, dock on mobile/tablet).
 *
 * Providers
 *   `SpaceRefreshProvider`, `UploadDialogProvider`, `<LoginModal />`
 *   and `<UploadDialog />` all live in `providers.tsx` (root). This
 *   layout is now a pure composition: `<SpaceShell>` wraps the route
 *   content. Moving those providers to root was needed because the
 *   upload dialog and login modal must be reachable from any surface
 *   (landing hero in Turn C, `/library` in Fase 11), not just from
 *   inside `(app)/`.
 *
 * Why the shell gate stays here
 *   The `WalletContext.status` check (restoring → blank, disconnected
 *   → redirect to `/`, connected → chrome + page) is content-scoped,
 *   not chrome-scoped: `/space` and future `(app)/*` routes should
 *   redirect when the session drops. The login modal and upload
 *   dialog should NOT — they must remain mountable on the landing
 *   even without a session (that is how a visitor opens login).
 *
 * `robots: { index: false, follow: false }`
 *   `/space` is authenticated. Next.js App Router applies layout
 *   metadata to every route in the group.
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
