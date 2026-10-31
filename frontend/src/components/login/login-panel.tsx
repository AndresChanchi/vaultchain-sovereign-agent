"use client";

/**
 * Login panel — the composition rendered inside the login modal.
 *
 * Content (matches the mockup's step 2, adjusted per product decisions):
 *   - Header: KipioMark + title + close button.
 *   - Subtitle: "Choose how. You can add more ways later."
 *   - Social grid (3×2): Google, X, Microsoft, GitHub, Twitch, Passkey.
 *     Apple and Discord are omitted — Apple needs a server relay that
 *     does not exist yet; Discord is not in the current provider set.
 *   - Wallet divider: "Or use a wallet" / "Web3".
 *   - Wallet list: MetaMask, Brave, Rabby, Ledger + "More wallets".
 *   - Error banner (only when an error is pending and not a
 *     user-cancelled action).
 *   - Footer: the privacy line from the mockup.
 *
 * Email input — deliberately absent
 *   The mockup shows an email field followed by a "Continue" button.
 *   The product decision is OAuth-only: email OTP and magic links
 *   require a centralised backend that contradicts the static-frontend
 *   constraint. Email *sign-in* still exists — it is reached through
 *   Google / Microsoft OAuth, which is the correct implementation of
 *   "sign in with your email" on a static app.
 *
 * Error translation
 *   `WalletError.rawMessage` is English and can contain provider-level
 *   detail ("Token exchange failed (400): …"). Showing it directly
 *   breaks i18n and can leak technical strings. The panel maps the
 *   error's `code` to a translated string, and carries the raw
 *   message in the banner's `title` attribute for debugging (hover
 *   on desktop; assistive tech reads it as the accessible
 *   description).
 *
 *   `error.cancelled === true` is treated as a no-op — the user
 *   cancelled on purpose, so showing an error would be noise.
 *
 * Redirect on success
 *   The panel does not redirect on success. `LoginModal` observes
 *   `useWallet().status` and, when the modal was opened while signed
 *   out, closes the modal and redirects to the recorded return-to (or
 *   `/space`). OAuth completion happens on `/auth/callback`, not here
 *   — the panel is unmounted by the redirect.
 *
 * Focus management
 *   The close button is the last focusable element in the header.
 *   Focus initially lands on the first focusable control (the first
 *   OAuth button), courtesy of the parent `<dialog>`'s `showModal()`
 *   behaviour. The panel does not implement its own focus trap — the
 *   native `<dialog>` does. See `login-modal.tsx`.
 *
 * `aria-labelledby` target
 *   The `<h1>` carries `id="login-panel-title"`. The modal's `<dialog>`
 *   references it via `aria-labelledby="login-panel-title"` so screen
 *   readers announce "Log in to Kipio, dialog" on open.
 *
 * TODO: when the passkey flow lands (WebAuthn + relay + 7702), the
 *       Passkey button in `SocialGrid` becomes enabled. This panel
 *       does not change — the gating lives in the grid + the dict's
 *       `login.passkey.disabledReason`.
 */

import { useCallback, useEffect, useState } from "react";
import { useI18n } from "@context/I18nContext";
import { type OAuthProvider } from "@context/WalletContext";
import { useOAuthLogin } from "@hooks/web3/useOAuthLogin";
import { useWalletDiscovery } from "@hooks/web3/useWalletDiscovery";
import { KipioMark } from "@components/ui/kipio-mark";
import { SocialGrid } from "@components/login/social-grid";
import { WalletList } from "@components/login/wallet-list";
import type { WalletError } from "@lib/wallet/errors";

type LoginPanelProps = {
  /** Close the modal. Called by the close button. */
  onClose: () => void;
};

export function LoginPanel({ onClose }: LoginPanelProps) {
  const { t } = useI18n();
  const wallets = useWalletDiscovery();

  // `redirectUri` — computed from `window.location.origin` after mount.
  // Empty during SSR; the `useOAuthLogin` guard prevents the callback
  // handler from running with an empty value.
  const [redirectUri, setRedirectUri] = useState("");
  useEffect(() => {
    setRedirectUri(`${window.location.origin}/auth/callback`);
  }, []);

  const { state: oauthState, beginLogin } = useOAuthLogin(redirectUri);
  const [walletError, setWalletError] = useState<WalletError | null>(null);

  const handleProvider = useCallback(
    (provider: OAuthProvider) => {
      // A new attempt means the user is moving on — drop the wallet
      // error so it does not linger under the next attempt.
      setWalletError(null);
      void beginLogin(provider);
    },
    [beginLogin],
  );

  const handleWalletError = useCallback((error: WalletError) => {
    setWalletError(error);
  }, []);

  const error =
    walletError ?? (oauthState.phase === "error" ? oauthState.error : null);

  // Translated message, keyed off `WalletError.code`.
  const errorMessage = (() => {
    if (!error) return null;
    switch (error.code) {
      case "rejected":
        return t("login.error.rejected");
      case "network":
        return t("login.error.network");
      case "unauthorized":
      case "no_provider":
        return t("login.error.noAccount");
      case "unsupported":
        return t("login.error.unsupported");
      default:
        return t("login.error.generic");
    }
  })();

  const oauthBusy =
    oauthState.phase === "redirecting" || oauthState.phase === "exchanging";

  return (
    <div className="glass rounded-[28px] p-6">
      <header className="flex items-center gap-3">
        <KipioMark />
        <h1
          id="login-panel-title"
          className="flex-1 text-[22px] font-bold tracking-[-0.02em] text-ink"
        >
          {t("login.title")}
        </h1>
        <button
          type="button"
          onClick={onClose}
          aria-label={t("login.close")}
          className="inline-flex h-8 w-8 items-center justify-center rounded-full text-muted transition-colors duration-200 hover:text-ink"
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            aria-hidden="true"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
      </header>

      <p className="mb-4 mt-2.5 text-[14px] text-muted">
        {t("login.subtitle")}
      </p>

      <SocialGrid onProvider={handleProvider} disabled={oauthBusy} />

      <div className="label-mono mb-2 mt-[22px] flex items-center justify-between">
        <span className="text-muted">{t("login.wallet.label")}</span>
        <span className="text-violet-text">{t("login.wallet.badge")}</span>
      </div>

      <WalletList wallets={wallets} onError={handleWalletError} />

      {error && !error.cancelled && errorMessage ? (
        <div
          role="alert"
          title={error.rawMessage}
          className="mt-4 rounded-[12px] border border-danger/30 bg-danger/10 px-3 py-2 text-[12px] leading-relaxed text-danger-text break-words"
        >
          {errorMessage}
        </div>
      ) : null}

      <p className="mt-2.5 text-center text-[12px] leading-[1.5] text-muted">
        {t("login.footer")}
      </p>
    </div>
  );
}
