"use client";

/**
 * Language picker — globe button + popover, replaces the static `EN`
 * button in `navbar.tsx`.
 *
 * Reads and writes through `useI18n()`. `setLocale` (from the context)
 * handles persistence, `<html lang/dir>`, and dictionary loading. This
 * component owns only the interaction: which item is hovered, whether
 * the popover is open, keyboard navigation.
 *
 * Available vs. supported locales
 *   The menu iterates `AVAILABLE_LOCALES` (the ones with a real
 *   dictionary), not `LOCALES` (the full 12-language roadmap). Showing
 *   a locale that silently falls back to English would be a UX lie;
 *   when `dictionaries/zh.ts` lands and `zh` joins `AVAILABLE_LOCALES`,
 *   the picker shows it without any change here.
 *
 * Trigger label
 *   `t("landing.navbar.language")` reads the short code from the
 *   *active* dictionary. In English it is "EN"; switching to Spanish
 *   makes it "ES"; the label always reflects the locale currently in
 *   effect, not the target of a pending switch.
 *
 * Positioning — two layouts
 *   Desktop (≥ md)
 *     `absolute end-0 top-full mt-2 w-[220px]`. Anchored to the
 *     trigger's right edge, opening downward. 220px is enough for
 *     "Bahasa Indonesia" on one row without wrapping.
 *
 *   Mobile (< md)
 *     `fixed inset-x-4 top-full mt-2`. The trigger sits ~180px from
 *     the right edge on a 320px viewport; an absolutely-anchored
 *     220px popover would overflow off-screen to the left (180-220 =
 *     -40px). Fixed positioning relative to the header spans the
 *     viewport minus 16px on each side — the same pattern every
 *     mobile web app uses for a language menu.
 *
 *     `top-full` with `fixed` resolves against the header because
 *     `backdrop-blur-sm` on the header creates a containing block
 *     for fixed descendants (per spec: a non-`none` `backdrop-filter`
 *     establishes a containing block for fixed descendants). The
 *     header is 84px + 1px border = 85px tall, so `top-full` = 85px
 *     from header top, `mt-2` = 8px gap → 93px from viewport top,
 *     right below the sticky navbar in all scroll states.
 *
 *     If the header ever loses `backdrop-blur-sm`, the fixed popover
 *     becomes viewport-relative and `top-full` breaks. Keep the
 *     `backdrop-blur-sm` on the header while this picker uses fixed
 *     mobile positioning — an alternative is to switch to a fixed
 *     `top-[calc(env(safe-area-inset-top)+84px+8px)]`, which is
 *     independent of the header's stacking context. Not done today
 *     to keep the two breakpoints symmetric.
 *
 * Popover styling
 *   `glass` utility (matches the trigger button). Borderless between
 *   items, one active item background. Positioned with logical
 *   `end-0` on desktop so RTL locales anchor it on the correct side.
 *   Width fixed at 220px on desktop; fluid on mobile.
 *
 * Keyboard
 *   - Escape closes and returns focus to the trigger.
 *   - ArrowUp / ArrowDown cycle the menu items.
 *   - Home / End jump to first / last.
 *   - Enter / Space activates the focused item (native button behaviour).
 *   - Tab moves out of the menu, closing it (implemented via the
 *     `focusin` listener watching for focus leaving the wrapper).
 *   - On open, focus moves to the currently-active item so keyboard
 *     users see where they are without an extra Tab.
 *
 * Close triggers
 *   - Selection (after `setLocale` resolves).
 *   - Click outside the wrapper.
 *   - Escape.
 *   - Focus leaving the wrapper.
 *
 * Scroll lock
 *   Not implemented. The popover is short and users dismiss it by
 *   tapping outside; locking scroll for a language menu would be
 *   disproportionate. Revisit only if a screen reader reports the
 *   page scrolling underneath.
 *
 * Mobile scroll inside the menu
 *   `max-h-[min(70vh,480px)] overflow-y-auto` on the list itself, not
 *   on the popover, so the top/bottom rounded corners clip cleanly.
 *   At 12 items × ~40px, the menu is 480px — taller than an SE's
 *   viewport, so scroll is required once all locales are translated.
 */

import { useEffect, useRef, useState } from "react";
import { useI18n } from "@context/I18nContext";
import {
  AVAILABLE_LOCALES,
  LOCALE_META,
  type Locale,
} from "@lib/i18n/locales";

export function LanguagePicker() {
  const { locale, setLocale, t } = useI18n();
  const [open, setOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

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

  async function select(code: Locale) {
    if (code === locale) {
      setOpen(false);
      triggerRef.current?.focus();
      return;
    }
    // Await the switch before closing so the button label flips in
    // one paint (instead of showing the old code for a frame while
    // the dynamic import resolves).
    await setLocale(code);
    setOpen(false);
    triggerRef.current?.focus();
  }

  return (
    <div ref={wrapperRef} className="relative">
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t("landing.navbar.changeLanguage")}
        className="glass inline-flex h-10 items-center gap-2 rounded-[14px] px-3 text-sm font-medium text-ink transition-colors duration-200 hover:bg-elevated"
      >
        <GlobeIcon />
        <span className="hidden md:inline">
          {t("landing.navbar.language")}
        </span>
      </button>

      {open && (
        <div
          ref={menuRef}
          role="menu"
          aria-label={t("landing.navbar.changeLanguage")}
          onKeyDown={onMenuKeyDown}
          className="glass fixed inset-x-4 top-full z-30 mt-2 max-h-[min(70vh,480px)] overflow-y-auto rounded-[14px] p-1.5 md:absolute md:inset-x-auto md:end-0 md:w-[220px]"
        >
          {AVAILABLE_LOCALES.map((code) => {
            const meta = LOCALE_META[code];
            const isActive = code === locale;
            return (
              <button
                key={code}
                type="button"
                role="menuitemradio"
                aria-checked={isActive}
                onClick={() => select(code)}
                className={`flex w-full items-center justify-between gap-3 rounded-[10px] px-3 py-2 text-start text-sm transition-colors duration-150 ${
                  isActive
                    ? "bg-elevated text-ink"
                    : "text-muted hover:bg-elevated/60 hover:text-ink"
                }`}
              >
                <span>{meta.nativeName}</span>
                <span className="font-mono text-[11px] text-muted">
                  {meta.label}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

/**
 * Globe icon — same 18×18 frame as the other navbar controls, so
 * the three buttons (theme toggle, language, log in) share a visual
 * rhythm.
 */
function GlobeIcon() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18" />
    </svg>
  );
}
