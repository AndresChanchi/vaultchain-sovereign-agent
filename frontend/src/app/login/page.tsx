"use client";

/**
 * /login — direct-access fallback for the login modal.
 *
 * The login UI is a modal (see `components/login/login-modal.tsx`),
 * not a page. `LoginModalProvider` detects direct access to `/login`
 * on mount (`window.location.pathname === LOGIN_PATH`) and opens the
 * modal automatically.
 *
 * This file exists for two reasons:
 *
 *   1. `/login` must be a valid route. Without it, direct access is a
 *      404 — the modal would still open (mounted at the layout level)
 *      but the page underneath would look broken, and Next.js would
 *      not prerender the route for `output: 'export'`.
 *
 *   2. It redirects signed-in users away. Landing on `/login` while
 *      already signed in has no purpose. Redirect to `/space` (or
 *      the recorded `returnTo`).
 *
 * Signed-in redirect — and why `silent: true`
 *   The effect fires when `status === "connected" && session !== null`
 *   (i.e. the user connected from a deep-link, or was already signed
 *   in when the route mounted). It MUST call `closeLogin({ silent: true })`
 *   before `router.replace(target)`, exactly like `LoginModal`.
 *   Without it, `isOpen` stays `true` (the default `closeLogin`
 *   reverts the URL but does not toggle the state on the marker-less
 *   path) and the modal stays open over `/space` — the user lands on
 *   `/space` with the dialog floating above it.
 *
 * The `wasOpen` guard — why it exists
 *   The `wasOpen` effect handles the "user closed the modal" redirect
 *   to `/`. It must NOT fire when the close was caused by a
 *   successful sign-in: in that case the signed-in effect above owns
 *   the navigation.
 *
 *   Without the guard:
 *     1. Signed-in effect: `router.replace("/space")`.
 *     2. `isOpen` becomes `false` on the next render.
 *     3. `wasOpen` effect: `router.replace("/")`.
 *     4. Two `router.replace` calls in the same tick — the second
 *        wins. User lands on `/`, not `/space`. This is the deep-link
 *        symptom: connect from `/login`, end up on the landing.
 *
 *   With the guard (`if (status === "connected" && session !== null)
 *   return`), the `wasOpen` effect steps aside and only the signed-in
 *   effect navigates.
 *
 * Backdrop vs empty — the `null` return
 *   Three states of `isOpen` need distinct visuals:
 *
 *     - `isOpen === false, wasOpen.current === false` — initial
 *       mount, before `LoginModalProvider` flips `isOpen` to `true`.
 *       Render the backdrop (`<KipioMark>` on `amb-bg`) so the page
 *       does not flash empty for the ~1 frame it takes for the
 *       provider's mount effect to fire.
 *
 *     - `isOpen === false, wasOpen.current === true` — the modal was
 *       open and just closed (Escape, X button, browser back). Return
 *       `null`. The `router.replace("/")` above is in flight; the
 *       backdrop would be a stale, static image of a page the user
 *       is leaving. An empty body is cleaner and honest.
 *
 *     - `isOpen === true` — render the backdrop. It sits underneath
 *       the modal (a `<dialog>` overlay), providing visual grounding
 *       around the panel edges.
 *
 * Redirect after close
 *   `closeLogin()` on a direct-landing path calls
 *   `history.replaceState(null, "", "/")` — this changes the URL bar
 *   to `/` but does NOT trigger a Next.js navigation. The React tree
 *   stays on `/login`. The `wasOpen` effect catches the open → closed
 *   transition and navigates via `router.replace("/")`.
 *
 *   `wasOpen` guards against the initial mount (`isOpen` starts
 *   `false` before `LoginModalProvider`'s mount effect flips it).
 *
 * Race with `LoginModal`'s redirect effect
 *   In the deep-link + connect case, BOTH `LoginPage` and `LoginModal`
 *   run their redirect effect. `LoginPage` consumes `returnTo` first
 *   (it is rendered higher in the tree, its effects run first);
 *   `LoginModal` gets `null` and falls back to `/space`. Same target
 *   in the common case (`returnTo` is only set by in-page
 *   `openLogin({ returnTo })` calls, which do not deep-link). The
 *   guard above prevents the `wasOpen` race that would otherwise
 *   override both.
 *
 *   Edge case: deep-link `/login` with a stale `returnTo` in
 *   `sessionStorage` from a prior open. `LoginPage` targets the
 *   stale path, `LoginModal` targets `/space` and wins (last effect).
 *   Minor loss of `returnTo`, documented for Fase 9 — a
 *   `usePathname()` guard in `LoginModal` would close it, but the
 *   pathname is the same (`/login` via `pushState` and via actual
 *   route) so the guard is not reliable today.
 *
 * SSR
 *   `useWallet()` and `useLoginModal()` require their providers,
 *   which are mounted at the root. During SSG, the effects do not
 *   run — the page renders the backdrop, hydrates, and the redirect
 *   effects fire client-side. No hydration mismatch: `isOpen` starts
 *   `false` on both SSR and the client's first render.
 */

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  consumeLoginReturnTo,
  useLoginModal,
} from "@context/LoginModalContext";
import { useWallet } from "@context/WalletContext";
import { KipioMark } from "@components/ui/kipio-mark";

const DEFAULT_RETURN_TO = "/space";

export default function LoginPage() {
  const router = useRouter();
  const { status, session } = useWallet();
  const { isOpen, closeLogin } = useLoginModal();

  // Signed-in redirect. Must use `closeLogin({ silent: true })` —
  // see "Signed-in redirect — and why `silent: true`" in the header.
  useEffect(() => {
    if (status !== "connected" || session === null) return;
    const target = consumeLoginReturnTo() ?? DEFAULT_RETURN_TO;
    closeLogin({ silent: true });
    router.replace(target);
  }, [status, session, closeLogin, router]);

  // Redirect to `/` after the modal closes on direct landing. The
  // guard at the end is what prevents this effect from racing the
  // signed-in effect above — see "The `wasOpen` guard — why it
  // exists" in the header.
  const wasOpen = useRef(false);
  useEffect(() => {
    if (isOpen) {
      wasOpen.current = true;
      return;
    }
    if (!wasOpen.current) return;
    if (status === "connected" && session !== null) return;
    router.replace("/");
  }, [isOpen, router, status, session]);

  // See "Backdrop vs empty — the `null` return" in the header.
  if (!isOpen && wasOpen.current) {
    return null;
  }

  return (
    <main className="amb-bg flex min-h-dvh items-center justify-center px-6">
      <KipioMark />
    </main>
  );
}
