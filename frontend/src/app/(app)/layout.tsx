import type { ReactNode } from "react";
import type { Metadata } from "next";
import { SpaceShell } from "@components/space/space-shell";
import { SpaceRefreshProvider } from "@context/SpaceRefreshContext";
import { UploadDialogProvider } from "@context/UploadDialogContext";
import { UploadDialog } from "@components/space/upload/upload-dialog";

/**
 * Authenticated route group — every route under `(app)/` renders
 * inside `SpaceShell` (sidebar on desktop, dock on mobile/tablet).
 *
 * Provider order
 *   `<SpaceRefreshProvider>` → `<UploadDialogProvider>` →
 *   `<SpaceShell>` + `<UploadDialog>`
 *
 *   - SpaceRefresh first: reactive reads (`useSpaceStats`,
 *     `useSpaceGallery`) watch `version` and refetch on `bump()`.
 *   - UploadDialogProvider second: open/close state for the upload
 *     modal. Independent of refresh — the two do not talk to each
 *     other (registerUpload already calls bump() internally; the
 *     dialog does not trigger refetches itself).
 *
 * `<UploadDialog>` sits OUTSIDE `<SpaceShell>` — it is a modal
 * overlay, not content inside `<main>`. The dialog is portaled to the
 * top layer by `<dialog>.showModal()`, so layout position does not
 * affect rendering, but keeping it out of the shell makes the intent
 * clear: it is a chrome-level overlay, not page content.
 *
 * `robots: { index: false, follow: false }`
 *   `/space` is authenticated. Crawlers see the shell's "restoring"
 *   state (SSR) and never the real content. Next.js App Router
 *   applies layout metadata to every route in the group.
 */
export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default function AppGroupLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <SpaceRefreshProvider>
      <UploadDialogProvider>
        <SpaceShell>{children}</SpaceShell>
        <UploadDialog />
      </UploadDialogProvider>
    </SpaceRefreshProvider>
  );
}
