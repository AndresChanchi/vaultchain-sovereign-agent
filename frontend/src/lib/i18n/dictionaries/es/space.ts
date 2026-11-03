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

    oauthGateTitle: "Solo las billeteras pueden subir",
    oauthGateBody:
      "Las fotos necesitan una billetera que pueda firmar. Inicia sesión con una billetera para añadir fotos a tu espacio.",
    oauthGateAction: "Cambiar a una billetera",

    reviewTitle: "Revisar",
    reviewOfTotal: "{current} de {total}",
    reviewLockedNote:
      "Bloqueadas en tu dispositivo. Nada ha salido todavía.",
    reviewTermsLabel: "Cuánto tiempo guardarlas",
    reviewTerm30: "30 días",
    reviewTerm1y: "1 año",
    reviewTermForever: "Para siempre",
    reviewTermFutureHint: "Solo con el contrato nuevo",
    reviewTermsHint:
      "No todas las fotos necesitan para siempre. Más corto cuesta menos. Puedes extender cuando quieras, pero nunca acortar.",
    reviewStorageLabel: "Almacenamiento · fijado por la red",
    reviewFeeLabel: "Comisión de Kipio",
    reviewTotalLabel: "Total",
    reviewPriceLoading: "—",
    reviewEachPhotoNote: "Cada foto se optimiza y se guarda por separado.",
    reviewContinue: "Continuar",
    reviewBack: "Volver",

    progressTitle: "Subiendo",
    progressCurrentFile: "Subiendo {name}",
    progressOfTotal: "{current} de {total}",
    progressItemLocked: "Bloqueada en tu dispositivo",
    progressItemKept: "Guardada en muchos lugares",
    progressItemNoted: "Anotada por el notario ciego",
    progressWaiting: "Esperando aprobación…",
    progressKeepOpen:
      "Mantén esta pestaña abierta hasta que termine.",

    keptTitle: "Guardadas. Son tuyas.",
    keptStepDone: "Hecho",
    keptBody:
      "Bloqueadas, anotadas y guardadas en muchos lugares. Solo tú puedes abrirlas.",
    keptOwnerLabel: "Propietario",
    keptIrysLabel: "Foto",
    keptOpenSpace: "Abrir mi espacio",
    keptUploadMore: "Subir más",

    error: {
      oauth: "Las billeteras pueden subir. Cambia de cuenta para añadir fotos.",
      unlock: "No se pudo desbloquear tu espacio. Inténtalo de nuevo.",
      imageWorker:
        "El optimizador de imágenes no se cargó. Recarga e inténtalo de nuevo.",
      irysInit:
        "No se pudo conectar con la red de almacenamiento. Inténtalo de nuevo.",
      funding:
        "No se pudo financiar la subida. Revisa tu billetera e inténtalo de nuevo.",
      irysUpload:
        "La red de almacenamiento rechazó la subida. Inténtalo de nuevo.",
      register:
        "La foto se subió pero no se pudo registrar. Contacta a soporte.",
      wrongChain:
        "Tu billetera está en otra red. Vuelve a la red correcta para intentarlo de nuevo.",
      generic: "Algo salió mal. Inténtalo de nuevo.",
      retry: "Inténtalo de nuevo",
      cancel: "Cancelar",
    },
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
  
  overview: {
    greeting: "Bienvenido de vuelta.",
    subtitle: "Todo está bloqueado y guardado.",
    keptLabel: "Fotos guardadas",
    recentTitle: "Subidas recientes",
    viewAll: "Ver todo",
    galleryError: "No se pudieron cargar tus fotos.",
    galleryEmpty: "Aún no hay fotos.",
    quickActionsLabel: "Acciones rápidas",
    quickUpload: "Subir fotos",
    quickShare: "Compartir un álbum",
    quickBackup: "Respaldar tu acceso",
    unlockTitle: "Desbloquea tu espacio",
    unlockBodyWallet:
      "Firma con tu billetera para desbloquear tus fotos. Esto es local — nada sale de tu dispositivo.",
    unlockAction: "Desbloquear espacio",
    unlocking: "Desbloqueando…",
    unlockError: "No se pudo desbloquear tu espacio. Inténtalo de nuevo.",
  },
};
