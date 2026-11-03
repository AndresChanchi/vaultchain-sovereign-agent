"use client";

/**
 * Login modal — state and History integration.
 *
 * The login panel is a modal, not a page. Next.js's own intercepting
 * routes (`@modal/(.)login`) would give us this for free, but they
 * are incompatible with `output: 'export'` — and the Fleek target
 * requires that mode. So we implement the behaviour ourselves with
 * the History API. Same UX, zero framework coupling, works on any
 * static host.
 *
 * Contract
 *   `isOpen`            — whether the modal should render.
 *   `openLogin(opts?)`  — push `/login` onto the history stack,
 *                         sync `returnTo`, open the modal.
 *   `closeLogin(opts?)` — close the modal. By default the URL is
 *                         reverted (via `history.back()` when the
 *                         marker is present, `replaceState("/")`
 *                         when the user landed on `/login` directly).
 *                         With `{ silent: true }`, the URL is left
 *                         untouched — the caller is about to navigate
 *                         elsewhere via `router.replace` and would
 *                         race the `history.back()`.
 *
 * Why `silent`
 *   `closeLogin()` on the marker path calls `history.back()` — an
 *   async browser navigation. If the caller also calls
 *   `router.replace(target)` in the same tick (the post-login
 *   redirect), the two navigations race and one wins arbitrarily.
 *   In practice `history.back()` wins and the user lands on `/`
 *   instead of `/space`. `{ silent: true }` skips the history
 *   manipulation entirely; the caller's `router.replace` owns the
 *   navigation, and `isOpen` resets so the modal unmounts on the
 *   next render.
 *
 *   `LoginModal` and `LoginPage` both use `{ silent: true }` when
 *   redirecting after a successful sign-in. No other caller does —
 *   the user-driven close paths (X, Escape, backdrop) use the
 *   default `closeLogin()` and revert the URL correctly.
 *
 * History state marker
 *   `openLogin` pushes `{ kipioLoginModal: true }`. The `popstate`
 *   listener uses that marker to decide whether the modal should be
 *   open after a back/forward navigation. Without the marker, closing
 *   the modal programmatically and then pressing forward would
 *   re-open it — with the marker, the state machine is consistent.
 *
 * `returnTo` — why sessionStorage
 *   The login can be triggered from two places: the navbar ("just
 *   log in") and the upload flow ("log in to continue uploading").
 *   After a successful sign-in, the user must land where they
 *   intended. A URL query param (`/login?next=/upload`) would leak
 *   into the address bar and survive link sharing; `localStorage`
 *   would persist across tabs and days. `sessionStorage` dies with
 *   the tab and is scoped to the current origin — exactly the
 *   lifetime of the modal.
 *
 *   `returnTo` is synced on every `openLogin` call: a stale
 *   destination from a prior open that was never consumed must not
 *   hijack the next generic "Log in" click. `returnTo` is validated
 *   as an internal path before storage — `//evil.example` and
 *   `https://evil.example` are rejected, only `/…` is accepted.
 *
 * Double-`back()` guard
 *   `history.back()` is asynchronous: `popstate` fires on the next
 *   task. If two `closeLogin` calls land in the same task (double
 *   click on the modal close button, or a consumer calling it twice
 *   from a `useEffect`), both would see the marker, both would call
 *   `back()`, and the user would end up two entries back. The
 *   `pendingBackRef` guard blocks the second call until the first
 *   `popstate` clears it.
 *
 * SSR safety
 *   The provider never reads `window` during render. All History and
 *   `sessionStorage` access happens inside `useEffect` or inside the
 *   `useCallback` handlers, which only run after mount.
 *
 * Scroll lock and focus trap
 *   Deliberately NOT in this context. They belong to the visual
 *   modal (`components/login/login-modal.tsx`). The context stays a
 *   pure state machine.
 *
 * TODO: when the route restructure (Fase 9) ships, `"/login"` moves
 *       under `(default)/login` and `[locale]/login`. This file
 *       references the path as a constant (`LOGIN_PATH`) so the
 *       change is one line.
 */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";

const LOGIN_PATH = "/login";
const RETURN_TO_KEY = "kipio:login:return";

type LoginHistoryState = { kipioLoginModal: true };

/**
 * Reject anything that would navigate outside the origin. Only plain
 * internal paths (`/upload`, `/dashboard`, `/foo?bar=1`) are accepted.
 * `//evil.example` (protocol-relative) and `https://evil.example`
 * (absolute) are silently dropped.
 */
function isSafeInternalPath(value: string): boolean {
  return value.startsWith("/") && !value.startsWith("//");
}

type OpenOptions = { returnTo?: string };
type CloseOptions = {
  /**
   * When `true`, only reset `isOpen` — do not touch the history. Use
   * this when the caller is about to `router.replace()` to another
   * route; the browser-history manipulation would race the Next.js
   * navigation. See "Why `silent`" in the file header.
   */
  silent?: boolean;
};

type LoginModalContextValue = {
  isOpen: boolean;
  openLogin: (options?: OpenOptions) => void;
  closeLogin: (options?: CloseOptions) => void;
};

const LoginModalContext = createContext<LoginModalContextValue | null>(null);

export function LoginModalProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const pendingBackRef = useRef(false);

  useEffect(() => {
    if (typeof window === "undefined") return;

    if (window.location.pathname === LOGIN_PATH) {
      setIsOpen(true);
    }

    const handlePopState = (event: PopStateEvent) => {
      pendingBackRef.current = false;
      const state = event.state as Partial<LoginHistoryState> | null;
      setIsOpen(state?.kipioLoginModal === true);
    };

    window.addEventListener("popstate", handlePopState);
    return () => window.removeEventListener("popstate", handlePopState);
  }, []);

  const openLogin = useCallback((options?: OpenOptions) => {
    if (typeof window === "undefined") return;

    try {
      if (
        options?.returnTo !== undefined &&
        isSafeInternalPath(options.returnTo)
      ) {
        window.sessionStorage.setItem(RETURN_TO_KEY, options.returnTo);
      } else {
        window.sessionStorage.removeItem(RETURN_TO_KEY);
      }
    } catch {
      // sessionStorage can throw in private mode or when disabled.
    }

    if (window.location.pathname === LOGIN_PATH) {
      setIsOpen(true);
      return;
    }

    const state: LoginHistoryState = { kipioLoginModal: true };
    window.history.pushState(state, "", LOGIN_PATH);
    setIsOpen(true);
  }, []);

  const closeLogin = useCallback((options?: CloseOptions) => {
    if (typeof window === "undefined") return;

    // Silent close: only reset state, do not touch the URL. Used by
    // the post-login redirect paths so `router.replace(target)` does
    // not race a `history.back()`. See "Why `silent`" in the header.
    if (options?.silent === true) {
      setIsOpen(false);
      return;
    }

    const state = window.history.state as Partial<LoginHistoryState> | null;

    if (state?.kipioLoginModal === true) {
      if (pendingBackRef.current) return;
      pendingBackRef.current = true;
      window.history.back();
      return;
    }

    if (window.location.pathname !== LOGIN_PATH) {
      setIsOpen(false);
      return;
    }

    window.history.replaceState(null, "", "/");
    setIsOpen(false);
  }, []);

  const value = useMemo<LoginModalContextValue>(
    () => ({ isOpen, openLogin, closeLogin }),
    [isOpen, openLogin, closeLogin],
  );

  return (
    <LoginModalContext.Provider value={value}>
      {children}
    </LoginModalContext.Provider>
  );
}

export function useLoginModal(): LoginModalContextValue {
  const ctx = useContext(LoginModalContext);
  if (ctx === null) {
    throw new Error("useLoginModal must be used inside <LoginModalProvider>.");
  }
  return ctx;
}

/**
 * Read the post-login destination recorded by `openLogin`. Returns
 * `null` when no destination was set. Clears the entry so a later
 * modal open does not inherit a stale value. Call exactly once, after
 * a successful sign-in.
 *
 * Exported as a separate function (not a hook) because it is called
 * from an event handler after the auth completes, not during render.
 *
 * Validates the stored value once more before returning it — the
 * value was validated at write time, but `sessionStorage` is
 * user-writable. A tampered `"//evil.example"` would otherwise be
 * handed to `router.push()` by the consumer.
 */
export function consumeLoginReturnTo(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const value = window.sessionStorage.getItem(RETURN_TO_KEY);
    window.sessionStorage.removeItem(RETURN_TO_KEY);
    if (value === null) return null;
    return isSafeInternalPath(value) ? value : null;
  } catch {
    return null;
  }
}
