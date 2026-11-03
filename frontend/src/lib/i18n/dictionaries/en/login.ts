/**
 * Login surface — English.
 *
 * Covers the panel rendered by the client-side intercepted login modal
 * and by the standalone `/login` fallback route. Strings are grouped by
 * visual block (header, social row, wallet list, passkey, footer) so a
 * translator can work section by section without losing context.
 *
 * Provider names (Google, Microsoft, MetaMask, …) are proper nouns and
 * stay untranslated by default. A translator may localise them only if
 * a market uses a different brand name — rare, but allowed.
 *
 * Provider status
 *   `provider.<id>.relay` is shown when the provider requires a
 *   server-side step that does not exist yet (GitHub needs a
 *   `client_secret` at token exchange; Apple needs an ES256-signed JWT
 *   as `client_secret`). Google, Microsoft, Twitch and X complete the
 *   Authorization Code + PKCE flow entirely in the browser.
 *
 *   The relay copy explains *why* the flow cannot complete, not a
 *   generic "coming soon". When the serverless relay ships, those keys
 *   are removed and the provider button connects to a real flow.
 *
 * No `as const`
 *   Same reason as `en.ts` — see its header. Leaf strings must widen
 *   to `string` so `es/login.ts` and the template can `satisfies
 *   Dictionary` with translated values.
 */

export const login = {
  /** Modal / page header. */
  title: "Log in to Kipio",
  subtitle: "Choose how. You can add more ways later.",
  close: "Close",

  /** Social / OAuth block — rendered as a grid. */
  social: {
    label: "Continue with",
    google: "Google",
    x: "X",
    microsoft: "Microsoft",
    apple: "Apple",
    github: "GitHub",
    twitch: "Twitch",
  },

  /**
   * Per-provider status when the flow cannot complete without a
   * server-side relay. Rendered as an inline note under the button,
   * shown on click (not on hover) so it is reachable on touch and by
   * keyboard.
   */
  provider: {
    github: {
      relay:
        "GitHub needs a secure relay to finish sign-in. It will be available when the serverless relay ships.",
    },
    apple: {
      relay:
        "Apple needs a secure relay to finish sign-in. It will be available when the serverless relay ships.",
    },
  },

  /** Passkey — independent cryptographic mechanism, not part of the grid. */
  passkey: {
    label: "Use a passkey",
    disabledReason:
       "Passkeys need a secure relay and the contract-level binding. Both are on the way.",
    unsupported:
      "This browser does not support passkeys. You can use a wallet or a social account.",
  },

  /** Wallet block. */
  wallet: {
    label: "Or use a wallet",
    badge: "Web3",
    detected: "Detected",
    install: "Install",
    more: "More wallets",
    moreTitle: "Wallets detected on this browser",
    empty:
      "No wallet detected. Install a wallet extension, or open this page in a browser that has one.",
    metamask: "MetaMask",
    brave: "Brave Wallet",
    rabby: "Rabby",
    ledger: "Ledger",
    ledgerConnect: "Connect Ledger",
    ledgerError:
      "Could not reach the Ledger device. Check the connection and try again.",
  },

  /** Session / provider feedback. Rendered inline, never as an alert. */
  error: {
    generic: "Something went wrong. Try again.",
    rejected: "The request was cancelled.",
    noAccount:
      "No account was returned by the provider. Try another way in.",
    network:
      "The network is not reachable right now. Try again in a moment.",
    unsupported:
      "This sign-in method is not available yet. Try another way in.",
  },

  /** Footer — identical to the mockup. */
  footer:
    "We never see your photos. Logging in does not tell the networks your name.",
};
