//! Compile-time construction of the Kipio Account fragmented root init code.
//!
//! WHY THIS EXISTS
//! ---------------
//! `kipio_account` compresses to ~57 KB, exceeding the 24 KB single-fragment
//! limit of Arbitrum Stylus. `cargo stylus deploy` therefore splits it into 3
//! fragment contracts plus a small root contract that references them by
//! address.
//!
//! `cargo stylus get-initcode` refuses to produce the init code of a
//! fragmented contract:
//!
//!     error: fragmented contracts not currently supported for
//!            initcode retrieval
//!
//! The Gateway still needs that init code as a `const &[u8]` for two
//! purposes:
//!   - predict the CREATE2 address of a user's account (hash of init code)
//!   - deploy that account with `RawDeploy` (raw `create2` host call)
//!
//! So we reconstruct the init code at build time from a fixed template plus
//! the 3 fragment addresses captured at deploy time.
//!
//! CONFIRMED LAYOUT (verified against a real Sepolia deploy, 2026-10-01)
//! --------------------------------------------------------------------
//!   [0..42)    EVM prelude (42 bytes):
//!                0x7f <runtime_len u32 BE, left-padded to 32 bytes>
//!                0x80 0x60 0x2b 0x60 0x00 0x39 0x60 0x00 0xf3
//!   [42]       Stylus init code version byte (0x00)
//!   [43..47)   Stylus header: 0xEF 0xF0 0x02 0x00 (fragmented)
//!   [47..51)   decompressed WASM size (u32 BE)
//!   [51..71)   fragment 0 address (20 bytes, raw)
//!   [71..91)   fragment 1 address (20 bytes, raw)
//!   [91..111)  fragment 2 address (20 bytes, raw)
//!
//! The prelude's `runtime_len` field equals the number of bytes the EVM
//! will RETURN: header (4) + payload (4 + N*20) = 68 for 3 fragments.
//! The version byte at [42] is NOT part of the returned runtime.
//!
//! WHAT IT WRITES
//! --------------
//! `$OUT_DIR/kipio_account_init.bin` — the raw bytes above.
//!
//! Consumed by `src/internal/deploy.rs`:
//!     include_bytes!(concat!(env!("OUT_DIR"), "/kipio_account_init.bin"))
//!
//! CONFIG FILE
//! -----------
//! `fragments.toml`, sibling of this script. If absent, writes an empty
//! file so that unit tests build without a real deployment.

use std::env;
use std::fs;
use std::path::PathBuf;

/// Size in bytes of the EVM prelude that precedes the version byte.
const PRELUDE_LEN: usize = 42;

/// Stylus init code version byte. 0x00 for both single and fragmented.
const VERSION_BYTE: u8 = 0x00;

/// Stylus header for fragmented contracts. The `02` distinguishes this
/// from the single-fragment header (0xEFF00000).
const FRAGMENTED_HEADER: [u8; 4] = [0xEF, 0xF0, 0x02, 0x00];

/// Number of fragments expected for kipio_account v1.
const FRAGMENT_COUNT: usize = 3;

/// Shape of the parsed config.
#[derive(Debug)]
struct FragmentConfig {
    decompressed_size: u32,
    addresses: Vec<[u8; 20]>,
}

fn main() {
    // Re-run only when the config or this script changes.
    println!("cargo:rerun-if-changed=fragments.toml");
    println!("cargo:rerun-if-changed=build.rs");

    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR not set"));
    let out_file = out_dir.join("kipio_account_init.bin");

    let config_path = PathBuf::from("fragments.toml");
    if !config_path.exists() {
        // No config → write empty file. `production_build` gates the
        // actual use; without it, ACCOUNT_INIT_CODE is `&[]`.
        fs::write(&out_file, &[]).expect("failed to write empty init code");
        println!(
            "cargo:warning=fragments.toml not found; kipio_account_init.bin written empty"
        );
        return;
    }

    let text = fs::read_to_string(&config_path).expect("failed to read fragments.toml");
    let config = parse_config(&text).expect("invalid fragments.toml");
    let init_code = build_init_code(&config);
    fs::write(&out_file, &init_code).expect("failed to write init code");

    println!(
        "cargo:warning=kipio_account_init.bin: {} bytes ({} fragments, decompressed_size={})",
        init_code.len(),
        config.addresses.len(),
        config.decompressed_size,
    );
}

/// Parses the minimal TOML shape used by fragments.toml.
///
///     decompressed_size = <u32>
///
///     [addresses]
///     fragment_0 = "0x<40 hex>"
///     fragment_1 = "0x<40 hex>"
///     fragment_2 = "0x<40 hex>"
///
/// Comments (starting with `#`) and blank lines are ignored. No external
/// TOML crate is pulled in — the shape is fixed and tiny.
fn parse_config(text: &str) -> Result<FragmentConfig, String> {
    let mut decompressed_size: Option<u32> = None;
    let mut addresses: Vec<[u8; 20]> = Vec::new();
    let mut in_addresses = false;

    for (idx, raw_line) in text.lines().enumerate() {
        let lineno = idx + 1;
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') {
            in_addresses = line == "[addresses]";
            continue;
        }
        let (key, value) = line
            .split_once('=')
            .ok_or_else(|| format!("line {}: not a key=value", lineno))?;
        let key = key.trim();
        let value = value.trim();

        if key == "decompressed_size" {
            let n: u32 = value
                .parse()
                .map_err(|e| format!("line {}: invalid decompressed_size: {}", lineno, e))?;
            decompressed_size = Some(n);
        } else if in_addresses && key.starts_with("fragment_") {
            let hex = value
                .trim_matches('"')
                .strip_prefix("0x")
                .ok_or_else(|| format!("line {}: address must start with 0x", lineno))?;
            if hex.len() != 40 {
                return Err(format!(
                    "line {}: address must be 40 hex chars, got {}",
                    lineno,
                    hex.len()
                ));
            }
            let bytes =
                hex_to_bytes(hex).map_err(|e| format!("line {}: {}", lineno, e))?;
            let mut addr = [0u8; 20];
            addr.copy_from_slice(&bytes);
            addresses.push(addr);
        }
    }

    let decompressed_size =
        decompressed_size.ok_or_else(|| "missing decompressed_size".to_string())?;

    if addresses.len() != FRAGMENT_COUNT {
        return Err(format!(
            "expected {} fragment addresses, got {}",
            FRAGMENT_COUNT,
            addresses.len()
        ));
    }

    Ok(FragmentConfig {
        decompressed_size,
        addresses,
    })
}

fn hex_to_bytes(hex: &str) -> Result<Vec<u8>, String> {
    if hex.len() % 2 != 0 {
        return Err("odd number of hex chars".into());
    }
    let bytes = hex.as_bytes();
    let mut out = Vec::with_capacity(bytes.len() / 2);
    for i in (0..bytes.len()).step_by(2) {
        let hi = hex_nibble(bytes[i])?;
        let lo = hex_nibble(bytes[i + 1])?;
        out.push((hi << 4) | lo);
    }
    Ok(out)
}

fn hex_nibble(b: u8) -> Result<u8, String> {
    match b {
        b'0'..=b'9' => Ok(b - b'0'),
        b'a'..=b'f' => Ok(b - b'a' + 10),
        b'A'..=b'F' => Ok(b - b'A' + 10),
        _ => Err(format!("invalid hex char: {}", b as char)),
    }
}

fn build_init_code(config: &FragmentConfig) -> Vec<u8> {
    // Runtime portion (what the EVM will RETURN):
    //   header (4) + decompressed_size (4) + N * 20 (addresses)
    let payload_len = 4 + config.addresses.len() * 20;
    let runtime_len = FRAGMENTED_HEADER.len() + payload_len;
    let runtime_len_u32 = runtime_len as u32;

    let mut out = Vec::with_capacity(PRELUDE_LEN + 1 + runtime_len);

    // --- EVM prelude (42 bytes) ---
    // 0x7f PUSH32 <runtime_len u32 BE, left-padded to 32 bytes>
    out.push(0x7f);
    let mut len_be = [0u8; 32];
    len_be[28..32].copy_from_slice(&runtime_len_u32.to_be_bytes());
    out.extend_from_slice(&len_be);
    // 0x80 DUP1
    out.push(0x80);
    // 0x60 0x2b PUSH1 0x2b  (CODECOPY src offset = byte 43)
    out.extend_from_slice(&[0x60, 0x2b]);
    // 0x60 0x00 PUSH1 0x00  (CODECOPY dst offset = 0)
    out.extend_from_slice(&[0x60, 0x00]);
    // 0x39 CODECOPY
    out.push(0x39);
    // 0x60 0x00 PUSH1 0x00  (RETURN offset = 0)
    out.extend_from_slice(&[0x60, 0x00]);
    // 0xf3 RETURN
    out.push(0xf3);

    debug_assert_eq!(out.len(), PRELUDE_LEN);

    // --- Version byte (1 byte) ---
    out.push(VERSION_BYTE);

    // --- Stylus header (4 bytes) ---
    out.extend_from_slice(&FRAGMENTED_HEADER);

    // --- Payload: decompressed_size + fragment addresses ---
    out.extend_from_slice(&config.decompressed_size.to_be_bytes());
    for addr in &config.addresses {
        out.extend_from_slice(addr);
    }

    debug_assert_eq!(out.len(), PRELUDE_LEN + 1 + runtime_len);
    out
}
