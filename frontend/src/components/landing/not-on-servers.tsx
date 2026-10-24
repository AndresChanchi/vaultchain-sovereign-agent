import { NetworkViz } from "./network-viz";

/**
 * "Not on our servers" — landing section.
 *
 * Two-column layout on `lg:` — copy on the left, the animated network
 * panel on the right. Single column below `lg:` so the copy reads first
 * on narrow viewports.
 *
 * Copy source of truth is the mockup (Landing-dark.html / Landing-Light),
 * not the inline version that this component replaces. Two changes worth
 * noting relative to the inline copy:
 *
 *   - H2 was "Not on our servers." → now "Your photo lives on many
 *     computers. None of them is ours." (the section eyebrow retains
 *     the phrase "Not on our servers" — the mockup treats the headline
 *     as the answer, the eyebrow as the label).
 *   - The 4 statements were separate cards in the inline version →
 *     now a compact bullet list, matching the mockup. A fifth statement
 *     ("Not married to anyone. Irys today. Arweave or Filecoin
 *     tomorrow…") is added.
 *
 * Composition
 *   - Copy column: eyebrow + H2 + lede + bullet list. Server-rendered,
 *     zero interactivity.
 *   - Panel column: <NetworkViz /> — the network visualization
 *     component. It owns its own `card` surface (bg + border + radius),
 *     so this wrapper does NOT add another card around it.
 *
 * Motion
 *   Everything animated in this section lives in `<NetworkViz />`
 *   (dashed radiating lines + ambient dot pulse), driven by
 *   `.journey-line` and `.network-node` in `globals.css`. No
 *   interaction, no JS. Under `prefers-reduced-motion: reduce`, the
 *   animations are disabled by the token overrides.
 *
 * Accessibility
 *   - The bullet list is a `<ul>`; each `<li>` contains a `<b>` lead-in
 *     followed by explanatory text. Screen readers read it as
 *     "We built the door, not the house. Kipio does not host your
 *     photos." — the intended natural language.
 *   - The `<NetworkViz />` panel is fully decorative (`aria-hidden` on
 *     the SVG internals); the chips are visual annotations of the
 *     semantics already spelled out in the copy. Nothing is lost if a
 *     screen reader skips them.
 *
 * Not carried from the mockup (deliberate)
 *   The mockup wraps this entire section in `.pd` (padding-top: 120px).
 *   The other extracted sections in `(public)/page.tsx` have all used
 *   `py-24 md:px-10` for consistent rhythm. To avoid a one-off, this
 *   section uses the same `py-24` as its siblings. If the mockup's
 *   tighter inter-section rhythm matters, it should be applied
 *   uniformly across all sections in a polish pass, not selectively
 *   here.
 */

const BULLETS = [
  {
    title: "We built the door, not the house.",
    body: "Kipio does not host your photos.",
  },
  {
    title: "Many computers agree on it.",
    body: "No single company can quietly take it back.",
  },
  {
    title: "Two networks, two jobs.",
    body: "Arbitrum records who it belongs to. Irys keeps the locked file.",
  },
  {
    title: "Not married to anyone.",
    body: "Irys today. Arweave or Filecoin tomorrow, if they serve you better.",
  },
] as const;

export function NotOnServers() {
  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-center">
        <div>
          <p className="label-mono text-emerald-text">Not on our servers</p>
          <h2 className="mt-4 text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            Your photo lives on many computers. None of them is ours.
          </h2>
          <p className="mt-4 text-[17px] leading-[1.55]">
            Every copy is locked before it leaves your device.{" "}
            <span className="text-emerald-text">
              The computers that keep it cannot see it. Neither can Kipio, or
              the protocol. Only you can.
            </span>
          </p>
          <ul className="mt-7 flex flex-col gap-4 text-[15px] leading-[1.55] text-muted">
            {BULLETS.map((b) => (
              <li key={b.title}>
                <b className="font-semibold text-ink">{b.title}</b> {b.body}
              </li>
            ))}
          </ul>
        </div>

        <NetworkViz />
      </div>
    </section>
  );
}
