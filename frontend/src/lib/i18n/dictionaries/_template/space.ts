/**
 * Space surface (authenticated) — translation template.
 *
 * Copy the whole `_template/` folder to `dictionaries/<code>/`,
 * translate every `TODO translate:`, and add `<code>` to `LOCALES` +
 * `AVAILABLE_LOCALES` in `locales.ts`.
 *
 * Provider names (MetaMask, Brave Wallet, Rabby, Ledger, Google, X,
 * Microsoft, Apple, GitHub, Twitch) are pre-filled as-is.
 */

export const space = {
  sidebar: {
    navLabel: "TODO translate: Space navigation",
    home: "TODO translate: Home",
    library: "TODO translate: Library",
    moments: "TODO translate: Moments",
    shared: "TODO translate: Shared",
    offers: "TODO translate: Offers",
    settings: "TODO translate: Settings",
    comingSoon: "TODO translate: Coming in a later phase",
    signOut: "TODO translate: Sign out",
    collapse: "TODO translate: Collapse sidebar",
    expand: "TODO translate: Expand sidebar",
  },

  dock: {
    navLabel: "TODO translate: Space navigation",
    upload: "TODO translate: Upload",
  },

  account: {
    menuLabel: "TODO translate: Account menu",
    walletMetamask: "MetaMask",
    walletBrave: "Brave Wallet",
    walletRabby: "Rabby",
    walletLedger: "Ledger",
    walletInjected: "TODO translate: Wallet",
    oauthGoogle: "Google",
    oauthX: "X",
    oauthMicrosoft: "Microsoft",
    oauthApple: "Apple",
    oauthGithub: "GitHub",
    oauthTwitch: "Twitch",
  },

  speculos: {
    title: "TODO translate: Ledger Simulator active",
    body: "TODO translate: Approve every transaction on the emulator screen.",
    open: "TODO translate: Open emulator",
  },

  header: {
    searchPlaceholder: "TODO translate: Search your photos",
    searchShortcut: "⌘K",
  },

  upload: {
    button: "TODO translate: Upload",
    dialogTitle: "TODO translate: Upload photos",
    dialogDescription:
      "TODO translate: Locked on your device. Kept in many places.",
    connectPrompt: "TODO translate: Connect a wallet to upload.",
    connectButton: "TODO translate: Connect wallet",
  },

  welcome: {
    eyebrow: "TODO translate: Your space is ready",
    headlineFirst: "TODO translate: It is empty.",
    headlineSecond: "TODO translate: Not for long.",
    description:
      "TODO translate: See what happens to a photo here. Try a sample first. Nothing is recorded until you upload.",
    ctaExplore: "TODO translate: Look around first",
    ctaUpload: "TODO translate: Upload your first photos",
    keptByOthers: "TODO translate: photos kept by people like you",
    starter: {
      onePhoto: {
        label: "TODO translate: 1 photo",
        title: "TODO translate: Keep your first photo",
        body:
          "TODO translate: Locked on your device, kept in many places.",
      },
      fivePhotos: {
        label: "TODO translate: 5 photos",
        title: "TODO translate: Unlock your first Moment",
        body:
          "TODO translate: Kipio builds it privately, only for you.",
      },
      share: {
        label: "TODO translate: Share",
        title: "TODO translate: Share with someone",
        body: "TODO translate: Invite them. Stop any time.",
      },
    },
  },
};
