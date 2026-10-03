#!/usr/bin/env python3
"""
Decode the 64-byte fragment table embedded in a fragmented Stylus
root contract's init code payload.

Layout (confirmed empirically on 2026-10-01):
    [0..4)    decompressed_wasm_size (uint32 big-endian)
    [4..24)   fragment 0 address (20 bytes raw)
    [24..44)  fragment 1 address (20 bytes raw)
    [44..64)  fragment 2 address (20 bytes raw)

The number of fragments is inferred as (len(data) - 4) / 20.

Usage:
    decode_fragment_table.py <payload_bin>
"""
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: decode_fragment_table.py <payload_bin>", file=sys.stderr)
        return 2

    with open(sys.argv[1], "rb") as f:
        data = f.read()

    print(f"Payload size: {len(data)} bytes")
    print()

    if len(data) < 4:
        print("ERROR: too short to contain size header", file=sys.stderr)
        return 1

    size = int.from_bytes(data[0:4], "big")
    print(f"[0..4)   decompressed_wasm_size = {size} (0x{size:08x})")

    rest = len(data) - 4
    if rest % 20 != 0:
        print(f"WARN: (len - 4) = {rest} is not a multiple of 20")
    n = rest // 20
    print(f"          fragment count (inferred) = {n}")
    print()

    for i in range(n):
        off = 4 + i * 20
        addr = data[off:off + 20]
        print(f"[{off:>3}..{off + 20:>3}) fragment {i} = 0x{addr.hex()}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
