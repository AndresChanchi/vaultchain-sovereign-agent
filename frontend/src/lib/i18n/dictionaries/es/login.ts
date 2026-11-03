/**
 * Login surface — Spanish.
 *
 * Mirrors `en/login.ts` one-to-one. The `satisfies Dictionary` clause
 * in the aggregator (`es.ts`) is the parity check: if `en/login.ts`
 * grows or drops a key and this file does not follow, the build fails
 * on the `login` property of the aggregate.
 *
 * Register
 *   Consumer-facing Spanish. Second person singular ("tú"), sentence
 *   case, no exclamations, no emoji. Matches the tone established in
 *   `es/landing.ts`.
 *
 * Provider names
 *   Kept as-is (Google, X, Microsoft, Apple, GitHub, Twitch, MetaMask,
 *   Brave Wallet, Rabby, Ledger). Proper nouns — no translation.
 *
 * Terminology
 *   "wallet" → "billetera". "passkey" → "clave de acceso" (the term
 *   Google, Apple and Microsoft use in Spanish-language UIs). "relay"
 *   → "puente" (readable for non-technical readers).
 */

export const login = {
  title: "Inicia sesión en Kipio",
  subtitle: "Elige cómo. Puedes añadir más formas después.",
  close: "Cerrar",

  social: {
    label: "Continúa con",
    google: "Google",
    x: "X",
    microsoft: "Microsoft",
    apple: "Apple",
    github: "GitHub",
    twitch: "Twitch",
  },

  provider: {
    github: {
      relay:
        "GitHub necesita un puente seguro para completar el inicio de sesión. Estará disponible cuando el puente serverless esté listo.",
    },
    apple: {
      relay:
        "Apple necesita un puente seguro para completar el inicio de sesión. Estará disponible cuando el puente serverless esté listo.",
    },
  },

  passkey: {
    label: "Usar una clave de acceso",
    disabledReason:
      "Las claves de acceso necesitan un puente seguro y la vinculación con el contrato. Ambos están en camino.",
    unsupported:
      "Este navegador no admite claves de acceso. Puedes usar una billetera o una cuenta social.",
  },

  wallet: {
    label: "O usa una billetera",
    badge: "Web3",
    detected: "Detectada",
    install: "Instalar",
    more: "Más billeteras",
    moreTitle: "Billeteras detectadas en este navegador",
    empty:
      "No se detectó ninguna billetera. Instala una extensión de billetera o abre esta página en un navegador que tenga una.",
    metamask: "MetaMask",
    brave: "Brave Wallet",
    rabby: "Rabby",
    ledger: "Ledger",
    ledgerConnect: "Conectar Ledger",
    ledgerError:
      "No se pudo conectar con el dispositivo Ledger. Revisa la conexión e inténtalo de nuevo.",
  },

  error: {
    generic: "Algo salió mal. Inténtalo de nuevo.",
    rejected: "La solicitud se canceló.",
    noAccount:
      "El proveedor no devolvió ninguna cuenta. Prueba con otra forma de entrar.",
    network:
      "La red no está disponible en este momento. Inténtalo de nuevo en un momento.",
    unsupported:
      "Este método de inicio de sesión aún no está disponible. Prueba con otra forma de entrar.",
  },

  footer:
    "Nunca vemos tus fotos. Iniciar sesión no revela tu nombre a las redes públicas.",
};
