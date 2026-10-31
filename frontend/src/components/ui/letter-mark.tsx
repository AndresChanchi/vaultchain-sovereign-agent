/**
 * LetterMark — the small round letter badge used by the login panel's
 * wallet rows and OAuth provider grid.
 *
 * Matches the mockup: 22×22 circle, `bg-elevated`, Geist Mono, 11px,
 * single uppercase letter. Intentionally NOT a brand logo — using real
 * MetaMask / Google SVGs would require trademark licensing and would
 * drift from the mockup, which is the source of truth for the design.
 *
 * When a wallet announces a proper icon via EIP-6963 (data URI), the
 * wallet row shows that instead of the letter. `LetterMark` is the
 * fallback for wallets that do not provide an icon (Ledger, unknown
 * wallets the user has not detected yet, and every OAuth provider,
 * which never has a 6963-style icon).
 *
 * `tone`
 *   `"default"` — the neutral badge (`bg-elevated`).
 *   `"emerald"` — used by the "Detected" badge inside a wallet row.
 *     It is a *badge* tone, not a mark tone; the letter itself stays
 *     `text-ink` so it remains readable on the emerald tint.
 *
 * Accessibility
 *   `aria-hidden="true"` — the mark is decorative. The adjacent label
 *   ("MetaMask", "Google") carries the semantic name. Screen readers
 *   announce "MetaMask", never "M MetaMask".
 *
 * Sizing
 *   Default 22px matches the mockup. `size` is exposed for any future
 *   surface that needs a different dimension. The font size is fixed
 *   at 11px, not scaled with `size` — the mockup is the only
 *   reference and its single dimension works at both call sites. If a
 *   future surface needs a larger mark, add a `text-` class on the
 *   consumer rather than a font-size prop here.
 */

type LetterMarkProps = {
  /**
   * Single character shown inside the circle. The caller picks it —
   * the mark does not infer a letter from a name because the mapping
   * is context-specific: MetaMask → M, Brave Wallet → B, GitHub and
   * Google both want G but for different rows, and Twitch wants T
   * while X wants X.
   */
  letter: string;
  /** Diameter in px. Defaults to the mockup's 22. */
  size?: number;
  /** Visual tone. See "tone" in the file header. */
  tone?: "default" | "emerald";
};

export function LetterMark({
  letter,
  size = 22,
  tone = "default",
}: LetterMarkProps) {
  return (
    <span
      aria-hidden="true"
      className={
        "grid shrink-0 place-items-center rounded-full font-mono text-[11px] leading-none text-ink " +
        (tone === "emerald"
          ? "bg-emerald/15 ring-1 ring-emerald/30"
          : "bg-elevated")
      }
      style={{ width: size, height: size }}
    >
      {letter}
    </span>
  );
}
