#!/usr/bin/env bash
# Post-process a Stylus-generated .sol interface to fix tuple-type
# parameters in external function signatures.
#
# WHY THIS EXISTS:
#
# Stylus SDK 0.10.9 (issue #368, audit finding M-17) renders function
# parameters of tuple type as inline tuples in the exported Solidity:
#
#   function dispatch((address, address, uint256, bytes calldata) envelope)
#       external payable returns (uint8[] memory);
#
# Solidity does not accept inline tuple types in the parameter list of
# an external function. It requires a named struct:
#
#   struct DispatchEnvelope {
#       address caller;
#       address execution_account;
#       uint256 value;
#       bytes payload;
#   }
#   function dispatch(DispatchEnvelope calldata envelope)
#       external payable returns (uint8[] memory);
#
# This script rewrites the interface in place, producing Solidity that
# `solc` accepts. The ABI selector is unchanged: Solidity computes the
# same canonical type string for both the inline tuple and the struct.
#
# USAGE:
#   scripts/fix-tuple-abi.sh <path-to-interface.sol>
#
# The script is idempotent: running it twice on an already-fixed file
# is a no-op.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <path-to-interface.sol>" >&2
    exit 2
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "error: $FILE not found" >&2
    exit 1
fi

# Detect inline tuple parameters in function signatures.
# Pattern: a '(' immediately followed by a type name and a comma,
# inside the parameter list of a 'function ...' declaration.
# We only touch signatures that start a function and end with ');'.
if ! grep -qE 'function [a-zA-Z_][a-zA-Z0-9_]*\(\([a-zA-Z]' "$FILE"; then
    exit 0
fi

python3 - "$FILE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
src = path.read_text()

# Match: function NAME((T1, T2, ... [data-location]) param_name) ...
# Capture the tuple contents and the parameter name.
pattern = re.compile(
    r'(function\s+[A-Za-z_][A-Za-z0-9_]*\s*\()'   # group 1: "function X("
    r'\(\s*'                                        # open tuple
    r'(?P<types>[^)]+?)'                            # group 2: type list
    r'\)\s+'                                        # close tuple
    r'(?P<param>[A-Za-z_][A-Za-z0-9_]*)'            # group 3: param name
    r'\s*\)'                                        # close parameter list
)

struct_name = "DispatchEnvelope"  # single known case; extend if more tuples appear

def repl(match):
    types_raw = match.group("types").strip()
    param = match.group("param")
    # Split on commas, respecting that data-location keywords ("calldata",
    # "memory", "storage") follow the type on the same comma-segment.
    parts = [p.strip() for p in types_raw.split(",")]
    fields = []
    for i, part in enumerate(parts):
        # Strip trailing data-location keyword, if present.
        tokens = part.split()
        if len(tokens) >= 2 and tokens[-1] in ("calldata", "memory", "storage"):
            typ = " ".join(tokens[:-1])
        else:
            typ = part
        fields.append((f"field_{i}", typ))

    struct_block = f"struct {struct_name} {{\n"
    for name, typ in fields:
        struct_block += f"        {typ} {name};\n"
    struct_block += "    }\n\n    "

    return struct_block + match.group(1) + f"{struct_name} calldata {param})"

new_src, n = pattern.subn(repl, src)

# Also fix any returns (...) that contain tuples (rare, same issue).
# Same pattern, anchored on "returns (".
ret_pattern = re.compile(
    r'(returns\s*\()'
    r'\(\s*(?P<types>[^)]+?)\s*\)\s*\)'
)

def ret_repl(match):
    types_raw = match.group("types").strip()
    parts = [p.strip() for p in types_raw.split(",")]
    fields = []
    for i, part in enumerate(parts):
        tokens = part.split()
        if len(tokens) >= 2 and tokens[-1] in ("calldata", "memory", "storage"):
            typ = " ".join(tokens[:-1])
        else:
            typ = part
        fields.append((f"field_{i}", typ))

    struct_name_r = "DispatchReturn"
    struct_block = f"struct {struct_name_r} {{\n"
    for name, typ in fields:
        struct_block += f"        {typ} {name};\n"
    struct_block += "    }\n\n    "
    return struct_block + match.group(1) + f"{struct_name_r} memory)"

new_src, n2 = ret_pattern.subn(ret_repl, new_src)

if n or n2:
    path.write_text(new_src)
    print(f"  fix-tuple-abi: rewrote {n + n2} tuple signature(s) in {path.name}")
PY
