"use client";

/**
 * Account avatar — compact identity trigger + sign-out menu.
 *
 * Two consumers:
 *   - `< md` mobile header — `menuDirection="down"`. Menu drops below
 *     the avatar, right-aligned. Header sits at the top of the
 *     viewport; the dropdown has plenty of room.
 *
 *   - Collapsed sidebar (`lg+`) — `menuDirection="up"`. Menu floats
 *     above the avatar, left-aligned, extending to the right into
 *     the main column (tooltip-style overlay). Matches the "attached
 *     to its trigger" feel the user asked for.
 *
 * Menu positioning — `bottom-full` / `top-full`, not `calc()`
 *   `bottom: calc(100% + 6px)` is the intent, but Tailwind v4 emits
 *   arbitrary values as `calc(100%+6px)` (no spaces around `+`),
 *   which strict parsers reject. When rejected, the property is
 *   ignored and the menu falls back to its **static flow position**
 *   — wrong place, sometimes off-screen.
 *
 *   `bottom-full` (= `bottom: 100%`) + `mb-N` (= margin-bottom) is
 *   the valid-CSS equivalent. `top-full` + `mt-N` for the downward
 *   variant. No calc, no parser edge cases.
 *
 * Shared logic
 *   `useDismissable` (click-outside + Escape) and `identityLabel`
 *   (brand mapping) are imported from the same modules as the full
 *   card, so the two identity surfaces never drift apart.
 *
 * A11y
 *   `aria-haspopup`, `aria-expanded`, `role="menu"`, `role="menuitem"`,
 *   Escape closes, click-outside closes. `title` carries the full
 *   address for hover/long-press.
 */
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useI18n } from "@context/I18nContext";
import { useWallet } from "@context/WalletContext";
import { useDismissable } from "@hooks/ui/use-dismissable";
import { identityLabel } from "./space-account-identity";

type SpaceAccountAvatarProps = {
  menuDirection?: "up" | "down";
};

export function SpaceAccountAvatar({
  menuDirection = "down",
}: SpaceAccountAvatarProps = {}) {
  const { t } = useI18n();
  const { session, disconnect } = useWallet();
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useDismissable(menuOpen, () => setMenuOpen(false));

  if (!session) return null;

  const label = identityLabel(session, t);
  const initial = label.charAt(0).toUpperCase();

  const handleSignOut = () => {
    setMenuOpen(false);
    disconnect();
    router.replace("/");
  };

  const menuPosition =
    menuDirection === "up"
      ? "bottom-full mb-2 start-0"
      : "top-full mt-1.5 end-0";

  return (
    <div ref={menuRef} className="relative">
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setMenuOpen((open) => !open)}
        aria-haspopup="menu"
        aria-expanded={menuOpen}
        aria-label={label}
        title={session.address}
        className="grid h-9 w-9 place-items-center rounded-full bg-gradient-to-br from-emerald to-violet text-[13px] font-semibold text-white"
      >
        {initial}
      </button>

      {menuOpen && (
        <div
          role="menu"
          aria-label={t("space.account.menuLabel")}
          className={
            "glass absolute z-30 min-w-[160px] rounded-[14px] p-1 " +
            menuPosition
          }
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
