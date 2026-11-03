/**
 * robots.txt — generated at build time, static-export compatible.
 *
 * Two audiences
 *   - Classic search: Googlebot, Bingbot. Allowed everywhere public.
 *   - AI agents: each vendor has its own user agent. The choices below
 *     reflect a site that wants to be *cited* by AI answers without
 *     handing over training corpora blindly. See the matrix at the
 *     bottom of the file for the reasoning per crawler.
 *
 * Why one group per crawler
 *   `robots.txt` groups are evaluated per matching `User-agent` line.
 *   A crawler that finds a group addressed to it uses *only* that
 *   group — the wildcard `User-agent: *` is ignored for it. So every
 *   AI crawler we want to control needs its own group; leaving it to
 *   the wildcard means "whatever the wildcard says", which is the
 *   wrong default for training crawlers.
 *
 * AI crawler matrix (2026-10, verified against vendor docs)
 *   GPTBot            OpenAI · training        → allowed on public,
 *                                                blocked on /api/ and
 *                                                /dashboard (no useful
 *                                                content for a model).
 *   OAI-SearchBot     OpenAI · ChatGPT search  → allowed everywhere.
 *                                                This is the one that
 *                                                makes the site show up
 *                                                in ChatGPT's answers.
 *   ClaudeBot         Anthropic · retrieval    → allowed everywhere.
 *                                                Anthropic honours
 *                                                robots.txt groups
 *                                                addressed to it.
 *   PerplexityBot     Perplexity · indexing    → allowed everywhere.
 *                                                Perplexity uses the
 *                                                page content directly
 *                                                in its answers.
 *   Google-Extended   Google · Gemini training → allowed on public.
 *                                                Does NOT affect
 *                                                Googlebot or AI
 *                                                Overviews; blocking
 *                                                it removes the site
 *                                                from Gemini training
 *                                                only.
 *   CCBot             Common Crawl             → allowed on public.
 *                                                Common Crawl feeds
 *                                                many open models; if
 *                                                you want the site to
 *                                                appear in open-weight
 *                                                models, keep it
 *                                                allowed.
 *   Bingbot           Microsoft · search + Copilot → allowed. Copilot
 *                                                inherits from Bing's
 *                                                index; allowing Bingbot
 *                                                is the cheapest way to
 *                                                be citable there.
 *
 * When to change this file
 *   - If a client asks "why is my photo in ChatGPT?", the answer is
 *     that OAI-SearchBot and ClaudeBot are allowed. Block them here
 *     and the site stops appearing in those answers within a recrawl
 *     window (hours to days). The trade-off is symmetric: no more
 *     citations either.
 *   - If you only care about search engines and want to opt out of AI
 *     entirely, add `Disallow: /` groups for GPTBot, OAI-SearchBot,
 *     ClaudeBot, PerplexityBot, Google-Extended, CCBot and leave
 *     Googlebot + Bingbot allowed.
 */

import type { MetadataRoute } from "next";

const SITE_URL = "https://kipio.xyz";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      // ── Classic search ─────────────────────────────────────────
      {
        userAgent: "Googlebot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
      {
        userAgent: "Bingbot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },

      // ── AI crawlers ────────────────────────────────────────────
      // Each crawler gets its own group — see the header note.
      {
        userAgent: "GPTBot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
      {
        userAgent: "OAI-SearchBot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
      {
        userAgent: "ClaudeBot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
      {
        userAgent: "PerplexityBot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
      {
        userAgent: "Google-Extended",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
      {
        userAgent: "CCBot",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },

      // ── Everything else ────────────────────────────────────────
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/api/", "/dashboard/"],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  };
}
