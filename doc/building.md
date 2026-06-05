# Building

## Prerequisites

- **minc compiler** — run `./tools/get_minc.ps1` (Windows) or
  `./tools/get_minc.sh` (Linux). Or install manually from
  <https://github.com/SpacesOfPlay/minc-dev/releases> and put on PATH.
- A POSIX shell (Linux/macOS) or PowerShell 5+ (Windows).

## Commands

```
./build.ps1                          # examples/01_https_get.mc
./build.ps1 examples/04_https_post.mc # any .mc file
./build.ps1 my/file.mc -NoRun        # just compile
```

On Linux: `./build.sh`, `--no-run`. The build script runs `minc`
with the dist root as cwd, drops the binary in `build/`, and runs it.

## Online examples

`examples/01_https_get.mc` and `03_concurrent_https.mc` take their
target from env vars:

```
$env:TLS_HOST='www.google.com'; $env:TLS_PORT='443'; $env:TLS_SNI='www.google.com'
./build.ps1 examples/01_https_get.mc
```

```sh
TLS_HOST=www.google.com TLS_PORT=443 TLS_SNI=www.google.com ./build.sh examples/01_https_get.mc
```

## Troubleshooting

- **`minc compiler not found`** — run `./tools/get_minc.{ps1,sh}` or
  put `minc(.exe)` on PATH.
- **`missing lib/picotls.mc`** — you're running `build.ps1` from
  outside the dist root.
- **TLS handshake fails against a public server** — see
  [crypto_coverage.md](crypto_coverage.md).
