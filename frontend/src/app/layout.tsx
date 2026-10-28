import type { ReactNode } from "react";
import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Instrument_Serif } from "next/font/google";
import { Web3Provider } from "@components/web3-provider";
import { ThemeProvider } from "@context/ThemeContext";
import { I18nProvider } from "@context/I18nContext";

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
 * writes, defaults to dark. Errors are swallowed so private modes and
 * blocked-storage environments do not break rendering.
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
 *   `<ThemeProvider>` → `<I18nProvider>` → `<Web3Provider>` → children
 *
 *   - ThemeProvider first: it drives `data-theme` on `<html>`, which
 *     every other layer's CSS depends on. If it were deeper in the tree,
 *     a child component could paint before the theme attribute is set.
 *
 *   - I18nProvider second: the strings from every downstream component
 *     resolve through `useI18n()`. Web3Provider hosts wallet state and
 *     is irrelevant to any string; i18n does not depend on it, so it
 *     sits outside. When a future login overlay (Phase 9) needs both,
 *     it consumes `useI18n()` and `useAccount()` without a provider
 *     ordering constraint.
 *
 *   - Web3Provider innermost: `wagmi` and TanStack Query are wrapped
 *     only where they are needed. The public landing does not require
 *     wallet connectivity for the H1 to paint; keeping it innermost
 *     means the i18n and theme layers never wait for wagmi's
 *     initialization.
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
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
        <link rel="stylesheet" href="/output.css" />
        <link rel="icon" href="/favicon.ico" />
      </head>
      <body>
        <ThemeProvider>
          <I18nProvider>
            <Web3Provider>{children}</Web3Provider>
          </I18nProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
