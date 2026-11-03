"use client";

/**
 * OAuth 2.0 Authorization Code + PKCE — browser-only ceremony.
 *
 * Implements the flow for providers that support PKCE on public
 * clients: Google, Microsoft, X.
 *
 * Google's token endpoint requires `client_secret` even with PKCE —
 * a known deviation from RFC 7636, documented by Google in their
 * OAuth 2.0 for Web Server Applications guide. The value lives in
 * the bundle (`NEXT_PUBLIC_GOOGLE_CLIENT_SECRET`), which is
 * acceptable *for Google specifically* because PKCE is the real
 * security: without the `code_verifier`, the authorization code is
 * useless to any interceptor. Do NOT replicate this pattern for
 * Microsoft or X — both honour PKCE-only exchanges; adding a secret
 * there would weaken the flow without any benefit.
 *
 * Providers that require a relay (GitHub, Apple, Twitch) are reported
 * as `relay_required` — the UI shows the honest "needs a secure
 * relay" note, never a fake success.
 *
 * Reference
 *   RFC 9700 (BCP 240, January 2025) — public clients MUST use PKCE;
 *   the implicit grant is deprecated.
 *   RFC 7636 — PKCE mechanics.
 *   RFC 10017 — OAuth 2.0 for Browser-Based Apps.
 *   Google OAuth 2.0 for Web Server Applications — documents the
 *   `client_secret` requirement at the token endpoint.
 *
 * Security invariants
 *   - `code_verifier` is 64 chars from the unreserved set, generated
 *     with `crypto.getRandomValues` and mapped WITHOUT modulo bias
 *     (rejection sampling at 192/256). RFC 7636 §4.1.
 *   - `state` (CSRF) is 32 bytes hex, compared in CONSTANT TIME.
 *     RFC 9700 §2.1.1.
 *   - OIDC `nonce` is generated and validated against `id_token`
 *     where the provider returns one. OIDC Core §3.1.2.1.
 *   - `id_token` claims `iss`, `aud`, `exp`, `nonce` are validated
 *     against the provider's expected values. The signature is NOT
 *     verified — no backend. Acceptable because the token comes
 *     directly from the provider over TLS in response to our PKCE
 *     exchange.
 *   - Tokens are NOT persisted. Only the provider and — when
 *     present — the OIDC `sub` are kept inside the session created
 *     by `connectOAuth`.
 *   - `redirect_uri` must match the provider registration exactly.
 *   - Fetch is aborted on unmount via `AbortController`.
 *
 * Why no refresh token
 *   Nowhere safe to store it (`sessionStorage` is XSS-readable). The
 *   session lifetime is the tab's. When the tab closes, the user
 *   re-authenticates.
 *
 * The `success` phase
 *   After the token exchange completes and `connectOAuth` runs, the
 *   hook transitions to `phase: "success"`. Without it, the caller
 *   cannot distinguish "idle because no callback ran" from "idle
 *   because the exchange succeeded."
 *
 * The `redirectUri` guard
 *   The callback page computes `redirectUri` from
 *   `window.location.origin` in an effect. If `handleCallback` runs
 *   with an empty `redirectUri`, the token exchange sends
 *   `redirect_uri=""` and the provider rejects it. The guard
 *   `if (!redirectUri) return;` prevents that.
 *
 * `subject` — the OIDC `sub` claim
 *   Parsed and validated against the ID token. Passed to
 *   `WalletContext.connectOAuth(provider, subject)` so the session
 *   carries the correlation key the contract layer will use to map
 *   the OAuth identity to a CREATE2 address. Providers without an
 *   ID token (X) omit it; relay providers never reach this code.
 *
 * TODO: when the serverless relay ships (Marlin Oyster / Fleek
 *       Functions), add GitHub / Apple / Twitch by routing their
 *       token exchange through the relay. The client half of the
 *       flow is identical; only `tokenUrl` changes.
 * TODO: DPoP (RFC 9449) is the 2026 best practice for public-client
 *       token binding. None of the three PKCE providers advertise
 *       support yet.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { useWallet, type OAuthProvider } from "@context/WalletContext";
import { networkError, type WalletError } from "@lib/wallet/errors";

/* ──────────────────────────────────────────────────────────────────
 * Provider configuration
 * ────────────────────────────────────────────────────────────────── */

type PkceProviderConfig = {
  authUrl: string;
  tokenUrl: string;
  clientId: string;
  /**
   * Optional. Only Google requires it — its token endpoint rejects
   * PKCE exchanges without a `client_secret`, a documented deviation
   * from RFC 7636. The value lives in the bundle
   * (`NEXT_PUBLIC_GOOGLE_CLIENT_SECRET`), which is acceptable *for
   * Google* because PKCE is the real security. Do NOT set this on
   * Microsoft or X — both honour PKCE-only exchanges.
   */
  clientSecret?: string;
  scopes: string;
  /** Expected `iss` claim in the id_token. */
  issuer: string;
  /** Extra params the provider requires. */
  extraAuthParams?: Record<string, string>;
  /** Whether the provider returns and expects an OIDC `nonce`. */
  usesNonce: boolean;
};

const PKCE_PROVIDERS: Partial<Record<OAuthProvider, PkceProviderConfig>> = {
  google: {
    authUrl: "https://accounts.google.com/o/oauth2/v2/auth",
    tokenUrl: "https://oauth2.googleapis.com/token",
    clientId: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? "",
    // Google-specific: PKCE alone is rejected by the token endpoint.
    // See "Google's token endpoint requires `client_secret`" in the
    // file header.
    clientSecret: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_SECRET ?? "",
    scopes: "openid email profile",
    issuer: "https://accounts.google.com",
    extraAuthParams: { access_type: "online", prompt: "select_account" },
    usesNonce: true,
  },
  microsoft: {
    authUrl:
      "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
    tokenUrl:
      "https://login.microsoftonline.com/common/oauth2/v2.0/token",
    clientId: process.env.NEXT_PUBLIC_MICROSOFT_CLIENT_ID ?? "",
    // No `clientSecret` — Microsoft honours PKCE for SPA clients.
    // No `offline_access` — a refresh token would be unusable (no
    // safe storage) and requesting it widens the consent screen for
    // no gain.
    scopes: "openid email profile",
    issuer: "https://login.microsoftonline.com",
    usesNonce: true,
  },
  x: {
    authUrl: "https://x.com/i/oauth2/authorize",
    tokenUrl: "https://api.x.com/2/oauth2/token",
    clientId: process.env.NEXT_PUBLIC_X_CLIENT_ID ?? "",
    // No `clientSecret` — X honours PKCE for public clients.
    // X returns no `id_token` for this scope set — the `nonce` is
    // sent but never validated. `usesNonce: true` documents the
    // intent; the validation branch checks `if (idToken)` before
    // reading claims, so absence is tolerated.
    scopes: "users.read tweet.read",
    issuer: "https://x.com",
    usesNonce: true,
  },
};

const RELAY_PROVIDERS: readonly OAuthProvider[] = [
  "github",
  "apple",
  "twitch",
];

/* ──────────────────────────────────────────────────────────────────
 * PKCE helpers — RFC 7636 §4.1–4.6
 * ────────────────────────────────────────────────────────────────── */

const VERIFIER_KEY = "kipio:oauth:verifier";
const STATE_KEY = "kipio:oauth:state";
const NONCE_KEY = "kipio:oauth:nonce";
const PROVIDER_KEY = "kipio:oauth:provider";

/**
 * Unreserved set per RFC 7636 §4.1: ALPHA / DIGIT / "-" / "." / "_" / "~".
 */
const UNRESERVED =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";

/**
 * Generate a 64-char verifier from the unreserved set without modulo
 * bias. Rejection sampling: a byte is used only if it falls in the
 * largest multiple of `UNRESERVED.length` (192 for 64 chars). Bytes
 * outside that range are discarded.
 *
 * `charAt` (not `[]`) keeps `noUncheckedIndexedAccess` happy: string
 * index access returns `string | undefined` under that flag, while
 * `charAt` is declared to return `string`. The index is always in
 * `[0, 63]`, so `charAt` never returns the empty string.
 */
function generateVerifier(): string {
  const out: string[] = [];
  const limit = 256 - (256 % UNRESERVED.length); // 192
  while (out.length < 64) {
    const bytes = new Uint8Array(64);
    crypto.getRandomValues(bytes);
    for (const b of bytes) {
      if (b < limit) {
        out.push(UNRESERVED.charAt(b % UNRESERVED.length));
        if (out.length === 64) break;
      }
    }
  }
  return out.join("");
}

function generateCsrfState(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function generateOidcNonce(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Constant-time string comparison. Length difference is folded into
 * the result without early exit. RFC 9700 §2.1.1.
 */
function constantTimeEqual(a: string, b: string): boolean {
  const len = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < len; i++) {
    diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }
  return diff === 0;
}

async function sha256Base64Url(input: string): Promise<string> {
  if (
    typeof crypto === "undefined" ||
    typeof crypto.subtle === "undefined"
  ) {
    throw new Error(
      "Web Crypto is not available. OAuth requires a secure context (HTTPS or localhost).",
    );
  }
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const bytes = new Uint8Array(digest);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/* ──────────────────────────────────────────────────────────────────
 * ID token claims
 * ────────────────────────────────────────────────────────────────── */

type IdTokenClaims = {
  sub?: string;
  email?: string;
  iss?: string;
  aud?: string | string[];
  exp?: number;
  nonce?: string;
};

function parseIdToken(idToken: string): IdTokenClaims {
  try {
    const parts = idToken.split(".");
    if (parts.length !== 3) return {};
    const payload = parts[1];
    if (!payload) return {};
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const json = atob(padded);
    const parsed: unknown = JSON.parse(json);
    if (typeof parsed !== "object" || parsed === null) return {};
    const claims = parsed as Record<string, unknown>;
    return {
      sub: typeof claims.sub === "string" ? claims.sub : undefined,
      email: typeof claims.email === "string" ? claims.email : undefined,
      iss: typeof claims.iss === "string" ? claims.iss : undefined,
      aud:
        typeof claims.aud === "string" || Array.isArray(claims.aud)
          ? (claims.aud as string | string[])
          : undefined,
      exp: typeof claims.exp === "number" ? claims.exp : undefined,
      nonce: typeof claims.nonce === "string" ? claims.nonce : undefined,
    };
  } catch {
    return {};
  }
}

function validateIdTokenClaims(
  claims: IdTokenClaims,
  config: PkceProviderConfig,
  expectedNonce: string | null,
): string | null {
  if (!claims.sub) return "ID token is missing the sub claim.";
  if (claims.iss !== config.issuer) {
    return `ID token issuer mismatch: expected ${config.issuer}, got ${claims.iss ?? "none"}.`;
  }
  const aud = claims.aud;
  const audOk = Array.isArray(aud)
    ? aud.includes(config.clientId)
    : aud === config.clientId;
  if (!audOk) return "ID token audience mismatch.";
  if (typeof claims.exp !== "number" || claims.exp * 1000 < Date.now()) {
    return "ID token is expired.";
  }
  if (config.usesNonce) {
    if (!expectedNonce) return "Missing nonce for this provider.";
    if (claims.nonce !== expectedNonce) return "ID token nonce mismatch.";
  }
  return null;
}

/* ──────────────────────────────────────────────────────────────────
 * Hook
 * ────────────────────────────────────────────────────────────────── */

export type OAuthLoginState =
  | { phase: "idle" }
  | { phase: "redirecting"; provider: OAuthProvider }
  | { phase: "exchanging"; provider: OAuthProvider }
  | { phase: "success"; provider: OAuthProvider }
  | { phase: "error"; error: WalletError };

export type UseOAuthLoginResult = {
  state: OAuthLoginState;
  beginLogin: (provider: OAuthProvider) => Promise<void>;
};

export function useOAuthLogin(redirectUri: string): UseOAuthLoginResult {
  const { connectOAuth } = useWallet();
  const [state, setState] = useState<OAuthLoginState>({ phase: "idle" });
  const callbackHandled = useRef(false);
  const abortRef = useRef<AbortController | null>(null);

  // Abort any in-flight fetch on unmount.
  useEffect(() => {
    return () => {
      abortRef.current?.abort();
    };
  }, []);

  const beginLogin = useCallback(
    async (provider: OAuthProvider) => {
      if (RELAY_PROVIDERS.includes(provider)) {
        setState({
          phase: "error",
          error: {
            code: "unsupported",
            rawMessage: `OAuth provider ${provider} requires a server-side relay.`,
            cancelled: false,
          },
        });
        return;
      }

      const config = PKCE_PROVIDERS[provider];
      if (!config || !config.clientId) {
        setState({
          phase: "error",
          error: {
            code: "unsupported",
            rawMessage: `OAuth provider ${provider} is not configured.`,
            cancelled: false,
          },
        });
        return;
      }

      // A non-HTTPS redirect URI in production is a misconfiguration.
      // localhost is allowed for development.
      if (
        typeof window !== "undefined" &&
        window.location.protocol !== "https:" &&
        !window.location.hostname.includes("localhost")
      ) {
        setState({
          phase: "error",
          error: {
            code: "unsupported",
            rawMessage: "OAuth requires HTTPS in production.",
            cancelled: false,
          },
        });
        return;
      }

      // Empty redirectUri reaches this branch if the caller did not
      // wait for `window.location.origin`. Fail loudly instead of
      // letting the provider reject the redirect_uri mismatch.
      if (!redirectUri) {
        setState({
          phase: "error",
          error: {
            code: "unknown",
            rawMessage: "redirectUri is empty — the caller must provide it.",
            cancelled: false,
          },
        });
        return;
      }

      setState({ phase: "redirecting", provider });

      try {
        if (
          typeof crypto === "undefined" ||
          typeof crypto.subtle === "undefined"
        ) {
          throw new Error(
            "Web Crypto is not available. OAuth requires a secure context.",
          );
        }

        const verifier = generateVerifier();
        const challenge = await sha256Base64Url(verifier);
        const csrfState = generateCsrfState();
        const oidcNonce = config.usesNonce ? generateOidcNonce() : null;

        try {
          window.sessionStorage.setItem(VERIFIER_KEY, verifier);
          window.sessionStorage.setItem(STATE_KEY, csrfState);
          window.sessionStorage.setItem(PROVIDER_KEY, provider);
          if (oidcNonce) {
            window.sessionStorage.setItem(NONCE_KEY, oidcNonce);
          } else {
            window.sessionStorage.removeItem(NONCE_KEY);
          }
        } catch {
          setState({
            phase: "error",
            error: {
              code: "unknown",
              rawMessage: "sessionStorage is unavailable.",
              cancelled: false,
            },
          });
          return;
        }

        const params = new URLSearchParams({
          response_type: "code",
          client_id: config.clientId,
          redirect_uri: redirectUri,
          scope: config.scopes,
          state: csrfState,
          code_challenge: challenge,
          code_challenge_method: "S256",
          ...(oidcNonce ? { nonce: oidcNonce } : {}),
          ...(config.extraAuthParams ?? {}),
        });

        window.location.assign(`${config.authUrl}?${params.toString()}`);
      } catch (error) {
        // `location.assign` can throw under CSP `navigate-to`
        // restrictions or a popup blocker. Do not leave the state
        // stuck on "redirecting".
        setState({ phase: "error", error: networkError(error) });
      }
    },
    [redirectUri],
  );

  const handleCallback = useCallback(async (): Promise<OAuthProvider | null> => {
    if (callbackHandled.current) return null;
    if (typeof window === "undefined") return null;
    if (!redirectUri) return null;

    // Mark as handled only after the redirectUri is available — a
    // premature mark would block the real attempt once the origin
    // resolves (see "The `redirectUri` guard" in the header).
    callbackHandled.current = true;

    const url = new URL(window.location.href);
    const code = url.searchParams.get("code");
    const returnedState = url.searchParams.get("state");
    const errorParam = url.searchParams.get("error");
    const errorDescription = url.searchParams.get("error_description");

    const cleanUrl = () => {
      url.searchParams.delete("code");
      url.searchParams.delete("state");
      url.searchParams.delete("error");
      url.searchParams.delete("error_description");
      window.history.replaceState(null, "", url.toString());
    };

    const clearPkceStorage = () => {
      try {
        window.sessionStorage.removeItem(VERIFIER_KEY);
        window.sessionStorage.removeItem(STATE_KEY);
        window.sessionStorage.removeItem(NONCE_KEY);
        window.sessionStorage.removeItem(PROVIDER_KEY);
      } catch {
        /* ignore */
      }
    };

    if (errorParam) {
      clearPkceStorage();
      cleanUrl();
      setState({
        phase: "error",
        error: {
          code:
            errorParam === "access_denied" || errorParam === "user_cancelled"
              ? "rejected"
              : "unknown",
          rawMessage: errorDescription ?? errorParam,
          cancelled:
            errorParam === "access_denied" || errorParam === "user_cancelled",
        },
      });
      return null;
    }

    if (!code || !returnedState) {
      // No callback in the URL — normal on a non-callback page.
      return null;
    }

    let storedState: string | null = null;
    let verifier: string | null = null;
    let oidcNonce: string | null = null;
    let provider: string | null = null;
    try {
      storedState = window.sessionStorage.getItem(STATE_KEY);
      verifier = window.sessionStorage.getItem(VERIFIER_KEY);
      oidcNonce = window.sessionStorage.getItem(NONCE_KEY);
      provider = window.sessionStorage.getItem(PROVIDER_KEY);
      window.sessionStorage.removeItem(STATE_KEY);
      window.sessionStorage.removeItem(VERIFIER_KEY);
      window.sessionStorage.removeItem(NONCE_KEY);
      window.sessionStorage.removeItem(PROVIDER_KEY);
    } catch {
      /* ignore */
    }

    if (!storedState || !verifier || !provider) {
      cleanUrl();
      setState({
        phase: "error",
        error: {
          code: "unknown",
          rawMessage: "OAuth state or verifier missing.",
          cancelled: false,
        },
      });
      return null;
    }

    // Constant-time comparison — RFC 9700 §2.1.1.
    if (!constantTimeEqual(storedState, returnedState)) {
      cleanUrl();
      setState({
        phase: "error",
        error: {
          code: "unknown",
          rawMessage: "OAuth state mismatch.",
          cancelled: false,
        },
      });
      return null;
    }

    if (!isOAuthProvider(provider)) {
      cleanUrl();
      setState({
        phase: "error",
        error: {
          code: "unknown",
          rawMessage: `Unknown OAuth provider: ${provider}`,
          cancelled: false,
        },
      });
      return null;
    }

    const config = PKCE_PROVIDERS[provider];
    if (!config) {
      cleanUrl();
      setState({
        phase: "error",
        error: {
          code: "unsupported",
          rawMessage: `No PKCE configuration for ${provider}.`,
          cancelled: false,
        },
      });
      return null;
    }

    setState({ phase: "exchanging", provider });

    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const body = new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
        client_id: config.clientId,
        code_verifier: verifier,
      });

      // Google rejects PKCE-only exchanges. See "Google's token
      // endpoint requires `client_secret`" in the file header.
      // Microsoft and X honour RFC 7636 and do not need this.
      if (config.clientSecret) {
        body.set("client_secret", config.clientSecret);
      }

      const response = await fetch(config.tokenUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body.toString(),
        signal: controller.signal,
      });

      if (!response.ok) {
        const text = await response.text().catch(() => "");
        cleanUrl();
        setState({
          phase: "error",
          error: {
            code: "unknown",
            rawMessage: `Token exchange failed (${response.status}): ${text.slice(0, 200)}`,
            cancelled: false,
          },
        });
        return null;
      }

      const tokens: unknown = await response.json();
      if (typeof tokens !== "object" || tokens === null) {
        cleanUrl();
        setState({
          phase: "error",
          error: {
            code: "unknown",
            rawMessage: "Token response was not an object.",
            cancelled: false,
          },
        });
        return null;
      }
      const tokenRecord = tokens as Record<string, unknown>;
      const idToken =
        typeof tokenRecord.id_token === "string"
          ? tokenRecord.id_token
          : null;

      let subject: string | undefined;
      if (idToken) {
        const claims = parseIdToken(idToken);
        const claimError = validateIdTokenClaims(
          claims,
          config,
          oidcNonce,
        );
        if (claimError) {
          cleanUrl();
          setState({
            phase: "error",
            error: {
              code: "unknown",
              rawMessage: `ID token validation failed: ${claimError}`,
              cancelled: false,
            },
          });
          return null;
        }
        subject = claims.sub;
      }

      // `subject` is the OIDC `sub` claim (when present). It travels
      // in the session — the contract layer (Fase 9+) will use it to
      // map this OAuth identity to a CREATE2 address. Providers
      // without an ID token (X) simply omit it.
      await connectOAuth(provider, subject);

      cleanUrl();
      setState({ phase: "success", provider });
      return provider;
    } catch (error) {
      if (controller.signal.aborted) {
        // Component unmounted; do not setState.
        return null;
      }
      cleanUrl();
      setState({ phase: "error", error: networkError(error) });
      return null;
    }
  }, [connectOAuth, redirectUri]);

  // Run the callback handler once `redirectUri` is ready. The guard
  // prevents the token exchange from running with an empty
  // `redirect_uri` on the callback page's first render.
  useEffect(() => {
    if (!redirectUri) return;
    void handleCallback();
  }, [handleCallback, redirectUri]);

  return { state, beginLogin };
}

function isOAuthProvider(value: string): value is OAuthProvider {
  return (
    value === "google" ||
    value === "x" ||
    value === "microsoft" ||
    value === "apple" ||
    value === "github" ||
    value === "twitch"
  );
}
