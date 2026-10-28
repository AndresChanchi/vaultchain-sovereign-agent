"use client";

/**
 * Currency picker — glass button + popover listing every currency the
 * app supports. Consumed by the `PricingCard` (and any future surface
 * that needs a currency selector: checkout, offers, upload review).
 *
 * Positioning — `absolute`, not `fixed`
 *   The first version used `fixed inset-x-4 top-full` (mirroring
 *   `language-picker.tsx`). That pattern is only valid inside the
 *   navbar, where `backdrop-blur-sm` establishes a containing block
 *   for `fixed` descendants. This picker lives inside the pricing
 *   card, which has no `backdrop-filter` — so `fixed top-full`
 *   resolves against the viewport and lands at `top: 100vh`, i.e.
 *   below the fold.
 *
 *   The current implementation uses `absolute end-0 top-full w-[240px]`
 *   at every breakpoint. `absolute` resolves against the wrapper
 *   `<div className="relative">` — trigger height is 36px, so
 *   `top: 100%` = 36px, and the popover appears 8px below the button
 *   (`mt-2`). Right-aligned (`end-0`) to the trigger, the popover
 *   extends leftward and fits inside the card on any realistic
 *   viewport. `max-w-[calc(100vw-32px)]` guards against hypothetical
 *   viewports narrower than 272px.
 *
 * Trigger content
 *   The button shows the **symbol** of the currently-selected currency
 *   (`$`, `R$`, `€`, `S/`) plus its ISO code, and a chevron. The
 *   symbol is what the user recognizes at a glance; the ISO code
 *   disambiguates between currencies that share a symbol (USD, COP,
 *   MXN, ARS, CLP, UYU all use `$` in their locale). `aria-label`
 *   carries both.
 *
 * Popover content — primary grouping
 *   `SUPPORTED_CURRENCIES` entries with `primary: true` (USD, COP,
 *   MXN, BRL, ARS) render in the top block; the rest sit below a
 *   `role="separator"` divider. Users in Mexico/Argentina do not
 *   scroll past "British Pound" to reach MXN/ARS.
 *
 * Accessibility — `role="menu"` + `role="menuitemradio"`
 *   The `role="menu"` container accepts `menuitemradio` children and
 *   `role="separator"` dividers per WAI-ARIA 1.2. `aria-checked` on
 *   each row reflects single-select state. Focus moves to the active
 *   item on open; Escape closes and returns focus; focus-leave
 *   closes; arrow keys cycle; Home/End jump to ends.
 *
 * Persistence
 *   The selected currency is NOT persisted. It is component state in
 *   `PricingCard`. A currency preference is per-transaction, not
 *   per-user. A future Settings surface that wants a persisted
 *   default passes the value in as a prop; this component stays
 *   stateless.
 *
 * i18n
 *   The trigger's `aria-label` is built from `pricing.currencyLabel`
 *   and the currency's `label` from `SUPPORTED_CURRENCIES`. Currency
 *   names are proper nouns, not translated. The user's language
 *   affects the *format* of the price (via `format.currency`), not
 *   the labels here.
 */

import { useEffect, useRef, useState } from "react";
import { SUPPORTED_CURRENCIES, type CurrencyCode } from "@config/pricing";
import { useI18n } from "@context/I18nContext";

type CurrencyEntry = (typeof SUPPORTED_CURRENCIES)[number];

type CurrencyPickerProps = {
  value: CurrencyCode;
  onChange: (next: CurrencyCode) => void;
};

export function CurrencyPicker({ value, onChange }: CurrencyPickerProps) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  const current = SUPPORTED_CURRENCIES.find((c) => c.code === value);
  const primary = SUPPORTED_CURRENCIES.filter((c) => c.primary);
  const secondary = SUPPORTED_CURRENCIES.filter((c) => !c.primary);

  // ── Close on outside click / Escape / focus-leave ────────────────
  useEffect(() => {
    if (!open) return;

    function onPointerDown(event: PointerEvent) {
      if (!wrapperRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setOpen(false);
        triggerRef.current?.focus();
      }
    }
    function onFocusIn(event: FocusEvent) {
      if (!wrapperRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    }

    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    document.addEventListener("focusin", onFocusIn);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
      document.removeEventListener("focusin", onFocusIn);
    };
  }, [open]);

  // ── Focus the active item when the menu opens ────────────────────
  useEffect(() => {
    if (!open) return;
    const active = menuRef.current?.querySelector<HTMLButtonElement>(
      '[aria-checked="true"]',
    );
    active?.focus();
  }, [open]);

  // ── Arrow / Home / End navigation inside the menu ────────────────
  function onMenuKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    const items = Array.from(
      event.currentTarget.querySelectorAll<HTMLButtonElement>(
        '[role="menuitemradio"]',
      ),
    );
    if (items.length === 0) return;
    const currentIndex = items.findIndex(
      (item) => item === document.activeElement,
    );
    const focus = (index: number) => {
      const clamped = (index + items.length) % items.length;
      items[clamped]?.focus();
      event.preventDefault();
    };
    switch (event.key) {
      case "ArrowDown":
        focus(currentIndex + 1);
        break;
      case "ArrowUp":
        focus(currentIndex - 1);
        break;
      case "Home":
        focus(0);
        break;
      case "End":
        focus(items.length - 1);
        break;
    }
  }

  function select(code: CurrencyCode) {
    onChange(code);
    setOpen(false);
    triggerRef.current?.focus();
  }

  function renderRow(entry: CurrencyEntry) {
    const isActive = entry.code === value;
    return (
      <button
        key={entry.code}
        type="button"
        role="menuitemradio"
        aria-checked={isActive}
        onClick={() => select(entry.code)}
        className={`flex w-full items-center justify-between gap-3 rounded-[10px] px-3 py-2 text-start text-sm transition-colors duration-150 ${
          isActive
            ? "bg-elevated text-ink"
            : "text-muted hover:bg-elevated/60 hover:text-ink"
        }`}
      >
        <span className="flex items-center gap-2">
          <span
            aria-hidden="true"
            className="inline-flex h-5 min-w-[24px] items-center justify-center rounded-[6px] bg-elevated/60 px-1 font-mono text-[11px] text-ink"
          >
            {entry.symbol}
          </span>
          <span>{entry.label}</span>
        </span>
        <span className="font-mono text-[11px] text-muted">{entry.code}</span>
      </button>
    );
  }

  return (
    <div ref={wrapperRef} className="relative">
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={`${t("landing.pricing.currencyLabel")}, ${
          current?.label ?? value
        }`}
        className="glass inline-flex h-9 items-center gap-2 rounded-[12px] px-3 text-sm font-medium text-ink transition-colors duration-200 hover:bg-elevated"
      >
        <span className="font-mono text-[12px]">{current?.symbol ?? "$"}</span>
        <span className="font-mono text-[11px] text-muted">
          {current?.code ?? value}
        </span>
        <svg
          aria-hidden="true"
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.4"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="text-muted"
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>

      {open && (
        <div
          ref={menuRef}
          role="menu"
          aria-label={t("landing.pricing.currencyLabel")}
          onKeyDown={onMenuKeyDown}
          className="glass absolute end-0 top-full z-30 mt-2 max-h-[min(70vh,480px)] w-[240px] max-w-[calc(100vw-32px)] overflow-y-auto rounded-[14px] p-1.5"
        >
          {primary.map((c) => renderRow(c))}
          {secondary.length > 0 && (
            <div
              role="separator"
              aria-orientation="horizontal"
              className="my-1 h-px bg-hairline"
            />
          )}
          {secondary.map((c) => renderRow(c))}
        </div>
      )}
    </div>
  );
}
