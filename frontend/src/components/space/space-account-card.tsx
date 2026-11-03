"use client";

/**
 * Account card — sidebar identity display + sign-out menu (desktop).
 *
 * Trigger
 *   The whole card is the button. Avatar + brand label + truncated
 *   address. Menu opens **upward** (the card sits at the bottom of
 *   the sidebar, so downward would go off-screen).
 *
 * Menu positioning — `bottom-full mb-1.5`, not `bottom-[calc(100%+6px)]`
 *   `bottom: calc(100% + 6px)` is the intent, but Tailwind v4 emits
 *   the arbitrary value with no spaces around the `+`
 *   (`calc(100%+6px)`), which is invalid CSS per spec and rejected
 *   by strict browsers. When the property is rejected, the menu
 *   falls back to its **static flow position** — below the button,
 *   not above. That was the "sign-out goes below the fold" bug.
 *
 *   `bottom-full` (= `bottom: 100%`) + `mb-1.5` (= `margin-bottom: 6px`)
 *   is the valid-CSS equivalent: menu's bottom edge at parent's top,
 *   plus a 6px gap. No calc(), no parser edge cases.
 *
 * Sign-out hidden inside the menu
 *   Intentional: keeping the exit out of the primary path discourages
 *   accidental logouts, which cost gas on the current contract (each
 *   session revalidates identity on-chain). A user who wants to sign
 *   out can find it — the card is discoverable — but is not prompted
 *   to.
 *
 * A11y
 *   `aria-haspopup`, `aria-expanded`, `role="menu"`, `role="menuitem"`,
 *   Escape closes, click-outside closes. Focus returns to the trigger
 *   on Escape. No arrow-key navigation — Tab covers the single item.
 *
 * Shared logic
 *   `useDismissable` (click-outside + Escape) and `identityLabel`
 *   (brand mapping) are imported from their modules so this card and
 *   `space-account-avatar.tsx` stay in lockstep.
 */
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useI18n } from "@context/I18nContext";
import { useWallet } from "@context/WalletContext";
import { useDismissable } from "@hooks/ui/use-dismissable";
import { identityLabel } from "./space-account-identity";

export function SpaceAccountCard() {
  const { t } = useI18n();
  const { session, disconnect } = useWallet();
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useDismissable(menuOpen, () => setMenuOpen(false));

  if (!session) return null;

  const label = identityLabel(session, t);
  const address = `${session.address.slice(0, 6)}…${session.address.slice(-4)}`;
  const initial = label.charAt(0).toUpperCase();

  const handleSignOut = () => {
    setMenuOpen(false);
    disconnect();
    router.replace("/");
  };

  return (
    <div ref={menuRef} className="relative mt-2">
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setMenuOpen((open) => !open)}
        aria-haspopup="menu"
        aria-expanded={menuOpen}
        title={session.address}
        className="flex w-full items-center gap-2.5 rounded-[14px] bg-elevated px-2 py-2.5 text-start transition-colors duration-200 hover:bg-elevated/70"
      >
        <span
          aria-hidden="true"
          className="grid h-8 w-8 flex-none place-items-center rounded-full bg-gradient-to-br from-emerald to-violet text-[13px] font-semibold text-white"
        >
          {initial}
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-[13px] font-medium text-ink">
            {label}
          </span>
          <span className="mt-0.5 block truncate font-mono text-[10px] text-muted">
            {address}
          </span>
        </span>
      </button>

      {menuOpen && (
        <div
          role="menu"
          aria-label={t("space.account.menuLabel")}
          className="glass absolute start-0 end-0 bottom-full mb-1.5 z-30 rounded-[14px] p-1"
        >
          <button
            type="button"
            role="menuitem"
            onClick={handleSignOut}
            className="flex h-9 w-full items-center rounded-[10px] px-3 text-start text-sm text-muted transition-colors hover:bg-elevated hover:text-ink"
          >
            {t("space.sidebar.signOut")}
          </button>
        </div>
      )}
    </div>
  );
}
