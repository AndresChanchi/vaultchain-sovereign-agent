import type { CSSProperties } from "react";

/**
 * "Sign in however you like" — landing section.
 *
 * Centered composition: eyebrow, headline, sub, then two rows of
 * `chip-pulse` chips (methods on top in emerald, wallets below in
 * violet), a connector SVG that funnels both rows into a single point,
 * and a glass card at the bottom reading "Your space — The same one,
 * whichever way you came in."
 *
 * The connector is the mockup's main contribution to this section: it
 * is not ornamental. Two visually distinct rows (methods vs. wallets)
 * converge on one endpoint, which is exactly the product claim in the
 * subtitle ("The same one, whichever way you came in"). Removing it
 * would reduce the section to "we support a lot of login options"; the
 * SVG makes the "one space" part visible.
 *
 * Copy source of truth
 *   The mockup (Landing-dark.html / Landing-Light / Landing-Mobile).
 *   Changes relative to the inline version this replaces:
 *     - Eyebrow: "Ways in" → "Any way in, one space" (mockup).
 *     - Chips: 6 static → 10 animated. First row = methods (emerald),
 *       second row = wallets (violet). The mockup's two-tone treatment
 *       names a real distinction: methods identify you, wallets sign
 *       for you. Same endpoint either way.
 *     - Sub rewritten to match the mockup: "Email, social, passkey or
 *       a web3 wallet. Kipio never asks who you are, only that it is
 *       you."
 *     - Connector SVG added between the chips and the card. Not in
 *       the inline. In the mockup (`.hm` class).
 *     - Glass card at the bottom added: 52px emerald icon, "Your
 *       space", "The same one, whichever way you came in."
 *
 * Reused utilities
 *   - `.chip-pulse` (globals.css): base chip + staggered pulse. First
 *     row uses the default (emerald); second row overrides
 *     `--chip-color: var(--color-violet)` per chip.
 *     `--chip-i` is the global chip index (0..5 for methods, 6..9 for
 *     wallets) so the stagger sweeps across both rows as one wave.
 *   - `.journey-line` (globals.css): dashed 3/7 at 2.2s linear. Shared
 *     with `network-viz.tsx` and JourneyStage's network slide. The
 *     three consumers are documented in the globals.css section header;
 *     renaming the class breaks all three.
 *   - `.glass` (globals.css): the "Your space" card. Not nested inside
 *     a `preserve-3d` ancestor, so the blur is stable.
 *
 * Connector SVG
 *   ViewBox `0 0 1000 100`, `preserveAspectRatio="none"` so it stretches
 *   to the container width and stays 100px tall. The five paths
 *   converge on `(500, 98)`. Three start at x=200/350/500 with emerald
 *   stroke (methods); two at x=650/800 with violet stroke (wallets).
 *   The visual effect: both rows feed the same endpoint, one in each
 *   brand color.
 *
 *   Hidden on `< md` (`hidden md:block`, mockup's `.hm`). On mobile the
 *   two rows wrap unpredictably and the funnel geometry would land on
 *   chips at arbitrary positions. Removing it on mobile avoids the
 *   "broken arrow pointing nowhere" look. On desktop it always lands
 *   on the card below because the card is `max-w-[560px]` centered and
 *   the SVG is inside the same centered column.
 *
 *   `stroke="var(--color-emerald)"` and `stroke="var(--color-violet)"`
 *   instead of the mockup's hardcoded `oklch(...)` values — the tokens
 *   are the same color, and using them means the connector follows if
 *   the palette ever shifts. `strokeWidth="1.5"` matches the mockup.
 *
 * Server Component
 *   No state, no effects, no handlers. `--chip-i` is a static per-chip
 *   index from `Array.map`, not state. Reduced motion: `--animate-chip-pulse`
 *   resolves to `none` (globals.css), the connector's `journey-line`
 *   animation resolves to `none`, and the section becomes fully static
 *   without any conditional logic here.
 *
 * Placeholder behavior
 *   Today all chips are decorative — clicking one does nothing. The
 *   login flow (Fase 9) will wrap the relevant chips in buttons that
 *   open the login overlay. Until then, `<span>` is correct: they are
 *   perceivable, not interactive. When they become interactive, the
 *   span→button swap is per-chip and localized.
 */

const METHODS = [
  "Email",
  "Google",
  "X",
  "Apple",
  "Microsoft",
  "Passkey",
] as const;

const WALLETS = ["MetaMask", "Brave Wallet", "Rabby", "Ledger"] as const;

export function SignIn() {
  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="mx-auto max-w-2xl text-center">
        <p className="label-mono text-emerald-text">Any way in, one space</p>
        <h2 className="mt-3 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
          Sign in however you like.
        </h2>
        <p className="mx-auto mt-3 max-w-[480px] text-[16px] leading-[1.55] text-muted">
          Email, social, passkey or a web3 wallet. Kipio never asks who you
          are, only that it is you.
        </p>

        {/* Methods — emerald chips (default `--chip-color`) */}
        <div className="mt-9 flex flex-wrap justify-center gap-3">
          {METHODS.map((method, i) => (
            <span
              key={method}
              className="chip-pulse"
              style={{ "--chip-i": i } as CSSProperties}
            >
              {method}
            </span>
          ))}
        </div>

        {/* Wallets — violet chips. `--chip-i` continues from the methods
            row (6..9) so the pulse travels across both rows as one
            wave, matching the mockup's `--i:6` .. `--i:9`. */}
        <div className="mt-3 flex flex-wrap justify-center gap-3">
          {WALLETS.map((wallet, i) => (
            <span
              key={wallet}
              className="chip-pulse"
              style={
                {
                  "--chip-i": i + METHODS.length,
                  "--chip-color": "var(--color-violet)",
                } as CSSProperties
              }
            >
              {wallet}
            </span>
          ))}
        </div>

        {/* Connector — desktop only. Funnels both rows into the card
            below. Hidden at < md; see the file header. */}
        <svg
          aria-hidden="true"
          className="hidden h-[100px] w-full md:block"
          viewBox="0 0 1000 100"
          preserveAspectRatio="none"
        >
          <g fill="none" strokeWidth="1.5">
            <path
              className="journey-line"
              d="M200 0C200 70 500 30 500 98"
              stroke="var(--color-emerald)"
            />
            <path
              className="journey-line"
              d="M350 0C350 70 500 30 500 98"
              stroke="var(--color-emerald)"
            />
            <path
              className="journey-line"
              d="M500 0V98"
              stroke="var(--color-emerald)"
            />
            <path
              className="journey-line"
              d="M650 0C650 70 500 30 500 98"
              stroke="var(--color-violet)"
            />
            <path
              className="journey-line"
              d="M800 0C800 70 500 30 500 98"
              stroke="var(--color-violet)"
            />
          </g>
        </svg>

        {/* Destination card — the "one space" both rows converge on. */}
        <div className="glass mx-auto mt-6 flex max-w-[560px] items-center gap-5 rounded-[24px] px-7 py-6 text-left">
          <div className="flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-[15px] bg-emerald text-on-emerald">
            <svg
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <rect x="5" y="11" width="14" height="9" rx="2" />
              <path d="M8 11V8a4 4 0 0 1 8 0v3" />
            </svg>
          </div>
          <div>
            <div className="text-[20px] font-semibold text-ink">
              Your space
            </div>
            <div className="mt-1 text-[14px] text-muted">
              The same one, whichever way you came in.
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
