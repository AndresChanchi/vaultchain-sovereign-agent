"use client";

import { useI18n } from "@context/I18nContext";
import { NetworkViz } from "./network-viz";

/**
 * "Not on our servers" — landing section.
 *
 * Two-column layout on `lg:` — copy on the left, the animated network
 * panel on the right. Single column below `lg:` so the copy reads first
 * on narrow viewports.
 *
 * Copy
 *   Every visible string comes from the active dictionary
 *   (`landing.notOnServers.*`). Switching the language re-renders the
 *   section with the target strings, including the bullet list. The
 *   `lede` and `ledeEmphasis` fragments are stored separately in the
 *   dictionary so each locale can translate them as independent
 *   sentences; the component joins them with a literal space.
 *
 *   Bullet keys use the array index, not the translated title — a
 *   locale change would otherwise remount every `<li>` (harmless here
 *   since there is no animation, but consistent with the rest of the
 *   codebase where index-keyed lists are the norm).
 *
 * Client Component
 *   `useI18n()` reads the active dictionary and exposes `t()`. No
 *   other state, effect, or ref lives here. This file used to be a
 *   Server Component; making it client adds ~2 KB to the client
 *   bundle for i18n and does not affect the SSR output (the initial
 *   HTML still carries the fully-rendered section).
 *
 * Composition
 *   - Copy column: eyebrow + H2 + lede + bullet list.
 *   - Panel column: `<NetworkViz />` — the network visualization
 *     component. It owns its own `card` surface (bg + border + radius),
 *     so this wrapper does NOT add another card around it.
 *
 * Accessibility
 *   - The bullet list is a `<ul>`; each `<li>` contains a `<b>` lead-in
 *     followed by explanatory text. Screen readers read it as
 *     "We built the door, not the house. Kipio does not host your
 *     photos." — the intended natural language.
 *   - The `<NetworkViz />` panel is decorative (`aria-hidden` on the
 *     SVG internals); the chips annotate the semantics already spelled
 *     out in the copy. Nothing is lost if a screen reader skips them.
 *
 * Not carried from the mockup (deliberate)
 *   The mockup wraps this entire section in `.pd` (padding-top: 120px).
 *   The other sections use `py-24 md:px-10` for consistent rhythm; to
 *   avoid a one-off, this section uses the same `py-24` as its
 *   siblings.
 */
export function NotOnServers() {
  const { t, dictionary } = useI18n();
  const bullets = dictionary.landing.notOnServers.bullets;

  return (
    <section className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-center">
        <div>
          <p className="label-mono text-emerald-text">
            {t("landing.notOnServers.eyebrow")}
          </p>
          <h2 className="mt-4 text-balance text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            {t("landing.notOnServers.title")}
          </h2>
          <p className="mt-4 text-pretty text-[17px] leading-[1.55]">
            {t("landing.notOnServers.lede")}{" "}
            <span className="text-emerald-text">
              {t("landing.notOnServers.ledeEmphasis")}
            </span>
          </p>
          <ul className="mt-7 flex flex-col gap-4 text-[15px] leading-[1.55] text-muted">
            {bullets.map((b, i) => (
              <li key={i} className="text-pretty">
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
