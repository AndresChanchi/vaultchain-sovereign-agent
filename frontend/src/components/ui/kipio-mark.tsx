type KipioMarkProps = {
  /** Square side in px. Default 34. */
  size?: number;
  className?: string;
};

/**
 * Kipio brand mark: the "K" glyph inside a rounded square.
 *
 * Consumed by the navbar, the footer and any future public surface.
 * Kept as a component (not inline SVG) so the stroke path is defined
 * exactly once — the mark is a brand asset that must not drift between
 * pages.
 */
export function KipioMark({ size = 34, className = "" }: KipioMarkProps) {
  const glyph = Math.round(size * 0.6);
  return (
    <span
      aria-hidden="true"
      className={`inline-flex items-center justify-center rounded-[10px] border border-hairline bg-elevated ${className}`}
      style={{ width: size, height: size }}
    >
      <svg width={glyph} height={glyph} viewBox="0 0 24 24" fill="none">
        <path
          d="M4 4v16 M4 12h5l7-8 M9 12l7 8"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="text-emerald-text"
        />
      </svg>
    </span>
  );
}
