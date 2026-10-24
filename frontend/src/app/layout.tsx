import type { ReactNode } from "react";
import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono, Instrument_Serif } from "next/font/google";
import { Web3Provider } from "@components/web3-provider";
import { ThemeProvider } from "@context/ThemeContext";

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
    var theme = (stored === "dark" || stored === "light" || stored === "system") ? stored : "dark";
    document.documentElement.dataset.theme = theme;
  } catch (e) {
    document.documentElement.dataset.theme = "dark";
  }
})();
`;

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
          <Web3Provider>{children}</Web3Provider>
        </ThemeProvider>
      </body>
    </html>
  );
}
