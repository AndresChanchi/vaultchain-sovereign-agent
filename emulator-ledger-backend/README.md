# Ledger Emulator Backend

Emulates a Ledger Nano S Plus device for local development and hackathon
demos. The emulator runs the official Ledger Ethereum app inside a Docker
container and exposes its screen through a web UI, so the dApp can sign
transactions without requiring physical hardware.

This backend is a development and demo tool. Production deployments of
the dApp do not depend on it: users with a physical Ledger device sign
through WebHID directly from the browser.

## Requirements

- Docker

## Structure

- `apps/ethereum_nanosp.elf` — compiled Ledger Ethereum app for Nano S Plus.
  Loaded by Speculos at startup.

## Running Speculos

```bash
docker run -d --name speculos-eth \
  -p 5000:5000 \
  -p 40000:40000 \
  -v "$(pwd)/apps:/speculos/apps" \
  ghcr.io/ledgerhq/speculos:latest \
  ./apps/ethereum_nanosp.elf \
  --seed "YOUR_WORD_MNEMONIC_HERE" \
  --display headless \
  --api-port 5000 \
  --apdu-port 40000
```

- **Port 5000** — web UI. Shows the emulated screen and buttons.
- **Port 40000** — APDU server. Used by the frontend Ledger connector.
- `--seed` — any valid BIP-39 mnemonic (12 or 24 words). The address
  derived at `m/44'/60'/0'/0/0` is the account the dApp will use.

Open `http://localhost:5000` to view the emulated device, approve
transactions, and read the derived Ethereum address. The account derived
from the seed needs ETH on the target network to pay for gas.

## Regenerating the ELF

The ELF in `apps/` is compiled from the official Ledger Ethereum app.
To rebuild it:

```bash
git clone --recurse-submodules https://github.com/LedgerHQ/app-ethereum.git
cd app-ethereum

docker run --rm -ti \
  --user "$(id -u):$(id -g)" \
  -v "$(realpath .):/app" \
  -w /app \
  ghcr.io/ledgerhq/ledger-app-builder/ledger-app-dev-tools:latest \
  bash -c "make clean && make -j BOLOS_SDK=\$NANOSP_SDK DEBUG=1"

cp bin/app.elf ../apps/ethereum_nanosp.elf
```

The `app-ethereum/` directory is not committed to this repository because
it is a full clone of the upstream project. Run the steps above to
regenerate the ELF whenever the upstream source is updated.

## Frontend configuration

The frontend reads two environment variables to locate Speculos:

- `NEXT_PUBLIC_SPECULOS_URL_REMOTE` — remote endpoint (e.g. a VPS deployment)
- `NEXT_PUBLIC_SPECULOS_URL_LOCAL` — local endpoint (default: `http://localhost:5000`)

The Ledger connector tries each URL in order and caches the first one that
responds. This allows a single frontend build to target a remote emulator
in production while keeping the local Docker instance as a development
fallback.
