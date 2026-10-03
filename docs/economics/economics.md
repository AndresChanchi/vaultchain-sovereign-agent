# Kipio Economic Domain

## Philosophy

The Economic Domain exists solely to enable permanent data preservation.

It is **not** a financial protocol, an exchange, or a custody system.

Its responsibility is to coordinate economic operations required to preserve user data while remaining completely independent from the Identity Domain.

Identity determines **who** may perform an action.

Economics determines **whether the required resources have been provided**.

---

## Payment

**Definition**

A Payment is the economic action through which a user (or another funding source) covers the cost required to preserve data.

A Payment does not imply custody.

A Payment does not imply ownership transfer.

A Payment simply satisfies the economic requirements of an operation.

---

## Funding Source

**Definition**

A Funding Source is the origin of the economic resources used to execute an operation.

Examples include:

* User wallet
* User preferred token
* Sponsor
* Grant
* Protocol incentive
* Fiat on-ramp

The Economic Domain does not distinguish between these sources beyond their ability to fund an operation.

---

## Preferred Token

**Definition**

The asset the user prefers to spend whenever payment is required.

The protocol attempts to use this asset whenever compatible with the supported settlement infrastructure.

This is purely a user preference.

It has no impact on identity.

---

## Estimated Cost

**Definition**

An estimation presented before execution representing the expected economic cost of preserving data.

Estimated Cost combines:

* storage pricing (Irys)
* execution costs
* protocol fee

It exists exclusively to improve user experience.

It is never considered protocol state.

---

## Protocol Fee

**Definition**

The additional amount charged by Kipio above the underlying infrastructure cost.

Its purpose is to sustain protocol development, maintenance, future governance, and ecosystem growth.

It is intentionally independent from storage pricing.

---

## Credit

**Definition**

Credit represents reusable purchasing capacity already available for future operations.

Credit exists solely to reduce user friction.

It is not an investment.

It is not interest-bearing.

It is not a custodial account.

Its only purpose is to simplify repeated interactions.

---

## Balance

**Definition**

Balance is intentionally avoided as a domain term.

It suggests custodial ownership over deposited assets.

The protocol instead reasons in terms of Credit or Funding Availability.

---

## Sponsor

**Definition**

A Sponsor voluntarily funds operations on behalf of users.

Sponsors may include:

* ecosystem programs
* foundations
* companies
* promotional campaigns

Sponsors reduce or eliminate the user's payment requirement.

They never modify ownership of preserved data.

---

## Grant

**Definition**

A Grant represents protocol-level funding allocated for predefined purposes.

Examples include:

* onboarding campaigns
* educational programs
* hackathons
* ecosystem incentives

Grants behave as a Funding Source.

---

## Treasury

**Definition**

Treasury coordinates protocol-owned economic resources.

Its responsibility is limited to deciding whether protocol resources may fund an operation.

Treasury does not participate in identity.

Treasury does not authorize users.

Treasury does not evaluate permissions.

Treasury only manages protocol-owned economic capacity.

---

## Settlement

**Definition**

Settlement is the process through which economic resources reach their final destination.

Settlement may involve:

* bridges
* token conversion
* cross-chain execution
* infrastructure payments

Settlement belongs entirely to the Economic Domain.

Identity never observes Settlement.

---

## Storage Payment

**Definition**

The economic obligation required before permanent storage may occur.

Once satisfied, the protocol considers storage economically authorized.

---

## Storage Authorization

**Definition**

A Storage Authorization is the economic approval allowing permanent preservation to proceed.

It answers one question only:

> Has the required economic obligation been satisfied?

It does not indicate:

* identity
* permissions
* ownership
* authentication

Those belong to other domains.

---

## Paid Operation

**Definition**

An operation is Paid once every economic requirement has been successfully satisfied.

How those resources were obtained is irrelevant to downstream domains.

Identity receives only the resulting authorization.

---

## Pricing

**Definition**

Pricing determines the economic cost of an operation.

Infrastructure pricing is obtained from external systems.

Kipio does not define storage market prices.

It only combines infrastructure pricing with protocol-defined fees.

---

## Storage Provider

**Definition**

A Storage Provider is the external infrastructure responsible for preserving user data.

The Economic Domain treats Storage Providers as external services.

Their pricing model is consumed, never controlled.

---

## Cross-Chain Payment

**Definition**

A payment originating on one network and economically settled on another.

Cross-chain execution is an implementation detail of Settlement.

It is intentionally invisible to the Identity Domain.

---

# Relationship with the Identity Domain

```
Identity Domain

Who are you?

↓

Economic Domain

Has the operation been economically authorized?

↓

Storage Domain

Persist the encrypted data.

↓

Identity Domain

Bind the storage reference to the user's identity.
