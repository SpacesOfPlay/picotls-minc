# picotls-minc

A [minc](https://minc.dev/)-language port of
[picotls](https://github.com/h2o/picotls) (TLS 1.3) with
[cifra](https://github.com/ctz/cifra) (AEAD + hash) and
[monocypher](https://monocypher.org/) (X25519 + Ed25519). Includes
`pico_https_get` — a one-call HTTPS GET helper.

Pure minc — no C compiler, no system TLS library, no CA bundle.

## Quickstart

Windows:
```powershell
git clone https://github.com/<your-org>/picotls-minc
cd picotls-minc
./tools/get_minc.ps1     # one-time: fetch minc compiler (~1.7 MB)
./build.ps1              # runs examples/01_https_get.mc against www.google.com
```

Linux:
```sh
git clone https://github.com/<your-org>/picotls-minc
cd picotls-minc
./tools/get_minc.sh
./build.sh
```

Then pass any `.mc` path to run something else:
```
./build.ps1 examples/02_in_memory_handshake.mc   # offline TLS 1.3 handshake
```

## Hello world

```mc
import pico_https;

i32 main() {
    u8[65536] response;
    i32 n = pico_https_get(cast(u8*, "www.google.com"), 443,
                        cast(u8*, "www.google.com"), cast(u8*, "/"),
                        &response[0], 65536,
                        null, null, null);
    if n < 0 { printf("failed: %d\n", n); return 1; }
    for i32 i = 0; i < n; i++ { printf("%c", cast(i32, response[i])); }
    return 0;
}
```

Save as `hello.mc`, then `./build.ps1 hello.mc`.

## What works

- TLS 1.3, all three standard ciphersuites (AES-128-GCM,
  AES-256-GCM, ChaCha20-Poly1305), X25519 key exchange.
- Cert verify: Ed25519, ECDSA-P256, RSA-PSS — all SPKI-pinned.
- `pico_https_get` / `pico_https_request` — one-call HTTPS, IPv4 + DNS.
- `pico_https_conn_*` — HTTP/1.1 keep-alive over one handshake.
- `pico_https_serve_once` — single-connection HTTPS server.

## What doesn't

- CA-bundle chain validation. Verification is SPKI-pin based.
- IPv6, session resumption, 0-RTT, HTTP/2.

See [`doc/crypto_coverage.md`](doc/crypto_coverage.md) for the full
matrix.

## Prerequisites

- **minc compiler** — `./tools/get_minc.{ps1,sh}` fetches a pinned
  release from
  <https://github.com/SpacesOfPlay/minc-dev/releases> (SHA-256
  verified, dropped at `tools/minc/`). Or install manually and put
  on PATH.

  **`minc` is closed-source proprietary software, NOT covered by
  this repo's license.** See [`LICENSE.md`](LICENSE.md).

## See also

- [`doc/building.md`](doc/building.md) — build commands + troubleshooting
- [`doc/crypto_coverage.md`](doc/crypto_coverage.md) — what negotiates
- [`LICENSE.md`](LICENSE.md)

## Credits

picotls (c) Kazuho Oku et al. (MIT). cifra (c) Joseph Birr-Pixton
(public-domain). monocypher (c) Loup Vaillant (CC0/BSD-2). Port by
Mattias Ljungström, Spaces Of Play UG (haftungsbeschrankt). See
LICENSE.md.
