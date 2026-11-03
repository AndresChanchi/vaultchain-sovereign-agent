"use client";

/**
 * Space sidebar — desktop navigation (≥ lg / 1024px).
 *
 * Not rendered in tablet (768-1023px) or mobile. The dock
 * (`space-dock.tsx`) is the navigation on those breakpoints: with
 * the sidebar visible at 768-1023, the content column dropped to
 * ~500px and felt cramped; forcing it collapsed in tablet made the
 * toggle undiscoverable. Two clean breakpoints (sidebar on desktop,
 * dock everywhere else) beat three messy ones.
 *
 * States (desktop only):
 *   - Expanded (default): 248px. Logo + wordmark + collapse chevron
 *     at the top. Full labels on nav items. Account card at the
 *     bottom.
 *   - Collapsed: 68px. Chevron-only header (click expands). Icons
 *     only in nav, `title` on each carries the label. Compact
 *     account avatar at the bottom, menu opens upward.
 *
 *   The toggle state persists in `localStorage["kipio:space:sidebar-expanded"]`
 *   — a user preference, reset only by the user. SSR-safe: `expanded`
 *   starts `true`, the `useEffect` reads storage on mount and applies
 *   the stored value. One tick of expanded for returning-collapsed
 *   users, no hydration mismatch.
 *
 * Collapsed header — why no logo
 *   68px - 24px (p-3 = 12px each side) = 44px of internal width. The
 *   KipioMark is 34px, the chevron 28px; they do not fit side by
 *   side. Showing just the chevron keeps the header a single
 *   predictable element, and the toggle target is the whole header
 *   row (56px tall) — easy to hit. The logo comes back on expand.
 *
 * Nav items
 *   Home is active (`aria-current="page"`). Library, Moments, Shared,
 *   Offers, Settings are disabled until their routes ship. `title`
 *   carries the label in collapsed state; the honest "coming in a
 *   later phase" tooltip in expanded state (the label is already
 *   visible).
 */
import { useEffect, useState } from "react";
import Link from "next/link";
import { useI18n } from "@context/I18nContext";
import { KipioMark } from "@components/ui/kipio-mark";
import { SpaceAccountCard } from "./space-account-card";
import { SpaceAccountAvatar } from "./space-account-avatar";
import {
  ChevronIcon,
  HomeIcon,
  LibraryIcon,
  MomentsIcon,
  SharedIcon,
  OffersIcon,
  SettingsIcon,
} from "./space-icons";

const STORAGE_KEY = "kipio:space:sidebar-expanded";

type NavKey = "home" | "library" | "moments" | "shared" | "offers" | "settings";

type NavItem =
  | { key: NavKey; enabled: true; href: "/space" }
  | { key: NavKey; enabled: false; href: null };

const NAV_ITEMS: readonly NavItem[] = [
  { key: "home", enabled: true, href: "/space" },
  { key: "library", enabled: false, href: null },
  { key: "moments", enabled: false, href: null },
  { key: "shared", enabled: false, href: null },
  { key: "offers", enabled: false, href: null },
  { key: "settings", enabled: false, href: null },
];

function renderIcon(key: NavKey) {
  switch (key) {
    case "home":
      return <HomeIcon />;
    case "library":
      return <LibraryIcon />;
    case "moments":
      return <MomentsIcon />;
    case "shared":
      return <SharedIcon />;
    case "offers":
      return <OffersIcon />;
    case "settings":
      return <SettingsIcon />;
  }
}

export function SpaceSidebar() {
  const { t } = useI18n();
  const [expanded, setExpanded] = useState(true);

  useEffect(() => {
    try {
      const stored = window.localStorage.getItem(STORAGE_KEY);
      if (stored === "false") setExpanded(false);
    } catch {
      /* private mode / disabled storage — keep default expanded */
    }
  }, []);

  const toggleExpanded = () => {
    setExpanded((v) => {
      const next = !v;
      try {
        window.localStorage.setItem(STORAGE_KEY, String(next));
      } catch {
        /* ignore */
      }
      return next;
    });
  };

  return (
    <aside
      aria-label={t("space.sidebar.navLabel")}
      className={
        "glass sticky top-3 m-3 hidden min-h-[calc(100dvh-1.5rem)] flex-none flex-col gap-1 self-start rounded-[22px] p-3 transition-[width] duration-300 ease-[cubic-bezier(0.2,0.8,0.2,1)] lg:flex " +
        (expanded ? "w-[248px]" : "w-[68px]")
      }
    >
      {/* Header row */}
      {expanded ? (
        <div className="mb-2 flex items-center justify-between gap-2 px-1.5 py-1">
          <Link
            href="/space"
            className="flex min-w-0 items-center gap-2.5 rounded-[10px] focus-visible:outline-offset-4"
          >
            <KipioMark />
            <span className="truncate text-[17px] font-bold text-ink">
              Kipio
            </span>
          </Link>
          <button
            type="button"
            onClick={toggleExpanded}
            aria-label={t("space.sidebar.collapse")}
            aria-expanded={true}
            className="grid h-7 w-7 flex-none place-items-center rounded-[8px] text-muted transition-colors duration-200 hover:bg-elevated hover:text-ink"
          >
            <ChevronIcon direction="left" />
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={toggleExpanded}
          aria-label={t("space.sidebar.expand")}
          aria-expanded={false}
          className="mx-auto mb-2 grid h-10 w-10 place-items-center rounded-[8px] text-muted transition-colors duration-200 hover:bg-elevated hover:text-ink"
        >
          <ChevronIcon direction="right" />
        </button>
      )}

      {/* Nav */}
      <nav className="flex flex-col gap-0.5">
        {NAV_ITEMS.map((item) => {
          const label = t(`space.sidebar.${item.key}`);
          if (item.enabled) {
            return (
              <Link
                key={item.key}
                href={item.href}
                aria-current="page"
                title={!expanded ? label : undefined}
                className={
                  "flex h-[42px] items-center gap-3 rounded-[12px] bg-elevated text-sm font-medium text-ink shadow-[inset_0_0_0_1px_var(--color-hairline)] " +
                  (expanded ? "px-3" : "justify-center")
                }
              >
                <span className="flex-none text-emerald-text">
                  {renderIcon(item.key)}
                </span>
                {expanded && <span className="truncate">{label}</span>}
              </Link>
            );
          }
          return (
            <button
              key={item.key}
              type="button"
              disabled
              aria-disabled="true"
              title={
                !expanded ? label : t("space.sidebar.comingSoon")
              }
              className={
                "flex h-[42px] cursor-not-allowed items-center gap-3 rounded-[12px] text-sm text-muted " +
                (expanded ? "px-3" : "justify-center")
              }
            >
              <span className="flex-none">{renderIcon(item.key)}</span>
              {expanded && <span className="truncate">{label}</span>}
            </button>
          );
        })}
      </nav>

      <div className="flex-1" />

      {/* Account — full card when expanded, compact avatar when
          collapsed. The collapsed avatar's menu opens upward since
          it sits at the bottom of the sidebar. */}
      {expanded ? (
        <SpaceAccountCard />
      ) : (
        <div className="flex justify-center">
          <SpaceAccountAvatar menuDirection="up" />
        </div>
      )}
    </aside>
  );
}
