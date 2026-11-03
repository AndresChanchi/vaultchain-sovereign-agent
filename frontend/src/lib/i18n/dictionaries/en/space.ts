/**
 * Space surface (authenticated) — English.
 *
 * Covers every visible string in the authenticated shell:
 *   - sidebar / dock navigation labels
 *   - account card (brand labels + menu)
 *   - Speculos notice (Ledger Simulator sessions)
 *   - header (breadcrumb, search, upload)
 *   - welcome state (0 photos)
 *
 * Scream Architecture: this module is self-contained. Brand names
 * appear here rather than being imported from `landing.navbar.*` or
 * `login.social.*` — sharing a key would couple two surfaces, and a
 * rename in one would silently change the other.
 *
 * Register: consumer-facing English. Sentence case, no exclamations,
 * no emoji. Matches `landing.ts` and `login.ts`.
 *
 * No placeholders today. If a future key introduces `{count}` or
 * `{name}`, keep the placeholder verbatim in every locale.
 */

export const space = {
  /** Sidebar (desktop navigation, vertical). */
  sidebar: {
    navLabel: "Space navigation",
    home: "Home",
    library: "Library",
    moments: "Moments",
    shared: "Shared",
    offers: "Offers",
    settings: "Settings",
    comingSoon: "Coming in a later phase",
    signOut: "Sign out",
    collapse: "Collapse sidebar",
    expand: "Expand sidebar",
  },

  /** Dock (mobile navigation, horizontal, with central upload). */
  dock: {
    navLabel: "Space navigation",
    upload: "Upload",
  },

  /**
   * Account card — the identity panel at the bottom of the sidebar.
   * Brand names are proper nouns and stay untranslated. `menuLabel`
   * is the accessible name for the popover.
   */
  account: {
    menuLabel: "Account menu",
    walletMetamask: "MetaMask",
    walletBrave: "Brave Wallet",
    walletRabby: "Rabby",
    walletLedger: "Ledger",
    walletInjected: "Wallet",
    oauthGoogle: "Google",
    oauthX: "X",
    oauthMicrosoft: "Microsoft",
    oauthApple: "Apple",
    oauthGithub: "GitHub",
    oauthTwitch: "Twitch",
  },

  /** Speculos notice — shown to Ledger Simulator sessions. */
  speculos: {
    title: "Ledger Simulator active",
    body: "Approve every transaction on the emulator screen.",
    open: "Open emulator",
  },

  /**
   * Header — breadcrumb, search, upload. Search and upload are
   * disabled in 9.A with the `comingSoon` tooltip.
   */
  header: {
    searchPlaceholder: "Search your photos",
    searchShortcut: "⌘K",
  },

  upload: {
    button: "Upload",
    dialogTitle: "Upload photos",
    dialogDescription: "Locked on your device. Kept in many places.",

    // OAuth gate (10.4)
    oauthGateTitle: "Only wallets can upload",
    oauthGateBody:
      "Photos need a wallet that can sign. Sign in with a wallet to add photos to your space.",
    oauthGateAction: "Switch to a wallet",

    // Step 1 — Review
    reviewTitle: "Review",
    reviewOfTotal: "{current} of {total}",
    reviewLockedNote: "Locked on your device. Nothing has left it yet.",
    reviewTermsLabel: "How long to keep them",
    reviewTerm30: "30 days",
    reviewTerm1y: "1 year",
    reviewTermForever: "Forever",
    reviewTermFutureHint: "Only with the new contract",
    reviewTermsHint:
      "Not every photo needs forever. Shorter costs less. You can extend any time, but never shorten.",
    reviewStorageLabel: "Storage · set by the network",
    reviewFeeLabel: "Kipio fee",
    reviewTotalLabel: "Total",
    reviewPriceLoading: "—",
    reviewEachPhotoNote: "Each photo is optimized and stored on its own.",
    reviewContinue: "Continue",
    reviewBack: "Back",

    // Step 2 — Progress
    progressTitle: "Uploading",
    progressCurrentFile: "Uploading {name}",
    progressOfTotal: "{current} of {total}",
    progressItemLocked: "Locked on your device",
    progressItemKept: "Kept in many places",
    progressItemNoted: "Noted by the blind notary",
    progressWaiting: "Waiting for approval…",
    progressKeepOpen: "Keep this tab open until it finishes.",

    // Step 3 — Kept
    keptTitle: "Kept. They are yours.",
    keptStepDone: "Done",
    keptBody:
      "Locked, noted and stored in many places. Only you can open them.",
    keptOwnerLabel: "Owner",
    keptIrysLabel: "Photo",
    keptOpenSpace: "Open my space",
    keptUploadMore: "Upload more",

    // Errors
    error: {
      oauth: "Wallets can upload. Switch accounts to add photos.",
      unlock: "Could not unlock your space. Try again.",
      imageWorker: "The image optimizer did not load. Refresh and try again.",
      irysInit: "Could not reach the storage network. Try again.",
      funding: "Could not fund the upload. Check your wallet and try again.",
      irysUpload: "The storage network rejected the upload. Try again.",
      register: "The photo was uploaded but could not be recorded. Contact support.",
      wrongChain: "Your wallet is on a different network. Switch back to try again.",
      generic: "Something went wrong. Try again.",
      retry: "Try again",
      cancel: "Cancel",
    },
  },
 
  /** Welcome — 0-photo state (mockup `Welcome.dc.html`). */
  welcome: {
    eyebrow: "Your space is ready",
    headlineFirst: "It is empty.",
    headlineSecond: "Not for long.",
    description:
      "See what happens to a photo here. Try a sample first. Nothing is recorded until you upload.",
    ctaExplore: "Look around first",
    ctaUpload: "Upload your first photos",
    keptByOthers: "photos kept by people like you",
    starter: {
      onePhoto: {
        label: "1 photo",
        title: "Keep your first photo",
        body: "Locked on your device, kept in many places.",
      },
      fivePhotos: {
        label: "5 photos",
        title: "Unlock your first Moment",
        body: "Kipio builds it privately, only for you.",
      },
      share: {
        label: "Share",
        title: "Share with someone",
        body: "Invite them. Stop any time.",
      },
    },
  },

    /**
   * Overview — the state shown when the space has at least one
   * photo. Only `greeting` and `keptLabel` exist in 9.B; the rest
   * of the sections (quick actions, expiring soon, recent,
   * activity) add their keys as their sub-components ship.
   */
  overview: {
    greeting: "Welcome back.",
    subtitle: "Everything is locked and kept.",
    keptLabel: "Photos kept",
    recentTitle: "Recent uploads",
    viewAll: "View all",
    galleryError: "Could not load your photos.",
    galleryEmpty: "No photos yet.",
    quickActionsLabel: "Quick actions",
    quickUpload: "Upload photos",
    quickShare: "Share an album",
    quickBackup: "Back up your access",
    unlockTitle: "Unlock your space",
    unlockBodyWallet:
      "Sign with your wallet to unlock your photos. This is local — nothing leaves your device.",
    unlockAction: "Unlock space",
    unlocking: "Unlocking…",
    unlockError: "Could not unlock your space. Try again.",
  },
};
