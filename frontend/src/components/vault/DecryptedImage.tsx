"use client";

import { useEffect, useState } from "react";
import { useKipioCrypto } from "@hooks/useKipioCrypto";
import { useI18n } from "@context/I18nContext";
import { IRYS_CONFIG } from "@config/contracts";
import type { Hex } from "viem";

/**
 * DecryptedImage — per-tile fetch + decrypt + render.
 *
 * Sizing — `h-full` fills the parent
 *   The parent in `space-gallery.tsx` is `aspect-square` +
 *   `overflow-hidden`. This component fills it completely via
 *   `h-full w-full`. Earlier it used `h-56` (224px) on every state,
 *   which left the tile taller than the image on desktop — the
 *   `aspect-square` parent was ~350px, the image 224px, and the gap
 *   read as "the gallery is cut".
 *
 * Six states, three of them user-facing errors:
 *   loading, decrypting, ready, expired, network-error, decrypt-error.
 *
 * Why three error states, not one
 *   `PIPELINE_ERROR // CHECK_CONSOLE` was a debugging string. Each
 *   failure mode has a different cause and next action:
 *     expired     — Irys testnet TTL exceeded; nothing to do.
 *     network     — check connection, retry.
 *     decrypt     — wrong key or corrupted ciphertext.
 *
 * Retry loop
 *   Three retries at 2s intervals cover Irys gateway propagation.
 *   After that, 404 means the object is gone (testnet expiry) and
 *   network error means the fetch failed.
 */

type Status =
  | "loading"
  | "decrypting"
  | "ready"
  | "expired"
  | "network-error"
  | "decrypt-error";

type DecryptedImageProps = {
  contentHash: Hex;
  irysId: string;
};

export function DecryptedImage({ contentHash, irysId }: DecryptedImageProps) {
  const { t } = useI18n();
  const { decryptFile, isLocked } = useKipioCrypto();
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [status, setStatus] = useState<Status>("loading");

  useEffect(() => {
    let objectUrl: string | null = null;
    let isMounted = true;

    const fetchAndDecrypt = async () => {
      if (isLocked || !decryptFile || imageUrl) return;

      try {
        setStatus("loading");

        const baseUrl = (IRYS_CONFIG.gateway || "https://gateway.irys.xyz").replace(
          /\/$/,
          "",
        );
        const targetUrl = `${baseUrl}/${irysId}`;

        let response: Response | undefined;
        let lastHttpStatus: number | null = null;
        let attempt = 1;
        const maxAttempts = 3;

        while (attempt <= maxAttempts && isMounted) {
          try {
            response = await fetch(targetUrl, { cache: "no-store" });
            if (response.ok) break;
            lastHttpStatus = response.status;
          } catch {
            lastHttpStatus = null;
          }
          attempt++;
          if (attempt <= maxAttempts) {
            await new Promise((r) => setTimeout(r, 2000));
          }
        }

        if (!isMounted) return;

        if (!response || !response.ok) {
          if (lastHttpStatus === 404) {
            setStatus("expired");
          } else {
            setStatus("network-error");
          }
          return;
        }

        const encryptedBuffer = await response.arrayBuffer();
        if (!isMounted) return;

        setStatus("decrypting");
        let decryptedBuffer: ArrayBuffer;
        try {
          decryptedBuffer = await decryptFile(encryptedBuffer, contentHash);
        } catch {
          if (isMounted) setStatus("decrypt-error");
          return;
        }

        if (!isMounted || !decryptedBuffer) return;

        const blob = new Blob([decryptedBuffer], { type: "image/webp" });
        objectUrl = URL.createObjectURL(blob);
        if (isMounted) {
          setImageUrl(objectUrl);
          setStatus("ready");
        }
      } catch {
        if (isMounted) setStatus("network-error");
      }
    };

    void fetchAndDecrypt();

    return () => {
      isMounted = false;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [irysId, contentHash, decryptFile, isLocked, imageUrl]);

  if (status === "ready" && imageUrl) {
    return (
      <div className="relative h-full w-full bg-black/40">
        <img
          src={imageUrl}
          alt=""
          className="h-full w-full object-cover"
        />
      </div>
    );
  }

  if (status === "expired") {
    return (
      <TileMessage
        title={t("space.overview.photo.expired")}
        body={t("space.overview.photo.expiredBody")}
      />
    );
  }

  if (status === "network-error") {
    return (
      <TileMessage
        title={t("space.overview.photo.networkError")}
        body={t("space.overview.photo.networkErrorBody")}
      />
    );
  }

  if (status === "decrypt-error") {
    return (
      <TileMessage
        title={t("space.overview.photo.decryptError")}
        body={t("space.overview.photo.decryptErrorBody")}
      />
    );
  }

  return (
    <div className="flex h-full w-full items-center justify-center bg-elevated/40">
      <div
        aria-hidden="true"
        className="h-6 w-6 animate-spin rounded-full border-2 border-hairline border-t-emerald"
      />
      <span className="sr-only">
        {status === "loading"
          ? t("space.overview.photo.loading")
          : t("space.overview.photo.decrypting")}
      </span>
    </div>
  );
}

function TileMessage({ title, body }: { title: string; body: string }) {
  return (
    <div className="flex h-full w-full flex-col items-center justify-center gap-1.5 bg-elevated/40 px-3 text-center">
      <p className="text-[12px] font-medium text-muted">{title}</p>
      <p className="text-[11px] leading-[1.4] text-muted-soft">{body}</p>
    </div>
  );
}
