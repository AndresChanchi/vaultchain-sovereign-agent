/**
 * Space surface (authenticated) — Spanish.
 *
 * Mirrors `en/space.ts` one-to-one. The `satisfies Dictionary` clause
 * in the aggregate (`es.ts`) is the parity check.
 *
 * Register: consumer-facing Spanish. Second person singular, sentence
 * case, no exclamations, no emoji. Matches `es/landing.ts` and
 * `es/login.ts`.
 */

export const space = {
  sidebar: {
    navLabel: "Navegación del espacio",
    home: "Inicio",
    library: "Biblioteca",
    moments: "Momentos",
    shared: "Compartido",
    offers: "Ofertas",
    settings: "Ajustes",
    comingSoon: "Disponible en una fase posterior",
    signOut: "Cerrar sesión",
    collapse: "Contraer barra lateral",
    expand: "Expandir barra lateral",
  },

  dock: {
    navLabel: "Navegación del espacio",
    upload: "Subir",
  },

  account: {
    menuLabel: "Menú de cuenta",
    walletMetamask: "MetaMask",
    walletBrave: "Brave Wallet",
    walletRabby: "Rabby",
    walletLedger: "Ledger",
    walletInjected: "Billetera",
    oauthGoogle: "Google",
    oauthX: "X",
    oauthMicrosoft: "Microsoft",
    oauthApple: "Apple",
    oauthGithub: "GitHub",
    oauthTwitch: "Twitch",
  },

  speculos: {
    title: "Simulador de Ledger activo",
    body: "Aprueba cada transacción en la pantalla del emulador.",
    open: "Abrir emulador",
  },

  header: {
    searchPlaceholder: "Busca tus fotos",
    searchShortcut: "⌘K",
  },

  upload: {
    button: "Subir",
    dialogTitle: "Subir fotos",
    dialogDescription:
      "Bloqueadas en tu dispositivo. Guardadas en muchos lugares.",
    connectPrompt: "Conecta una billetera para subir.",
    connectButton: "Conectar billetera",
  },

  welcome: {
    eyebrow: "Tu espacio está listo",
    headlineFirst: "Está vacío.",
    headlineSecond: "No por mucho.",
    description:
      "Mira qué pasa con una foto aquí. Prueba con una de muestra primero. No se registra nada hasta que subas.",
    ctaExplore: "Mira alrededor primero",
    ctaUpload: "Sube tus primeras fotos",
    keptByOthers: "fotos guardadas por personas como tú",
    starter: {
      onePhoto: {
        label: "1 foto",
        title: "Guarda tu primera foto",
        body: "Bloqueada en tu dispositivo, guardada en muchos lugares.",
      },
      fivePhotos: {
        label: "5 fotos",
        title: "Desbloquea tu primer Momento",
        body: "Kipio lo construye en privado, solo para ti.",
      },
      share: {
        label: "Compartir",
        title: "Comparte con alguien",
        body: "Invítalos. Detente cuando quieras.",
      },
    },
  },
};
