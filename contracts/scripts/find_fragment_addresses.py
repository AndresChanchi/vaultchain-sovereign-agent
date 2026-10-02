#!/usr/bin/env python3
"""
Locate fragment contract addresses inside a decompressed Stylus root WASM.

Searches each address in two encodings:
  - raw 20-byte sequence
  - 32-byte left-padded (12 zero bytes + 20 address bytes)

Usage:
    find_fragment_addresses.py <wasm_path> <comma_separated_addrs>
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: find_fragment_addresses.py <wasm_path> <addrs_csv>",
              file=sys.stderr)
        return 2

    wasm_path, addrs_csv = sys.argv[1], sys.argv[2]
    with open(wasm_path, "rb") as f:
        data = f.read()

    addrs = [a.strip() for a in addrs_csv.split(",") if a.strip()]
    print(f"WASM size: {len(data)} bytes")
    print(f"Searching for {len(addrs)} fragment address(es)")
    print()

    for addr in addrs:
        raw_hex = addr[2:] if addr.startswith("0x") else addr
        raw = bytes.fromhex(raw_hex)
        padded = b"\x00" * 12 + raw

        offsets_raw = []
        start = 0
        while True:
            i = data.find(raw, start)
            if i < 0:
                break
            offsets_raw.append(i)
            start = i + 1

        offsets_padded = []
        start = 0
        while True:
            i = data.find(padded, start)
            if i < 0:
                break
            offsets_padded.append(i)
            start = i + 1

        print(f"  [0x{raw_hex.lower()}]")
        if offsets_raw:
            print(f"    raw (20B):    offsets {offsets_raw}")
        else:
            print(f"    raw (20B):    NOT FOUND")
        if offsets_padded:
            print(f"    padded (32B): offsets {offsets_padded}")
        else:
            print(f"    padded (32B): NOT FOUND")
    return 0


if __name__ == "__main__":
    sys.exit(main())
