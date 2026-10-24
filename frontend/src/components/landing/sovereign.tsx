import type { ReactNode } from "react";

/**
 * "Sovereign by design" — landing panel.
 *
 * A single glass panel that groups four statements about the protocol's
 * guarantees. Not a grid of cards: the mockup wraps everything in one
 * `.gl` surface so the statements read as facets of one whole, not as
 * four separate features. Each statement carries one emerald fragment
 * (the part a user should remember) inside otherwise muted body copy.
 *
 * Why a panel and not cards
 *   The inline version this replaces rendered four bordered cards,
 *   which visually fragmented the four claims. The mockup's single
 *   panel communicates "these four belong together" — the guarantees
 *   are facets of the same design decision (sovereignty), not separate
 *   selling points. This is a deliberate visual inversion and it is
 *   the mockup's choice; not reverting it.
 *
 * Copy source of truth
 *   The mockup (Landing-dark.html / Landing-Light / Landing-Mobile).
 *   Relative to the earlier inline copy:
 *     - Order changed to No master key → No monthly bill → Private,
 *       not anonymous → Yours to share.
 *     - Bodies rewritten and tightened (the mockup's text is shorter
 *       and less editorial — no second sentence per claim).
 *     - The H2 ("The details that matter.") was removed. The mockup
 *       goes eyebrow → statements with no intermediate heading.
 *     - Emerald emphasis added to the four key fragments. This is the
 *       most consequential change: it converts the panel from "four
 *       paragraphs" into "four claims with a highlight".
 *
 * Body as ReactNode
 *   Each statement carries an inline emerald fragment, so `body` is
 *   `ReactNode`, not `string`. A string representation would need a
 *   mini-markup (`**…**`) plus a parser — fragile for four items and
 *   hostile to TypeScript's strict mode. JSX keeps the copy at the
 *   data level while allowing the emphasis to be part of the string.
 *
 * Server Component
 *   No state, no effects, no refs, no handlers. Everything is static
 *   markup. Under `prefers-reduced-motion`, nothing changes — the
 *   panel has no motion to disable.
 *
 * Glass surface
 *   `.glass` is normally reserved for sidebar / dock / slide-overs /
 *   popovers (DESIGN §4.4). The mockup applies it here as well. This
 *   is the second deliberate exception after `LiveStats`: the panel
 *   sits over the page's drifting orbs and the backdrop-filter lets
 *   them show through as quiet life behind the text. Not nested in
 *   any `preserve-3d` ancestor, so the blur is stable.
 *
 * Mobile
 *   At < sm, the grid collapses to one column. Padding stays `p-11`
 *   (44px) as in the mockup — the mockup does not override `.gl`'s
 *   padding under 700px. The inner width on a 390px viewport is
 *   ~262px, tight but legible for the longest statement
 *   ("Private, not anonymous"). Not reducing it without a mockup
 *   change: the panel's mass is part of the design.
 */

const STATEMENTS: readonly {
  readonly title: string;
  readonly body: ReactNode;
}[] = [
  {
    title: "No master key.",
    body: (
      <>
        <span className="text-emerald-text">We cannot open your photos</span>,
        even if asked.
      </>
    ),
  },
  {
    title: "No monthly bill.",
    body: (
      <>
        Pay when you upload.{" "}
        <span className="text-emerald-text">Nothing lapses</span> and takes
        them away.
      </>
    ),
  },
  {
    title: "Private, not anonymous.",
    body: (
      <>
        Your photos are <span className="text-emerald-text">fully private</span>
        . Your account is pseudonymous: public networks see an address, never
        your name. We cannot promise anonymity.
      </>
    ),
  },
  {
    title: "Yours to share.",
    body: (
      <>
        Share with whoever you choose,{" "}
        <span className="text-emerald-text">without giving up your key</span>.
      </>
    ),
  },
];

export function Sovereign() {
  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="glass rounded-panel p-11">
        <p className="label-mono text-emerald-text">Sovereign by design</p>
        <div className="mt-7 grid gap-x-12 gap-y-8 sm:grid-cols-2">
          {STATEMENTS.map((s) => (
            <div key={s.title}>
              <h3 className="text-[21px] font-semibold tracking-[-0.01em] text-ink">
                {s.title}
              </h3>
              <p className="mt-2 text-[15px] leading-[1.6] text-muted">
                {s.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
