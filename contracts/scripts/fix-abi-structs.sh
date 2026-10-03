#!/usr/bin/env bash
# Post-process a Stylus-generated .sol interface to inject missing
# struct declarations from a companion file.
#
# WHY THIS EXISTS:
#
# Stylus SDK 0.10.x omits struct declarations when a struct is only used
# as an INPUT parameter in some function signature. Solidity rejects the
# resulting interface with:
#
#   Error (7920): Identifier not found or not unique.
#
# The SDK only emits structs reachable from return types and storage
# fields. Input-only structs are silently dropped.
#
# TRANSITIVE CLOSURE:
#
# A first pass finds structs referenced directly in the interface but
# not declared. That alone is not enough: an injected struct may itself
# reference other structs that also live only in the companion file.
# For example, injecting PolicyConsumptionAbi requires also injecting
# PolicyAbi, because PolicyAbi appears only inside the body of
# PolicyConsumptionAbi.
#
# So the script computes the transitive closure: start from the missing
# set, look at the body of each missing struct in the companion, find
# any referenced struct that is not yet declared in the interface or
# already scheduled for injection, and add it. Repeat until fixed point.
#
# USAGE:
#   scripts/fix-abi-structs.sh <interface.sol> <companion.sol>
#
# The script is idempotent: running it twice on an already-fixed file is
# a no-op.

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 <interface.sol> <companion.sol>" >&2
    exit 2
fi

IFACE="$1"
COMPANION="$2"

if [ ! -f "$IFACE" ]; then
    echo "error: interface not found: $IFACE" >&2
    exit 1
fi

if [ ! -f "$COMPANION" ]; then
    echo "error: companion not found: $COMPANION" >&2
    exit 1
fi

python3 - "$IFACE" "$COMPANION" <<'PY'
import re
import sys
from pathlib import Path

iface_path = Path(sys.argv[1])
companion_path = Path(sys.argv[2])

src = iface_path.read_text()
companion = companion_path.read_text()

# ----------------------------------------------------------------------
# 1. Parse the companion file: extract every `struct Name { body }` block.
# ----------------------------------------------------------------------
companion_structs = {}
pattern = re.compile(
    r'struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{([^}]*)\}',
    re.DOTALL,
)
for m in pattern.finditer(companion):
    companion_structs[m.group(1)] = m.group(2).strip()

if not companion_structs:
    # Nothing to inject.
    sys.exit(0)

# ----------------------------------------------------------------------
# 2. Find declared structs in the interface.
# ----------------------------------------------------------------------
declared = set(re.findall(r'struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{', src))

# ----------------------------------------------------------------------
# 3. First pass: structs referenced directly in the interface.
# ----------------------------------------------------------------------
referenced_in_iface = set()
for name in companion_structs.keys():
    if re.search(r'\b' + re.escape(name) + r'\b', src):
        referenced_in_iface.add(name)

# ----------------------------------------------------------------------
# 4. Transitive closure: keep adding structs referenced from the body
#    of any struct that is already in the "to inject" set.
# ----------------------------------------------------------------------
to_inject = {name for name in referenced_in_iface if name not in declared}

changed = True
while changed:
    changed = False
    for name in list(to_inject):
        body = companion_structs.get(name, "")
        # Extract candidate type identifiers from the body: any identifier
        # that starts with an uppercase letter. Solidity builtins are all
        # lowercase (uint256, bytes, address, bool, string, ...), so any
        # uppercase identifier must be a struct or an interface name.
        candidates = set(re.findall(r'\b([A-Z][A-Za-z0-9_]*)\b', body))
        for cand in candidates:
            # Only consider identifiers that the companion knows about.
            if cand not in companion_structs:
                continue
            # Skip if already declared in the interface.
            if cand in declared:
                continue
            # Skip if already scheduled.
            if cand in to_inject:
                continue
            to_inject.add(cand)
            changed = True

if not to_inject:
    # Nothing missing.
    sys.exit(0)

# ----------------------------------------------------------------------
# 5. Inject missing structs inside the interface body, before the final
#    closing brace. Solidity allows forward references within a single
#    contract or interface scope, so the order of injection does not
#    matter relative to SDK-emitted structs or among the injected ones.
# ----------------------------------------------------------------------
stripped = src.rstrip()
if not stripped.endswith('}'):
    print(
        f"  fix-abi-structs: ERROR: {iface_path.name} does not end with '}}'",
        file=sys.stderr,
    )
    sys.exit(1)

insert_pos = stripped.rfind('}')

# Emit in companion-declaration order for stable output across runs.
ordered = [name for name in companion_structs.keys() if name in to_inject]

block = ""
for name in ordered:
    body = companion_structs[name]
    block += f"\n    struct {name} {{{body}}}\n"

new_src = stripped[:insert_pos] + block + stripped[insert_pos:]

if not new_src.endswith('\n'):
    new_src += '\n'

iface_path.write_text(new_src)
print(
    f"  fix-abi-structs: injected {len(ordered)} struct(s) into "
    f"{iface_path.name}: {', '.join(ordered)}"
)
PY
