"use client";

/**
 * Upload step 2 — sign in prompt.
 *
 * Rendered when `session === null` after the user clicked Continue in
 * Review. "Log in" opens the login modal (stacks on top of the upload
 * dialog — both `<dialog>` elements remain open, the login modal is
 * topmost). After login succeeds, the login modal closes and the
 * upload dialog advances: wallet → progress, OAuth → pay.
 *
 * "Back" returns to Review. The files are still in IndexedDB (saved
 * by the dialog before this step rendered), so Review restores them
 * on mount.
 *
 * Copy — no fake wallet promises
 *   "Photos need an account that can sign." is accurate: OAuth
 *   sessions can sign EIP-712 with an ephemeral key, but they cannot
 *   upload (no funds for the register tx). The prompt is neutral so
 *   the user does not expect "just Google" to work — the pay step
 *   that follows for OAuth explains the specific limitation.
 */
import { useI18n } from "@context/I18nContext";
import { LockIcon } from "@components/space/space-icons";

type UploadLoginStepProps = {
  onSignIn: () => void;
  onBack: () => void;
};

export function UploadLoginStep({ onSignIn, onBack }: UploadLoginStepProps) {
  const { t } = useI18n();

  return (
    <div className="flex flex-col gap-4">
      <span className="label-mono text-emerald-text">
        {t("space.upload.signInToUpload")}
      </span>

      <div className="flex flex-col items-center gap-3 py-2 text-center">
        <LockIcon size={28} className="text-emerald-text" />
        <p className="max-w-[320px] text-[13px] leading-[1.5] text-muted">
          {t("space.upload.signInBody")}
        </p>
        <button
          type="button"
          onClick={onSignIn}
          className="mt-2 inline-flex h-[48px] w-full items-center justify-center rounded-[14px] bg-emerald text-[15px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.01]"
        >
          {t("space.upload.signInAction")}
        </button>
        <button
          type="button"
          onClick={onBack}
          className="mt-1 text-[13px] font-medium text-muted transition-colors hover:text-ink"
        >
          {t("space.upload.reviewBack")}
        </button>
      </div>
    </div>
  );
}
