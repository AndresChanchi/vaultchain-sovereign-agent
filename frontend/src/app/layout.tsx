import type { ReactNode } from "react";
import type { Metadata, Viewport } from "next";
import Script from "next/script";
import { Providers } from "./providers";
import { geistSans, geistMono, instrumentSerif } from "@lib/fonts";
import { themeInitScript } from "@lib/theme/init-script";

/**
 * Root layout — the only `<html>` for the whole app.
 *
 * Composition only
 *   Fonts, theme init script and providers live in their own modules
 *   (`lib/fonts.ts`, `lib/theme/init-script.ts`, `app/providers.tsx`).
 *   This file composes them into `<html>` and `<body>`. Kept minimal
 *   so the app's document structure is readable at a glance.
 *
 * Provider order and rationale
 *   See `app/providers.tsx` — the doc lives with the code it
 *   describes.
 *
 * `<html lang>` and `<html dir>`
 *   Hardcoded to `en` / `ltr`, matching the default locale.
 *   `I18nProvider` updates both attributes on mount if the user's
 *   stored preference differs. After the route restructure, each
 *   `[locale]` root layout will set `lang` and `dir` on the server,
 *   and this file moves those attributes into a shared `RootDocument`
 *   both groups render.
 *
 * `<html data-theme>`
 *   The `dark` default is overwritten by `themeInitScript` before
 *   paint. `suppressHydrationWarning` is required because the script
 *   mutates the attribute before React hydrates — see
 *   `lib/theme/init-script.ts`.
 *
 * `<head>`
 *   - `<Script id="theme-init" strategy="beforeInteractive">` — runs
 *     before paint, no FOUC.
 *   - `<link rel="stylesheet" href="/output.css">` — the Tailwind CLI
 *     emits `public/output.css`; the `<link>` tag is the connection.
 *   - `<link rel="icon">` — favicon.
 *
 * Metadata
 *   `title`, `description`, and the third-party verification token
 *   (TalentApp) are declared here. The token is a build-time
 *   constant; if it ever needs to vary by environment, move it to
 *   `NEXT_PUBLIC_TALENTAPP_VERIFICATION` in `next.config` / `.env`
 *   and read it in `metadata`.
 */
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
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
