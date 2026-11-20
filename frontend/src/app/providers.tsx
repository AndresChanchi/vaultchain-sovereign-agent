"use client";

/**
 * Providers — the client boundary of the app.
 *
 * Every provider in the tree is `"use client"` (they hold state, refs,
 * or context). Nesting them in a dedicated client module isolates the
 * boundary from the server-rendered layout, so `layout.tsx` stays a
 * Server Component.
 *
 * Provider order
 *   `<ThemeProvider>` → `<I18nProvider>` → `<WalletProvider>` →
 *   `<KipioProvider>` → `<UploadDialogProvider>` →
 *   `<LoginModalProvider>` → `<SpaceRefreshProvider>` →
 *   `<Web3Provider>` → ( `{children}` + `<UploadDialogSlot />` ) +
 *   `<LoginModal />`
 *
 *   - ThemeProvider first: drives `data-theme` on `<html>`.
 *   - I18nProvider second: every downstream `t()` call.
 *   - WalletProvider third: single source of truth for identity.
 *   - KipioProvider fourth: cryptographic operations. Depends on
 *     WalletProvider.signTypedData.
 *   - UploadDialogProvider fifth: open/close state for the upload
 *     modal. Root-mounted so any surface can call `openUpload()` —
 *     today `/space`, Turn C the landing hero, future `/library`.
 *   - LoginModalProvider sixth: login modal state.
 *   - SpaceRefreshProvider seventh: version counter for reactive
 *     contract reads. `useVault` (via `useUploadFlow` in the dialog)
 *     calls `bump()`; `useSpaceStats` / `useSpaceGallery` (inside
 *     `/space`) refetch. Both consumers live below it now.
 *   - Web3Provider innermost: wagmi + TanStack Query. Required by the
 *     legacy dashboard, and by any component that uses `useQuery`.
 *
 * `<UploadDialogSlot />` mount strategy
 *   - Signed in (`session !== null`): mount eagerly so the crypto
 *     and image workers spawn ahead of the first upload — same
 *     timing as before Turn B, no UX regression.
 *   - Signed out: mount lazily when `isOpen === true`. The dialog
 *     opens with the sign-in gate; workers spawn only if the user
 *     tries to upload, not on landing load.
 *
 * Why `<UploadDialogSlot />` is INSIDE `<Web3Provider>`
 *   `UploadReview` calls `useUploadQuote`, which uses TanStack Query's
 *   `useQuery`. `useQuery` requires a `QueryClientProvider` in the
 *   ancestor tree — even when `enabled: false`, the hook itself runs.
 *   `QueryClientProvider` lives inside `<Web3Provider>` (wagmi's
 *   conventional setup). Placing `UploadDialogSlot` as a sibling of
 *   `<Web3Provider>` crashed every route with "No QueryClient set"
 *   the moment the dialog mounted.
 *
 *   The dialog must be inside `<Web3Provider>` today. Fase 10 will
 *   retire `Web3Provider`; at that point, `QueryClientProvider`
 *   should be lifted to its own provider at root (independent of
 *   wagmi), and this slot can move out. Not today — the move would
 *   touch `web3-provider.tsx` internals, and the current position
 *   works.
 *
 *   `<LoginModal />` stays OUTSIDE `<Web3Provider>` — it does not use
 *   `useQuery`, only `useWallet` / `useLoginModal` / `useRouter`.
 *   Keeping it out preserves the "login is independent of wagmi"
 *   design from Turn 8.
 */

import type { ReactNode } from "react";
import { Web3Provider } from "@components/web3-provider";
import { ThemeProvider } from "@context/ThemeContext";
import { I18nProvider } from "@context/I18nContext";
import { WalletProvider, useWallet } from "@context/WalletContext";
import { KipioProvider } from "@context/KipioContext";
import { LoginModalProvider } from "@context/LoginModalContext";
import { SpaceRefreshProvider } from "@context/SpaceRefreshContext";
import {
  UploadDialogProvider,
  useUploadDialog,
} from "@context/UploadDialogContext";
import { LoginModal } from "@components/login/login-modal";
import { UploadDialog } from "@components/space/upload/upload-dialog";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider>
      <I18nProvider>
        <WalletProvider>
          <KipioProvider>
            <UploadDialogProvider>
              <LoginModalProvider>
                <SpaceRefreshProvider>
                  <Web3Provider>
                    {children}
                    <UploadDialogSlot />
                  </Web3Provider>
                  <LoginModal />
                </SpaceRefreshProvider>
              </LoginModalProvider>
            </UploadDialogProvider>
          </KipioProvider>
        </WalletProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}

/**
 * Upload dialog mount gate. See "`<UploadDialogSlot />` mount
 * strategy" in the file header.
 */
function UploadDialogSlot() {
  const { session } = useWallet();
  const { isOpen } = useUploadDialog();

  const shouldMount = session !== null || isOpen;
  if (!shouldMount) return null;
  return <UploadDialog />;
}
