"use client";

/**
 * Login modal — native `<dialog>` wrapper around `LoginPanel`.
 *
 * Renders once, at the root layout. `LoginModalProvider` tracks
 * `isOpen`; this component opens and closes the native `<dialog>` in
 * sync. The browser handles the backdrop, focus trap, Escape, and
 * body scroll lock.
 *
 * Why `<dialog>` and not a custom overlay
 *   `<dialog>.showModal()` provides: backdrop (`::backdrop`),
 *   focus trap, Escape to close (fires native `close`), body scroll
 *   lock, return focus on close. Baseline Widely Available since
 *   March 2022 (Chrome 37+, Safari 15.4+, Firefox 98+). Zero
 *   dependencies.
 *
 *   The `closedby` attribute (Firefox 141+, Edge 134+) would let the
 *   browser close on backdrop click natively. Until it is Baseline,
 *   the backdrop click handler below covers the case with
 *   `event.target === dialogRef.current` — only clicks that land on
 *   the backdrop area reach the `<dialog>` itself (children stop
 *   propagation by being children).
 *
 * Two mechanisms guard the post-login redirect
 *   The redirect effect navigates to `/space` (or the recorded
 *   return-to). It uses `closeLogin({ silent: true })` +
 *   `router.replace(target)`. That pairing is necessary but NOT
 *   sufficient — the `<dialog>`'s own `close` event fires when the
 *   `[isOpen]` effect calls `dialog.close()`, and the `handleClose`
 *   listener would run `closeLogin()` (non-silent) → `history.back()`
 *   → race again.
 *
 *   Two pieces, both required:
 *
 *     1. `silent: true` in the redirect effect → the `closeLogin()`
 *        call from the redirect path does NOT touch the history.
 *
 *     2. `programmaticCloseRef` → the `handleClose` listener knows
 *        whether the native close event was triggered by our own
 *        `[isOpen]` effect (which happens for every `isOpen → false`
 *        transition) versus a user action (Escape, X, backdrop). In
 *        the programmatic case, `handleClose` returns early — the
 *        context state is already correct, no further closeLogin is
 *        needed.
 *
 *   Without (2), the sequence would be:
 *
 *     - redirect effect: `closeLogin({ silent: true })` + `router.replace("/space")`
 *     - `[isOpen]` effect: `dialog.close()`
 *     - `close` event → `handleClose` → `closeLogin()` (non-silent)
 *     - non-silent: marker still present → `history.back()` scheduled
 *     - `history.back()` races `router.replace()`, `back()` wins
 *     - user lands on `/` instead of `/space`
 *
 *   With both, the flow is race-free:
 *
 *     - redirect effect: `closeLogin({ silent: true })` + `router.replace("/space")`
 *     - `[isOpen]` effect: `programmaticCloseRef.current = true` + `dialog.close()`
 *     - `close` event → `handleClose` → flag is true → reset, return early
 *     - `router.replace()` navigates. End of story.
 *
 * Redirect on success — the two "no redirect" cases
 *   Two cases must NOT redirect:
 *     - The user opens the modal while already signed in. The navbar
 *       hides the button once connected, but the modal stays
 *       defensive.
 *     - The wallet status is "restoring" when the modal opens, and
 *       resolves to "connected" because a previous session is
 *       resumed. The user did not sign in — the session was already
 *       there.
 *
 *   `sessionAtOpenRef` captures the session the moment the modal
 *   opens AND `status` is no longer "restoring". `null` = signed
 *   out at open (redirect enabled); non-null = signed in at open
 *   (no redirect); `undefined` = not captured yet (closed or still
 *   restoring — effect returns early).
 *
 * Close event vs context close — the four close paths
 *   Every close path is exercised, in order:
 *
 *     - Escape: browser closes dialog → `close` event → `handleClose`
 *       → flag is false → `closeLogin()` (non-silent) → `history.back()`
 *       → `popstate` → `setIsOpen(false)` → `[isOpen]` effect: guard
 *       `!isOpen && dialog.open` is false (dialog already closed), so
 *       no-op. Correct.
 *
 *     - X button / backdrop click: `LoginPanel`'s `onClose` or the
 *       backdrop handler → `closeLogin()` (non-silent) → `history.back()`
 *       → `popstate` → `setIsOpen(false)` → `[isOpen]` effect:
 *       `dialog.close()` (dialog was still open, since the state
 *       changed but the native close hadn't fired yet) →
 *       `programmaticCloseRef.current = true` → `dialog.close()` →
 *       `close` event → `handleClose` → flag true → reset, return.
 *       Correct — no double `history.back()`.
 *
 *     - Post-login redirect: as above. Race-free.
 *
 *     - Browser back button: `popstate` → `setIsOpen(false)` →
 *       `[isOpen]` effect → `dialog.close()` → `close` event →
 *       `handleClose` → flag true → reset, return. URL already
 *       reverted by the browser. Correct.
 *
 *   The flag is reset on every open, so a stuck `true` from a rare
 *   incomplete close cannot silence the next user-initiated close.
 *
 * Styling
 *   The `<dialog>` is transparent — the `LoginPanel` paints the
 *   rounded glass card. `::backdrop` is 60% black. The UA's default
 *   `padding: 1em` and `border: solid` are cleared with
 *   `p-0 border-0`. `m-auto` centres the `<dialog>` in its
 *   viewport-sized containing block (Tailwind v4 Preflight resets
 *   `margin: 0`, killing the UA's `dialog:modal { margin: auto }`).
 */

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import {
  consumeLoginReturnTo,
  useLoginModal,
} from "@context/LoginModalContext";
import { useWallet, type Session } from "@context/WalletContext";
import { LoginPanel } from "@components/login/login-panel";

/**
 * Default post-login destination. Same value used by
 * `app/login/page.tsx` and `app/auth/callback/page.tsx`. Three call
 * sites now — extract into `config/routes.ts` when the next touch
 * of any of them happens.
 */
const DEFAULT_RETURN_TO = "/space";

export function LoginModal() {
  const { isOpen, closeLogin } = useLoginModal();
  const { session, status } = useWallet();
  const router = useRouter();
  const dialogRef = useRef<HTMLDialogElement>(null);

  // Captured when the modal opens (once `status !== "restoring"`).
  // `undefined` = not captured yet; `null` = signed out at open;
  // non-null = signed in at open. See "Redirect on success" in the
  // file header.
  const sessionAtOpenRef = useRef<Session | null | undefined>(undefined);

  // Distinguishes the native `close` event triggered by our own
  // `[isOpen]` effect (`dialog.close()`) from one triggered by a
  // user action (Escape). See "Two mechanisms guard the post-login
  // redirect" in the file header.
  const programmaticCloseRef = useRef(false);

  // ── Open / close the native dialog ─────────────────────────────
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (isOpen && !dialog.open) {
      // Reset the flag on every open. If a prior programmatic close
      // somehow left the flag true (a `close` event that never fired
      // — very unlikely), the next user-initiated close would be
      // silently ignored. Resetting here is the cheapest defence.
      programmaticCloseRef.current = false;
      dialog.showModal();
    } else if (!isOpen && dialog.open) {
      programmaticCloseRef.current = true;
      dialog.close();
    }
  }, [isOpen]);

  // ── Sync native `close` back to context ────────────────────────
  // When the close was user-initiated (Escape), the flag is false
  // and we forward to `closeLogin()` (non-silent), which reverts the
  // URL via `history.back()`. When the close was programmatic (our
  // `[isOpen]` effect), the flag is true and we return early — the
  // context is already in the right state and no further navigation
  // is needed.
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    const handleClose = () => {
      if (programmaticCloseRef.current) {
        programmaticCloseRef.current = false;
        return;
      }
      closeLogin();
    };
    dialog.addEventListener("close", handleClose);
    return () => dialog.removeEventListener("close", handleClose);
  }, [closeLogin]);

  // ── Capture session at open ────────────────────────────────────
  useEffect(() => {
    if (!isOpen) {
      sessionAtOpenRef.current = undefined;
      return;
    }
    if (sessionAtOpenRef.current !== undefined) return;
    // Wait for the resume effect to finish before capturing — a
    // "restoring" snapshot would be a false "signed out at open"
    // if the user actually has a session.
    if (status === "restoring") return;
    sessionAtOpenRef.current = session;
  }, [isOpen, status, session]);

  // ── Redirect on successful connect ─────────────────────────────
  // `closeLogin({ silent: true })` is necessary but not sufficient;
  // `programmaticCloseRef` handles the `close` event that fires when
  // the `[isOpen]` effect calls `dialog.close()`. Both are required.
  // See "Two mechanisms guard the post-login redirect" in the file
  // header.
  useEffect(() => {
    if (!isOpen) return;
    if (sessionAtOpenRef.current === undefined) return;
    if (sessionAtOpenRef.current !== null) return; // signed in at open
    if (session === null) return; // still not signed in
    const target = consumeLoginReturnTo() ?? DEFAULT_RETURN_TO;
    closeLogin({ silent: true });
    router.replace(target);
  }, [isOpen, session, closeLogin, router]);

  // ── Backdrop click (Escape is native) ──────────────────────────
  // Clicks that land on the `<dialog>` itself are clicks on the
  // backdrop area (the panel is a child, so its clicks target the
  // panel, not the dialog). Uses the non-silent close path: the URL
  // reverts to the previous surface.
  const handleBackdropClick = (
    event: React.MouseEvent<HTMLDialogElement>,
  ) => {
    if (event.target === dialogRef.current) {
      closeLogin();
    }
  };

  return (
    <dialog
      ref={dialogRef}
      aria-labelledby="login-panel-title"
      onClick={handleBackdropClick}
      className="m-auto w-[min(92vw,420px)] max-h-[100dvh] overflow-visible border-0 bg-transparent p-0 backdrop:bg-black/60"
    >
      <LoginPanel onClose={closeLogin} />
    </dialog>
  );
}
