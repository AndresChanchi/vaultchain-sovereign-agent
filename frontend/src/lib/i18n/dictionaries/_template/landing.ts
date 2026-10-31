/**
 * Translation template — copy this folder to `<locale>/` and fill the
 * values in. Do not import or ship this file directly. Its twin
 * `_template.ts` (the aggregator) shows how the pieces fit together;
 * both are copied when a new locale is added.
 *
 * Workflow (full version; this file is step 2)
 *   1. `cp -r dictionaries/_template dictionaries/zh`
 *      `cp dictionaries/_template.ts dictionaries/zh.ts`
 *      (and fix the aggregator's `import { landing } from "./_template/landing"`
 *       to `"./zh/landing"`; also `export const xx` → `export const zh`).
 *   2. Replace `TODO translate` markers in `zh/landing.ts` with the
 *      target-language string. Keep placeholders (`{count}`, `{year}`,
 *      `{index}`, `{total}`, `{title}`) verbatim — the translate
 *      function looks them up by name.
 *   3. Keep the structure identical to `en/landing.ts`. The
 *      aggregator's `satisfies Dictionary` (in `zh.ts`) will fail the
 *      build if any key is missing or extra.
 *   4. Add the code to `LOCALES` and `LOCALE_META` in `locales.ts`,
 *      and to `AVAILABLE_LOCALES`.
 *   5. Add a `case "zh"` in `I18nContext.tsx`'s `loadDictionary`.
 *   6. Run `bun run build` — the picker shows the new locale without
 *      any other change.
 *
 * AI-assisted translation — recommended prompt
 *   Attach `en/landing.ts` + `es/landing.ts` as context and ask for
 *   the target locale. The JSDoc in `en/landing.ts` carries the
 *   *intent* of each string (voice, product vocabulary,
 *   placeholders). `es/landing.ts` demonstrates the required shape
 *   and the translation voice. Do not paraphrase the intent; do
 *   translate the strings.
 *
 *   For Arabic (`ar`): set `dir: "rtl"` in `LOCALE_META` and verify
 *   that the RTL layout of the navbar/picker still works. The
 *   dictionaries themselves have no direction markers — CSS `dir`
 *   handles mirroring.
 *
 *   For Chinese, Japanese and Korean: `Intl.PluralRules` will return
 *   `other` for every count, so the plural forms in the `one` field
 *   are unused. Keep the `other` value honest.
 *
 * Proper nouns to leave untouched
 *   "Arbitrum", "Irys", "MetaMask", "Brave Wallet", "Rabby", "Ledger",
 *   "iPhone", "Android", "Windows", "Mac", "Google", "Apple",
 *   "Microsoft", "Passkey", "Kipio". Only the labels around them are
 *   translated.
 */

export const landing = {
  navbar: {
    openSpace: "TODO translate: Open your space",
    signOut: "TODO translate: Sign out",
    howItWorks: "TODO translate",
    docs: "TODO translate",
    language: "XX", // Replace with the short code for this locale (e.g. "中文", "DE").
    logIn: "TODO translate",
    openMenu: "TODO translate",
    closeMenu: "TODO translate",
    themeToggle: "TODO translate",
    changeLanguage: "TODO translate",
  },

  hero: {
    eyebrow: "TODO translate",
    title: "TODO translate",
    subtitle: "TODO translate",
    lede: "TODO translate",
    dropPhoto: "TODO translate",
    uploadCta: "TODO translate",
    noAccount: "TODO translate", // Keep the {count} placeholder.
    orLookAround: "TODO translate",
  },

  journey: {
    eyebrow: "TODO translate",
    title: "TODO translate",
    subtitle: "TODO translate",
    steps: [
      { title: "TODO translate", body: "TODO translate", hood: "TODO translate" },
      { title: "TODO translate", body: "TODO translate", hood: "TODO translate" },
      { title: "TODO translate", body: "TODO translate", hood: "TODO translate" },
      { title: "TODO translate", body: "TODO translate", hood: "TODO translate" },
    ],
    previous: "TODO translate",
    pause: "TODO translate",
    play: "TODO translate",
    next: "TODO translate",
    showStep: "TODO translate", // Keep {index}, {total}, {title}.
    stepsLabel: "TODO translate",

    slideOverlays: {
      optimize: {
        sizeLabel: "TODO translate",
        priceLabel: "TODO translate",
        chip: "TODO translate", // Keep the " · " separator.
      },
      lock: {
        chip: "TODO translate",
      },
      notary: {
        eyebrow: "TODO translate", // Keep the " · " separator; sentence case.
        ownerLabel: "TODO translate",
        contentLabel: "TODO translate",
        nameLabel: "TODO translate",
        typeLabel: "TODO translate",
        cannotSee: "TODO translate",
      },
      network: {
        chip: "TODO translate",
      },
    },
  },

  liveStats: {
    eyebrow: "TODO translate",
    subtitle: "TODO translate",
    photosKept: "TODO translate",
    spacesOpened: "TODO translate",
    dataStored: "TODO translate",
    photosShared: "TODO translate",
    notAvailable: "—", // Do not translate.
    unitGb: "GB", // Do not translate.
  },

  notOnServers: {
    eyebrow: "TODO translate",
    title: "TODO translate",
    lede: "TODO translate",
    ledeEmphasis: "TODO translate",
    bullets: [
      { title: "TODO translate", body: "TODO translate" },
      { title: "TODO translate", body: "TODO translate" },
      { title: "TODO translate", body: "TODO translate" },
      { title: "TODO translate", body: "TODO translate" },
    ],
    networkViz: {
      arbitrumLabel: "Arbitrum", // Proper noun — do not translate.
      arbitrumAnnotation: "TODO translate",
      lockedCopies: "TODO translate", // Keep the " · " separator.
      irysLabel: "Irys", // Proper noun — do not translate.
      irysAnnotation: "TODO translate",
    },
  },

  pricing: {
    termFallbackNote: "TODO translate",
    calculating: "TODO translate",
    feePreviewNote: "TODO translate",
    priceUnavailable: "TODO translate",
    unitKb: "KB",
    unitMb: "MB",
    unitGb: "GB",
    unitTb: "TB",
    sizeLabel: "TODO translate",
    sizeHint: "TODO translate",
    currencyLabel: "TODO translate",
    eyebrow: "TODO translate",
    title: "TODO translate",
    subtitle: "TODO translate",
    terms: {
      days30: "TODO translate",
      year1: "TODO translate",
      forever: "TODO translate",
    },
    shorterCostsLess: "TODO translate",
    storageLabel: "TODO translate", // Keep the " · " separator.
    feeLabel: "TODO translate",
    totalLabel: "TODO translate",
    sponsorNote: "TODO translate",
    pending: "—", // Do not translate.
  },

  sovereign: {
    eyebrow: "TODO translate",
    statements: [
      { title: "TODO translate", body: "TODO translate", bodyEmphasis: "TODO translate", bodyAfter: "TODO translate" },
      { title: "TODO translate", body: "TODO translate", bodyEmphasis: "TODO translate", bodyAfter: "TODO translate" },
      { title: "TODO translate", body: "TODO translate", bodyEmphasis: "TODO translate", bodyAfter: "TODO translate" },
      { title: "TODO translate", body: "TODO translate", bodyEmphasis: "TODO translate", bodyAfter: "TODO translate" },
    ],
  },

  anyDevice: {
    eyebrow: "TODO translate",
    title: "TODO translate",
    subtitle: "TODO translate",
    devices: ["iPhone", "Android", "Windows", "Mac", "Web"], // Product names.
  },

  openByDesign: {
    repoAriaLabel: "TODO translate", // Keep the {title} placeholder.
    eyebrow: "TODO translate",
    title: "TODO translate",
    paragraph1: "TODO translate",
    paragraph2: "TODO translate",
    paragraph2Emphasis: "TODO translate",
    paragraph2After: "TODO translate",
    repos: [
      { slug: "[org]/contracts", title: "TODO translate", body: "TODO translate", view: "TODO translate" },
      { slug: "[org]/frontend", title: "TODO translate", body: "TODO translate", view: "TODO translate" },
      { slug: "[org]/docs", title: "TODO translate", body: "TODO translate", view: "TODO translate" },
    ],
  },

  economy: {
    eyebrow: "TODO translate",
    title: "TODO translate",
    subtitle: "TODO translate",
    bars: [
      { label: "TODO translate", pct: "[X]%" },
      { label: "TODO translate", pct: "[X]%" },
      { label: "TODO translate", pct: "[X]%" },
    ],
    illustrative: "TODO translate",
    subsidy: {
      eyebrow: "TODO translate",
      amount: "USD [X]", // Currency code stays "USD"; translate only if the locale uses a different default.
      bodyBefore: "TODO translate",
      bodyEmphasis: "[N]",
      bodyAfter: "TODO translate",
      donate: "TODO translate",
      readContract: "TODO translate",
      disclaimer: "TODO translate",
      contract: "TODO translate",
    },
  },

  signIn: {
    eyebrow: "TODO translate",
    title: "TODO translate",
    subtitle: "TODO translate",
    methods: ["TODO translate", "TODO translate", "X", "TODO translate", "TODO translate", "Passkey"],
    wallets: ["MetaMask", "Brave Wallet", "Rabby", "Ledger"], // Product names.
    cardTitle: "TODO translate",
    cardBody: "TODO translate",
  },
  
  footer: {
    contractPrefix: "TODO translate",
    contractAriaLabel: "TODO translate", // Keep the {address} placeholder.
    navAriaLabel: "TODO translate",
    docs: "TODO translate",
    github: "GitHub", // Proper noun — do not translate.
    arbitrum: "Arbitrum", // Proper noun.
    irys: "Irys", // Proper noun.
    copyright: "© {year} Kipio", // Keep the {year} placeholder; reorder "©", "Kipio" and the placeholder if the target locale prefers a different reading order.
  },
};
