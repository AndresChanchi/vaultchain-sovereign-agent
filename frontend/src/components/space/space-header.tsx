"use client";

/**
 * Space header — chrome above the main content.
 *
 * Two layouts, one component, internal branch:
 *
 *   Desktop (≥ md)
 *     Breadcrumb (left) · search bar · language picker · upload button.
 *     Logo lives in the sidebar — not duplicated here.
 *
 *   Mobile (< md)
 *     Logo (left) · language picker · account avatar.
 *     The avatar is the only sign-out entry point on mobile (the
 *     sidebar is hidden and the dock has no account slot).
 *
 * Search — desktop only
 *   Desktop renders the wide bar the mockup shows (`Search your photos
 *   ⌘K`). Mobile does not: the mockup shows the mobile header without
 *   a search field (search moves to a full-screen sheet when it wires
 *   in 9.C). A header search button on mobile would be a stand-in for
 *   an action that does not exist yet and would compete with the dock
 *   for attention. Honest: no button, no lie.
 *
 * Language picker
 *   Added next to the avatar (mobile) and next to search (desktop).
 *   Absent from the mockup, but the only way to switch language in
 *   `/space` otherwise. Standard position: configuration next to
 *   search.
 *
 * Upload button (desktop only)
 *   Mobile has upload in the dock (central `+`), so the header button
 *   would be a duplicate. Hidden below md.
 *
 * Breadcrumb
 *   Inline mapping: `/space` → Home. Grows when sibling routes ship.
 *   No `labelForPath` helper — a single-route mapping does not need a
 *   function.
 */
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useI18n } from "@context/I18nContext";
import { KipioMark } from "@components/ui/kipio-mark";
import { LanguagePicker } from "@components/ui/language-picker";
import { SpaceAccountAvatar } from "./space-account-avatar";
import { SearchIcon, UploadIcon } from "./space-icons";

export function SpaceHeader() {
  const { t } = useI18n();
  const pathname = usePathname();
  const breadcrumb = pathname === "/space" ? t("space.sidebar.home") : "";
  const soon = t("space.sidebar.comingSoon");

  return (
    <>
      {/* ─── Mobile header (< md) ──────────────────────────────── */}
      <header className="flex items-center justify-between gap-3 md:hidden">
        <Link
          href="/space"
          className="flex items-center gap-2 focus-visible:outline-offset-4"
        >
          <KipioMark />
          <span className="text-[17px] font-bold text-ink">Kipio</span>
        </Link>
        <div className="flex items-center gap-1.5">
          <LanguagePicker />
          <SpaceAccountAvatar />
        </div>
      </header>

      {/* ─── Desktop header (≥ md) ─────────────────────────────── */}
      <header className="hidden h-11 items-center justify-between gap-4 md:flex">
        <span className="text-sm text-muted">{breadcrumb}</span>
        <div className="flex items-center gap-2.5">
          <div
            role="search"
            aria-disabled="true"
            title={soon}
            className="glass flex h-10 w-[240px] items-center gap-2.5 rounded-[12px] px-3.5 text-sm text-muted lg:w-[260px]"
          >
            <SearchIcon size={16} />
            <span className="flex-1 truncate">
              {t("space.header.searchPlaceholder")}
            </span>
            <kbd className="font-mono text-[11px]">
              {t("space.header.searchShortcut")}
            </kbd>
          </div>
          <LanguagePicker />
          <button
            type="button"
            disabled
            aria-disabled="true"
            title={soon}
            className="flex h-10 cursor-not-allowed items-center gap-2 rounded-[14px] bg-emerald px-4 text-sm font-semibold text-on-emerald opacity-60"
          >
            <UploadIcon size={16} />
            {t("space.upload.button")}
          </button>
        </div>
      </header>
    </>
  );
}
