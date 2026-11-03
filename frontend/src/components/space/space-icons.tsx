/**
 * SVG icons used by the space chrome. Single source — reused by the
 * sidebar (18px), the dock (22px), the header (16px), the welcome
 * stage (24-36px), and the welcome hero CTA (16px). All stroke icons
 * share `iconProps`: 1.8 stroke weight, rounded caps, no fill,
 * `currentColor` so tinting comes from the caller's `text-*` class.
 *
 * Exceptions:
 *   - `CursorIcon` is filled (matches the native OS pointer, which is
 *     filled, not stroked) and takes its own SVG builder inline.
 *   - `ChevronIcon` accepts a `direction` hint that flips it via
 *     `transform: rotate(180deg)` — the glyph itself is always the
 *     same right-pointing chevron.
 */

type IconProps = { size?: number; className?: string };

function iconProps({ size = 18, className }: IconProps) {
  return {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none" as const,
    stroke: "currentColor" as const,
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    "aria-hidden": true as const,
    className,
  };
}

export function HomeIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <path d="M4 11l8-7 8 7" />
      <path d="M6 10v10h12V10" />
    </svg>
  );
}

export function LibraryIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <rect x="4" y="4" width="7" height="7" rx="1.5" />
      <rect x="13" y="4" width="7" height="7" rx="1.5" />
      <rect x="4" y="13" width="7" height="7" rx="1.5" />
      <rect x="13" y="13" width="7" height="7" rx="1.5" />
    </svg>
  );
}

export function MomentsIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <path d="M12 3l2 6 6 2-6 2-2 6-2-6-6-2 6-2z" />
    </svg>
  );
}

export function SharedIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <circle cx="9" cy="8" r="3.5" />
      <path d="M3 20c0-3.5 2.7-6 6-6s6 2.5 6 6" />
      <path d="M16 5a3.5 3.5 0 0 1 0 6.5M18 14c2 .8 3 2.7 3 6" />
    </svg>
  );
}

export function OffersIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <path d="M3 12V4h8l10 10-8 8z" />
      <circle cx="7.5" cy="8.5" r="1.2" />
    </svg>
  );
}

export function SettingsIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1" />
    </svg>
  );
}

export function UploadIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <path d="M12 16V4M7 9l5-5 5 5" />
      <path d="M5 20h14" />
    </svg>
  );
}

/**
 * Play triangle — the mockup's "Try with a sample photo" CTA. Stroked,
 * not filled: it reads as "play" (a symbol), not "play button" (a
 * media control). A filled triangle would carry the wrong affordance —
 * the CTA does not start playback, it opens a preview flow. The
 * outline keeps the visual weight in line with the other stroke icons
 * in this file.
 */
export function PlayIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <path d="M8 5l11 7-11 7z" />
    </svg>
  );
}

export function SearchIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <circle cx="11" cy="11" r="7" />
      <path d="M20 20l-4-4" />
    </svg>
  );
}

export function LockIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <rect x="5" y="11" width="14" height="9" rx="2" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
    </svg>
  );
}

export function PlusIcon(p: IconProps) {
  return (
    <svg {...iconProps(p)}>
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

/**
 * Filled pointer used by the welcome stage to walk the user through
 * "a photo lands here." Reads as the native OS cursor — a stroke
 * outline would look like an icon, not a mouse.
 *
 * Deliberately excluded from `iconProps` (which forces
 * `fill: none`). The drop-shadow that makes it legible over any
 * background lives on the parent wrapper in `welcome-stage.tsx`,
 * not here — shadow is a placement concern, not part of the glyph.
 */
export function CursorIcon({ size = 24, className }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      className={className}
    >
      <path d="M5 3l14 8-6 2 4 7-3 1-4-7-5 4z" />
    </svg>
  );
}

/**
 * Chevron — sidebar collapse toggle. Points right when expanded
 * (clicking collapses toward the left), left when collapsed
 * (clicking expands toward the right). `direction` is a semantic
 * hint, not a rotation: the icon itself is a right-chevron glyph;
 * `direction="left"` flips it via `transform: rotate(180deg)`.
 */
export function ChevronIcon({
  size = 16,
  className,
  direction = "right",
}: IconProps & { direction?: "right" | "left" }) {
  return (
    <svg
      {...iconProps({ size, className })}
      style={
        direction === "left" ? { transform: "rotate(180deg)" } : undefined
      }
    >
      <path d="M9 6l6 6-6 6" />
    </svg>
  );
}
