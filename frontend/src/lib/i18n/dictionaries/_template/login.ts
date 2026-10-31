/**
 * Login surface — translation template.
 *
 * Starting a new locale
 *   1. Copy `dictionaries/_template/` → `dictionaries/<code>/` and
 *      `dictionaries/_template.ts` → `dictionaries/<code>.ts`.
 *   2. Translate every `TODO translate:` in this file.
 *   3. Add `<code>` to `LOCALES`, `LOCALE_META` and
 *      `AVAILABLE_LOCALES` in `locales.ts`.
 *   4. Add `case "<code>"` to `loadDictionary` in `I18nContext.tsx`.
 *
 * Proper nouns
 *   Provider names (Google, X, Microsoft, Apple, GitHub, Twitch,
 *   MetaMask, Brave Wallet, Rabby, Ledger) are pre-filled as-is. They
 *   are brand names and stay identical across locales unless the
 *   provider itself uses a different name in that market.
 *
 * Placeholders
 *   No `{placeholder}` variables in this file today. If a future key
 *   introduces one (e.g. `{count}`), keep it verbatim in the
 *   translation.
 *
 * Register
 *   Match the tone established in `es/login.ts`: second person
 *   singular, sentence case, no exclamations, no emoji. Keep copy
 *   short — these strings live in a 392px panel.
 *
 * Parity
 *   The `satisfies Dictionary` clause in `_template.ts` (the
 *   aggregator) is what enforces parity against `en/login.ts`.
 *   Missing keys and dropping keys are caught at the aggregate. Keep
 *   this file free of `satisfies` and free of `types.ts` imports — the
 *   feature file stays pure data.
 */

export const login = {
  title: "TODO translate: Log in to Kipio",
  subtitle: "TODO translate: Choose how. You can add more ways later.",
  close: "TODO translate: Close",

  social: {
    label: "TODO translate: Continue with",
    google: "Google",
    x: "X",
    microsoft: "Microsoft",
    apple: "Apple",
    github: "GitHub",
    twitch: "Twitch",
  },

  provider: {
    github: {
      relay:
        "TODO translate: GitHub needs a secure relay to finish sign-in. It will be available when the serverless relay ships.",
    },
    apple: {
      relay:
        "TODO translate: Apple needs a secure relay to finish sign-in. It will be available when the serverless relay ships.",
    },
  },

  passkey: {
    label: "TODO translate: Use a passkey",
    disabledReason:
      "TODO translate: Passkeys need a secure relay and the contract-level binding. Both are on the way.",
    unsupported:
      "TODO translate: This browser does not support passkeys. You can use a wallet or a social account.",
  },

  wallet: {
    label: "TODO translate: Or use a wallet",
    badge: "Web3",
    detected: "TODO translate: Detected",
    install: "TODO translate: Install",
    more: "TODO translate: More wallets",
    moreTitle: "TODO translate: Wallets detected on this browser",
    empty:
      "TODO translate: No wallet detected. Install a wallet extension, or open this page in a browser that has one.",
    metamask: "MetaMask",
    brave: "Brave Wallet",
    rabby: "Rabby",
    ledger: "Ledger",
    ledgerConnect: "TODO translate: Connect Ledger",
    ledgerError:
      "TODO translate: Could not reach the Ledger device. Check the connection and try again.",
  },

  error: {
    generic: "TODO translate: Something went wrong. Try again.",
    rejected: "TODO translate: The request was cancelled.",
    noAccount:
      "TODO translate: No account was returned by the provider. Try another way in.",
    network:
      "TODO translate: The network is not reachable right now. Try again in a moment.",
    unsupported:
      "TODO translate: This sign-in method is not available yet. Try another way in.",
  },

  footer:
    "TODO translate: We never see your photos. Logging in does not tell the networks your name.",
};
