import Link from "next/link";
import { KipioMark } from "@components/ui/kipio-mark";

const DOCS_URL =
  "https://github.com/AndresChanchi/vaultchain-sovereign-agent";

/**
 * Landing navbar (mockup `Landing-dark.html` / `Landing-Light.dc.html`).
 *
 * Desktop
 *   - logo (square mark + "Kipio" wordmark) left
 *   - "How it works" anchor + Docs link, ghost style
 *   - EN chip (globe + label) + "Log in" chip right
 *
 * Mobile (< md)
 *   - logo left
 *   - EN chip collapses to globe-only
 *   - "Log in" stays visible
 *   - "How it works" and "Docs" are intentionally omitted, per the
 *     mockup. Both are reachable without a menu:
 *       - "How it works" via the hero's "Or look around first" link
 *         (`#journey`);
 *       - "Docs" via the footer.
 *     If a mobile menu is later desired (e.g. when the language picker
 *     and theme toggle arrive in Phase 7), it can be layered on
 *     without touching this chrome.
 *
 * Server Component
 *   No state, no effects, no refs, no event handlers. RSC-first: the
 *   only interactivity this component will ever need is the language
 *   popover (Phase 7) and the `/login` link (Phase 9); when either
 *   lands, the corresponding sub-tree becomes a client island — this
 *   file stays a Server Component.
 *
 * Visual notes
 *   - Height `84px` matches the mockup, not the previous `h-16`
 *     (64px). The extra 20px is where the mockup gets its breathing
 *     room above the hero.
 *   - `glass` on the EN and Log in buttons: the mockup styles them
 *     with `.bs` (glass + 14px radius), distinct from the page-wide
 *     ambient background. The header itself is deliberately NOT glass
 *     — it stays `bg-bg/80 backdrop-blur-sm`. Glass is reserved for
 *     chips, popovers, sheets, dock, and the sidebar per DESIGN §4.4.
 *   - `aria-disabled` on both buttons: they are perceivable and
 *     focusable, but do not act yet. When Phase 7/9 wire them up,
 *     drop the attribute.
 *
 * Anchors
 *   `#journey` resolves to the Journey section in `(public)/page.tsx`.
 *   `scroll-margin-top: 5rem` in globals.css clears the sticky navbar
 *   (64px previously, 84px now — 5rem = 80px still leaves a small
 *   gap; fine).
 *
 * TODO: replace DOCS_URL with "/docs" once the docs route exists.
 * TODO: open /login intercepted route on Log in click (Phase 9).
 * TODO: open language popover on EN click (Phase 7).
 */
export function Navbar() {
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

        <nav
          className="hidden items-center md:flex"
          aria-label="Primary"
        >
          <a
            href="#journey"
            className="px-3.5 py-2 text-sm text-muted transition-colors duration-200 hover:text-ink"
          >
            How it works
          </a>
          <a
            href={DOCS_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="px-3.5 py-2 text-sm text-muted transition-colors duration-200 hover:text-ink"
          >
            Docs
          </a>
        </nav>

        <div className="flex items-center gap-1.5">
          <button
            type="button"
            aria-label="Change language, currently English"
            aria-disabled="true"
            className="glass inline-flex h-10 items-center gap-2 rounded-[14px] px-3 text-sm font-medium text-ink transition-colors duration-200 hover:bg-elevated"
          >
            <GlobeIcon />
            <span className="hidden md:inline">EN</span>
          </button>
          <button
            type="button"
            aria-disabled="true"
            className="glass inline-flex h-10 items-center rounded-[14px] px-[18px] text-sm font-medium text-ink transition-colors duration-200 hover:bg-elevated"
          >
            Log in
          </button>
        </div>
      </div>
    </header>
  );
}

/**
 * Globe icon for the language chip. Inline (not a separate `ui/icons.tsx`
 * module) because it has one consumer. Extract to a shared icons file
 * when a second one appears, so the module earns its existence.
 */
function GlobeIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18" />
    </svg>
  );
}
