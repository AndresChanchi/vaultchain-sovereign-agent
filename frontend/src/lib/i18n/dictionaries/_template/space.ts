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

    oauthGateTitle: "TODO translate: Only wallets can upload",
    oauthGateBody:
      "TODO translate: Photos need a wallet that can sign. Sign in with a wallet to add photos to your space.",
    oauthGateAction: "TODO translate: Switch to a wallet",

    reviewTitle: "TODO translate: Review",
    reviewOfTotal: "TODO translate: {current} of {total}",
    reviewLockedNote:
      "TODO translate: Locked on your device. Nothing has left it yet.",
    reviewTermsLabel: "TODO translate: How long to keep them",
    reviewTerm30: "TODO translate: 30 days",
    reviewTerm1y: "TODO translate: 1 year",
    reviewTermForever: "TODO translate: Forever",
    reviewTermFutureHint: "TODO translate: Only with the new contract",
    reviewTermsHint:
      "TODO translate: Not every photo needs forever. Shorter costs less. You can extend any time, but never shorten.",
    reviewStorageLabel:
      "TODO translate: Storage · set by the network",
    reviewFeeLabel: "TODO translate: Kipio fee",
    reviewTotalLabel: "TODO translate: Total",
    reviewPriceLoading: "—",
    reviewEachPhotoNote:
      "TODO translate: Each photo is optimized and stored on its own.",
    reviewContinue: "TODO translate: Continue",
    reviewBack: "TODO translate: Back",

    progressTitle: "TODO translate: Uploading",
    progressCurrentFile: "TODO translate: Uploading {name}",
    progressOfTotal: "TODO translate: {current} of {total}",
    progressItemLocked: "TODO translate: Locked on your device",
    progressItemKept: "TODO translate: Kept in many places",
    progressItemNoted: "TODO translate: Noted by the blind notary",
    progressWaiting: "TODO translate: Waiting for approval…",
    progressKeepOpen:
      "TODO translate: Keep this tab open until it finishes.",

    keptTitle: "TODO translate: Kept. They are yours.",
    keptStepDone: "TODO translate: Done",
    keptBody:
      "TODO translate: Locked, noted and stored in many places. Only you can open them.",
    keptOwnerLabel: "TODO translate: Owner",
    keptIrysLabel: "TODO translate: Photo",
    keptOpenSpace: "TODO translate: Open my space",
    keptUploadMore: "TODO translate: Upload more",

    error: {
      oauth:
        "TODO translate: Wallets can upload. Switch accounts to add photos.",
      unlock:
        "TODO translate: Could not unlock your space. Try again.",
      imageWorker:
        "TODO translate: The image optimizer did not load. Refresh and try again.",
      irysInit:
        "TODO translate: Could not reach the storage network. Try again.",
      funding:
        "TODO translate: Could not fund the upload. Check your wallet and try again.",
      irysUpload:
        "TODO translate: The storage network rejected the upload. Try again.",
      register:
        "TODO translate: The photo was uploaded but could not be recorded. Contact support.",
      wrongChain:
        "TODO translate: Your wallet is on a different network. Switch back to try again.",
      generic: "TODO translate: Something went wrong. Try again.",
      retry: "TODO translate: Try again",
      cancel: "TODO translate: Cancel",
    },
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

  overview: {
    greeting: "TODO translate: Welcome back.",
    subtitle: "TODO translate: Everything is locked and kept.",
    keptLabel: "TODO translate: Photos kept",
    recentTitle: "TODO translate: Recent uploads",
    viewAll: "TODO translate: View all",
    galleryError: "TODO translate: Could not load your photos.",
    galleryEmpty: "TODO translate: No photos yet.",
    quickActionsLabel: "TODO translate: Quick actions",
    quickUpload: "TODO translate: Upload photos",
    quickShare: "TODO translate: Share an album",
    quickBackup: "TODO translate: Back up your access",
    unlockTitle: "TODO translate: Unlock your space",
    unlockBodyWallet:
      "TODO translate: Sign with your wallet to unlock your photos. This is local — nothing leaves your device.",
    unlockAction: "TODO translate: Unlock space",
    unlocking: "TODO translate: Unlocking…",
    unlockError: "TODO translate: Could not unlock your space. Try again.",
  },
};
