"use client";

import { useState } from "react";
import { useI18n } from "@context/I18nContext";

/**
 * "Sovereign by design" — landing panel.
 *
 * A single glass panel that groups four statements about the protocol's
 * guarantees. Not a grid of cards: the panel wraps everything in one
 * surface so the statements read as facets of one whole, not as four
 * separate features. Each statement carries one emerald fragment (the
 * part a user should remember) inside otherwise muted body copy.
 *
 * Desktop (≥ sm) — unchanged from the mockup
 *   Two-column grid, four statement blocks, all bodies visible.
 *   Padding `p-11` (44px) recovers the mockup's generous interior.
 *   No icons, no numbering — the copy is the content.
 *
 * Mobile (< sm) — "sovereign oath" accordion
 *   The mobile problem: the four statements stacked flat produce
 *   ~700px of dense text on a 390px viewport, and the longest
 *   statement ("Private, not anonymous") wraps to five or six lines
 *   of body copy. The section reads as a wall.
 *
 *   The redesign is structural, not decorative. Each statement becomes
 *   a **collapsed row** that reveals its body on tap:
 *
 *     - Four rows, ~56px tall each when collapsed.
 *     - One open at a time (accordion, not disclosure list) — the
 *       section reads as a *set of guarantees*, not as four
 *       independent toggles the reader has to keep track of.
 *     - First statement is open on mount, so the pattern is legible
 *       without a click.
 *
 *   Collapsed, the mobile footprint is ~280px instead of ~700px. Even
 *   with one body expanded it stays below ~400px — half the previous
 *   height. Same copy; the reader controls the depth.
 *
 *   Visual identity on mobile
 *     - **Icon per row**, in a 32px circle: key (no master key),
 *       calendar-check (no monthly bill), shield (private, not
 *       anonymous), share-nodes (yours to share). Icons name the
 *       *subject* of each "No…" title — the negation lives in the
 *       title, not the icon (a crossed-out key would read as a
 *       cancelled feature, not as a guarantee). All `aria-hidden`;
 *       the title carries the semantics.
 *     - **Continuous thread** connecting the four icons — a
 *       hairline at the icon column's center, gradient-faded at top
 *       and bottom. Reads as connective tissue: these four are one
 *       set, not four cards.
 *     - **Emerald accent** on the open row: icon circle switches
 *       from muted border to emerald border + emerald background
 *       tint; the row background lifts to `elevated/50`. One
 *       glance tells the reader "this is the current guarantee".
 *     - **Chevron** that rotates 90° on open — the only motion in
 *       the row besides the height animation.
 *
 *   Why an accordion rather than disclosure or tabs
 *     - Tabs hide everything but one; a reader who wants to compare
 *       two guarantees has to remember the previous one.
 *     - Independent disclosures (each row toggles without affecting
 *       the others) let all four open at once, which reintroduces
 *       the wall of text the redesign is trying to remove.
 *     - Accordion (one-open-at-a-time) lets the reader compare two
 *       adjacent items by tapping between them, without ever
 *       reverting to the four-at-once state.
 *
 * Accessibility
 *   - Each row is `<h3><button aria-expanded aria-controls>` — the
 *     standard interactive-heading pattern. Valid HTML (an `<h3>`
 *     inside a `<button>` is not, hence the wrapping).
 *   - Body content lives in a `<div role="region" aria-labelledby>`
 *     that stays in the DOM at all times; the `grid-template-rows:
 *     0fr` collapse hides it visually but keeps it findable via
 *     Ctrl+F and indexable by search engines. `hidden` attribute
 *     would remove it from both — not what we want here.
 *   - Icons and chevron are `aria-hidden`; the button's text content
 *     is the title alone.
 *   - Focus ring comes from `:focus-visible` in globals.css.
 *   - Under `prefers-reduced-motion: reduce`, the height and chevron
 *     transitions are removed (globals.css); the toggle still works
 *     instantly. The accordion behaviour is essential, not
 *     decorative — never disabled.
 *
 * i18n layout stability
 *   - Titles use `text-balance` (no widow word on the last line in
 *     German "Kein Hauptschlüssel", French "Pas de clé maître", etc.).
 *   - Bodies use `text-pretty` (avoids a trailing orphan line in
 *     the longest statement, #3, in every locale).
 *   - The height animation uses `grid-template-rows`, which adapts
 *     to any content height — no assumption about the translated
 *     body's number of lines.
 *   - Icons are indexed by *position*, not by title text: a future
 *     locale reordering the statements (it should not, this is the
 *     mockup's order, but defensive against editorial drift) keeps
 *     the icon attached to its intended slot.
 *
 * Dictionary reading
 *   `dictionary.landing.sovereign.statements` is an array; `t()` only
 *   resolves leaf strings, so arrays come from the dictionary
 *   directly. The `body` / `bodyEmphasis` / `bodyAfter` split lets
 *   translators reorder the emerald fragment freely within the
 *   sentence — the component renders them in that exact sequence.
 *
 * Client Component
 *   `"use client"` because of `useI18n()` and the local accordion
 *   state. The desktop grid uses the same state implicitly (it
 *   renders every body unconditionally, ignoring `openIndex`).
 */

const ICONS = [KeyIcon, CalendarCheckIcon, ShieldIcon, ShareIcon] as const;

export function Sovereign() {
  const { t, dictionary } = useI18n();
  const statements = dictionary.landing.sovereign.statements;
  const [openIndex, setOpenIndex] = useState<number>(0);

  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="glass rounded-panel p-6 sm:p-11">
        <p className="label-mono text-emerald-text">
          {t("landing.sovereign.eyebrow")}
        </p>

        {/* ── Desktop (≥ sm) — unchanged 2-col grid ────────────── */}
        <div className="mt-7 hidden gap-x-12 gap-y-8 sm:grid sm:grid-cols-2">
          {statements.map((s, i) => (
            <div key={i}>
              <h3 className="text-balance text-[21px] font-semibold tracking-[-0.01em] text-ink">
                {s.title}
              </h3>
              <p className="mt-2 text-pretty text-[15px] leading-[1.6] text-muted">
                {s.body}
                <span className="text-emerald-text">{s.bodyEmphasis}</span>
                {s.bodyAfter}
              </p>
            </div>
          ))}
        </div>

        {/* ── Mobile (< sm) — accordion on a thread ─────────────── */}
        <div className="relative mt-5 sm:hidden">
          <div className="sovereign-thread" aria-hidden="true" />

          <ul role="list" className="relative">
            {statements.map((s, i) => {
              const Icon = ICONS[i] ?? ShieldIcon;
              const isOpen = i === openIndex;
              const panelId = `sovereign-panel-${i}`;
              const buttonId = `sovereign-btn-${i}`;
              return (
                <li key={i}>
                  <h3>
                    <button
                      id={buttonId}
                      type="button"
                      aria-expanded={isOpen}
                      aria-controls={panelId}
                      onClick={() => setOpenIndex(isOpen ? -1 : i)}
                      className={`flex w-full items-center gap-3 rounded-[14px] px-2 py-2.5 text-start transition-colors duration-200 ${
                        isOpen
                          ? "bg-elevated/50"
                          : "hover:bg-elevated/30"
                      }`}
                    >
                      <span
                        aria-hidden="true"
                        className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full border transition-colors duration-200 ${
                          isOpen
                            ? "border-emerald bg-emerald/10 text-emerald"
                            : "border-hairline text-muted"
                        }`}
                      >
                        <Icon />
                      </span>
                      <span className="text-balance flex-1 text-[15px] font-semibold text-ink">
                        {s.title}
                      </span>
                      <svg
                        aria-hidden="true"
                        width="14"
                        height="14"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        className={`sovereign-chevron shrink-0 text-muted ${
                          isOpen ? "is-open" : ""
                        }`}
                      >
                        <path d="M9 6l6 6-6 6" />
                      </svg>
                    </button>
                  </h3>

                  <div
                    id={panelId}
                    role="region"
                    aria-labelledby={buttonId}
                    className={`sovereign-body ${isOpen ? "is-open" : ""}`}
                  >
                    <div>
                      <p className="pb-3 ps-[52px] pe-3 pt-1 text-pretty text-[14px] leading-[1.55] text-muted">
                        {s.body}
                        <span className="text-emerald-text">
                          {s.bodyEmphasis}
                        </span>
                        {s.bodyAfter}
                      </p>
                    </div>
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
      </div>
    </section>
  );
}

/* ── Thematic icons ────────────────────────────────────────────────────
 * 16px glyph inside a 32px circle. `strokeWidth="1.8"` matches the
 * icon set used in the navbar, footer and theme toggle. All `aria-hidden`.
 *
 *     key              → "No master key"
 *     calendar-check   → "No monthly bill"
 *     shield           → "Private, not anonymous"
 *     share-nodes      → "Yours to share"
 *
 * The icons name the *subject* of each statement — the negation ("No…")
 * lives in the title only. A crossed-out key would read as "feature
 * cancelled"; a plain key reads as "the subject is keys".
 * ─────────────────────────────────────────────────────────────────── */

function KeyIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <circle cx="9" cy="15" r="4" />
      <path d="M12 12l8-8M17 4h3v3" />
    </svg>
  );
}

function CalendarCheckIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4M9 15l2 2 4-4" />
    </svg>
  );
}

function ShieldIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M12 3l8 3v6c0 5-3.5 8.5-8 9-4.5-.5-8-4-8-9V6l8-3z" />
    </svg>
  );
}

function ShareIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <circle cx="6" cy="12" r="3" />
      <circle cx="18" cy="6" r="3" />
      <circle cx="18" cy="18" r="3" />
      <path d="M8.5 10.5l7-3M8.5 13.5l7 3" />
    </svg>
  );
}
