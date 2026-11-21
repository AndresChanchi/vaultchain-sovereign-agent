"use client";

/**
 * Space overview — the state shown when the space has ≥1 photo.
 *
 * Layout (matches the mockup's `Space(renombrado).dc.html`)
 *   - Greeting block: "Welcome back." + a caption line.
 *   - Two-column row on desktop: "Kept so far" (5fr) + "Quick actions"
 *     (3fr). Collapses to a single column below `md`.
 *   - Recent uploads (gallery) — full width.
 *
 * Gallery limit — why it is not fixed at 8
 *   A fixed `limit={8}` made the gallery show 8 tiles while the "Photos
 *   kept" counter above said 10. Silent discrepancy that reads as a
 *   bug. The counter is the truth; the grid must agree up to a cap.
 *
 *   The cap is `GALLERY_MAX_ITEMS` (48). Below it, fetch exactly
 *   `photoCount` so the grid and the counter agree. Above it, fetch 48
 *   and leave the remainder for `/library` (Fase 11) — the "View all"
 *   button on the gallery is already prepared for that route.
 *
 *   `Math.max(8, ...)` keeps the original minimum so a user with 1–8
 *   photos sees a grid of the same layout as before (the grid handles
 *   empties gracefully). `Math.min(48, photoCount)` bounds the fetch.
 *
 *   Cost: N+1 parallel RPC reads for N photos (one
 *   getMyGalleryPaginated + one getMyPhoto per hash). At 48 photos
 *   that is 49 reads, ~200-500ms on Sepolia. Acceptable for a
 *   dashboard load; `/library` will move this to paginated reads.
 *
 * Cards not yet rendered
 *   - Expiring soon: the legacy contract has no term concept (every
 *     photo is Forever). Renders only once the new contracts ship
 *     and expose a `getExpiring()` view. Hidden, not stubbed.
 *   - New Moment teaser: Fase 12 (Private AI).
 *   - Activity feed: Fase 11 (needs an event indexer).
 *
 *   All three will slot into the same grid when they ship: the top
 *   row grows from 5fr/3fr to 5fr/4fr/3fr, and the activity card
 *   joins the moment card on the right of the gallery. No re-layout
 *   needed below today's code.
 *
 * Kept so far — no bar chart yet
 *   The mockup shows a two-segment bar (forever vs. term bytes).
 *   Today: (a) no term concept in the legacy contract, (b) no byte
 *   total view — the ABI returns count, not size. The card shows the
 *   count in mono and nothing else. Honest shape: "Photos kept: N".
 *   The bar chart lands with the new contracts (byte + term data).
 *
 * Quick actions — all disabled in 9.B
 *   - Upload: opens the upload dialog in Fase 10.
 *   - Share an album: opens in Fase 12.
 *   - Back up your access: opens in Fase 12.
 *
 *   Disabled state uses the same "coming in a later phase" tooltip
 *   as the sidebar. No lies — the CTAs are visible, honest, and
 *   wired progressively.
 *
 * Greeting
 *   "Welcome back." — a fixed string. The mockup uses a time-based
 *   greeting; computing it in render produces a hydration mismatch
 *   (server in UTC, client in local time). The fixed version reads
 *   warm and does not depend on the clock. Time-based is a future
 *   enhancement if it ever matters.
 */

import { useI18n } from "@context/I18nContext";
import { SpaceGallery } from "./space-gallery";
import { UploadIcon } from "./space-icons";

/**
 * Hard cap on the number of tiles the "Recent uploads" grid fetches.
 *
 * The grid is meant as a "recent" surface — a sample of the vault, not
 * an exhaustive view. Above this cap, the future `/library` route
 * (Fase 11) is the right destination for the full list. Below it, we
 * fetch everything the user has so the dashboard is complete for the
 * typical case.
 *
 * See "Gallery limit — why it is not fixed at 8" in the file header
 * for the trade-offs behind the specific value.
 */
const GALLERY_MAX_ITEMS = 48;

type SpaceOverviewProps = {
  photoCount: number;
};

export function SpaceOverview({ photoCount }: SpaceOverviewProps) {
  const { t } = useI18n();
  const soon = t("space.sidebar.comingSoon");

  // Below the cap: fetch exactly what exists so the grid and the
  // counter stay in agreement. Above the cap: fetch the cap; the rest
  // is `/library`'s job (Fase 11). Floor at 8 so a user with fewer
  // photos still gets the same layout the gallery was designed for.
  const galleryLimit = Math.max(8, Math.min(photoCount, GALLERY_MAX_ITEMS));

  return (
    <div className="flex flex-1 flex-col gap-6 pt-6">
      <div>
        <h1 className="text-[28px] font-bold tracking-[-0.025em] text-ink md:text-[32px]">
          {t("space.overview.greeting")}
        </h1>
        <p className="mt-1.5 text-[14px] text-muted">
          {t("space.overview.subtitle")}
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-[5fr_3fr]">
        {/* Kept so far */}
        <div className="cd p-6">
          <p className="label-mono text-muted">
            {t("space.overview.keptLabel")}
          </p>
          <p className="mt-2 font-mono text-[36px] font-semibold leading-none tracking-[-0.03em] tabular-nums text-ink">
            {photoCount}
          </p>
        </div>

        {/* Quick actions */}
        <div className="cd flex flex-col gap-2 p-4">
          <p className="label-mono px-2 pt-1 pb-2 text-muted">
            {t("space.overview.quickActionsLabel")}
          </p>
          <QuickAction
            label={t("space.overview.quickUpload")}
            hint={soon}
            icon={<UploadIcon size={18} />}
          />
          <QuickAction
            label={t("space.overview.quickShare")}
            hint={soon}
          />
          <QuickAction
            label={t("space.overview.quickBackup")}
            hint={soon}
          />
        </div>
      </div>

      <SpaceGallery limit={galleryLimit} />
    </div>
  );
}

function QuickAction({
  label,
  hint,
  icon,
}: {
  label: string;
  hint: string;
  icon?: React.ReactNode;
}) {
  return (
    <button
      type="button"
      disabled
      aria-disabled="true"
      title={hint}
      className="flex h-10 cursor-not-allowed items-center gap-2.5 rounded-[10px] px-2 text-start text-[14px] text-ink opacity-70"
    >
      {icon && <span className="flex-none text-emerald-text">{icon}</span>}
      <span className="flex-1">{label}</span>
    </button>
  );
}
