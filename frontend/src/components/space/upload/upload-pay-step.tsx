"use client";

/**
 * Upload step 3 — payment method picker (OAuth sessions only).
 *
 * Three of four methods are placeholders
 *   Card / Nequi / Bre-B require a server-side relay to create the
 *   payment session (Stripe/Ripio/Koywe all return a `client_secret`
 *   from the server, never from the browser). That relay (Marlin
 *   Oyster / Fleek Functions) is not deployed yet, and the
 *   `kipio_execution_gateway` contract that would settle the fiat →
 *   crypto hop is paused. Rendering them as functional buttons would
 *   be a lie.
 *
 *   They are visible but `aria-disabled` with a "Coming soon" badge —
 *   the same treatment the sidebar applies to Library / Moments.
 *   Users see the roadmap, not a broken flow.
 *
 * Wallet is the only live escape
 *   An OAuth session cannot upload (ephemeral wallet has no funds for
 *   the register tx). Clicking "Wallet" calls `onSwitchToWallet`,
 *   which disconnects the OAuth session and reopens the login modal
 *   with `returnTo: "/"`. The user signs in with a real wallet,
 *   returns to Review (files restored from IndexedDB), and can
 *   proceed to Progress.
 *
 * Crypto-signed external payment (research only)
 *   The user's investigation covers peer-to-peer fiat / crypto
 *   transfers from external wallets (ZKP2P, Ramp). Those flows
 *   require the contract to emit a `PaymentReceived`-style event that
 *   the frontend can poll. The current MVP contract has no such
 *   event. Deferred until the new contracts ship.
 */
import { useI18n } from "@context/I18nContext";

type UploadPayStepProps = {
  onSwitchToWallet: () => void;
  onBack: () => void;
};

export function UploadPayStep({
  onSwitchToWallet,
  onBack,
}: UploadPayStepProps) {
  const { t } = useI18n();

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <span className="label-mono text-emerald-text">
          {t("space.upload.payStep.title")}
        </span>
      </div>

      <div>
        <h3 className="text-[17px] font-semibold text-ink">
          {t("space.upload.payStep.heading")}
        </h3>
        <p className="mt-1.5 text-[13px] leading-[1.5] text-muted">
          {t("space.upload.payStep.subtitle")}
        </p>
      </div>

      <div className="flex flex-col gap-2">
        <DisabledMethod
          label={t("space.upload.payStep.card")}
          hint={t("space.upload.payStep.cardHint")}
          soon={t("space.upload.payStep.comingSoon")}
        />
        <DisabledMethod
          label={t("space.upload.payStep.nequi")}
          hint=""
          soon={t("space.upload.payStep.comingSoon")}
        />
        <DisabledMethod
          label={t("space.upload.payStep.breb")}
          hint=""
          soon={t("space.upload.payStep.comingSoon")}
        />
        <button
          type="button"
          onClick={onSwitchToWallet}
          className="flex h-12 items-center gap-3 rounded-[12px] border border-emerald bg-emerald/[0.08] px-3.5 text-start transition-colors hover:bg-emerald/[0.14]"
        >
          <span
            aria-hidden="true"
            className="grid h-[18px] w-[18px] flex-none place-items-center rounded-full border-[1.5px] border-emerald bg-emerald shadow-[inset_0_0_0_3px_var(--color-card)]"
          />
          <span className="flex-1 text-[15px] font-medium text-ink">
            {t("space.upload.payStep.wallet")}
          </span>
          <span className="font-mono text-[11px] text-muted">
            {t("space.upload.payStep.walletHint")}
          </span>
        </button>
      </div>

      <button
        type="button"
        onClick={onBack}
        className="mt-1 text-[13px] font-medium text-muted transition-colors hover:text-ink"
      >
        {t("space.upload.reviewBack")}
      </button>
    </div>
  );
}

function DisabledMethod({
  label,
  hint,
  soon,
}: {
  label: string;
  hint: string;
  soon: string;
}) {
  return (
    <div
      aria-disabled="true"
      title={soon}
      className="flex h-12 cursor-not-allowed items-center gap-3 rounded-[12px] border border-hairline bg-card/50 px-3.5 opacity-60"
    >
      <span
        aria-hidden="true"
        className="h-[18px] w-[18px] flex-none rounded-full border-[1.5px] border-hairline"
      />
      <span className="flex-1 text-[15px] font-medium text-muted">{label}</span>
      <span className="font-mono text-[11px] text-muted">
        {hint || soon}
      </span>
    </div>
  );
}
