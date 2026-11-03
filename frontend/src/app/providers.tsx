"use client";

/**
 * Providers — the client boundary of the app.
 *
 * Every provider in the tree is `"use client"` (they hold state, refs,
 * or context). Nesting them in a dedicated client module isolates the
 * boundary from the server-rendered layout, so `layout.tsx` stays a
 * Server Component.
 *
 * Server children pass through
 *   Next.js App Router preserves `{children}` as a server-rendered
 *   slot even when the parent is a client component. The page tree
 *   below `<Providers>` remains server-rendered by default; only the
 *   providers themselves hydrate.
 *
 * Provider order
 *   `<ThemeProvider>` → `<I18nProvider>` → `<WalletProvider>` →
 *   `<KipioProvider>` → `<LoginModalProvider>` → `<Web3Provider>` →
 *   children + `<LoginModal />`
 *
 *   - ThemeProvider first: drives `data-theme` on `<html>`, which
 *     every other layer's CSS depends on.
 *   - I18nProvider second: every downstream `t()` call resolves
 *     through it. No dependency on wallet or wagmi.
 *   - WalletProvider third: `WalletContext` — the single source of
 *     truth for authenticated identity. Independent of wagmi by
 *     design; the login surface (modal, /auth/callback, /space shell)
 *     reads only `useWallet()`.
 *   - KipioProvider fourth: cryptographic operations (vault master
 *     key, encrypt/decrypt, crypto worker). Depends on
 *     `WalletProvider.signTypedData` to derive the AES key — that is
 *     why it must sit inside `WalletProvider`. It does NOT depend on
 *     wagmi; the signer is session-aware (wallet → provider popup,
 *     OAuth → local ephemeral signature).
 *   - LoginModalProvider fifth: `LoginModal` history integration.
 *   - Web3Provider innermost: wagmi + TanStack Query. Kept innermost
 *     because it is currently only used by the legacy upload flow
 *     that Fase 10 rewrites. Nothing above it needs it.
 *
 *   `<LoginModal />` sits outside `Web3Provider` — it does not use
 *   wagmi hooks. Keeps the login flow independent of the legacy
 *   stack at the tree level.
 *
 *   `LoginModal` must be a child of `LoginModalProvider` — the
 *   native `<dialog>` opens via `useLoginModal().isOpen`.
 *
 * Fase 10 retirement note
 *   When the legacy upload flow is rewritten against `WalletContext`,
 *   `<Web3Provider>` becomes dead code and is removed from this file.
 *   The other five stay — they are the runtime the new product uses.
 */

import type { ReactNode } from "react";
import { Web3Provider } from "@components/web3-provider";
import { ThemeProvider } from "@context/ThemeContext";
import { I18nProvider } from "@context/I18nContext";
import { WalletProvider } from "@context/WalletContext";
import { KipioProvider } from "@context/KipioContext";
import { LoginModalProvider } from "@context/LoginModalContext";
import { LoginModal } from "@components/login/login-modal";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider>
      <I18nProvider>
        <WalletProvider>
          <KipioProvider>
            <LoginModalProvider>
              <Web3Provider>{children}</Web3Provider>
              <LoginModal />
            </LoginModalProvider>
          </KipioProvider>
        </WalletProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
