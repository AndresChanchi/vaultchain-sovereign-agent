"use client";

/**
 * Social / OAuth sign-in grid — 3×2.
 *
 * Layout matches the mockup: Google, X, Microsoft on the first row;
 * GitHub, Twitch, Passkey on the second. Apple and Discord are
 * intentionally omitted: Apple needs a server-side relay that does
 * not exist yet, and Discord is not in the current provider set. The
 * dictionary keeps `login.social.apple` and `login.provider.apple.relay`
 * for when the relay ships.
 *
 * Passkey button — accessible disabled state
 *   Uses `aria-disabled="true"` instead of the `disabled` attribute.
 *   Why: `disabled` buttons are skipped by keyboard navigation and
 *   not announced by most screen readers, so the honest reason
 *   ("needs a secure relay and the contract-level binding") never
 *   reaches users who need it. `aria-disabled` keeps the button
 *   focusable, so the `aria-label` (label + reason) is announced
 *   when the user tabs to it. `onClick` calls `preventDefault()` to
 *   neutralise activation. This matches WCAG 2.2 SC 4.1.2 (Name,
 *   Role, Value) and the WAI-ARIA Authoring Practices guidance on
 *   disabled controls.
 *
 *   When the relay + contract binding land, switch to a real
 *   `<button onClick={beginPasskey}>`, drop `aria-disabled`,
 *   `aria-label`, `title`, `onClick`. The label already matches
 *   `login.passkey.label`.
 *
 * Group accessibility
 *   `role="group"` + `aria-label={t("login.social.label")}`. Screen
 *   readers announce "Continue with, group" before the buttons.
 *   Each button keeps its visible label ("Google", "X", …) as its
 *   accessible name. No per-button aria-label needed — "Google,
 *   button" is unambiguous in this group context.
 *
 * Dictionary
 *   Every visible label comes from `login.social.*` and
 *   `login.passkey.*`. No hardcoded English.
 */

import { useI18n } from "@context/I18nContext";
import type { OAuthProvider } from "@context/WalletContext";
import { LetterMark } from "@components/ui/letter-mark";

type SocialGridProps = {
  onProvider: (provider: OAuthProvider) => void;
  disabled?: boolean;
};

type GridEntry =
  | { kind: "oauth"; provider: OAuthProvider; letter: string }
  | { kind: "passkey"; letter: string };

const ENTRIES: readonly GridEntry[] = [
  { kind: "oauth", provider: "google", letter: "G" },
  { kind: "oauth", provider: "x", letter: "X" },
  { kind: "oauth", provider: "microsoft", letter: "M" },
  { kind: "oauth", provider: "github", letter: "G" },
  { kind: "oauth", provider: "twitch", letter: "T" },
  { kind: "passkey", letter: "P" },
];

export function SocialGrid({ onProvider, disabled = false }: SocialGridProps) {
  const { t } = useI18n();

  return (
    <div
      className="grid grid-cols-3 gap-2"
      role="group"
      aria-label={t("login.social.label")}
    >
      {ENTRIES.map((entry) => {
        if (entry.kind === "passkey") {
          const reason = t("login.passkey.disabledReason");
          return (
            <button
              key="passkey"
              type="button"
              aria-disabled="true"
              aria-label={`${t("login.passkey.label")} — ${reason}`}
              title={reason}
              onClick={(event) => event.preventDefault()}
              className="flex h-11 cursor-not-allowed items-center justify-center gap-2 rounded-[12px] border border-hairline bg-elevated/40 px-2 text-[13px] font-medium text-muted/60"
            >
              <LetterMark letter={entry.letter} />
              <span className="truncate">{t("login.passkey.label")}</span>
            </button>
          );
        }

        const label = t(`login.social.${entry.provider}` as const);
        return (
          <button
            key={entry.provider}
            type="button"
            disabled={disabled}
            onClick={() => onProvider(entry.provider)}
            className="flex h-11 items-center justify-center gap-2 rounded-[12px] border border-hairline bg-card px-2 text-[13px] font-medium text-ink transition-colors duration-200 hover:bg-elevated focus-visible:border-emerald/50 disabled:cursor-not-allowed disabled:opacity-50"
          >
            <LetterMark letter={entry.letter} />
            <span className="truncate">{label}</span>
          </button>
        );
      })}
    </div>
  );
}
