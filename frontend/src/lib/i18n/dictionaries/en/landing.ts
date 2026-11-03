/**
 * English — landing strings.
 *
 * The single file for every visible word on the landing page. Nested
 * by section, one group per component under `components/landing/`:
 *
 *   landing.navbar        ↔ components/landing/navbar.tsx
 *   landing.hero          ↔ components/landing/hero.tsx
 *   landing.journey       ↔ components/landing/journey-stage.tsx (+ journey-samples.tsx)
 *   landing.liveStats     ↔ components/landing/live-stats.tsx
 *   landing.notOnServers  ↔ components/landing/not-on-servers.tsx (+ network-viz.tsx)
 *   landing.pricing       ↔ components/landing/pricing-card.tsx (+ wrapper in (public)/page.tsx)
 *   landing.sovereign     ↔ components/landing/sovereign.tsx
 *   landing.anyDevice     ↔ components/landing/any-device.tsx
 *   landing.openByDesign  ↔ components/landing/open-by-design.tsx
 *   landing.economy       ↔ components/landing/economy.tsx
 *   landing.signIn        ↔ components/landing/sign-in.tsx
 *   landing.footer        ↔ components/landing/footer.tsx
 *
 * The 1:1 mapping is intentional. When a new section is added to the
 * landing, its file name becomes the group name here. When the app
 * grows (dashboard, settings, docs, …), each becomes its own file at
 * `dictionaries/en/<feature>.ts`; this file stays small.
 *
 * Conventions (identical to the previous monolithic en.ts — kept here
 * so a translator reading only this file has the full context)
 *   - `{placeholder}` marks interpolated values. Regex accepted:
 *     `\w+` (letters, digits, underscore). `t("key", { count: 3 })`
 *     replaces `{count}`.
 *   - Emphasis is expressed as separate keys (`lede` + `ledeEmphasis`)
 *     so translators can reorder fragments freely.
 *   - Every section carries JSDoc listing its purpose and placeholders.
 *   - Plain digits, no thousands separators inside strings — number
 *     formatting goes through `format.number` / `format.currency`.
 *   - Sentence case everywhere. No trailing punctuation on labels,
 *     eyebrows, buttons or headings.
 *
 * This file does NOT use `as const`. Rationale: `Dictionary` is
 * derived from the aggregate `en.ts` via `typeof en`. With `as const`,
 * each string would be a literal type (`"How it works"`), which would
 * make every other locale fail `satisfies Dictionary` because no
 * translation can equal that literal. Without `as const`, strings
 * widen to `string` and the structural check passes. Arrays still
 * widen to `string[]`, which `Path<T>` excludes from valid keys — the
 * iterable arrays (`steps`, `methods`, `wallets`, `devices`, `repos`,
 * `bullets`, `statements`, `bars`) are read via `.map()` in the
 * component, never via `t()`.
 */

export const landing = {
  /**
   * Landing — navigation bar.
   * Strings visible on every viewport: the two desktop anchors, the
   * language-picker button label ("EN" in English), the login CTA.
   *
   * `language` is the short code inside the trigger — overridden per
   * locale in that locale's own dictionary (e.g. `es/landing.ts` uses
   * `"ES"`). Kept here as the English fallback.
   *
   * `changeLanguage` is the aria-label of the trigger button and the
   * menu. It describes the action, not the state, which is what a
   * screen reader announces when the user focuses the button.
   */
  navbar: {
    openSpace: "Open your space",
    signOut: "Sign out",
    howItWorks: "How it works",
    docs: "Docs",
    language: "EN",
    logIn: "Log in",
    openMenu: "Open menu",
    closeMenu: "Close menu",
    themeToggle: "Change theme",
    changeLanguage: "Change language",
  },

  /**
   * Landing — hero.
   * The first screen: eyebrow, headline, subtitle, lede, drop-zone
   * copy and ghost link. `uploadCta` is the primary button.
   * `noAccount` uses `{count}` for the batch limit — resolved from
   * `MAX_BATCH_SIZE` in `hero.tsx`, not from the dictionary.
   */
  hero: {
    eyebrow: "Digital property, not rental",
    title: "Your photos are yours.",
    subtitle: "The intelligence built on them is yours too.",
    lede:
      "Locked on your device, recorded as yours, kept forever. No subscription, and nobody else holds the key.",
    dropPhoto: "Drop a photo here",
    uploadCta: "Upload your first photo",
    noAccount: "No account needed to start. Choose up to {count} photos at once.",
    orLookAround: "Or look around first",
  },

  /**
   * Landing — journey stage.
   * The 3D carousel of four steps. `steps[i]` is the caption below
   * the stage; `slideOverlays` is the annotation drawn inside each
   * card. Both mirror the four `SlideX` sub-components of
   * `journey-stage.tsx`, in that order.
   *
   * Transport strings (`previous`, `pause`, `play`, `next`,
   * `showStep`, `stepsLabel`) drive the controls below the stage.
   * `showStep` uses `{index}`, `{total}`, `{title}`.
   *
   * `" · "` in `slideOverlays.*.chip` and `.notary.eyebrow` is a
   * decorative separator — translate the words around it, keep the
   * character. `notary.eyebrow` renders uppercase via CSS; keep the
   * source in sentence case so non-Latin scripts are not mangled.
   *
   * Placeholders: only `showStep`.
   */
  journey: {
    eyebrow: "How it works",
    title: "Your photo's journey.",
    subtitle:
      "One approval, and all four steps happen together. If one fails, none of them do.",
    steps: [
      {
        title: "Each photo, optimized.",
        body:
          "Every photo is tidied and made lighter on your device, then stored on its own.",
        hood: "Under the hood · per-photo optimization",
      },
      {
        title: "Locked on your device.",
        body: "Scrambled with a key only you hold, before anything leaves.",
        hood: "Under the hood · symmetric encryption",
      },
      {
        title: "Noted by a blind notary.",
        body:
          "A public contract records that it is yours. It cannot see what it is.",
        hood: "Under the hood · Arbitrum smart contract",
      },
      {
        title: "Kept in many places.",
        body:
          "Locked copies on computers around the world, for good or for the time you choose. Nobody hosting one can see inside.",
        hood: "Under the hood · Irys storage network",
      },
    ],
    previous: "Previous step",
    pause: "Pause",
    play: "Play",
    next: "Next step",
    showStep: "Show step {index} of {total}: {title}",
    stepsLabel: "Journey steps",

    slideOverlays: {
      optimize: {
        sizeLabel: "Size",
        priceLabel: "Price",
        chip: "Optimized · one photo at a time",
      },
      lock: {
        chip: "Key stays on this device",
      },
      notary: {
        eyebrow: "Public notary · smart contract",
        ownerLabel: "owner",
        contentLabel: "content",
        nameLabel: "name",
        typeLabel: "type",
        cannotSee: "It cannot see inside.",
      },
      network: {
        chip: "Locked copies, worldwide",
      },
    },
  },

  /**
   * Landing — live stats.
   * The glass panel summarising contract event counts. `notAvailable`
   * is the placeholder rendered when a figure has not yet been
   * computed (`—`). `unitGb` is the suffix shown for `dataStored`.
   */
  liveStats: {
    eyebrow: "Live from the network",
    subtitle: "Counted from public contract events. No names. No files.",
    photosKept: "Photos kept",
    spacesOpened: "Spaces opened",
    dataStored: "Data stored",
    photosShared: "Photos shared",
    notAvailable: "—",
    unitGb: "GB",
  },

  /**
   * Landing — "Not on our servers".
   * Two-column section with the network viz. `lede` and
   * `ledeEmphasis` render in the same paragraph (the emphasis half
   * carries the emerald colour). `bullets[i]` are the four cards
   * below the lede.
   *
   * `networkViz` holds the three floating chips over the SVG in
   * `network-viz.tsx`. The `<svg>` itself has no text nodes — every
   * visible word in that panel comes from this block.
   *
   * "Arbitrum" and "Irys" are proper nouns — stay unchanged in every
   * locale. The annotation after the separator is what gets
   * translated. `lockedCopies` keeps its " · " separator.
   */
  notOnServers: {
    eyebrow: "Not on our servers",
    title: "Your photo lives on many computers. None of them is ours.",
    lede: "Every copy is locked before it leaves your device.",
    ledeEmphasis:
      "The computers that keep it cannot see it. Neither can Kipio, or the protocol. Only you can.",
    bullets: [
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
        body:
          "Irys today. Arweave or Filecoin tomorrow, if they serve you better.",
      },
    ],
    networkViz: {
      arbitrumLabel: "Arbitrum",
      arbitrumAnnotation: "who it belongs to",
      lockedCopies: "Locked copies · only your key opens them",
      irysLabel: "Irys",
      irysAnnotation: "where it is kept",
    },
  },

  /**
   * Landing — pricing section.
   * Consumed by `pricing-card.tsx` and by the `<Pricing>` wrapper in
   * `(public)/page.tsx`. `pending` is the placeholder used where a
   * value is not yet known (`[PRICE]`, `[FEE]` — these are visual
   * labels, not dictionary placeholders). `sponsorNote` appears when
   * the upload is covered by the subsidy pool.
   */

  pricing: {
    termFallbackNote:
      "Term pricing is being finalized. Showing the permanent price as an upper bound; terms cost less.",
    calculating: "Calculating…",
    feePreviewNote:
      "During preview, the Kipio fee is 0%. It will be enabled when the economics contract activates.",
    priceUnavailable:
      "Live price unavailable. Retry in a moment.",
    unitKb: "KB",
    unitMb: "MB",
    unitGb: "GB",
    unitTb: "TB",
    sizeLabel: "Photo size",
    sizeHint: "Drag to see how much your upload costs.",
    currencyLabel: "Currency",
    eyebrow: "Honest pricing",
    title: "You pay what storing it really costs. Plus our fee, in the open.",
    subtitle:
      "We read the price from the storage network and show it to you. Then we add our fee. You pay per upload. Never a subscription.",
    terms: {
      days30: "30 days",
      year1: "1 year",
      forever: "Forever",
    },
    shorterCostsLess:
      "Shorter costs less. Photos cannot be deleted before their term ends, and you can extend any time.",
    storageLabel: "Storage · set by the network",
    feeLabel: "Kipio fee",
    totalLabel: "Total",
    sponsorNote:
      "Each photo is optimized and stored on its own. If a sponsor ever covers an upload, we tell you, and we tell you who pays.",
    pending: "—",
  },

  /**
   * Landing — sovereign panel.
   * Four statements in one glass panel. Each statement's body is split
   * in three parts: `body` (muted), `bodyEmphasis` (emerald),
   * `bodyAfter` (muted). `body` may be empty when the emphasis starts
   * the sentence.
   */
  sovereign: {
    eyebrow: "Sovereign by design",
    statements: [
      {
        title: "No master key.",
        body: "",
        bodyEmphasis: "We cannot open your photos",
        bodyAfter: ", even if asked.",
      },
      {
        title: "No monthly bill.",
        body: "Pay when you upload. ",
        bodyEmphasis: "Nothing lapses",
        bodyAfter: " and takes them away.",
      },
      {
        title: "Private, not anonymous.",
        body: "Your photos are ",
        bodyEmphasis: "fully private",
        bodyAfter:
          ". Your account is pseudonymous: public networks see an address, never your name. We cannot promise anonymity.",
      },
      {
        title: "Yours to share.",
        body: "Share with whoever you choose, ",
        bodyEmphasis: "without giving up your key",
        bodyAfter: ".",
      },
    ],
  },

  /**
   * Landing — "Any device".
   * Centred copy plus five chips naming the target platforms.
   * `devices` is a fixed list of five — the UI shows one chip per
   * entry, in order. Product names stay unchanged across locales.
   */
  anyDevice: {
    eyebrow: "Any device",
    title: "Your quality travels with you.",
    subtitle:
      "Take it on an iPhone, open it on Windows. Your original stays untouched, and you choose how to export: original or compatible.",
    devices: ["iPhone", "Android", "Windows", "Mac", "Web"],
  },

  /**
   * Landing — "Open by design".
   * Two paragraphs on the left, a three-row repos card on the right.
   * `paragraph2Emphasis` carries the emerald claim; `paragraph2After`
   * is the muted tail of the same sentence. `repos[i]` is the
   * three-row card: the mockup uses `[org]/…` as display slug until
   * the public org is live — `open-by-design.tsx` preserves that.
   */
  openByDesign: {
    repoAriaLabel: "{title} — View on GitHub",  
    eyebrow: "Open by design",
    title: "Works even if Kipio disappears.",
    paragraph1:
      "Your photos live on public networks, and the contracts that guard them are open. If we stopped tomorrow, your space would keep working. You could still open, move and share everything.",
    paragraph2: "",
    paragraph2Emphasis: "Kipio is open source.",
    paragraph2After:
      " Anyone can read the code and check how it is paid for.",
    repos: [
      {
        slug: "[org]/contracts",
        title: "Contracts",
        body: "How ownership is recorded",
        view: "View ↗",
      },
      {
        slug: "[org]/frontend",
        title: "Frontend",
        body: "The app you are using",
        view: "View ↗",
      },
      {
        slug: "[org]/docs",
        title: "Economics",
        body: "Fees, subsidy and where they go",
        view: "View ↗",
      },
    ],
  },

  /**
   * Landing — economy section.
   * Three allocation bars on the left, subsidy card on the right.
   * `bars[i].pct` is a string, not a number: the design system
   * renders `[X]` as an honest placeholder until the economics
   * contract is active. `subsidy.*` covers the card.
   */
  economy: {
    eyebrow: "Where the money goes",
    title: "No hidden business. See every dollar.",
    subtitle:
      "Storage is paid to the network that keeps your photos. Kipio adds a small fee for running the interface. A share of fees funds a universal subsidy, so more people can start for free.",
    bars: [
      { label: "Storage network", pct: "[X]%" },
      { label: "Kipio interface", pct: "[X]%" },
      { label: "Universal subsidy", pct: "[X]%" },
    ],
    illustrative: "Illustrative. Live numbers come straight from the contracts.",
    subsidy: {
      eyebrow: "Universal subsidy",
      amount: "USD [X]",
      bodyBefore: "in the pool today. Enough for ",
      bodyEmphasis: "[N]",
      bodyAfter: " first uploads.",
      donate: "Donate",
      readContract: "Read the contract",
      disclaimer:
        "Donations go to the protocol's subsidy pool, not to Kipio's team.",
      contract: "Contract 0x93b4…4F8a",
    },
  },

  /**
   * Landing — "Sign in however you like".
   * Two rows of chips + the "Your space" destination card.
   * `methods` are emerald, `wallets` are violet. `cardTitle` and
   * `cardBody` render inside the glass card below the connector.
   * Wallet and provider names stay unchanged across locales.
   */
  signIn: {
    eyebrow: "Any way in, one space",
    title: "Sign in however you like.",
    subtitle:
      "Email, social, passkey or a web3 wallet. Kipio never asks who you are, only that it is you.",
    methods: ["Email", "Google", "X", "Apple", "Microsoft", "Passkey"],
    wallets: ["MetaMask", "Brave Wallet", "Rabby", "Ledger"],
    cardTitle: "Your space",
    cardBody: "The same one, whichever way you came in.",
  },

  /**
   * Landing — footer.
   * One bar at the bottom: brand + contract short-link, four nav
   * links, copyright line. `copyright` uses `{year}` so the source
   * string is stable across years.
   *
   * `contractAriaLabel` is the full aria-label of the contract link;
   * the visible text is truncated to `CONTRACT_SHORT`, and the
   * placeholder `{address}` carries the full 42-character address
   * for screen readers and hover `title`. Translators should keep
   * the `{address}` placeholder even if they reorder the surrounding
   * words.
   *
   * `navAriaLabel` is the `<nav>` landmark name used by assistive
   * technology ("Footer" distinguishes it from the primary nav in
   * the header).
   */
  footer: {
    /** Prefix of the contract link. Full address is in `aria-label`. */
    contractPrefix: "Contract ",
    contractAriaLabel: "Contract {address} on Arbiscan",
    navAriaLabel: "Footer",
    docs: "Docs",
    github: "GitHub",
    arbitrum: "Arbitrum",
    irys: "Irys",
    copyright: "© {year} Kipio",
  },
};
