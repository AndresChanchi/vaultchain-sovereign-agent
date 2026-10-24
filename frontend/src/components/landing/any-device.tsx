import type { CSSProperties } from "react";

/**
 * "Any device" — landing section.
 *
 * Centered copy + five chips naming the device classes the app targets.
 * The chips pulse on a staggered 7s loop (mockup `.sg`), signalling
 * "alive" without promising a specific animation.
 *
 * Reuse — the `.chip-pulse` pattern
 *   The chip visual (card surface, hairline border, pill radius,
 *   staggered border+lift+halo pulse) is shared with the "Sign in"
 *   section (Fase 7): that section renders ten chips across two rows,
 *   emerald for methods, violet for wallets. Rather than duplicating
 *   the CSS in both components, both consume `.chip-pulse` from
 *   globals.css. Per-chip stagger and color come from inline CSS
 *   variables:
 *
 *     style={{ "--chip-i": index, "--chip-color": "var(--color-violet)" }}
 *
 *   AnyDevice overrides neither (all five chips pulse emerald on a
 *   0..4 stagger); SignIn overrides `--chip-color` on the second row.
 *
 *   The utility lands in globals.css next. Until it does, Tailwind's
 *   CLI emits no rule for `chip-pulse` and the chips render statically
 *   — same pattern already used for `stage-tilt`, `journey-*` and
 *   `network-node`.
 *
 * Copy source of truth
 *   The mockup (Landing-dark.html / Landing-Light / Landing-Mobile).
 *   The mockup's paragraph differs from the inline version this
 *   replaces:
 *
 *     Inline (old):  "The original stays the original. Open your space
 *                     from a phone, a laptop, or a borrowed browser,
 *                     and see the photo exactly as you kept it."
 *     Mockup (new):  "Take it on an iPhone, open it on Windows. Your
 *                     original stays untouched, and you choose how to
 *                     export: original or compatible."
 *
 *   The mockup's version names concrete devices and adds the
 *   export-choice detail. Follow the mockup.
 *
 * Layout
 *   No card. The mockup places this section directly on the page
 *   background — unlike "Sovereign" (inside a glass panel) and "Live
 *   from the network" (also inside a glass panel). The centered
 *   composition — eyebrow, H2, sub, chips — is the entire section.
 *   `text-center` on `<section>` cascades through the stack; only the
 *   chips row needs its own flex container to wrap.
 *
 * H2 size
 *   `text-[30px] md:text-[40px]` matches the mockup's `.sec` (40px on
 *   desktop, 30px on mobile). The inline version this replaces used
 *   `text-[28px] md:text-[36px]` — a small drift from an earlier pass;
 *   the mockup is the source of truth.
 *
 * Server Component
 *   No state, no effects, no handlers. `--chip-i` is a static per-chip
 *   index derived from `Array.map`, not state.
 */

const DEVICES = ["iPhone", "Android", "Windows", "Mac", "Web"] as const;

export function AnyDevice() {
  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 text-center md:px-10">
      <p className="label-mono text-emerald-text">Any device</p>
      <h2 className="mt-4 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
        Your quality travels with you.
      </h2>
      <p className="mx-auto mt-4 max-w-[520px] text-[16px] leading-[1.6] text-muted">
        Take it on an iPhone, open it on Windows. Your original stays
        untouched, and you choose how to export: original or compatible.
      </p>
      <div className="mt-[30px] flex flex-wrap justify-center gap-3">
        {DEVICES.map((device, i) => (
          <span
            key={device}
            className="chip-pulse"
            style={{ "--chip-i": i } as CSSProperties}
          >
            {device}
          </span>
        ))}
      </div>
    </section>
  );
}
