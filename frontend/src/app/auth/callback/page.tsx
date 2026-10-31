"use client";

/**
 * OAuth callback — resolves `?code=…&state=…` and redirects.
 *
 * Static page (`output: 'export'` compatible). The token exchange
 * runs entirely in the browser: the provider's token endpoint is
 * called directly from the client with PKCE, and the session is
 * persisted by `WalletContext.connectOAuth`.
 *
 * Flow
 *   1. `redirectUri` is computed from `window.location.origin` in an
 *      effect (empty on the server and during the first client
 *      render). `useOAuthLogin` guards against an empty `redirectUri`
 *      so the token exchange never runs with a mismatched value.
 *   2. `useOAuthLogin` runs `handleCallback` once `redirectUri` is
 *      ready. It resolves the code, exchanges it, validates the ID
 *      token claims, and persists the session.
 *   3. On `phase: "success"`, this page reads the post-login
 *      destination via `consumeLoginReturnTo()` and redirects. The
 *      destination is `/space` by default — the authenticated
 *      surface is called "space", not "dashboard", per the design
 *      copy.
 *   4. On `phase: "error"`, the error is shown, with a link back
 *      home. No fake success, no silent redirect.
 *
 * Why `/space` and not `/dashboard`
 *   "Dashboard" is the legacy route name (`app/dashboard/page.tsx`
 *   still exists as the MVP). The design copy calls the
 *   authenticated surface "space" — `Scream Architecture` and the
 *   landing's own strings ("Your space is ready") agree. When the
 *   route restructure (Fase 9) lands, the authenticated surface
 *   moves to `/space`; the legacy `/dashboard` is retired then. For
 *   now, this page redirects to `/space` so the login flow points
 *   at the correct destination. If the route does not exist yet in
 *   a given deployment, the 404 is the correct signal — the login
 *   succeeded, only the destination is pending.
 *
 * `closeLogin` is intentionally NOT called
 *   The login modal (`LoginModalContext`) is not mounted during an
 *   OAuth redirect: the modal lived on the source page, and the
 *   provider redirect destroyed it. Calling `closeLogin()` here
 *   would either `history.back()` (navigating away from the
 *   callback) or `replaceState("/")` (navigating to the root and
 *   losing the success redirect). Neither is correct. The session
 *   is already persisted; this page only needs to route.
 */

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useOAuthLogin } from "@hooks/web3/useOAuthLogin";
import { consumeLoginReturnTo } from "@context/LoginModalContext";

const DEFAULT_RETURN_TO = "/space";

export default function AuthCallbackPage() {
  const router = useRouter();
  const [redirectUri, setRedirectUri] = useState("");

  useEffect(() => {
    setRedirectUri(`${window.location.origin}/auth/callback`);
  }, []);

  const { state } = useOAuthLogin(redirectUri);

  useEffect(() => {
    if (state.phase !== "success") return;
    const target = consumeLoginReturnTo() ?? DEFAULT_RETURN_TO;
    router.replace(target);
  }, [state.phase, router]);

  const statusMessage = (() => {
    switch (state.phase) {
      case "redirecting":
        return "Redirecting to the provider…";
      case "exchanging":
        return "Signing you in…";
      case "success":
        return "Signed in. Redirecting…";
      case "error":
        return state.error.cancelled
          ? "Sign-in was cancelled."
          : "Could not complete sign-in.";
      case "idle":
        return "Preparing sign-in…";
    }
  })();

  return (
    <main className="amb-bg flex min-h-dvh flex-col items-center justify-center px-6 py-16 text-center">
      <div
        aria-live="polite"
        aria-atomic="true"
        className="max-w-md"
      >
        <p className="label-mono text-emerald-text">Kipio</p>
        <h1 className="mt-4 font-serif text-[32px] leading-tight tracking-[-0.015em] text-ink md:text-[44px]">
          {statusMessage}
        </h1>
        {state.phase === "error" && (
          <p className="mt-4 text-[14px] leading-relaxed text-muted">
            {state.error.rawMessage}
          </p>
        )}
        {state.phase === "error" && (
          <a
            href="/"
            className="mt-8 inline-flex h-11 items-center justify-center rounded-[14px] border border-hairline bg-card px-5 text-sm font-medium text-ink transition-colors hover:bg-elevated"
          >
            Back to the start
          </a>
        )}
        {state.phase !== "error" && (
          <p className="mt-4 text-[13px] text-muted-soft">
            Keep this tab open until the page moves on its own.
          </p>
        )}
      </div>
    </main>
  );
}
