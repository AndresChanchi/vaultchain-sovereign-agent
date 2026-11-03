"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { KipioMark } from "@components/ui/kipio-mark";
import { LanguagePicker } from "@components/ui/language-picker";
import { ThemeToggle } from "@components/ui/theme-toggle";
import { useI18n } from "@context/I18nContext";
import { useLoginModal } from "@context/LoginModalContext";
import { useWallet } from "@context/WalletContext";

const DOCS_URL =
  "https://github.com/AndresChanchi/vaultchain-sovereign-agent";

/**
 * Landing navbar.
 *
 * Layout
 *   - Logo (mark + "Kipio" wordmark) on the left.
 *   - "How it works" anchor + Docs link, ghost style, desktop only.
 *   - Right cluster: language picker, theme toggle, auth slot.
 *
 * Auth slot — three states
 *   - Signed out (or still restoring): "Log in" button. Clicking
 *     calls `openLogin()` from `LoginModalContext`. The modal is
 *     mounted at the root layout. During `restoring` the button is
 *     disabled to prevent a race where the user clicks just before
 *     the state resolves.
 *
 *   - Signed in: a compact chip that opens a small menu. The menu
 *     has two actions:
 *       * "Open your space" — `<Link href="/space">`.
 *       * "Sign out" — `WalletContext.disconnect()` then
 *         `router.replace("/")`.
 *
 *     Why a menu instead of a plain `<Link>`
 *       The user must be able to end their session from anywhere on
 *       the site, not just from `/space`. The legacy `/space`
 *       dashboard uses `wagmi` — its own `DisconnectButton` clears
 *       wagmi's session but leaves `WalletContext` untouched, and
 *       the navbar chip stays visible. Until `/space` is rewritten
 *       against `WalletContext` (Fase 9), the only reliable
 *       sign-out is the one this menu implements.
 *
 *     Why `router.replace("/")` (not `push`)
 *       Push would leave `/space` in the history stack. After sign-
 *       out, pressing back would return to `/space` without a
 *       session — an unauthenticated page. `replace` collapses the
 *       history so back goes to whatever was before `/space`.
 *
 *     Why `disconnect()` before `router.replace`
 *       `disconnect()` clears the session state (React) and
 *       `sessionStorage` (synchronous). By the time the landing
 *       re-renders, `session` is null and the chip is gone. If we
 *       navigated first, the target route would briefly render the
 *       stale session.
 *
 * TypeScript narrowing — why the check is inline
 *   The auth-slot condition is written as
 *   `session !== null && status === "connected"` **inside the
 *   ternary**, not extracted to a `const signedIn = ...` boolean.
 *   Extracting it breaks TypeScript's control-flow narrowing:
 *   `if (signedIn)` does NOT narrow `session` from `Session | null`
 *   to `Session`, because narrowing only works on direct variable
 *   checks, not on derived booleans. Inside the true branch,
 *   `session.address` would be "Object is possibly 'null'". Keeping
 *   the check inline preserves the narrowing. Same pattern as the
 *   original file — the fix here is restoring the inline form.
 *
 * Menu a11y
 *   `role="menu"` on the popover, `role="menuitem"` on each item.
 *   Escape closes. Click outside closes. Focus returns to the chip
 *   button on Escape. These behaviours are implemented with native
 *   listeners in a `useEffect` — no library.
 *
 *   `aria-haspopup="menu"` and `aria-expanded` on the trigger give
 *   screen readers the "this button opens a menu" signal. The
 *   menu does not implement arrow-key navigation — Tab traverses
 *   the two items, which is acceptable for a two-item account menu.
 *   Arrow keys are an ARIA menu-pattern enhancement, not a
 *   Baseline requirement, and add ~50 lines of focus-index
 *   bookkeeping for no user-visible benefit at this size.
 *
 *   The trigger is a `<button>`, not a `<Link>`. The chip is a
 *   menu trigger; the "Open your space" item inside is the actual
 *   navigation.
 *
 * Address display
 *   Truncated to `0xXXXX…YYYY` (6 + 4 chars). The full address is
 *   in the `title` attribute for hover / long-press. Full-width
 *   mono in the trigger would be too wide on the right cluster.
 *
 * `returnTo` — what happens on re-open
 *   If the user signs out and clicks "Log in" again, `openLogin()`
 *   is called without `returnTo` (the navbar does not pass one).
 *   The stale `returnTo` from a prior open was consumed by
 *   `consumeLoginReturnTo()` after the previous sign-in, so the
 *   next sign-in lands on `/space` by default. Correct.
 *
 * Anchor scroll offset
 *   `#journey` resolves to the Journey section. `scroll-margin-top:
 *   5rem` in globals.css clears the sticky navbar (84px tall).
 *
 * TODO (Fase 7.5): replace DOCS_URL with "/docs" once the docs route
 *                   exists.
 * TODO (Fase 9):   `/space` is rewritten against `WalletContext`,
 *                   retiring wagmi and its own `DisconnectButton`.
 *                   This menu stays — sign-out from anywhere is a
 *                   feature, not a workaround.
 */
export function Navbar() {
  const { t } = useI18n();
  const { openLogin } = useLoginModal();
  const { status, session, disconnect } = useWallet();
  const router = useRouter();

  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);

  // Close the menu on click-outside and Escape. The "sign out" and
  // "navigate away" paths close the menu explicitly — this effect
  // only covers the passive cases.
  useEffect(() => {
    if (!menuOpen) return;
    const handleClickOutside = (event: MouseEvent) => {
      if (
        menuRef.current &&
        !menuRef.current.contains(event.target as Node)
      ) {
        setMenuOpen(false);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMenuOpen(false);
        triggerRef.current?.focus();
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [menuOpen]);

  const handleSignOut = () => {
    setMenuOpen(false);
    disconnect();
    router.replace("/");
  };

  return (
    <header className="sticky top-0 z-20 border-b border-hairline bg-bg/80 backdrop-blur-sm">
      <div className="mx-auto flex h-[84px] max-w-[1280px] items-center justify-between px-6 md:px-10">
        <Link
          href="/"
          className="flex items-center gap-3 rounded-[10px] focus-visible:outline-offset-4"
          aria-label="Kipio — home"
        >
          <KipioMark />
          <span className="text-[18px] font-bold tracking-tight text-ink">
            Kipio
          </span>
        </Link>

        <nav className="hidden items-center md:flex" aria-label="Primary">
          <a
            href="#journey"
            className="px-3.5 py-2 text-sm text-muted transition-colors duration-200 hover:text-ink"
          >
            {t("landing.navbar.howItWorks")}
          </a>
          <a
            href={DOCS_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="px-3.5 py-2 text-sm text-muted transition-colors duration-200 hover:text-ink"
          >
            {t("landing.navbar.docs")}
          </a>
        </nav>

        <div className="flex items-center gap-1.5">
          <LanguagePicker />
          <ThemeToggle />
          {/* See "TypeScript narrowing — why the check is inline" in
              the file header. Do not extract to `const signedIn`. */}
          {session !== null && status === "connected" ? (
            <div ref={menuRef} className="relative">
              <button
                ref={triggerRef}
                type="button"
                onClick={() => setMenuOpen((open) => !open)}
                aria-haspopup="menu"
                aria-expanded={menuOpen}
                title={session.address}
                className="glass inline-flex h-10 items-center rounded-[14px] px-[18px] font-mono text-sm text-ink transition-colors duration-200 hover:bg-elevated"
              >
                {`${session.address.slice(0, 6)}…${session.address.slice(-4)}`}
              </button>
              {menuOpen && (
                <div
                  role="menu"
                  aria-label="Account"
                  className="glass absolute end-0 top-[calc(100%+6px)] z-30 min-w-[200px] rounded-[14px] p-1"
                >
                  <Link
                    href="/space"
                    role="menuitem"
                    onClick={() => setMenuOpen(false)}
                    className="flex h-9 items-center rounded-[10px] px-3 text-sm text-ink transition-colors hover:bg-elevated"
                  >
                    {t("landing.navbar.openSpace")}
                  </Link>
                  <button
                    type="button"
                    role="menuitem"
                    onClick={handleSignOut}
                    className="flex h-9 w-full items-center rounded-[10px] px-3 text-start text-sm text-muted transition-colors hover:bg-elevated hover:text-ink"
                  >
                    {t("landing.navbar.signOut")}
                  </button>
                </div>
              )}
            </div>
          ) : (
            <button
              type="button"
              onClick={() => openLogin()}
              disabled={status === "restoring"}
              className="glass inline-flex h-10 items-center rounded-[14px] px-[18px] text-sm font-medium text-ink transition-colors duration-200 hover:bg-elevated disabled:cursor-wait disabled:opacity-60"
            >
              {t("landing.navbar.logIn")}
            </button>
          )}
        </div>
      </div>
    </header>
  );
}
