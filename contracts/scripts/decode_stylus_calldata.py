#!/usr/bin/env python3
"""
Extract the init code from a StylusDeployer.deploy transaction calldata.

The deploy tx does NOT carry the init code as raw bytes. It calls the
StylusDeployer contract and passes the init code ABI-encoded as the
first `bytes` parameter. This script decodes that ABI and writes the
extracted init code as a hex string.

Usage:
    decode_stylus_calldata.py <raw_calldata_hex_file> <out_initcode_hex_file>

Input:  file with the raw calldata as hex (with or without 0x prefix).
Output: file with the extracted init code as hex (no 0x prefix).
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: decode_stylus_calldata.py <raw_hex_in> <initcode_hex_out>",
              file=sys.stderr)
        return 2

    raw_path, out_path = sys.argv[1], sys.argv[2]
    with open(raw_path, "r") as f:
        hex_str = f.read().strip()
    if hex_str.startswith("0x"):
        hex_str = hex_str[2:]
    data = bytes.fromhex(hex_str)

    if len(data) < 4:
        print("error: calldata too short (< 4 bytes)", file=sys.stderr)
        return 1

    # args start after the 4-byte selector
    args = data[4:]
    if len(args) < 32:
        print("error: no ABI args after selector", file=sys.stderr)
        return 1

    offset = int.from_bytes(args[0:32], "big")
    if len(args) < offset + 32:
        print(f"error: offset {offset} out of bounds", file=sys.stderr)
        return 1

    length = int.from_bytes(args[offset:offset + 32], "big")
    if len(args) < offset + 32 + length:
        print(f"error: length {length} at offset {offset} out of bounds",
              file=sys.stderr)
        return 1

    init_code = args[offset + 32:offset + 32 + length]
    with open(out_path, "w") as f:
        f.write(init_code.hex())

    print(f"Decoded init code: {len(init_code)} bytes", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
