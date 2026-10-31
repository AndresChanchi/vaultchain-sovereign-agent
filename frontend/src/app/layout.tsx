import type { ReactNode } from "react";
import type { Metadata, Viewport } from "next";
import Script from "next/script";
import { Geist, Geist_Mono, Instrument_Serif } from "next/font/google";
import { Web3Provider } from "@components/web3-provider";
import { ThemeProvider } from "@context/ThemeContext";
import { I18nProvider } from "@context/I18nContext";
import { WalletProvider } from "@context/WalletContext";
import { LoginModalProvider } from "@context/LoginModalContext";
import { LoginModal } from "@components/login/login-modal";

/**
 * Geist Sans — all UI text.
 * Geist Mono — addresses, hashes, prices, counters, mono labels.
 * Instrument Serif — hero H1s, featured Moment titles, public page name only.
 *
 * Each font exposes a CSS variable that `globals.css` @theme consumes as
 * `--font-sans`, `--font-mono`, `--font-serif`. `display: swap` avoids
 * invisible text during font load.
 */
const geistSans = Geist({
  subsets: ["latin"],
  variable: "--font-geist-sans",
  display: "swap",
});

const geistMono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-geist-mono",
  display: "swap",
});

const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-instrument-serif",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Kipio — Your photos are yours.",
  description:
    "Digital property, not rental. Locked on your device, recorded as yours, kept forever. No subscription, and nobody else holds the key.",
  other: {
    "talentapp:project_verification":
      "0e8df25d9f3bfe18da48710a0878309a9f387703e3f51c3a2fa401a4f947e24aa93849a05ec57b35066e1f39d751234d8f54a7a785528938bc49d7c01ef61307",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "oklch(0.12 0.02 250)" },
    { media: "(prefers-color-scheme: light)", color: "oklch(0.98 0.006 250)" },
  ],
};

/**
 * Sets `data-theme` on <html> before first paint so the user never sees a
 * flash of the wrong theme. Reads the same storage key that ThemeContext
 * writes, defaults to system. Errors are swallowed so private modes and
 * blocked-storage environments do not break rendering.
 *
 * Why `<Script>` and not `<script>`
 *   React 19 warns when it encounters a `<script>` tag inside the React
 *   tree during client rendering: "Scripts inside React components are
 *   never executed when rendering on the client." The `<script>` did
 *   execute on first HTML load (it is in the server-rendered `<head>`),
 *   but any subsequent client-side render of that tree re-encounters
 *   the tag and warns.
 *
 *   `next/script` with `strategy="beforeInteractive"` is the Next.js
 *   pattern for a script that must run before hydration. It is
 *   injected into the initial HTML `<head>` (so it still executes
 *   before paint, no FOUC), and it is not re-rendered by React — no
 *   warning. `id` is required by `next/script` for inline scripts.
 *
 * `suppressHydrationWarning` on `<html>` is still needed
 *   The script mutates `data-theme` on `<html>` before React hydrates.
 *   React sees `<html data-theme="light">` on the client when the
 *   server sent `data-theme="dark"` — a legitimate mismatch caused by
 *   client-side state. `suppressHydrationWarning` silences the warning
 *   for that one attribute. Without it, every reload of a non-dark
 *   theme logs a hydration error.
 */
const themeInitScript = `
(function(){
  try {
    var stored = localStorage.getItem("kipio:theme");
    var theme = (stored === "dark" || stored === "light" || stored === "system") ? stored : "system";
    document.documentElement.dataset.theme = theme;
  } catch (e) {
    document.documentElement.dataset.theme = "system";
  }
})();
`;

/**
 * Root layout — the only `<html>` for the whole app.
 *
 * Provider order
 *   `<ThemeProvider>` → `<I18nProvider>` → `<WalletProvider>` →
 *   `<LoginModalProvider>` → `<Web3Provider>` → children + `<LoginModal />`
 *
 *   - ThemeProvider first: it drives `data-theme` on `<html>`, which
 *     every other layer's CSS depends on.
 *
 *   - I18nProvider second: every downstream `t()` call resolves
 *     through it. No dependency on wallet or wagmi.
 *
 *   - WalletProvider third: session state (`context/WalletContext.tsx`).
 *     Independent of wagmi by design — the login surface must not pay
 *     for the legacy wagmi stack.
 *
 *   - LoginModalProvider fourth: history integration for the login
 *     modal. Reads `window.history` in effects only; SSR-safe.
 *
 *   - Web3Provider innermost: wagmi + TanStack Query, needed only by
 *     the legacy `/space` (formerly `/dashboard`) and its children.
 *     Kept innermost so nothing above it waits for wagmi init.
 *
 *   `<LoginModal />` renders outside `Web3Provider` because it does
 *   not use wagmi hooks. It reads `useWallet()` and `useLoginModal()`
 *   — both available in the ancestors. Placing it outside `Web3Provider`
 *   keeps the login flow independent of the legacy stack at the tree
 *   level, not just at the import level.
 *
 *   `LoginModal` must be a child of `LoginModalProvider` — the native
 *   `<dialog>` is opened via `useLoginModal().isOpen`.
 *
 * `<html lang>` and `<html dir>`
 *   Hardcoded to `en` / `ltr` here, matching the default locale.
 *   `I18nProvider` updates both attributes on mount if the user's
 *   stored preference differs — see its header. After the route
 *   restructure, each `[locale]` root layout will set `lang` and `dir`
 *   on the server, and this file's hardcoded attributes will move into
 *   a shared `RootDocument` component that both groups render.
 *
 * `<html data-theme>`
 *   The `dark` default is overwritten by `themeInitScript` before
 *   paint, so the value here is only the fallback for the one frame
 *   between HTML parse and inline script execution.
 */
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html
      lang="en"
      data-theme="dark"
      suppressHydrationWarning
      className={`${geistSans.variable} ${geistMono.variable} ${instrumentSerif.variable}`}
    >
      <head>
        <Script
          id="theme-init"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{ __html: themeInitScript }}
        />
        <link rel="stylesheet" href="/output.css" />
        <link rel="icon" href="/favicon.ico" />
      </head>
      <body>
        <ThemeProvider>
          <I18nProvider>
            <WalletProvider>
              <LoginModalProvider>
                <Web3Provider>{children}</Web3Provider>
                <LoginModal />
              </LoginModalProvider>
            </WalletProvider>
          </I18nProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
