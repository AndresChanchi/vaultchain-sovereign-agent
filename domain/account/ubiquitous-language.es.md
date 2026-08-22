# Ubiquitous Language de Kipio Account

## Provisional Domain Definition — Phase 2 Consolidated

> **Status:** Current semantic source of truth for the formalization of `Kipio Account`.
>
> This document reflects the domain decisions established during Phase 2.
> Implementation details may still evolve, but Dafny, Rust and blockchain representations must conform to these semantics rather than redefine them.

---

# 1. Propósito del dominio

`Kipio Account` define una primitive de **identidad soberana, autoridad y ejecución sobre blockchain**.

Su propósito es permitir que una aplicación determine:

1. qué `Identity` soberana está ejerciendo autoridad;
2. qué autoridad existe para esa Identity;
3. qué sujeto o mecanismo puede ejercer dicha autoridad;
4. bajo qué condiciones puede ejercerse;
5. qué acción solicita el contexto consumidor;
6. si dicho ejercicio está autorizado;
7. y cómo una decisión autorizada puede materializarse sobre blockchain.

`Kipio Account` **no define el significado de las acciones de negocio** del contexto consumidor.

El mismo modelo puede ser utilizado por aplicaciones que trabajen con:

* personas;
* organizaciones;
* empresas;
* agentes;
* servicios;
* dispositivos;
* u otros sujetos.

El dominio está diseñado alrededor de blockchain porque la soberanía representada por `Identity` requiere un entorno compartido en el que los estados y transiciones relevantes puedan verificarse sin depender exclusivamente de una autoridad central.

Sin embargo, el dominio no queda definido por:

* Ethereum;
* EVM;
* Arbitrum;
* Stylus;
* EIP-7702;
* ERC-4337;
* RIP-7560;
* una curva criptográfica;
* una wallet;
* una blockchain address;
* ni otra implementación concreta.

---

# 2. External Identity and Authentication Context

Una aplicación puede disponer de identidades y mecanismos de autenticación externos a `Kipio Account`.

Ejemplos:

```text
email
phone
passkey
WebAuthn credential
OAuth identity
EOA
hardware authenticator
```

Estos elementos pertenecen al contexto externo y **no son automáticamente una `Identity` de Kipio**.

Por tanto:

```text
External Identity
    !=
Kipio Identity

Authentication Mechanism
    !=
Kipio Identity

Blockchain Address
    !=
Kipio Identity
```

Un mecanismo externo puede producir evidencia que posteriormente sea reconocida por una `Credential`.

La relación conceptual es:

```text
External Identity / Authentication
        ↓
authentication evidence
        ↓
Credential
        ↓
Account recognition
        ↓
authority exercise
        ↓
blockchain execution
```

Una pérdida o sustitución de un mecanismo externo de autenticación **no implica por sí misma la pérdida de la Identity de Kipio**.

Esto permite que una Identity mantenga continuidad soberana aunque cambien los mecanismos mediante los cuales puede ser ejercida.

---

# 3. Subject

Un **Subject** representa el actor semántico al que se atribuye una Identity dentro de Kipio.

Puede representar:

* una persona;
* una organización;
* una empresa;
* un agente;
* un servicio;
* un dispositivo;
* u otro actor reconocido por el contexto consumidor.

Subject no es:

* una Identity;
* una Credential;
* una Account;
* una blockchain address;
* ni un mecanismo de autenticación.

La distinción es:

```text
Subject
    =
actor semántico

Identity
    =
continuidad soberana dentro de Kipio
```

Un mismo Subject puede estar asociado con múltiples Identities:

```text
Subject
    ├── Identity A
    ├── Identity B
    └── Identity C
```

Esto permite, por ejemplo, que una misma persona tenga identidades soberanas distintas para contextos diferentes, o que una organización tenga diferentes continuidades soberanas para diferentes funciones.

### Cardinalidad

```text
Subject
    1
    │
    └──── 0..N
           Identities
```

Cada `Identity` está atribuida a exactamente un `Subject`.

Dentro de Kipio, `Subject` es un **Value Object / semantic actor descriptor**.

---

# 4. Identity

Una **Identity** representa una continuidad soberana reconocida por Kipio mediante la cual un Subject puede ejercer autoridad.

`Identity` es una **Entity**.

La identidad de una Identity es independiente de:

* Credentials;
* Accounts;
* mecanismos criptográficos;
* blockchain addresses;
* estándares de Account Abstraction;
* representaciones técnicas.

Una Identity puede controlar múltiples Accounts:

```text
Identity A
    ├── Account A
    ├── Account B
    └── Account C
```

Una Identity también puede utilizar múltiples Credentials.

Cambiar, agregar, suspender, revocar o recuperar una Credential **no crea automáticamente una nueva Identity**.

Crear o eliminar una Account tampoco crea automáticamente una nueva Identity.

Cambiar la representación blockchain de una Account tampoco cambia automáticamente la Identity.

### Identity Identifier

Una Identity posee identidad individual propia y estable:

```text
IdentityId
```

### Cardinalidad

```text
Subject
    1
    │
    └──── 0..N
           Identity
```

---

# 5. Account

Una **Account** es el componente operativo mediante el cual una Identity ejerce autoridad sobre blockchain.

`Account` es una **Entity**.

Una Account posee identidad propia:

```text
AccountId
```

AccountId es diferente de una blockchain address.

La Account mantiene el estado operativo necesario para determinar qué ejercicios de autoridad pueden producir una ejecución válida.

Ese estado puede incluir:

* Capabilities;
* Credentials;
* Credential Authorities;
* Sessions;
* Delegations;
* Policy Effects reconocidos;
* y relaciones entre dichos elementos.

### Cardinalidad Identity ↔ Account

La relación soberana es:

```text
Identity
    1
    │
    └──── 0..N
           Accounts
```

Cada Account tiene **exactamente una Identity soberana**.

Por tanto:

```text
Account
    └── sovereign Identity = exactly one
```

Una segunda Identity puede recibir autoridad para operar una Account mediante:

* Credential;
* Delegation;
* Session;
* u otros mecanismos reconocidos.

Eso no convierte a la segunda Identity en soberana de esa Account.

Por tanto:

```text
Identity A ─────► Account X
     sovereign control

Identity B ─────► Account X
     authorized exercise
```

no significa:

```text
Identity A ──┐
             ├──► Account X
Identity B ──┘
    co-sovereignty
```

El dominio **no permite múltiples sovereign Identities directas sobre una misma Account**.

Crear otra Account crea otra Entity aunque pertenezca a la misma Identity.

---

# 6. Account Identity Representation

Una Account puede tener una representación técnica sobre una blockchain concreta.

Por ejemplo:

```text
Account
    ↓
EVM representation
    ↓
Address
```

Por tanto:

```text
Account
    !=
Blockchain Address
```

Una blockchain address representa cómo se materializa técnicamente una Account.

No representa:

* la Identity;
* la soberanía;
* ni necesariamente el AccountId.

Cambiar entre mecanismos compatibles de materialización no crea automáticamente otra Account mientras continúe el mismo lifecycle de la Entity.

### Principio

```text
Identity
    ≠
Account
    ≠
Blockchain Address
```

---

# 7. Authority

**Authority** representa la facultad efectiva de ejercer determinadas Capabilities.

Authority no constituye necesariamente una Entity persistente.

Es una relación semántica derivada de:

* Capabilities disponibles;
* Credential Authority;
* Sessions;
* Delegations;
* Restrictions;
* Policy Effects;
* Scope;
* condiciones temporales;
* contexto;
* y demás condiciones vigentes.

Authority responde:

> **qué puede ejercerse, por quién y bajo qué condiciones.**

Authority no define cómo se produce evidencia criptográfica.

---

# 8. Capability

Una **Capability** representa una facultad que puede ejercerse mediante una Identity o una autoridad derivada.

Capability expresa:

> **qué facultad existe.**

Ejemplos:

```text
Upload
Delete
Share
Transfer
Approve
Delegate
Manage
```

El significado específico de una Domain Action sigue perteneciendo al bounded context consumidor.

Una Capability puede ser limitada mediante:

* Scope;
* Restrictions;
* Session;
* Delegation;
* condiciones temporales;
* contexto;
* Policy Effects;
* y otras reglas reconocidas.

## Capability como Value Object

`Capability` es un **Value Object**.

Dos Capabilities con exactamente el mismo contenido semántico representan la misma facultad:

```text
Capability A
    ==
Capability B
```

No existe una identidad individual separada para:

```text
Upload(Album123)
```

Por tanto `Capability` **no necesita `CapabilityId`**.

Esto significa que:

```text
Capability
    =
facultad

Credential / Delegation / Authorization
    =
mecanismos mediante los cuales esa facultad puede ser ejercida
```

Revocar una Credential no revoca la existencia semántica de la Capability; únicamente impide que dicha Credential continúe utilizándola.

### Principio

> **Una Capability es una facultad por valor, no una concesión histórica individual.**

---

# 9. Capability Kind

Un **Capability Kind** identifica la clase semántica de una Capability.

Ejemplos:

```text
Upload
Delete
Share
Transfer
Approve
```

Capability Kind:

* no concede autoridad;
* no representa una ejecución;
* no identifica una Capability concreta.

`CapabilityKind` es un **Value Object**.

Su significado depende de sus valores.

---

# 10. Capability Scope

El **Capability Scope** determina el conjunto de recursos, objetos, sujetos o ámbitos sobre los que puede ejercerse una Capability.

Scope expresa:

> **sobre qué puede ejercerse la facultad.**

Ejemplo:

```text
Capability:
    Upload

Scope:
    Album #123
```

Scope es un **Value Object**.

No debe confundirse con `Execution Target`:

```text
Capability Scope
    =
where authority exists

Execution Target
    =
where execution is technically materialized
```

---

# 11. Capability Metadata

La **Capability Metadata** contiene información descriptiva asociada con una Capability.

Puede utilizarse para:

* presentación;
* clasificación;
* organización;
* descubrimiento;
* UX;
* integración.

Metadata no modifica por sí misma la autoridad.

Puede ser:

* pública;
* privada;
* cifrada;
* protegida mediante zero-knowledge proofs;
* u otros mecanismos.

La Account no determina el mecanismo de privacidad.

### Invariante

> **Modificar Metadata no modifica por sí mismo la autoridad representada por una Capability.**

---

# 12. Credential

Una **Credential** es una fuente reconocida por una Account mediante la cual puede producirse evidencia para ejercer autoridad.

La Credential no identifica la Identity. La Credential es una fuente reconocida mediante la cual puede ejercerse autoridad asociada a una Identity. Por tanto, cualquier mecanismo determinista que derive una Account debe basarse en la continuidad de la Identity soberana, o en una resolución determinista hacia ella, y no directamente en una Credential que pueda ser sustituida durante el lifecycle de la Identity.

`Credential` es una **Entity**.

Una Credential tiene continuidad individual durante su lifecycle:

```text
active
→ suspended
→ reactivated
→ revoked
```

Revocar una Credential no crea otra Credential.

Una Credential puede estar basada en:

* passkey;
* WebAuthn;
* secp256k1;
* P-256;
* hardware;
* multisig;
* threshold cryptography;
* mecanismos futuros;
* u otros mecanismos.

El dominio no identifica Credential con ninguno de esos mecanismos.

### Credential ≠ Identity

Una Credential no representa soberanía.

Una Credential no se convierte en Identity por producir una Proof.

### Credential ≠ Account

Una Credential tampoco es una Account.

Es una fuente reconocida mediante la cual pueden ejercerse determinadas capacidades sobre una o más Accounts.

---

# 13. Credential ↔ Account Recognition

La relación entre Credential y Account es **contextual y explícita en Authorization State**.

Una Credential puede ser reconocida por una o más Accounts.

Por tanto:

```text
Credential A
    ├── recognized by Account A
    ├── recognized by Account B
    └── recognized by Account C
```

El reconocimiento es independiente para cada Account.

Una Credential reconocida por una Account no adquiere soberanía sobre ella.

Tampoco implica que las Accounts compartan soberanía.

La relación semántica es:

```text
Credential
    │
    ├── Account A → Credential Authority A
    ├── Account B → Credential Authority B
    └── Account C → Credential Authority C
```

Por tanto, una misma Credential puede tener diferentes autoridades según la Account en la que sea reconocida.

### Credential ↔ Identity

La Identity soberana pertenece a la Account.

Una Credential puede ser utilizada como mecanismo para ejercer autoridad asociada a la Identity soberana de la Account o autoridad derivada reconocida por ella.

La Credential **no necesita contener la Identity como parte de su identidad estructural**.

Esto permite preservar la separación:

```text
Identity
    =
sovereign continuity

Credential
    =
recognized authority-exercise source

Account
    =
operational authority state
```

---

# 14. Credential Authority

**Credential Authority** representa el conjunto de Capabilities que una Credential puede intentar ejercer dentro de una Account concreta.

Credential Authority es un **Value Object / authority relation value**.

Dos Credentials pueden tener la misma Credential Authority:

```text
CredentialAuthority(A)
    ==
CredentialAuthority(B)
```

sin ser la misma Credential.

### Invariante

```text
Requested Capability
    ∈
Credential Authority
```

es una condición necesaria para que una Credential pueda intentar ejercer esa Capability.

No es suficiente para que la autoridad sea efectiva.

Sessions, Delegations, Restrictions, Policies y demás condiciones pueden reducirla posteriormente.

### Principio

> **Credential Authority describe qué puede intentar ejercer una Credential sobre una Account; no concede soberanía.**

---

# 15. Proof

Una **Proof** es evidencia criptográfica utilizada para demostrar que una Authorization fue producida mediante la Credential correspondiente.

Proof pertenece a infraestructura criptográfica.

No define:

* Identity;
* Capability;
* Scope;
* Authority;
* Authorization validity.

### Principio

> **Proof validity is not authorization validity.**

---

# 16. Verifier

Un **Verifier** verifica una Proof utilizando un mecanismo criptográfico concreto.

Puede utilizar:

* P-256;
* secp256k1;
* BLS;
* post-quantum cryptography;
* u otros mecanismos.

El Verifier determina:

> **si la evidencia satisface las reglas criptográficas de su mecanismo.**

No determina:

> **si el ejercicio de autoridad está permitido.**

---

# 17. Requested Authority

**Requested Authority** representa la autoridad que una Authorization intenta ejercer.

Puede incluir:

* Capabilities;
* Scope;
* Restrictions;
* condiciones temporales;
* contexto;
* y otras condiciones relevantes.

Requested Authority es un **Value Object**.

No concede autoridad.

Representa únicamente aquello que una Authorization solicita ejercer.

---

# 18. Authorization

Una **Authorization** representa una solicitud o evidencia verificable de ejercicio de autoridad.

Contiene o referencia:

* Credential;
* Requested Authority;
* Restrictions;
* condiciones temporales;
* Replay Protection;
* Proof;
* contexto relevante.

Authorization es un **Value Object**.

Dos Authorizations son iguales cuando tienen el mismo valor semántico completo.

No necesita `AuthorizationId`.

### Regla principal

Una Authorization puede aceptarse solamente cuando:

```text
Requested Authority
    ⊆
Effective Authority
```

y se satisfacen las demás condiciones de Authorization Validation.

Por tanto:

```text
Valid Proof
    ≠
Valid Authorization
```

### Replay

`replayKey` o cualquier mecanismo equivalente forma parte de Replay Protection.

No debe confundirse automáticamente con una identidad de Entity.

---

# 19. Authorization Validation

**Authorization Validation** determina si una Authorization puede ser aceptada por una Account en un estado y contexto determinados.

Debe considerar:

1. Credential reconocida;
2. Proof válida;
3. Credential Authority compatible;
4. Capabilities existentes;
5. Scope;
6. Restrictions;
7. Sessions;
8. Delegations;
9. Policy Effects;
10. temporalidad;
11. Replay Protection.

### Principio

> **Proof Verification valida evidencia criptográfica; Authorization Validation determina autoridad de dominio.**

La validación de autoridad puede estar distribuida entre diferentes bounded contexts o módulos.

---

# 20. Session

Una **Session** es una autorización temporal derivada de una Credential.

`Session` es una **Entity**.

Mantiene identidad durante su lifecycle:

```text
active
→ expired

active
→ revoked
```

La expiración o revocación no crea otra Session.

Una Session puede limitar:

* Capabilities;
* Scope;
* duración;
* frecuencia;
* valor;
* contexto;
* destinatarios;
* otras condiciones.

### Invariante

```text
Session Authority
    ⊆
Credential Authority
```

Una Session nunca puede ampliar la autoridad de su Credential origen.

Si la Credential deja de ser válida, las Sessions dependientes de ella dejan de poder producir Authorization válida.

---

# 21. Delegation

Una **Delegation** permite derivar autoridad hacia otro Subject bajo condiciones explícitas.

`Delegation` es una **Entity**.

Mantiene identidad durante su lifecycle:

```text
active
→ revoked
```

Revocar una Delegation no crea una nueva Delegation.

No transfiere automáticamente:

* Identity;
* soberanía;
* propiedad de las Capabilities originales.

### Invariante

```text
Delegated Authority
    ⊆
Delegatable Authority of source
```

La autoridad delegada nunca puede superar la autoridad que el origen puede legítimamente delegar.

---

# 22. Delegatee

Un **Delegatee** es el Subject que recibe autoridad derivada mediante una Delegation.

Puede representar:

* persona;
* organización;
* agente;
* servicio;
* dispositivo;
* Account;
* otro Subject.

Delegatee no significa sovereign owner.

---

# 23. Restriction

Una **Restriction** limita las condiciones bajo las cuales una Capability puede ejercerse.

Restriction es un **Value Object**.

No crea Capabilities nuevas.

Puede limitar:

* cantidad;
* valor;
* frecuencia;
* tiempo;
* destinatario;
* Scope;
* contexto;
* tipo de operación;
* número de ejecuciones.

Ejemplo:

```text
Spend
    +
maximum_value = X
    +
valid_until = T
```

Su significado depende de sus valores.

---

# 24. Effective Authority

**Effective Authority** representa la autoridad que realmente puede ejercerse en un contexto concreto.

Es una representación **derivada, contextual y por valor**.

Conceptualmente:

```text
Account Capabilities
        ∩
Credential Authority
        ∩
Session Authority
        ∩
Delegated Authority
        ∩
Scope Conditions
        ∩
Restrictions
        ∩
Temporal Conditions
        ∩
Applicable Policy Effects
        ↓
Effective Authority
```

Effective Authority no necesita identidad propia.

La misma Credential puede producir diferentes Effective Authorities dependiendo de:

* Account;
* Session;
* Delegation;
* Scope;
* tiempo;
* Restrictions;
* Authorization State;
* Policy Effects;
* Execution Context.

---

# 25. Authorization State

**Authorization State** representa el estado operativo de autorización mantenido por una Account.

Puede contener:

* Credentials;
* reconocimiento Credential ↔ Account;
* Credential Authorities;
* Sessions;
* Delegations;
* Capabilities;
* Restrictions;
* Policy Effects reconocidos;
* relaciones estructurales necesarias para evaluar autoridad.

Authorization State no representa una ejecución.

Authorization State es el estado sobre el cual se resuelve Effective Authority.

### Importante

`Credential`, `Session`, `Delegation`, `Capability`, etc. pueden existir como conceptos independientes, pero **las relaciones entre ellos pertenecen a Authorization State cuando dichas relaciones son parte del estado operativo de una Account**.

Esto evita introducir esas relaciones artificialmente dentro de los value objects.

---

# 26. Authorization State Transition

Una **Authorization State Transition** representa un cambio válido en Authorization State.

Ejemplos:

* registrar Credential;
* reconocer Credential en Account;
* establecer Credential Authority;
* modificar Credential Authority;
* revocar Credential;
* crear Session;
* revocar Session;
* crear Delegation;
* revocar Delegation;
* modificar Capabilities;
* aplicar Policy Effect.

Estas transiciones pertenecen al dominio de Account.

No representan ejecuciones de negocio sobre recursos externos.

---

# 27. Policy

Una **Policy** representa una decisión externa reconocida por Account como capaz de producir uno o más cambios sobre Authorization State.

La Policy **no necesita identidad propia dentro de Account**.

En contextos externos puede existir una Entity que representa el procedimiento que produjo esa decisión.

Por ejemplo:

```text
RecoveryPolicyRequest
```

puede ser una Entity del bounded context Recovery con:

* requestId;
* lifecycle;
* approval;
* expiration;
* cancellation;
* consumption.

Pero:

```text
RecoveryPolicyRequest
    ≠
Policy Effect
```

y:

```text
RecoveryPolicyRequest
    ≠
Account Policy Value
```

Account consume la decisión reconocida, no necesita conocer todo el lifecycle del bounded context productor.

---

# 28. Policy Effect

Un **Policy Effect** representa el cambio semántico que una Policy produce sobre Authorization State.

Ejemplos:

```text
RevokeCredential(X)
EnableRecovery
DisableCapability(Y)
ModifyAuthorizationCondition(Z)
```

`PolicyEffect` es un **Value Object**.

Dos Policies distintas pueden producir el mismo efecto:

```text
PolicyRequest #1
    → RevokeCredential(X)

PolicyRequest #2
    → RevokeCredential(X)
```

y:

```text
RevokeCredential(X)
    ==
RevokeCredential(X)
```

La identidad histórica pertenece al procedimiento externo, no al efecto.

---

# 29. Policy Consumption

**Policy Consumption** representa el reconocimiento y aplicación de una Policy por parte de Account.

Conceptualmente:

```text
External Policy
      ↓
Policy Recognition
      ↓
Policy Consumption
      ↓
Policy Effect(s)
      ↓
Authorization State Transition
```

Account no necesita conocer cómo fue aprobada la Policy.

La aprobación pertenece al bounded context productor.

Una Policy puede producir **uno o más Policy Effects**.

La semántica de:

* atomicidad;
* orden;
* idempotencia;
* duplicación;
* consumo parcial;

pertenece a la formalización de Policy Consumption y Account Transitions.

`PolicyConsumption` es un **Value Object / transition value** mientras no se descubra un lifecycle histórico propio dentro de Account.

---

# 30. Domain Action

Una **Domain Action** representa una intención concreta del bounded context consumidor.

Ejemplos:

```text
UploadPhoto
DeletePhoto
TransferFunds
ApprovePayroll
CreateInvoice
ShareAlbum
```

Kipio Account no define:

* el catálogo;
* el significado;
* el lifecycle;
* la identidad interna;
* las reglas de negocio.

Domain Action es un **external Value Object**.

Kipio sólo necesita una representación suficiente para determinar si existe autoridad para ejecutar la acción.

---

# 31. Execution Request

Un **Execution Request** representa una solicitud para materializar una Domain Action.

Puede contener:

* Domain Action;
* Authorization;
* Requested Authority;
* Execution Target;
* Execution Constraints;
* contexto necesario para Runtime.

Execution Request es un **Value Object / request value**.

No representa una Execution materializada.

---

# 32. Execution Target

Un **Execution Target** identifica el destino técnico sobre el cual se materializará la ejecución.

Puede representar:

* contrato;
* recurso;
* servicio;
* infraestructura;
* u otro destino compatible.

No define Authority.

La diferencia es:

```text
Capability Scope
    =
where authority exists

Execution Target
    =
where execution is materialized
```

---

# 33. Execution Context

Un **Execution Context** representa la decisión completa y validada necesaria para que una ejecución sea materializada.

Puede incorporar los resultados de:

* Authorization;
* Effective Authority;
* Authorization State;
* Policy Effects;
* Restrictions;
* Execution Constraints;
* Domain Action;
* Execution Target;
* y demás condiciones relevantes.

Un Execution Context válido significa:

> **la autoridad requerida y las condiciones necesarias han sido evaluadas y la ejecución puede proceder bajo ese contexto.**

El Execution Context es un **Value Object / complete execution decision**.

El Execution Engine recibe únicamente contextos válidos.

No vuelve a decidir Authority.

---

# 34. Execution Constraints

**Execution Constraints** representan condiciones que deben satisfacerse para materializar un Execution Context.

Pueden incluir:

* límites;
* temporalidad;
* atomicidad;
* límites operativos;
* condiciones de materialización;
* otras restricciones reconocidas.

Execution Constraints no crean Authority.

Sólo condicionan la materialización de una decisión autorizada.

---

# 35. Runtime

El **Runtime** es el componente transitorio que **orquesta la evaluación distribuida y la materialización operacional** de una solicitud.

El Runtime:

1. recibe una Execution Request;
2. coordina la obtención del Authorization State relevante;
3. coordina la validación de Authorization;
4. coordina la determinación de Effective Authority;
5. coordina la aplicación de Policy Effects y Restrictions relevantes;
6. verifica Execution Constraints;
7. construye Execution Context;
8. entrega únicamente contextos válidos al Execution Engine.

### Importante

Runtime **no es el propietario de todas las reglas de autoridad**.

La evaluación puede distribuirse entre bounded contexts o módulos especializados, por ejemplo:

```text
Authentication / Credential Verification
Authorization
Recovery
Access
Registry
Economics
Execution Gateway
```

Runtime coordina esos resultados.

Por tanto:

```text
Runtime
    =
Authority / Execution Orchestration
```

no:

```text
Runtime
    =
owner of every authorization rule
```

---

# 36. Execution Engine

El **Execution Engine** recibe un Execution Context válido y transforma esa decisión en operaciones materializables.

Su entrada conceptual es:

```text
Execution Context
```

No:

* interpreta Credentials;
* decide Authority;
* crea Authorization;
* define Domain Actions;
* redefine Policy;
* implementa reglas criptográficas.

Su responsabilidad es:

> **materializar una decisión ya tomada.**

Puede producir una o múltiples operaciones cuando la infraestructura soporte:

* batching;
* multicall;
* atomicidad;
* u otros mecanismos equivalentes.

---

# 37. Execution

Una **Execution** representa el proceso/materialización concreta de una acción autorizada.

No es actualmente una Entity del `Account domain`.

La arquitectura actual distingue:

```text
Execution Request
        ↓
Execution Context
        ↓
Runtime orchestration
        ↓
Execution Engine
        ↓
Adapter
        ↓
physical execution
```

Una ejecución puede consistir en:

```text
one operation
```

o:

```text
multiple operations
```

La infraestructura determina cómo se garantizan:

* atomicidad;
* integridad;
* replay protection;
* cumplimiento de constraints.

### Lifecycle

El Runtime puede poseer un lifecycle operacional:

```text
Validation
→ PreFlight
→ Accounting
→ Dispatch
→ Settlement
```

y resultados como:

```text
Completed
Reverted
Aborted
Expired
Cancelled
Failed
```

pero estos representan **el lifecycle del workflow operacional**, no una Entity `Execution` persistente del dominio Account.

Por tanto:

```text
Execution
    ≠
Execution Entity
```

y no se introduce `ExecutionId`.

---

# 38. Adapter

Un **Adapter** materializa una Execution sobre una infraestructura concreta.

Ejemplos:

* EIP-7702;
* ERC-4337;
* RIP-7560;
* futuras formas de Account Abstraction;
* otras infraestructuras compatibles.

El Adapter transforma:

```text
Kipio Execution Semantics
        ↓
Infrastructure primitives
```

y no al contrario.

### Principio

> **El dominio define qué significa una ejecución válida; el Adapter define cómo materializarla sobre una infraestructura concreta.**

---

# 39. Blockchain

La **Blockchain** forma parte del contexto fundamental de Kipio.

Proporciona el entorno compartido donde Accounts pueden:

* ejercer autoridad;
* producir cambios verificables;
* materializar ejecuciones.

Kipio no abstrae la existencia de blockchain.

Abstrae las diferencias entre las infraestructuras concretas utilizadas para operar sobre ella.

```text
Blockchain
    ≠
Ethereum
    ≠
EVM
    ≠
Arbitrum
    ≠
Stylus
    ≠
EIP-7702
    ≠
ERC-4337
```

---

# 40. Gas Payment

**Gas Payment** representa la provisión de recursos económicos necesarios para materializar una Execution.

Gas Payment es independiente de Authority.

Una entidad puede pagar una Execution sin adquirir autoridad sobre ella.

```text
Authority
    ≠
Gas Payment
```

Pagar no concede autorización.

---

# 41. Execution Sponsor

Un **Execution Sponsor** proporciona recursos para pagar una Execution en beneficio de otro sujeto.

El Sponsor no adquiere automáticamente Authority.

Los mecanismos concretos pueden incluir:

* relayers;
* paymasters;
* sponsored accounts;
* mecanismos nativos;
* u otros.

Sponsorship pertenece a infraestructura/economics.

---

# 42. Replay Protection

**Replay Protection** garantiza que una Authorization o Execution no pueda reutilizarse fuera de las condiciones para las cuales fue creada.

Puede depender de:

* replay keys;
* nonces;
* sequence numbers;
* expiración;
* consumption markers;
* state;
* temporalidad;
* u otros mecanismos.

El dominio exige:

> **Una Authorization válida en un contexto no debe convertirse automáticamente en una Authorization válida en un contexto posterior o diferente cuando sus condiciones originales ya no se cumplen.**

Replay Protection no implica que exista una Entity `Authorization`.

Su estado operacional puede pertenecer a Authorization State o a un estado específico de replay.

---

# 43. Authentication

**Authentication** es el proceso mediante el cual se obtiene evidencia de que una Credential corresponde al mecanismo o sujeto que pretende ejercerla.

Authentication no equivale a Authorization.

```text
Authentication
    =
who / what produced the evidence

Authorization
    =
what authority may be exercised
```

Una autenticación correcta no concede automáticamente una Capability.

---

# 44. Identity Sovereignty

**Identity Sovereignty** significa que la continuidad soberana de una Identity no depende del mecanismo concreto mediante el cual se autentica, ejerce, delega o materializa su autoridad.

Esto implica:

* cambiar Credentials no cambia automáticamente Identity;
* cambiar Accounts no cambia automáticamente Identity;
* cambiar blockchain representation no cambia automáticamente Identity;
* Delegation no transfiere automáticamente sovereignty;
* Sponsor no adquiere Authority por pagar;
* mecanismo criptográfico no define Identity;
* address no define Identity.

La soberanía pertenece a `Identity`.

---

# 45. Authority Abstraction

**Authority Abstraction** es la capacidad de representar:

```text
who may exercise
what authority
under what conditions
```

sin exigir que el modelo conceptual conozca:

* curva criptográfica;
* wallet;
* proveedor de autenticación;
* blockchain concreta;
* Account Abstraction standard;
* address representation;
* u otra implementación.

Authority Abstraction no significa eliminar blockchain del modelo.

Significa abstraer las implementaciones concretas mediante las cuales la autoridad se ejerce sobre blockchain.

---

# 46. Entity and Value Object Classification

La clasificación consolidada es:

## Entities

```text
Identity
Account
Credential
Session
Delegation
```

Estas entidades poseen identidad individual propia y continuidad/lifecycle.

Sus identifiers son:

```text
IdentityId
AccountId
CredentialId
SessionId
DelegationId
```

## Value Objects

```text
Subject
Capability
CapabilityKind
Scope
Restriction
CredentialAuthority
EffectiveAuthority
RequestedAuthority
Authorization
Policy
PolicyEffect
PolicyConsumption
DomainAction
ExecutionRequest
ExecutionContext
ExecutionConstraints
Timestamp
```

## Operational / Infrastructure Concepts

```text
Proof
Verifier
Runtime
Execution Engine
Execution
Adapter
Blockchain
Gas Payment
Execution Sponsor
Authentication
```

Estos últimos no deben recibir artificialmente identidad de Entity dentro del Account domain.

---

# 47. Identifier Semantics

Un **Identifier** representa una referencia estable utilizada para distinguir una Entity cuya identidad individual forma parte de su semántica.

Los identifiers actuales son:

```text
Identity       → IdentityId
Account        → AccountId
Credential     → CredentialId
Session        → SessionId
Delegation     → DelegationId
```

No se asignan identifiers propios a:

```text
Capability
PolicyEffect
Authorization
ExecutionContext
DomainAction
Restriction
Scope
```

porque su significado está determinado por su contenido.

### Identifier ≠ representación

Un Identifier no es automáticamente:

* hash;
* nonce;
* address;
* B256;
* private key;
* public key;
* clasificación.

### Tamaño

El dominio no establece actualmente:

```text
|Identifier| = 32 bytes
```

La representación física puede ser definida por infraestructura sin cambiar necesariamente la semántica del Identifier.

### Uniqueness

Cada Entity debe poder distinguirse dentro del ámbito de identidad que requiera su lifecycle.

La forma concreta de garantizar esa unicidad pertenece al diseño del estado y la infraestructura correspondiente.

### Generation

El dominio no exige un único mecanismo de generación.

Puede ser:

* deterministic;
* random;
* derived;
* assigned;
* external;
* u otro mecanismo compatible.

---

# 48. Universal Account Stress Test

Toda nueva abstracción debe justificarse mediante un problema real y recurrente.

Antes de introducir una nueva Entity, Value Object, relación o regla debe verificarse:

### 1. Problema real

¿Qué problema concreto y recurrente resuelve?

### 2. Reutilización

¿Aparece en más de una aplicación o contexto?

### 3. Independencia de aplicación

¿Puede existir sin conocer el modelo de negocio específico de una aplicación?

### 4. Independencia de infraestructura

¿Puede expresarse sin depender de una implementación concreta?

### 5. Composición

¿Puede resolverse componiendo conceptos existentes?

### 6. Semántica

¿Representa una realidad del dominio o una necesidad de implementación?

### 7. Reutilización entre Subjects

¿Puede utilizarse con diferentes tipos de Subject?

### 8. Identity Requirement

¿Necesita identidad individual propia o su significado está completamente determinado por sus valores?

La ausencia de una necesidad clara de identidad debe impedir introducir un Identifier artificial.

---

# 49. Principios arquitectónicos oficiales

1. **Subject, Identity, Account y Blockchain Address son conceptos diferentes.**

2. **External Identity y Authentication Mechanism no son automáticamente Kipio Identity.**

3. **Subject representa al actor semántico.**

4. **Identity representa continuidad soberana.**

5. **Una Identity puede controlar múltiples Accounts.**

6. **Cada Account tiene exactamente una sovereign Identity.**

7. **La autorización de otra Identity sobre una Account no crea co-soberanía.**

8. **Account es una Entity distinta de una Blockchain Address.**

9. **Capability es un Value Object.**

10. **Capability expresa una facultad y no una concesión histórica individual.**

11. **Capability no necesita CapabilityId.**

12. **CapabilityKind y Scope son Value Objects.**

13. **Credential es una Entity independiente de Identity.**

14. **Una Credential puede ser reconocida por una o más Accounts.**

15. **El reconocimiento de Credential es específico a cada Account.**

16. **Credential Authority es un Value Object que describe la autoridad que una Credential puede intentar ejercer sobre una Account.**

17. **Una Credential no adquiere soberanía por ser reconocida por una Account.**

18. **Una Session es una Entity temporal derivada de una Credential.**

19. **Session Authority nunca puede superar Credential Authority.**

20. **Delegation es una Entity con lifecycle propio.**

21. **Delegated Authority nunca puede superar la Delegatable Authority del origen.**

22. **Restriction es un Value Object que limita autoridad existente.**

23. **Effective Authority es contextual, derivada y por valor.**

24. **Authorization es un Value Object.**

25. **Authorization no necesita AuthorizationId.**

26. **Requested Authority es un Value Object.**

27. **Proof Verification y Authorization Validation son responsabilidades diferentes.**

28. **Proof válida no implica Authorization válida.**

29. **Policy es una decisión externa reconocida por Account y no necesita identidad propia dentro de Account.**

30. **RecoveryPolicyRequest u otras entidades históricas pertenecen a sus bounded contexts productores.**

31. **PolicyEffect es un Value Object.**

32. **Una Policy puede producir uno o más Policy Effects.**

33. **Policy Consumption produce cambios reconocidos sobre Authorization State.**

34. **Authorization State contiene relaciones operativas entre Credentials, Accounts, Sessions, Delegations, Capabilities y Policy Effects.**

35. **Authorization State Transition representa cambios válidos de ese estado.**

36. **Domain Action pertenece al bounded context consumidor.**

37. **Execution Request es un Value Object.**

38. **Execution Context es un Value Object y representa una decisión completa ya validada.**

39. **Execution Constraints no crean Authority.**

40. **Runtime coordina la evaluación distribuida de autoridad y la orquestación de ejecución.**

41. **Runtime no es propietario de todas las reglas de autorización.**

42. **Execution Engine materializa Execution Contexts válidos y no decide Authority.**

43. **Execution es un proceso/materialización operacional, no una Entity del Account domain.**

44. **No se introduce ExecutionId.**

45. **Una Execution puede producir múltiples operaciones cuando la infraestructura soporte batching, multicall o atomicidad.**

46. **Adapters materializan las semánticas del dominio sobre infraestructuras concretas.**

47. **Blockchain es parte fundamental del contexto de Kipio.**

48. **Authentication, Authorization y Gas Payment son responsabilidades diferentes.**

49. **Capability Scope y Execution Target son conceptos diferentes.**

50. **Metadata no modifica por sí misma la autoridad.**

51. **Los identifiers existen porque ciertas Entities necesitan identidad individual.**

52. **No todo concepto del dominio necesita Identifier.**

53. **Un Identifier no es automáticamente hash, nonce, address, B256 o clave criptográfica.**

54. **El dominio no fija actualmente un tamaño concreto de Identifier.**

55. **Replay Protection es una propiedad transversal y no convierte Authorization en una Entity.**

56. **Una nueva abstracción debe justificarse por una necesidad real y recurrente.**

57. **La formalización Dafny debe derivarse del significado del DDD y no utilizar detalles de Rust/EVM para redefinir el dominio.**

---

# 50. Modelo conceptual consolidado

```text
                         EXTERNAL WORLD
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
          External Identity          Authentication
          email / phone / EOA         mechanisms
                 │                           │
                 └─────────────┬─────────────┘
                               │
                         authentication
                           evidence
                               │
                               ▼
                           CREDENTIAL
                               │
                    recognized by Account
                               │
                               ▼
                           IDENTITY
                               │
                  sovereign ownership
                               │
                  ┌────────────┼────────────┐
                  │            │            │
               Account A    Account B    Account C
                  │            │            │
                  └────────────┼────────────┘
                               │
                     AUTHORIZATION STATE
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   CAPABILITIES            CREDENTIALS            POLICIES
        │                      │                      │
        │              CREDENTIAL AUTHORITY       POLICY EFFECTS
        │                      │                      │
        │                   SESSIONS                 │
        │                      │                      │
        │                 DELEGATIONS                │
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                         RESTRICTIONS
                               │
                               ▼
                     EFFECTIVE AUTHORITY
                               │
                    ┌──────────┴──────────┐
                    │                     │
              AUTHORIZATION         DOMAIN ACTION
                    │                     │
                    └──────────┬──────────┘
                               │
                      EXECUTION REQUEST
                               │
                               ▼
                            RUNTIME
                               │
                  distributed authority
                     / orchestration
                               │
                               ▼
                     EXECUTION CONTEXT
                               │
                               ▼
                      EXECUTION ENGINE
                               │
                               ▼
                            ADAPTER
                               │
                               ▼
                          BLOCKCHAIN
```

Infraestructura transversal:

```text
Proof
Verifier
Authentication mechanisms
Replay Protection
Gas Payment
Execution Sponsor
Privacy mechanisms
Blockchain Address representations
```

---

# 51. Distinción fundamental del dominio

```text
SUBJECT
    =
SEMANTIC ACTOR

IDENTITY
    =
SOVEREIGN CONTINUITY

ACCOUNT
    =
OPERATIONAL COMPONENT THROUGH WHICH
AN IDENTITY EXERCISES AUTHORITY ON BLOCKCHAIN

CAPABILITY
    =
WHAT AUTHORITY EXISTS

CREDENTIAL
    =
RECOGNIZED SOURCE FOR PRODUCING
AUTHORIZATION EVIDENCE

CREDENTIAL AUTHORITY
    =
WHAT A CREDENTIAL MAY ATTEMPT TO EXERCISE
ON AN ACCOUNT

AUTHORIZATION
    =
WHAT AUTHORITY IS REQUESTED / EVIDENCED

RESTRICTION / SCOPE / SESSION / DELEGATION
    =
UNDER WHAT CONDITIONS

EFFECTIVE AUTHORITY
    =
WHAT MAY ACTUALLY BE EXERCISED IN CONTEXT

AUTHORIZATION STATE
    =
OPERATIVE AUTHORITY STATE

RUNTIME
    =
DISTRIBUTED AUTHORITY / EXECUTION ORCHESTRATION

EXECUTION CONTEXT
    =
COMPLETE VALID EXECUTION DECISION

EXECUTION ENGINE
    =
EXECUTION MATERIALIZATION

EXECUTION
    =
OPERATIONAL MATERIALIZATION PROCESS

ADAPTER
    =
INFRASTRUCTURE-SPECIFIC MATERIALIZATION
```

Y las separaciones fundamentales:

```text
External Identity
    ≠
Subject
    ≠
Kipio Identity
    ≠
Account
    ≠
Blockchain Address
```

y:

```text
Capability
    ≠
Credential Authority
    ≠
Effective Authority
    ≠
Authorization
    ≠
Execution
```

---

# 52. Decisiones cerradas de Phase 2

La segunda iteración ha cerrado las siguientes decisiones:

```text
Subject
    → Value Object

Identity
    → Entity

Account
    → Entity

Capability
    → Value Object

CapabilityKind
    → Value Object

Scope
    → Value Object

Restriction
    → Value Object

Credential
    → Entity

CredentialAuthority
    → Value Object

Session
    → Entity

Delegation
    → Entity

EffectiveAuthority
    → Value Object

RequestedAuthority
    → Value Object

Authorization
    → Value Object

Policy
    → recognized external decision/value

PolicyEffect
    → Value Object

PolicyConsumption
    → Value Object / transition value

DomainAction
    → external Value Object

ExecutionRequest
    → Value Object

ExecutionContext
    → Value Object

ExecutionConstraints
    → Value Object

Execution
    → operational process, not Entity
```

Y:

```text
Identity 1
    └── 0..N Accounts

Account 1
    └── exactly 1 sovereign Identity

Credential 1
    └── 0..N recognized Accounts

Subject 1
    └── 0..N Identities
```

---

# 53. Rule for the formalization

La prioridad formal es:

```text
DDD semantic invariant
        ↓
Dafny domain model
        ↓
formal law
        ↓
proof
        ↓
Rust / blockchain representation
```

Nunca:

```text
Rust / EVM convenience
        ↓
Dafny type
        ↓
DDD retrofitted afterwards
```

Cuando Dafny encuentre una ambigüedad:

```text
Dafny ambiguity
      ↓
DDD clarification
      ↓
formal law
      ↓
proof
```

No se debe resolver una ambigüedad del dominio simplemente introduciendo una estructura conveniente en Dafny.
