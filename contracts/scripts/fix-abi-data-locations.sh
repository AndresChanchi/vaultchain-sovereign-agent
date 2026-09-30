#!/usr/bin/env bash
# Post-process a Stylus-generated .sol interface to add missing data
# location keywords (memory / calldata) on external function parameters.
#
# WHY THIS EXISTS:
#
# Stylus SDK 0.10.x emits external function signatures without data
# location keywords on struct, bytes and string parameters:
#
#   function registerCredential(CredentialAbi credential) external;
#
# Solidity rejects this with:
#
#   Error (6651): Data location must be "memory" or "calldata" for
#                 parameter in external function, but none was given.
#
# Arrays of primitives and arrays of structs DO get the keyword, so the
# SDK is inconsistent. This script normalizes every external function
# parameter to have `calldata` when the keyword is missing.
#
# WHAT IT TOUCHES:
#
#   - Function parameter lists in `function ... external ...` declarations.
#   - Parameters whose type is a struct name, `bytes`, or `string`, that
#     do not already carry `memory`, `calldata`, or `storage`.
#   - Array variants of those types.
#
# WHAT IT DOES NOT TOUCH:
#
#   - Return types (external functions do not accept data locations on
#     returns).
#   - Struct field declarations (fields never take data locations).
#   - Local variable declarations inside function bodies (there are none
#     in an interface file, but the script is defensive).
#   - Parameters that already have a data location.
#
# STRUCT NAME DISCOVERY:
#
# The script reads the companion file to learn every struct name that
# might appear as a parameter type. Structs already declared in the
# interface are also picked up. This gives a precise set of type names
# to look for, avoiding false positives on user-defined types that are
# not structs.
#
# USAGE:
#   scripts/fix-abi-data-locations.sh <interface.sol> <companion.sol>
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
# 1. Collect struct names: declared in the interface + declared in the
#    companion. This is the set of type names that need data locations.
# ----------------------------------------------------------------------
struct_names = set()
for m in re.finditer(r'struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{', src):
    struct_names.add(m.group(1))
for m in re.finditer(r'struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{', companion):
    struct_names.add(m.group(1))

# Types that always need a data location on external parameters.
# Arrays of them also need it, but those are handled by the same check.
ALWAYS_LOCATION = {"bytes", "string"}

# ----------------------------------------------------------------------
# 2. Process every line that starts with a `function` declaration.
# ----------------------------------------------------------------------
DATA_LOCATIONS = ("memory", "calldata", "storage")

def needs_location(type_with_arrays: str) -> bool:
    """True when the type requires a data location on an external param.

    Arrays of structs, arrays of bytes, arrays of string, and singular
    forms of those. Also arrays of arrays of those.
    """
    base = type_with_arrays.replace("[]", "")
    # Primitive arrays (uint256[], address[], bool[], ...) do not need a
    # data location in older solc, but in solc 0.8.x they do NOT — the
    # spec only requires it for reference types. Reference types are:
    # bytes, string, structs, and dynamic arrays of any of those (or of
    # primitives that are themselves reference-compatible).
    #
    # Since the SDK already emits data locations on primitive arrays, we
    # only touch singular reference types. If a primitive array arrives
    # without a location, we leave it alone (solc accepts it).
    if base in struct_names:
        return True
    if base in ALWAYS_LOCATION:
        return True
    # Nested arrays of reference types (e.g. SomeStruct[][]).
    if "[]" in type_with_arrays and base in struct_names:
        return True
    return False

def fix_param(param: str) -> str:
    """Insert `calldata` before the parameter name if needed.

    Returns the parameter unchanged when:
      - it already has memory/calldata/storage,
      - it is a primitive type without an array,
      - it is an array of a primitive type (the SDK always handles these).
    """
    p = param.strip()
    if not p:
        return p

    # Already carries a data location?
    for loc in DATA_LOCATIONS:
        if re.search(r'\b' + loc + r'\b', p):
            return p

    # Split "TYPE NAME". The TYPE may end with one or more "[]".
    # We require the last token to be the parameter name.
    tokens = p.rsplit(None, 1)
    if len(tokens) != 2:
        # No name (rare in valid Solidity, but be safe).
        return p
    typ, name = tokens
    typ = typ.strip()
    name = name.strip()

    if not needs_location(typ):
        return p

    return f"{typ} calldata {name}"

def fix_signature_line(line: str) -> str:
    """Rewrite a single `function ...` line.

    Locates the outer parameter list (between the first `(` after the
    function name and its matching `)`), splits parameters on commas at
    depth zero, and applies `fix_param` to each.
    """
    m = re.match(r'^(\s*function\s+[A-Za-z_][A-Za-z0-9_]*\s*\()(.*)$', line)
    if not m:
        return line
    prefix = m.group(1)
    rest = m.group(2)

    # Find the closing paren of the parameter list. Track depth for
    # safety, but in practice the parameter list contains no nested
    # parens after fix-tuple-abi.sh has run.
    depth = 0
    close_idx = -1
    for i, ch in enumerate(rest):
        if ch == '(':
            depth += 1
        elif ch == ')':
            if depth == 0:
                close_idx = i
                break
            depth -= 1

    if close_idx == -1:
        return line

    params_str = rest[:close_idx]
    tail = rest[close_idx:]

    # Split on commas at depth zero.
    params = []
    buf = []
    depth = 0
    for ch in params_str:
        if ch == '(':
            depth += 1
            buf.append(ch)
        elif ch == ')':
            depth -= 1
            buf.append(ch)
        elif ch == ',' and depth == 0:
            params.append(''.join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        params.append(''.join(buf))

    fixed = [fix_param(p) for p in params]

    # Preserve original spacing around commas. Reconstruct with ", ".
    new_params = ', '.join(fixed)
    return f"{prefix}{new_params}{tail}"

lines = src.splitlines(keepends=True)
touched = 0
for i, line in enumerate(lines):
    stripped = line.lstrip()
    if not stripped.startswith('function '):
        continue
    new_line = fix_signature_line(line)
    if new_line != line:
        lines[i] = new_line
        touched += 1

if touched == 0:
    sys.exit(0)

iface_path.write_text(''.join(lines))
print(f"  fix-abi-data-locations: added data locations on {touched} function signature(s) in {iface_path.name}")
PY
