# Crypto coverage

What this dist negotiates over TLS 1.3. If it's not listed, it
won't work.

## Cipher suites

| Suite                          | Code   |     |
|--------------------------------|--------|-----|
| `TLS_AES_128_GCM_SHA256`       | 0x1301 | ✅  |
| `TLS_AES_256_GCM_SHA384`       | 0x1302 | ✅  |
| `TLS_CHACHA20_POLY1305_SHA256` | 0x1303 | ✅  |

All three are advertised by `pico_https_get`; server picks. Order
= our preference (AES-128 first, then AES-256, then ChaCha-Poly).

## Key exchange

| Algorithm | Code   |     |
|-----------|--------|-----|
| X25519    | 0x001d | ✅  |
| P-256/384/521, x448 | various | ❌  |

X25519 is preferred by every modern TLS 1.3 server, so this almost
always negotiates.

## Cert verify signature schemes

| Scheme                     | Code   |     |
|----------------------------|--------|-----|
| `ed25519`                  | 0x0807 | ✅  |
| `ecdsa_secp256r1_sha256`   | 0x0403 | ✅  |
| `rsa_pss_rsae_sha256`      | 0x0804 | ✅  |
| `rsa_pss_rsae_sha384`      | 0x0805 | ✅  |
| `rsa_pss_rsae_sha512`      | 0x0806 | ✅  |

With `verify_or_null = null` no verify happens; any cert is
accepted. For verified connections, `pico_pinned_verify_cert_cb`
handles both ECDSA-P256 and RSA leaves via a single pin — see
`examples/10`. Per-algorithm callbacks are in `examples/08`
(ECDSA) and `examples/09` (RSA).

## Hashes & AEAD

SHA-256, SHA-384, SHA-512 (cifra); BLAKE2b (monocypher).
AES-128-GCM, AES-256-GCM, ChaCha20-Poly1305 (cifra) — all
16-byte tags.

## CSPRNG

`mc_csprng_bytes` — `BCryptGenRandom` (Windows) / `getrandom`
(Linux). Both internally synchronized; thread-safe. Use this as
`ctx.random_bytes` in production.
