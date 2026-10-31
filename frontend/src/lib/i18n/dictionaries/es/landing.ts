/**
 * Spanish — landing strings.
 *
 * Every key in `en/landing.ts` must appear here with a translated
 * value. The `satisfies Dictionary["landing"]` check in the aggregator
 * (`es.ts`) enforces it: a missing key or an extra key fails the
 * build.
 *
 * Voice notes for reviewers
 *   - Keep sentence case, no trailing punctuation on labels/headings.
 *   - "space" in the product language (never "bóveda" or "vault").
 *   - "locked" is "cifrado" in this locale — Spanish "bloqueado"
 *     reads as a moderation action (account suspended), which is
 *     worse. "Cifrado" is the honest technical term.
 *   - "fee" is "comisión" (not "tarifa" — a protocol fee is a
 *     commission, not a tax).
 *   - "term" is "plazo" in pricing (duration). Never "términos".
 *   - "Moments" stays "Moments" (product name).
 *   - Placeholders stay in English ({count}, {year}, {index},
 *     {total}, {title}) — the translate function looks them up by
 *     name, not by position.
 *
 * Proper nouns
 *   "Arbitrum", "Irys", "MetaMask", "Brave Wallet", "Rabby", "Ledger",
 *   "iPhone", "Android", "Windows", "Mac", "Google", "Apple",
 *   "Microsoft", "Passkey" stay in their original form. Only the
 *   labels around them are translated.
 */

export const landing = {
  navbar: {
    openSpace: "Abrir tu espacio",
    signOut: "Cerrar sesión",
    howItWorks: "Cómo funciona",
    docs: "Documentación",
    language: "ES",
    logIn: "Iniciar sesión",
    openMenu: "Abrir menú",
    closeMenu: "Cerrar menú",
    themeToggle: "Cambiar tema",
    changeLanguage: "Cambiar idioma",
  },

  hero: {
    eyebrow: "Propiedad digital, no alquiler",
    title: "Tus fotos son tuyas.",
    subtitle: "La inteligencia construida sobre ellas también.",
    lede:
      "Cifradas en tu dispositivo, registradas como tuyas, conservadas para siempre. Sin suscripción y sin que nadie más tenga la llave.",
    dropPhoto: "Arrastra una foto aquí",
    uploadCta: "Sube tu primera foto",
    noAccount:
      "No necesitas una cuenta para empezar. Elige hasta {count} fotos a la vez.",
    orLookAround: "O mira primero",
  },

  journey: {
    eyebrow: "Cómo funciona",
    title: "El viaje de tu foto.",
    subtitle:
      "Una sola aprobación y los cuatro pasos ocurren juntos. Si uno falla, ninguno se ejecuta.",
    steps: [
      {
        title: "Cada foto, optimizada.",
        body:
          "Cada foto se ajusta y se hace más ligera en tu dispositivo, y luego se almacena por su cuenta.",
        hood: "Bajo el capó · optimización por foto",
      },
      {
        title: "Cifrada en tu dispositivo.",
        body:
          "Codificada con una llave que solo tú tienes, antes de que algo salga de aquí.",
        hood: "Bajo el capó · cifrado simétrico",
      },
      {
        title: "Anotada por un notario ciego.",
        body:
          "Un contrato público deja constancia de que es tuya. No puede ver qué contiene.",
        hood: "Bajo el capó · contrato inteligente en Arbitrum",
      },
      {
        title: "Guardada en muchos lugares.",
        body:
          "Copias cifradas en computadores de todo el mundo, para siempre o por el tiempo que elijas. Nadie que aloje una copia puede ver su contenido.",
        hood: "Bajo el capó · red de almacenamiento Irys",
      },
    ],
    previous: "Paso anterior",
    pause: "Pausar",
    play: "Reproducir",
    next: "Paso siguiente",
    showStep: "Mostrar paso {index} de {total}: {title}",
    stepsLabel: "Pasos del viaje",

    slideOverlays: {
      optimize: {
        sizeLabel: "Tamaño",
        priceLabel: "Precio",
        chip: "Optimizada · una foto a la vez",
      },
      lock: {
        chip: "La llave se queda en este dispositivo",
      },
      notary: {
        eyebrow: "Notaría pública · contrato inteligente",
        ownerLabel: "propietario",
        contentLabel: "contenido",
        nameLabel: "nombre",
        typeLabel: "tipo",
        cannotSee: "No puede ver lo que hay dentro.",
      },
      network: {
        chip: "Copias cifradas, en todo el mundo",
      },
    },
  },

  liveStats: {
    eyebrow: "En vivo desde la red",
    subtitle:
      "Contado a partir de eventos públicos del contrato. Sin nombres. Sin archivos.",
    photosKept: "Fotos conservadas",
    spacesOpened: "Espacios abiertos",
    dataStored: "Datos almacenados",
    photosShared: "Fotos compartidas",
    notAvailable: "—",
    unitGb: "GB",
  },

  notOnServers: {
    eyebrow: "No en nuestros servidores",
    title:
      "Tu foto vive en muchos computadores. Ninguno es nuestro.",
    lede: "Cada copia se cifra antes de salir de tu dispositivo.",
    ledeEmphasis:
      "Los computadores que la guardan no pueden verla. Tampoco Kipio ni el protocolo. Solo tú.",
    bullets: [
      {
        title: "Construimos la puerta, no la casa.",
        body: "Kipio no aloja tus fotos.",
      },
      {
        title: "Muchos computadores lo confirman.",
        body: "Ninguna empresa puede quitártelas en silencio.",
      },
      {
        title: "Dos redes, dos funciones.",
        body:
          "Arbitrum registra a quién pertenece. Irys guarda el archivo cifrado.",
      },
      {
        title: "Sin compromiso con nadie.",
        body:
          "Irys hoy. Arweave o Filecoin mañana, si te sirven mejor.",
      },
    ],
    networkViz: {
      arbitrumLabel: "Arbitrum",
      arbitrumAnnotation: "a quién pertenece",
      lockedCopies: "Copias cifradas · solo tu llave las abre",
      irysLabel: "Irys",
      irysAnnotation: "dónde se guarda",
    },
  },

  pricing: {
    termFallbackNote:
  "El precio por plazo está en finalización. Mostrando el precio permanente como límite superior; los plazos cuestan menos.",
    calculating: "Calculando…",
    feePreviewNote:
      "Durante el preview, la comisión de Kipio es 0%. Se activará cuando el contrato de economía esté activo.",
    priceUnavailable:
      "Precio en vivo no disponible. Reintenta en un momento.",
    unitKb: "KB",
    unitMb: "MB",
    unitGb: "GB",
    unitTb: "TB",
    sizeLabel: "Tamaño de la foto",
    sizeHint: "Desliza para ver cuánto cuesta tu subida.",
    currencyLabel: "Moneda",
    eyebrow: "Precio honesto",
    title: "Pagas lo que realmente cuesta guardarlo. Más nuestra comisión, en abierto.",
    subtitle:
      "Leemos el precio de la red de almacenamiento y te lo mostramos. Luego añadimos nuestra comisión. Pagas por cada subida. Nunca una suscripción.",
    terms: {
      days30: "30 días",
      year1: "1 año",
      forever: "Para siempre",
    },
    shorterCostsLess:
      "Los plazos cortos cuestan menos. Las fotos no se pueden borrar antes de que termine su plazo, y puedes extenderlo cuando quieras.",
    storageLabel: "Almacenamiento · fijado por la red",
    feeLabel: "Comisión de Kipio",
    totalLabel: "Total",
    sponsorNote:
      "Cada foto se optimiza y se guarda por su cuenta. Si alguna vez un patrocinador cubre una subida, te lo decimos y te decimos quién paga.",
    pending: "—",
  },

  sovereign: {
    eyebrow: "Soberanía por diseño",
    statements: [
      {
        title: "Sin llave maestra.",
        body: "",
        bodyEmphasis: "No podemos abrir tus fotos",
        bodyAfter: ", ni aunque nos lo pidan.",
      },
      {
        title: "Sin factura mensual.",
        body: "Pagas cuando subes. ",
        bodyEmphasis: "Nada caduca",
        bodyAfter: " y se las lleva.",
      },
      {
        title: "Privadas, no anónimas.",
        body: "Tus fotos son ",
        bodyEmphasis: "totalmente privadas",
        bodyAfter:
          ". Tu cuenta es seudónima: las redes públicas ven una dirección, nunca tu nombre. No podemos prometer anonimato.",
      },
      {
        title: "Tuyas para compartir.",
        body: "Comparte con quien elijas, ",
        bodyEmphasis: "sin entregar tu llave",
        bodyAfter: ".",
      },
    ],
  },

  anyDevice: {
    eyebrow: "Cualquier dispositivo",
    title: "Tu calidad viaja contigo.",
    subtitle:
      "Tómala en un iPhone, ábrela en Windows. Tu original queda intacto, y tú eliges cómo exportarla: original o compatible.",
    devices: ["iPhone", "Android", "Windows", "Mac", "Web"],
  },

  openByDesign: {
    repoAriaLabel: "{title} — Ver en GitHub",
    eyebrow: "Abierto por diseño",
    title: "Funciona incluso si Kipio desaparece.",
    paragraph1:
      "Tus fotos viven en redes públicas y los contratos que las protegen son abiertos. Si mañana dejáramos de existir, tu espacio seguiría funcionando. Aún podrías abrir, mover y compartir todo.",
    paragraph2: "",
    paragraph2Emphasis: "Kipio es código abierto.",
    paragraph2After:
      " Cualquiera puede leer el código y verificar cómo se paga.",
    repos: [
      {
        slug: "[org]/contracts",
        title: "Contratos",
        body: "Cómo se registra la propiedad",
        view: "Ver ↗",
      },
      {
        slug: "[org]/frontend",
        title: "Frontend",
        body: "La aplicación que estás usando",
        view: "Ver ↗",
      },
      {
        slug: "[org]/docs",
        title: "Economía",
        body: "Comisiones, subsidio y a dónde van",
        view: "Ver ↗",
      },
    ],
  },

  economy: {
    eyebrow: "A dónde va el dinero",
    title: "Sin negocios ocultos. Mira cada dólar.",
    subtitle:
      "El almacenamiento se paga a la red que guarda tus fotos. Kipio añade una pequeña comisión por operar la interfaz. Una parte de las comisiones financia un subsidio universal, para que más personas puedan empezar gratis.",
    bars: [
      { label: "Red de almacenamiento", pct: "[X]%" },
      { label: "Interfaz de Kipio", pct: "[X]%" },
      { label: "Subsidio universal", pct: "[X]%" },
    ],
    illustrative:
      "Ilustrativo. Las cifras reales provienen directamente de los contratos.",
    subsidy: {
      eyebrow: "Subsidio universal",
      amount: "USD [X]",
      bodyBefore: "en el fondo hoy. Alcanza para ",
      bodyEmphasis: "[N]",
      bodyAfter: " primeras subidas.",
      donate: "Donar",
      readContract: "Leer el contrato",
      disclaimer:
        "Las donaciones van al fondo de subsidio del protocolo, no al equipo de Kipio.",
      contract: "Contrato 0x93b4…4F8a",
    },
  },

  signIn: {
    eyebrow: "Cualquier forma de entrar, un solo espacio",
    title: "Inicia sesión como prefieras.",
    subtitle:
      "Correo, red social, passkey o una billetera web3. Kipio nunca pregunta quién eres, solo que seas tú.",
    methods: ["Correo", "Google", "X", "Apple", "Microsoft", "Passkey"],
    wallets: ["MetaMask", "Brave Wallet", "Rabby", "Ledger"],
    cardTitle: "Tu espacio",
    cardBody: "El mismo, sin importar por dónde entraste.",
  },

  footer: {
    contractPrefix: "Contrato ",
    contractAriaLabel: "Contrato {address} en Arbiscan",
    navAriaLabel: "Pie de página",
    docs: "Documentación",
    github: "GitHub",
    arbitrum: "Arbitrum",
    irys: "Irys",
    copyright: "© {year} Kipio",
  },
};
