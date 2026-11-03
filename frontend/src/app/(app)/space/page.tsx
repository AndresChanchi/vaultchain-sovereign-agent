"use client";

/**
 * `/space` — Home for the authenticated surface.
 *
 * 9.A: renders `<SpaceWelcome />` unconditionally. The gate on real
 * stats (0 photos → Welcome, ≥1 → Overview) lands in 9.C when
 * `useSpaceStats` ships.
 *
 * The shell (`app/(app)/layout.tsx`) already gates on
 * `WalletContext.status`. This page assumes an authenticated session.
 *
 * Renamed from `app/space/page.tsx` (legacy dashboard). The legacy
 * page file has been deleted; git preserves the original if it is
 * ever needed for reference.
 */
import { SpaceWelcome } from "@components/space/space-welcome";

export default function SpacePage() {
  return <SpaceWelcome />;
}
