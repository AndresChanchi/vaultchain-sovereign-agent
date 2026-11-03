"use client";

/**
 * Wallet list — branded wallets + Ledger + "More wallets" dialog.
 *
 * Connection logic lives in `useWalletConnection`. This component is
 * presentational: it renders rows, opens the dialog, and forwards the
 * hook's `error` to the parent via `onError`.
 *
 * Hydration safety — why `wallets` and not `getWalletById`
 *   The "Detected" badge must not be driven by `getWalletById()`.
 *   That function reads the `mipd` store directly — in SSR the store
 *   is empty (`window` undefined), in the client it has entries. The
 *   two trees would differ, and React 19 regenerates the tree with a
 *   hydration-mismatch error. The fix is to derive "detected" from
 *   the `wallets` prop, which comes from `useWalletDiscovery()` →
 *   `useSyncExternalStore(subscribeDiscovery, getDiscoveredWallets,
 *   getServerSnapshot)` with `getServerSnapshot = EMPTY_DISCOVERY`.
 *   Both server and client's first render see the same empty array,
 *   and the client updates afterward via the store — no mismatch.
 *
 *   `getWalletById` is still used inside `useWalletConnection` for
 *   the actual connect call (an event handler, not render). That is
 *   safe: handlers run only after mount.
 *
 * Dialog centering — why `m-auto`
 *   Tailwind v4 Preflight resets `margin: 0` on every element,
 *   which kills the UA's `dialog:modal { margin: auto }` — the rule
 *   that centers a modal in its viewport-sized containing block.
 *   Without `m-auto` on the `<dialog>`, it pins to the top-left.
 *   `login-modal.tsx` already has `m-auto`; this one now also does.
 *
 * Busy lock
 *   While any connection is in progress (`busy !== null`), every
 *   connect-initiating control is disabled — wallet rows, the "More
 *   wallets" trigger, and the wallet buttons inside the dialog. The
 *   "Close" button inside the dialog stays enabled — closing is not
 *   a connect and must always work. Controls re-enable when the
 *   hook clears `busy` (success or failure).
 *
 * `type` vs `kind`
 *   The row discriminant is `type` (`"branded" | "ledger"`), not
 *   `kind`. `kind` is reserved for the wallet category in
 *   `WalletContext` (`wallet: "metamask" | … | "injected"`). Using
 *   the same word for two unrelated concepts read as a single
 *   discriminant and confused the two. `type` is row-shape only.
 *
 * Ledger
 *   One row today ("Ledger", WebHID). The Speculos row is a
 *   dev-only path — enabling it in the UI requires an env guard, and
 *   the login surface does not need it.
 *
 * "More wallets" — native `<dialog>`
 *   The browser handles backdrop, focus trap, Escape and return
 *   focus. Injected wallets whose brand is not in `KNOWN_WALLETS`
 *   (Phantom, Trust, Coinbase Wallet, …) connect with
 *   `kind: "injected"`.
 *
 * Error reporting
 *   The hook exposes `error`. A `useEffect` forwards it to `onError`
 *   so the parent (`LoginPanel`) can merge it with the OAuth error
 *   into one banner. `error.cancelled` is forwarded as-is.
 *
 * i18n
 *   Every label is `login.wallet.*`. No hardcoded English.
 */

import { useCallback, useEffect, useMemo, useRef } from "react";
import { useI18n } from "@context/I18nContext";
import type { WalletKind } from "@context/WalletContext";
import type { DiscoveredWallet } from "@lib/wallet/discovery";
import type { LedgerTransport } from "@lib/wallet/ledger";
import { useWalletConnection } from "@hooks/web3/useWalletConnection";
import type { WalletError } from "@lib/wallet/errors";
import { LetterMark } from "@components/ui/letter-mark";

type WalletListProps = {
  wallets: readonly DiscoveredWallet[];
  onError: (error: WalletError) => void;
};

/**
 * Branded wallet rows — the ones with a fixed `KNOWN_WALLETS` entry.
 * `id` is narrowed to exclude `"ledger"` (hardware, separate row
 * type) and `"injected"` (no fixed brand, lives in the dialog).
 */
type BrandedRow = {
  type: "branded";
  id: Exclude<WalletKind, "ledger" | "injected">;
  letter: string;
};

type LedgerRow = {
  type: "ledger";
  transport: LedgerTransport;
  letter: string;
};

type RowDef = BrandedRow | LedgerRow;

const ROWS: readonly RowDef[] = [
  { type: "branded", id: "metamask", letter: "M" },
  { type: "branded", id: "brave", letter: "B" },
  { type: "branded", id: "rabby", letter: "R" },
  { type: "ledger", transport: "physical", letter: "L" },
];

const DIALOG_TITLE_ID = "wallet-list-more-title";

export function WalletList({ wallets, onError }: WalletListProps) {
  const { t } = useI18n();
  const {
    connectInjected,
    connectLedgerDevice,
    connectProvider,
    busy,
    error,
    clearError,
  } = useWalletConnection();
  const dialogRef = useRef<HTMLDialogElement>(null);

  // Forward the hook's error to the parent. `error` is set exactly
  // once per failed attempt; the effect fires on every change.
  useEffect(() => {
    if (error) onError(error);
  }, [error, onError]);

  const openMoreWallets = useCallback(() => {
    clearError();
    dialogRef.current?.showModal();
  }, [clearError]);

  const closeMoreWallets = useCallback(() => {
    dialogRef.current?.close();
  }, []);

  // See "Hydration safety" in the file header. `wallets` is the
  // `useWalletDiscovery()` snapshot — `EMPTY_DISCOVERY` on the
  // server, the real list on the client after the store emits.
  // Deriving "detected" from this array keeps both trees identical
  // on the first render.
  const detectedIds = useMemo(
    () => new Set(wallets.map((w) => w.id)),
    [wallets],
  );

  // Injected wallets whose brand is not in `KNOWN_WALLETS` — Phantom,
  // Trust, Coinbase Wallet, etc. Shown in the "More wallets" dialog.
  const injectedWallets = useMemo(
    () => wallets.filter((w) => w.id === "injected"),
    [wallets],
  );

  // See "Busy lock" in the file header.
  const locked = busy !== null;

  return (
    <div className="flex flex-col gap-2">
      {ROWS.map((row) => {
        if (row.type === "branded") {
          const detected = detectedIds.has(row.id);
          const name = t(`login.wallet.${row.id}`);
          return (
            <button
              key={row.id}
              type="button"
              disabled={locked}
              onClick={() => void connectInjected(row.id).catch(() => {})}
              className="flex h-12 items-center gap-3 rounded-[12px] border border-hairline bg-card px-3.5 text-[15px] font-medium text-ink transition-colors duration-200 hover:bg-elevated disabled:cursor-wait disabled:opacity-60"
            >
              <LetterMark letter={row.letter} />
              <span className="flex-1 text-start">{name}</span>
              {detected ? (
                <span className="font-mono text-[10px] uppercase tracking-[0.12em] text-emerald-text">
                  {t("login.wallet.detected")}
                </span>
              ) : null}
            </button>
          );
        }

        const name =
          row.transport === "physical"
            ? t("login.wallet.ledger")
            : t("login.wallet.ledgerConnect");
        return (
          <button
            key={row.transport}
            type="button"
            disabled={locked}
            onClick={() =>
              void connectLedgerDevice(row.transport).catch(() => {})
            }
            className="flex h-12 items-center gap-3 rounded-[12px] border border-hairline bg-card px-3.5 text-[15px] font-medium text-ink transition-colors duration-200 hover:bg-elevated disabled:cursor-wait disabled:opacity-60"
          >
            <LetterMark letter={row.letter} />
            <span className="flex-1 text-start">{name}</span>
          </button>
        );
      })}

      <button
        type="button"
        disabled={locked}
        onClick={openMoreWallets}
        className="mt-1 inline-flex h-10 items-center justify-center rounded-[12px] px-3 text-[13px] text-muted transition-colors duration-200 hover:text-ink disabled:cursor-wait disabled:opacity-60"
      >
        {t("login.wallet.more")}
      </button>

      <dialog
        ref={dialogRef}
        aria-labelledby={DIALOG_TITLE_ID}
        className="m-auto w-[min(92vw,360px)] rounded-[20px] border border-hairline bg-card p-0 text-ink backdrop:bg-black/60"
        onClick={(event) => {
          if (event.target === dialogRef.current) closeMoreWallets();
        }}
      >
        <div className="border-b border-hairline px-5 py-4">
          <h2
            id={DIALOG_TITLE_ID}
            className="text-[15px] font-semibold text-ink"
          >
            {t("login.wallet.moreTitle")}
          </h2>
        </div>
        <ul className="max-h-[320px] overflow-y-auto p-2">
          {injectedWallets.length === 0 ? (
            <li className="px-3 py-4 text-[13px] text-muted">
              {t("login.wallet.empty")}
            </li>
          ) : (
            injectedWallets.map((wallet) => (
              <li key={wallet.rdns}>
                <button
                  type="button"
                  disabled={locked}
                  onClick={() => {
                    closeMoreWallets();
                    // `"injected"` — the session records "an injected
                    // provider whose brand is not in `KNOWN_WALLETS`".
                    void connectProvider(wallet.provider, "injected").catch(
                      () => {},
                    );
                  }}
                  className="flex w-full items-center gap-3 rounded-[10px] px-3 py-2.5 text-start text-[14px] text-ink transition-colors hover:bg-elevated disabled:cursor-wait disabled:opacity-60"
                >
                  <img
                    src={wallet.icon}
                    alt=""
                    width={22}
                    height={22}
                    className="rounded-full"
                  />
                  <span className="truncate">{wallet.name}</span>
                </button>
              </li>
            ))
          )}
        </ul>
        <div className="flex justify-end border-t border-hairline px-4 py-3">
          <button
            type="button"
            onClick={closeMoreWallets}
            className="inline-flex h-9 items-center rounded-[10px] border border-hairline bg-card px-4 text-[13px] font-medium text-ink transition-colors hover:bg-elevated"
          >
            {t("login.close")}
          </button>
        </div>
      </dialog>
    </div>
  );
}
