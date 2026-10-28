"use client";

import Link from "next/link";
import { KipioMark } from "@components/ui/kipio-mark";
import { LanguagePicker } from "@components/ui/language-picker";
import { ThemeToggle } from "@components/ui/theme-toggle";
import { useI18n } from "@context/I18nContext";

const DOCS_URL =
  "https://github.com/AndresChanchi/vaultchain-sovereign-agent";

/**
 * Landing navbar (mockup `Landing-dark.html` / `Landing-Light.dc.html`).
 *
 * Layout
 *   - Logo (mark + "Kipio" wordmark) on the left.
 *   - "How it works" anchor + Docs link, ghost style, desktop only.
 *   - Right cluster: language picker, theme toggle, "Log in" CTA.
 *
 * Client Component
 *   Converted from Server Component when i18n and theme UI joined the
 *   navbar. Three reasons, in order:
 *
 *     1. `useI18n()` reads the active dictionary and exposes
 *        `t()`. The translated strings ("How it works", "Docs",
 *        "Log in") change on locale switch — that is a client concern.
 *     2. `<LanguagePicker />` and `<ThemeToggle />` are client islands
 *        (both consume context). Rendering them from a server shell is
 *        possible, but the shell itself needs `t()` for the two
 *        anchors, so the boundary would cross this file anyway.
 *     3. The `.glass`/sticky CSS is unchanged; going client does not
 *        affect the visual layout.
 *
 *   The tree below this file that does NOT need interactivity (Hero,
 *   JourneyStage, section components) is unchanged — the boundary is
 *   per-component, not inherited from the layout.
 *
 * Right-cluster order
 *   language | theme | log in.
 *
 *   - Language and theme are configuration (persistent preferences),
 *     Log in is an action. Grouping the two preferences next to each
 *     other reads consistently.
 *   - Theme toggle sits between language and Log in on desktop so the
 *     right edge of the bar stays anchored by the CTA.
 *   - On mobile the three occupy `36px + 40px + ~68px` — under 150px —
 *     comfortably within a 320px viewport next to the logo.
 *
 * "How it works" / "Docs" anchors
 *   Desktop only (`hidden md:flex`), per the mockup. Mobile users
 *   reach those surfaces through the hero's "Or look around first"
 *   link (`#journey`) and through the footer's Docs link. Adding a
 *   mobile sheet would be a Fase 7+ decision, not a default — the
 *   mockup never showed one for this navbar.
 *
 * `aria-disabled` on "Log in"
 *   The `/login` intercepted route does not exist yet (Fase 9). The
 *   button is focusable and perceivable, but clicking does nothing —
 *   `aria-disabled="true"` tells assistive tech exactly that. When the
 *   route lands, drop the attribute and switch to `<Link href="/login">`.
 *
 * Anchor scroll offset
 *   `#journey` resolves to the Journey section. `scroll-margin-top:
 *   5rem` in globals.css clears the sticky navbar (84px tall, 5rem =
 *   80px leaves a small visual gap above the target heading).
 *
 * TODO (Fase 7.5): replace DOCS_URL with "/docs" once the docs route
 *                   exists.
 * TODO (Fase 9):   replace the "Log in" button with an intercepted
 *                   `/login` `<Link>` and drop `aria-disabled`.
 */
export function Navbar() {
  const { t } = useI18n();

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
          <button
            type="button"
            aria-disabled="true"
            className="glass inline-flex h-10 items-center rounded-[14px] px-[18px] text-sm font-medium text-ink transition-colors duration-200 hover:bg-elevated"
          >
            {t("landing.navbar.logIn")}
          </button>
        </div>
      </div>
    </header>
  );
}
