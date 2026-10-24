/**
 * Fictional photo samples used by the landing journey slides.
 *
 * Renders a hidden `<svg>` with four `<symbol id="s1..#s4">` definitions
 * plus the gradients, turbulence filter, pattern and building path they
 * depend on. Consumers render `<use href="#s1" />` (etc.) inside their
 * own `<svg>`. The symbols resolve across the document because both the
 * `<defs>` and the `<use>` live in the same DOM tree.
 *
 * Why a component and not a static SVG file
 *   - The defs must be present in the DOM once per page. A component
 *     makes "render these once" explicit at the call site.
 *   - If the dashboard "explorer state" (Fase 8) or the network viz
 *     (Fase 4) later reuse any of these, the import is one line.
 *
 * Why `journey/` and not `ui/`
 *   The samples are styled to feel like real photos at a glance (sunset,
 *   ocean, night, forest), but they are placeholders — not a general
 *   icon set. If they end up reused by non-landing sections, move the
 *   file to `ui/demo-photos.tsx` at that point. Until then, landing/
 *   is where they belong (Scream).
 *
 * Visual performance
 *   The filter `#gr` is `feTurbulence` at high frequency and each
 *   symbol applies it once. That is fine for the journey slides (the
 *   slide's outer `<use>` reuses a single rendered instance). If any
 *   future consumer renders 10+ `<use>` nodes of the same symbol in
 *   the same frame, prefer pre-rendering the symbol to a static
 *   `<image>` at build time instead of stacking filter effects.
 *
 * Rendering in JSX
 *   React attribute names: camelCase for multi-word attributes
 *   (`stopColor`, `stopOpacity`, `strokeWidth`), as-is for single-word
 *   camelCase-preserved ones (`baseFrequency`, `numOctaves`, `seed`).
 *   This mirrors React's DOM attribute mapping; the SVG result is
 *   identical to the mockup.
 *
 * TODO: replace with real curated photos or user-provided content
 *       once the upload flow (Fase 10) can render a preview.
 */
export function JourneySamples() {
  return (
    <svg
      width="0"
      height="0"
      style={{ position: "absolute" }}
      aria-hidden="true"
    >
      <defs>
        {/* Fine-grain noise overlay used by every symbol to give the
            "photo" a slightly imperfect, filmic surface. */}
        <filter id="gr">
          <feTurbulence
            type="fractalNoise"
            baseFrequency=".85"
            numOctaves="2"
            seed="3"
          />
          <feColorMatrix values="0 0 0 0 .5 0 0 0 0 .5 0 0 0 0 .5 0 0 0 .55 0" />
        </filter>

        {/* Vignette — darkens edges of every symbol. */}
        <radialGradient id="vg" cx=".5" cy=".5" r=".75">
          <stop offset=".55" stopColor="#000" stopOpacity="0" />
          <stop offset="1" stopColor="#000" stopOpacity=".45" />
        </radialGradient>

        {/* Sun glow — used by s1 (sunset) and s2 (sunrise over sea). */}
        <radialGradient id="sn">
          <stop offset="0" stopColor="#fff6d6" />
          <stop offset=".25" stopColor="#ffe3a1" stopOpacity=".9" />
          <stop offset="1" stopColor="#ffd08a" stopOpacity="0" />
        </radialGradient>

        {/* s1 — dusk over distant mountains. */}
        <linearGradient id="k1" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#16224f" />
          <stop offset=".38" stopColor="#6a4b92" />
          <stop offset=".62" stopColor="#f0a35c" />
          <stop offset=".74" stopColor="#f8d48e" />
        </linearGradient>
        <linearGradient id="lk" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#e79a58" />
          <stop offset=".4" stopColor="#5b4a7a" />
          <stop offset="1" stopColor="#1a2147" />
        </linearGradient>

        {/* s2 — sunrise over a calm sea. */}
        <linearGradient id="k2" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#14395e" />
          <stop offset=".45" stopColor="#4a86a8" />
          <stop offset=".7" stopColor="#f4b48c" />
          <stop offset=".82" stopColor="#fbd9a8" />
        </linearGradient>
        <linearGradient id="sea" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#f2b58a" />
          <stop offset=".35" stopColor="#2a5a7a" />
          <stop offset="1" stopColor="#0b2842" />
        </linearGradient>

        {/* s3 — night city with lit windows. */}
        <linearGradient id="k3" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#050a1c" />
          <stop offset=".55" stopColor="#1b2a5c" />
          <stop offset=".85" stopColor="#8a5a8f" />
        </linearGradient>

        {/* s4 — forest ridge with fog bands. */}
        <linearGradient id="k4" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#d6e8dc" />
          <stop offset=".5" stopColor="#8fb09a" />
          <stop offset="1" stopColor="#2c4a3c" />
        </linearGradient>
        <linearGradient id="fg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0" />
          <stop offset=".5" stopColor="#fff" stopOpacity=".5" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>

        {/* Pattern of tiny lit windows — fills the night-city buildings. */}
        <pattern id="wd" width="9" height="12" patternUnits="userSpaceOnUse">
          <rect x="2" y="3" width="3" height="4" fill="#ffd98a" />
        </pattern>

        {/* Skyline silhouette — reused twice (solid + window pattern). */}
        <path
          id="bl"
          d="M0 170h46v130H0z M40 130h40v170H40z M82 190h50v110H82z M128 110h44v190h-44z M176 160h52v140h-52z M224 95h38v205h-38z M266 150h48v150h-48z M310 120h44v180h-44z M352 170h48v130h-48z"
        />

        {/* ── Fictional photos (400×300 viewBox each) ──────────────── */}

        <symbol id="s1" viewBox="0 0 400 300">
          <rect width="400" height="300" fill="url(#k1)" />
          <circle cx="280" cy="170" r="75" fill="url(#sn)" />
          <path
            d="M0 172 L48 136 L92 162 L142 116 L202 166 L252 140 L322 174 L400 148 V215 H0Z"
            fill="#6a5290"
            opacity=".8"
          />
          <path
            d="M0 198 L70 152 L122 186 L192 140 L262 192 L332 160 L400 198 V232 H0Z"
            fill="#3b3566"
          />
          <rect y="206" width="400" height="94" fill="url(#lk)" />
          <ellipse cx="280" cy="224" rx="52" ry="3.5" fill="#fff2c4" opacity=".75" />
          <ellipse cx="282" cy="236" rx="34" ry="2.5" fill="#ffe2a0" opacity=".5" />
          <ellipse cx="278" cy="248" rx="20" ry="2" fill="#ffd38a" opacity=".35" />
          <path d="M0 264 Q90 234 170 264 T400 254 V300 H0Z" fill="#0f1430" />
          <path
            d="M38 272 L52 230 L66 272Z M62 274 L78 218 L94 274Z M326 270 L341 226 L356 270Z"
            fill="#090d22"
          />
          <rect width="400" height="300" filter="url(#gr)" opacity=".16" />
          <rect width="400" height="300" fill="url(#vg)" />
        </symbol>

        <symbol id="s2" viewBox="0 0 400 300">
          <rect width="400" height="300" fill="url(#k2)" />
          <circle cx="150" cy="192" r="70" fill="url(#sn)" />
          <circle cx="150" cy="192" r="22" fill="#fff1c9" />
          <rect y="196" width="400" height="104" fill="url(#sea)" />
          <ellipse cx="150" cy="212" rx="40" ry="3" fill="#fff0c2" opacity=".7" />
          <ellipse cx="152" cy="226" rx="26" ry="2.5" fill="#ffe0a0" opacity=".5" />
          <path d="M0 300 V244 Q36 222 74 250 Q104 268 128 300Z" fill="#0b1a2b" />
          <path d="M400 300 V208 Q352 198 322 242 Q302 274 282 300Z" fill="#10243a" />
          <path
            d="M230 90 q6 -6 12 0 q6 -6 12 0 M262 70 q5 -5 10 0 q5 -5 10 0"
            stroke="#1a2438"
            strokeWidth="2"
            fill="none"
          />
          <rect width="400" height="300" filter="url(#gr)" opacity=".16" />
          <rect width="400" height="300" fill="url(#vg)" />
        </symbol>

        <symbol id="s3" viewBox="0 0 400 300">
          <rect width="400" height="300" fill="url(#k3)" />
          <circle cx="332" cy="56" r="46" fill="url(#sn)" opacity=".5" />
          <circle cx="332" cy="56" r="13" fill="#f3f6ff" />
          <g fill="#fff" opacity=".7">
            <circle cx="40" cy="30" r="1.2" />
            <circle cx="110" cy="60" r="1" />
            <circle cx="190" cy="25" r="1.3" />
            <circle cx="250" cy="70" r="1" />
            <circle cx="70" cy="95" r="1" />
          </g>
          <use href="#bl" fill="#0a1022" />
          <use href="#bl" fill="url(#wd)" opacity=".75" />
          <rect width="400" height="300" filter="url(#gr)" opacity=".18" />
          <rect width="400" height="300" fill="url(#vg)" />
        </symbol>

        <symbol id="s4" viewBox="0 0 400 300">
          <rect width="400" height="300" fill="url(#k4)" />
          <path
            d="M0 210 L22 140 L44 214 L64 150 L88 218 L112 128 L138 220 L162 146 L188 222 L214 122 L242 224 L268 150 L296 220 L322 134 L350 226 L376 156 L400 214 V300 H0Z"
            fill="#5f8a74"
            opacity=".6"
          />
          <rect y="150" width="400" height="90" fill="url(#fg)" />
          <path
            d="M0 240 L30 150 L62 244 L88 160 L120 250 L152 138 L186 252 L214 166 L248 250 L282 142 L316 252 L346 162 L378 246 L400 200 V300 H0Z"
            fill="#3d6b55"
          />
          <rect y="190" width="400" height="80" fill="url(#fg)" />
          <path
            d="M-10 300 L20 170 L56 300Z M40 300 L84 130 L130 300Z M290 300 L338 120 L386 300Z M360 300 L396 190 L420 300Z"
            fill="#14281f"
          />
          <path d="M150 0 L210 0 L120 300 L40 300Z" fill="#fff" opacity=".07" />
          <rect width="400" height="300" filter="url(#gr)" opacity=".16" />
          <rect width="400" height="300" fill="url(#vg)" />
        </symbol>
      </defs>
    </svg>
  );
}
