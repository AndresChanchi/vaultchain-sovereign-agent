/**
 * Identity label helper — shared between the sidebar account card and
 * the header avatar (mobile).
 *
 * Extracted from `space-account-card.tsx` so both triggers display the
 * same brand name for the same session. The exhaustive switches end
 * with `_exhaustive: never` — if `WalletKind` or `OAuthProvider` gains
 * a new variant, this file fails to compile until the mapping is
 * updated, rather than silently falling through at runtime.
 */
import type { Session } from "@context/WalletContext";
import type { useI18n } from "@context/I18nContext";

type TFn = ReturnType<typeof useI18n>["t"];

export function identityLabel(session: Session, t: TFn): string {
  if (session.kind === "wallet") {
    switch (session.wallet) {
      case "metamask":
        return t("space.account.walletMetamask");
      case "brave":
        return t("space.account.walletBrave");
      case "rabby":
        return t("space.account.walletRabby");
      case "ledger":
        return t("space.account.walletLedger");
      case "injected":
        return t("space.account.walletInjected");
      default: {
        const _exhaustive: never = session.wallet;
        throw new Error(`Unhandled wallet kind: ${String(_exhaustive)}`);
      }
    }
  }
  switch (session.provider) {
    case "google":
      return t("space.account.oauthGoogle");
    case "x":
      return t("space.account.oauthX");
    case "microsoft":
      return t("space.account.oauthMicrosoft");
    case "apple":
      return t("space.account.oauthApple");
    case "github":
      return t("space.account.oauthGithub");
    case "twitch":
      return t("space.account.oauthTwitch");
    default: {
      const _exhaustive: never = session.provider;
      throw new Error(`Unhandled oauth provider: ${String(_exhaustive)}`);
    }
  }
}
