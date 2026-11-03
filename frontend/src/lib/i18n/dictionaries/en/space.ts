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

  /**
   * Upload — the dialog shell (header, description, connect prompt).
   * The pipeline body lives in `UploadOrchestrator` (rewired in
   * Fase 10 to read from `WalletContext`).
   */
  upload: {
    button: "Upload",
    dialogTitle: "Upload photos",
    dialogDescription: "Locked on your device. Kept in many places.",
    connectPrompt: "Connect a wallet to upload.",
    connectButton: "Connect wallet",
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
};
