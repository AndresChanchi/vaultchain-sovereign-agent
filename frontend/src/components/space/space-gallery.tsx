"use client";

/**
 * Space gallery — the "Recent uploads" grid on the overview.
 *
 * Four render branches, in priority order:
 *
 *   1. Error (any session) → error card with retry. Renders when the
 *      last unlock attempt threw (Ledger, missing ephemeral key,
 *      network failure on the wallet popup).
 *
 *   2. Wallet session + locked → locked card with "Unlock space"
 *      button. The click triggers `eth_signTypedData_v4`, which the
 *      wallet presents as a popup. On success, tiles appear.
 *
 *   3. OAuth session + locked + no error → tiles with their own
 *      loading state ("Syncing_L1" / "Decrypting_Core" from
 *      `DecryptedImage`). The auto-unlock runs in the background
 *      (see `useVaultUnlock`); within ~50ms the key is derived and
 *      the tiles switch to fetch + decrypt. The user sees the grid
 *      "come alive" instead of a blocking spinner.
 *
 *   4. Unlocked (any session) → tiles with real decrypted photos.
 *
 * Decryption is per-tile via `DecryptedImage`, which pulls ciphertext
 * from Irys, decrypts with the master key, and shows the image. That
 * component is unchanged — the fix is upstream (an actual trigger
 * calls `unlockVault`).
 *
 * Copy — wallet vs. OAuth
 *   Wallet sees `unlockBodyWallet` ("Sign with your wallet…").
 *   OAuth never sees a body (auto-unlock, no visible prompt).
 *   Error state uses `unlockError` for both — same reason for both,
 *   same next action ("try again").
 */
import { useI18n } from "@context/I18nContext";
import { useWallet } from "@context/WalletContext";
import { useSpaceGallery } from "@hooks/protocol/useSpaceGallery";
import { useVaultUnlock } from "@hooks/vault/useVaultUnlock";
import { DecryptedImage } from "@components/vault/DecryptedImage";
import { LockIcon } from "./space-icons";

type SpaceGalleryProps = {
  limit?: number;
};

export function SpaceGallery({ limit = 8 }: SpaceGalleryProps) {
  const { t } = useI18n();
  const { session } = useWallet();
  const { isLocked, isUnlocking, error, unlock } = useVaultUnlock();
  const gallery = useSpaceGallery(
    session?.address ?? null,
    session?.chainId ?? null,
    limit,
  );

  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-end justify-between">
        <h2 className="text-[17px] font-semibold text-ink">
          {t("space.overview.recentTitle")}
        </h2>
        <button
          type="button"
          disabled
          aria-disabled="true"
          title={t("space.sidebar.comingSoon")}
          className="cursor-not-allowed text-[13px] text-emerald-text opacity-60"
        >
          {t("space.overview.viewAll")}
        </button>
      </div>

      {/* 1. Error — highest priority, any session */}
      {error !== null && (
        <div className="cd flex flex-col items-center gap-3 px-6 py-10 text-center">
          <LockIcon size={28} className="text-muted" />
          <div className="space-y-1">
            <p className="text-[15px] font-medium text-ink">
              {t("space.overview.unlockTitle")}
            </p>
            <p className="max-w-[360px] text-[13px] leading-[1.5] text-muted">
              {t("space.overview.unlockError")}
            </p>
          </div>
          <button
            type="button"
            onClick={unlock}
            disabled={isUnlocking}
            className="mt-2 inline-flex h-10 items-center justify-center rounded-[12px] bg-emerald px-5 text-[14px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02] disabled:cursor-wait disabled:opacity-60"
          >
            {isUnlocking
              ? t("space.overview.unlocking")
              : t("space.overview.unlockAction")}
          </button>
        </div>
      )}

      {/* 2. Wallet + locked → explicit unlock button */}
      {error === null && isLocked && session?.kind === "wallet" && (
        <div className="cd flex flex-col items-center gap-3 px-6 py-10 text-center">
          <LockIcon size={28} className="text-emerald-text" />
          <div className="space-y-1">
            <p className="text-[15px] font-medium text-ink">
              {t("space.overview.unlockTitle")}
            </p>
            <p className="max-w-[360px] text-[13px] leading-[1.5] text-muted">
              {t("space.overview.unlockBodyWallet")}
            </p>
          </div>
          <button
            type="button"
            onClick={unlock}
            disabled={isUnlocking}
            className="mt-2 inline-flex h-10 items-center justify-center rounded-[12px] bg-emerald px-5 text-[14px] font-semibold text-on-emerald transition-transform duration-200 ease-[cubic-bezier(0.34,1.4,0.5,1)] hover:scale-[1.02] disabled:cursor-wait disabled:opacity-60"
          >
            {isUnlocking
              ? t("space.overview.unlocking")
              : t("space.overview.unlockAction")}
          </button>
        </div>
      )}

      {/* 3 + 4. OAuth locked (auto-unlocking) or unlocked (any) → grid */}
      {error === null &&
        (!isLocked || session?.kind === "oauth") && (
          <>
            {gallery.status === "loading" && (
              <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div
                    key={i}
                    className="skeleton aspect-square rounded-[14px]"
                    aria-hidden="true"
                  />
                ))}
              </div>
            )}

            {gallery.status === "error" && (
              <p className="text-[13px] text-muted">
                {t("space.overview.galleryError")}
              </p>
            )}

            {gallery.status === "ready" && gallery.items.length === 0 && (
              <p className="text-[13px] text-muted">
                {t("space.overview.galleryEmpty")}
              </p>
            )}

            {gallery.status === "ready" && gallery.items.length > 0 && (
              <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
                {gallery.items.map((item) => (
                  <div
                    key={item.hash}
                    className="relative aspect-square overflow-hidden rounded-[14px] transition-transform duration-300 ease-[cubic-bezier(0.2,0.8,0.2,1)] hover:-translate-y-0.5"
                  >
                    <DecryptedImage
                      contentHash={item.hash}
                      irysId={item.irysId}
                    />
                  </div>
                ))}
              </div>
            )}
          </>
        )}
    </section>
  );
}
