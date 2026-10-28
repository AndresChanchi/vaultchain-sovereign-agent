"use client";

import { useI18n } from "@context/I18nContext";
import { PricingCard } from "@components/landing/pricing-card";

/**
 * Pricing section — the composition root of the pricing area.
 *
 * Two-column layout on lg: copy on the left, `<PricingCard />` on the
 * right. Below lg, the copy stacks above the card.
 *
 * This component is the "wrapper" pattern used across the landing:
 *   - Owns the section chrome (eyebrow, H2, subtitle, `<section>` id,
 *     spacing, grid).
 *   - Delegates the interactive content (segmented, slider, picker,
 *     breakdown) to `<PricingCard />`, which is its own client island.
 *
 * `page.tsx` renders `<Pricing />` with no props. That composition
 * keeps `page.tsx` purely structural — it imports sections and orders
 * them, nothing else.
 *
 * Client Component
 *   `useI18n()` for the three visible strings. `PricingCard` handles
 *   its own state (TanStack Query, slider, picker) — the wrapper does
 *   not need to know about any of it.
 */
export function Pricing() {
  const { t } = useI18n();

  return (
    <section id="pricing" className="mx-auto max-w-[1280px] px-6 py-24 md:px-10">
      <div className="grid gap-12 lg:grid-cols-2 lg:items-center">
        <div>
          <p className="label-mono text-emerald-text">
            {t("landing.pricing.eyebrow")}
          </p>
          <h2 className="mt-4 text-balance text-[30px] font-bold leading-tight tracking-[-0.025em] text-ink md:text-[40px]">
            {t("landing.pricing.title")}
          </h2>
          <p className="mt-4 max-w-lg text-balance text-[15px] leading-[1.6] text-muted">
            {t("landing.pricing.subtitle")}
          </p>
        </div>
        <PricingCard />
      </div>
    </section>
  );
}
