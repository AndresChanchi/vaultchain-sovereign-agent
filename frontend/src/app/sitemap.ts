/**
 * Sitemap — one entry per public route, with hreflang alternates for
 * every locale. `x-default` points at the English version (served at
 * `/`), which is what Google and AI crawlers use when no language
 * matches.
 *
 * Static-export compatible
 *   `MetadataRoute.Sitemap` is emitted at build time and works with
 *   `output: 'export'`. There is no runtime server involved.
 *
 *   The route lives at `app/sitemap.ts`, NOT under `app/[locale]/`.
 *   Next.js 16.3 has a documented regression where a `sitemap.ts`
 *   inside a dynamic segment collapses to `/-/sitemap.xml`; keeping
 *   it at the app root avoids that and produces one sitemap that
 *   lists every locale, which is also what Google recommends for
 *   small-to-medium sites (one sitemap, many locales).
 *
 *   When the site grows past the 50k-URL-per-sitemap limit (or the
 *   50MB unzipped cap), split into a sitemap index — one child per
 *   locale. Not needed today; the landing has a handful of routes.
 *
 * `SITE_URL`
 *   Central constant so `robots.ts`, `sitemap.ts` and the JSON-LD
 *   blocks all emit the same base. When you switch to a custom domain
 *   or Fleek hosting, change it here (one place). The value is read at
 *   build time; no environment variable needed for a static export.
 */

import type { MetadataRoute } from "next";
import { LOCALES, LOCALE_META, localePath } from "@lib/i18n/locales";

/**
 * Canonical origin. Replace with the production domain when it is
 * finalized. The path segments below are appended in `localePath`.
 *
 * TODO: move to `@config/site.ts` when a second consumer appears
 * (JSON-LD block, `metadataBase` in root layouts). For now the only
 * consumer is this file plus `robots.ts`.
 */
const SITE_URL = "https://kipio.xyz";

/**
 * Routes that exist for every locale. Paths are locale-neutral — the
 * `localePath` helper prefixes them for non-default locales. The list
 * grows as the app adds routes; landing is the only public route
 * today, dashboard is not sitemap-eligible (auth required).
 */
const ROUTES = ["/"] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  return ROUTES.flatMap((route) =>
    LOCALES.map((locale) => {
      const url = `${SITE_URL}${localePath(locale, route)}`;

      /**
       * Alternate language map for this URL. `x-default` points at
       * English (`/`) — Google uses it when none of the listed
       * languages match the user. Each entry is a full absolute URL,
       * as required by `MetadataRoute.Sitemap`.
       */
      const languages = Object.fromEntries(
        LOCALES.map((l) => [
          l,
          `${SITE_URL}${localePath(l, route)}`,
        ]),
      );

      return {
        url,
        lastModified: now,
        changeFrequency: "weekly" as const,
        priority: locale === "en" ? 1.0 : 0.9,
        alternates: {
          languages: {
            ...languages,
            "x-default": `${SITE_URL}${localePath("en", route)}`,
          },
        },
        // `og:locale` shape, in case a future consumer wants it without
        // reading `LOCALE_META` again. Not part of the official type;
        // omitted today. Kept as a note for the reader.
      };
    }),
  );
}
