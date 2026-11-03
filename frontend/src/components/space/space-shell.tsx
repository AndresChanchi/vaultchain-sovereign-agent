"use client";

/**
 * Space shell — gate + chrome for every authenticated route.
 *
 * Gate on `WalletContext.status`:
 *   - `"restoring"` — blank amb-bg while the session resumes.
 *   - `"disconnected"` — null for one frame while a `useEffect`
 *     navigates to `/`.
 *   - `"connected"` — chrome + page.
 *
 * Chrome layout
 *   - Desktop (≥ lg / 1024px): sidebar + main column.
 *   - Mobile + tablet (< lg): main column full-width + dock.
 *
 * Horizontal overflow — `overflow-x-clip` on the outer shell
 *   The welcome hero carries an ambient glow (1200×900, `left: 50%;
 *   marginLeft: -600px`) that bleeds past the hero column by design.
 *   Without a clip somewhere upstream, the glow escapes into the
 *   scroll container and produces horizontal scroll.
 *
 *   Earlier the clip was on `<main>` — the wrong boundary. `<main>`
 *   is inset from the shell edges by the shell's `p-4`/`p-6` padding
 *   and the sidebar's `m-3` margin, so clipping at main's boundary
 *   cut the glow with a **visible vertical edge** where main's
 *   padding area begins. That produced the "green rectangle" the
 *   user noticed: the glow is visible inside main but not in the
 *   shell padding around it, and the boundary between the two is
 *   an abrupt cut.
 *
 *   Moving the clip to the outer shell div — the div whose bounds
 *   are the viewport — puts the cut at the viewport edges, where it
 *   is invisible. The glow bleeds into the shell padding freely,
 *   matching the mockup's `.kv.kd { overflow: hidden }` treatment
 *   (its clip is also at the viewport wrapper, not at a mid-page
 *   column).
 *
 * `main` as a flex column
 *   `flex flex-col` on `main` lets the page use `flex-1` to fill
 *   available height. `SpaceWelcome` relies on this to pin its
 *   starters to the bottom when content is short.
 *
 * Content width cap
 *   `main` carries `max-w-[1440px] mx-auto`. At 1440p+ the content
 *   stays centered at 1440 — the sidebar does not read as
 *   proportionally tiny next to a 3000px column.
 */
import { useEffect, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@context/WalletContext";
import { SpaceSidebar } from "./space-sidebar";
import { SpaceDock } from "./space-dock";
import { SpaceHeader } from "./space-header";

export function SpaceShell({ children }: { children: ReactNode }) {
  const { status } = useWallet();
  const router = useRouter();

  useEffect(() => {
    if (status === "disconnected") {
      router.replace("/");
    }
  }, [status, router]);

  if (status === "restoring") {
    return <div className="amb-bg min-h-dvh" aria-busy="true" />;
  }

  if (status === "disconnected") {
    return null;
  }

  return (
    <div className="amb-bg flex min-h-dvh overflow-x-clip">
      <SpaceSidebar />
      <div className="flex min-w-0 flex-1 flex-col gap-5 p-4 pb-24 lg:p-6 lg:pb-6">
        <SpaceHeader />
        <main className="mx-auto flex w-full min-w-0 max-w-[1440px] flex-1 flex-col">
          {children}
        </main>
      </div>
      <SpaceDock />
    </div>
  );
}
