"use client";

/**
 * Space dock — mobile + tablet navigation (< lg / 1024px).
 *
 * Five slots per the mockup: Home, Library, [Upload], Moments,
 * Settings. Shared and Offers are reachable via the sidebar on
 * desktop; on mobile and tablet they are deferred until Fase 12
 * adds a "More" surface.
 *
 * Central upload
 *   Larger, offset upward (negative margin), emerald surface — the
 *   visual anchor of the dock. Opens the upload dialog via
 *   `useUploadDialog().open`. Same handler as the header's Upload
 *   button; both routes reach the same single `<UploadDialog>`
 *   instance mounted by `(app)/layout.tsx`. OAuth sessions see the
 *   dialog's gate rather than a disabled button — the click always
 *   does something, the gate explains why if it cannot proceed.
 *
 * Breakpoint
 *   Appears on both mobile and tablet — the sidebar only renders
 *   from `lg` up (see `space-sidebar.tsx` for the breakpoint
 *   rationale). On tablet the dock sits at the bottom with plenty of
 *   horizontal space; it does not feel cramped.
 *
 * `env(safe-area-inset-bottom)`
 *   Preserves the home-indicator space on iOS. Applied to `nav` so
 *   the glass background extends into the safe area while the icon
 *   row stays above it.
 */
import Link from "next/link";
import { useI18n } from "@context/I18nContext";
import { useUploadDialog } from "@context/UploadDialogContext";
import {
  HomeIcon,
  LibraryIcon,
  MomentsIcon,
  SettingsIcon,
  PlusIcon,
} from "./space-icons";

export function SpaceDock() {
  const { t } = useI18n();
  const { open: openUpload } = useUploadDialog();

  return (
    <nav
      aria-label={t("space.dock.navLabel")}
      className="glass fixed inset-x-3 bottom-3 z-20 flex h-16 items-center justify-around rounded-[22px] px-2.5 lg:hidden"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <DockLink href="/space" label={t("space.sidebar.home")} active>
        <HomeIcon size={22} />
      </DockLink>
      <DockDisabled
        label={t("space.sidebar.library")}
        title={t("space.sidebar.comingSoon")}
      >
        <LibraryIcon size={22} />
      </DockDisabled>
      <button
        type="button"
        onClick={openUpload}
        aria-label={t("space.dock.upload")}
        className="-mt-4 grid h-12 w-12 flex-none place-items-center rounded-[16px] bg-emerald text-on-emerald shadow-[0_10px_24px_-6px_oklch(0.70_0.15_160_/_0.6)] transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.05]"
      >
        <PlusIcon size={24} />
      </button>
      <DockDisabled
        label={t("space.sidebar.moments")}
        title={t("space.sidebar.comingSoon")}
      >
        <MomentsIcon size={22} />
      </DockDisabled>
      <DockDisabled
        label={t("space.sidebar.settings")}
        title={t("space.sidebar.comingSoon")}
      >
        <SettingsIcon size={22} />
      </DockDisabled>
    </nav>
  );
}

function DockLink({
  href,
  label,
  active,
  children,
}: {
  href: string;
  label: string;
  active?: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-label={label}
      aria-current={active ? "page" : undefined}
      className={
        "grid h-11 w-11 place-items-center rounded-[14px] transition-colors " +
        (active ? "text-emerald-text" : "text-muted")
      }
    >
      {children}
    </Link>
  );
}

function DockDisabled({
  label,
  title,
  children,
}: {
  label: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      disabled
      aria-disabled="true"
      aria-label={label}
      title={title}
      className="grid h-11 w-11 cursor-not-allowed place-items-center rounded-[14px] text-muted/60"
    >
      {children}
    </button>
  );
}
