# Ledger Emulator Backend

Emulates a Ledger Nano S Plus device for local development and remote
hackathon demos. The emulator runs the official Ledger Ethereum app inside
a Docker container and exposes its screen through a web UI, so the dApp can
sign transactions without requiring physical hardware.

This backend is a development and demo tool. Production deployments of the
dApp do not depend on it: users with a physical Ledger device sign through
WebHID directly from the browser.

## Requirements

- Docker (local development)
- An Ubuntu VM with Docker and open ports 5000/40000 (remote deployment)
- HTTPS termination in front of Speculos (required for browser access from
  an HTTPS-hosted dApp)

## Structure

- `apps/ethereum_nanosp.elf` — compiled Ledger Ethereum app for Nano S Plus.
  Loaded by Speculos at startup.

## Running Speculos locally

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

## Remote deployment (Oracle Cloud)

The emulator can run on a remote VM so that a deployed dApp (e.g. on
Vercel) can reach it without requiring the visitor to run Docker locally.

### VM requirements

- Ubuntu 24.04 Minimal (aarch64 is supported and preferred for Oracle
  Always Free ARM shapes)
- Shape `VM.Standard.A1.Flex` with 1 OCPU and 6 GB RAM is sufficient for a
  single Speculos instance and fits within the Always Free tier
- Public IPv4 address assigned
- Ports **22** (SSH), **5000** (web UI + API) and **40000** (APDU) open

### Network setup

The VM must sit behind three independent layers of networking that all
need to be configured:

1. **VCN public subnet.** The subnet the VM is attached to must be a
   public subnet, and the VCN's route table must contain a rule pointing
   `0.0.0.0/0` to an Internet Gateway. Both are required before the VM
   can send outbound traffic.

2. **Security List.** The default Security List of the VCN must have
   ingress rules for TCP ports 22, 5000 and 40000 from `0.0.0.0/0`.

3. **iptables on the VM.** Oracle's Ubuntu images ship with an `iptables`
   ruleset that rejects incoming traffic by default. Even with the
   Security List correctly configured, inbound connections on 5000 and
   40000 will be blocked until the corresponding iptables rules are added.
   Docker publishing the ports is not sufficient on its own.

### Initialization

The VM can be bootstrapped manually over SSH. A `cloud-init` script is
also supported, but YAML is sensitive to invisible characters introduced
during copy/paste, and a single malformed byte causes the entire script
to be rejected silently. If `cloud-init` fails, the VM boots without any
of the expected packages and the setup must be completed manually.

Manual setup over SSH:

```bash
sudo apt-get update -y
sudo apt-get upgrade -y

echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | sudo debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | sudo debconf-set-selections

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker.io iptables-persistent iptables curl git

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

REJECT_POS=$(sudo iptables -L INPUT --line-numbers -n | grep -i "reject" | head -1 | awk '{print $1}')
if [ -z "$REJECT_POS" ]; then REJECT_POS=5; fi
sudo iptables -I INPUT "$REJECT_POS" -m state --state NEW -p tcp --dport 5000 -j ACCEPT
sudo iptables -I INPUT "$REJECT_POS" -m state --state NEW -p tcp --dport 40000 -j ACCEPT
sudo netfilter-persistent save

mkdir -p /home/ubuntu/speculos/apps
```

The user must reconnect over SSH after `usermod` for the docker group
membership to take effect.

### Transferring the ELF

```bash
scp apps/ethereum_nanosp.elf ubuntu@<VM_PUBLIC_IP>:/home/ubuntu/speculos/apps/
```

### Starting Speculos on the VM

```bash
cd ~/speculos
docker run -d --name speculos-eth \
  --restart unless-stopped \
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

The `--restart unless-stopped` flag ensures the container survives VM
reboots. The container is managed by the Docker daemon and does not
depend on any SSH session.

### HTTPS termination

Speculos itself only serves plain HTTP. When the dApp is hosted on an
HTTPS origin (Vercel, Netlify, any modern hosting), the browser blocks
every request from the page to an HTTP endpoint. This is enforced by the
browser's mixed content policy and cannot be bypassed from JavaScript.

To make Speculos reachable from an HTTPS dApp, it must be fronted by an
HTTPS endpoint. Cloudflare Tunnel is one option that does not require
opening additional ports on the VM. The tunnel runs as a systemd service
inside the VM, connects outbound to Cloudflare, and exposes a public
hostname with a managed TLS certificate.

Configuring the tunnel requires:

- A domain whose nameservers point to Cloudflare
- A Named Tunnel created from the Cloudflare Zero Trust dashboard
- A public hostname (e.g. `speculos.<domain>`) mapping to
  `http://localhost:5000` on the VM
- The `cloudflared` service installed on the VM using the token provided
  by the Cloudflare dashboard

Once the tunnel is active, `NEXT_PUBLIC_SPECULOS_URL_REMOTE` must point
to the HTTPS hostname, not to the VM's raw IP address.

## Frontend configuration

The frontend reads two environment variables to locate Speculos:

- `NEXT_PUBLIC_SPECULOS_URL_REMOTE` — remote endpoint (e.g. an HTTPS
  hostname in front of the VM)
- `NEXT_PUBLIC_SPECULOS_URL_LOCAL` — local endpoint (default:
  `http://localhost:5000`)

The Ledger connector tries each URL in order and caches the first one
that responds. This allows a single frontend build to target a remote
emulator in production while keeping the local Docker instance as a
development fallback.

Since `NEXT_PUBLIC_*` variables are inlined at build time, changing
either value requires a redeploy of the frontend.

## Operational notes

- **Persistent state.** The Speculos container derives its account from
  the seed passed at startup. Regenerating or losing the container without
  the seed prevents recovering the same address and the funds associated
  with it.
- **The seed is a demo credential.** It is only ever used to sign
  transactions on test networks. Do not reuse a mnemonic that controls
  real assets.
- **The emulated account must hold testnet ETH.** The dApp sends real
  transactions on Arbitrum Sepolia, so the account derived from the seed
  needs native testnet ETH to pay for gas. It can be topped up from any
  public faucet.
- **No Clear Signing without an origin token.** The signer is initialized
  without a Ledger origin token, so the device displays only the message
  or transaction hash. Full Clear Signing requires a token issued by
  Ledger to the application.
