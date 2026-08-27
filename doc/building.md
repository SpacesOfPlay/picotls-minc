# Building

## Prerequisites

- **minc compiler** — install the toolchain from <https://minc.dev>
  onto your PATH with the one-liner in `install_minc.md`. You can
  also set `$MINC` / `$env:MINC` or drop a `minc` binary next to the
  build script.

## Commands

```
minc run                              # examples/01_https_get.mc
minc run examples/04_https_post.mc    # any .mc file
minc build my/file.mc                 # just compile
minc clean                            # remove build/
```

The build (`build.mc`, run by the minc verbs above) runs `minc` with
the dist root as cwd, drops the binary in `build/`, and runs it with
`build/` as the working directory.

## Online examples

`examples/01_https_get.mc` and `03_concurrent_https.mc` take their
target from env vars:

```
$env:TLS_HOST='www.google.com'; $env:TLS_PORT='443'; $env:TLS_SNI='www.google.com'
minc run examples/01_https_get.mc
```

```sh
TLS_HOST=www.google.com TLS_PORT=443 TLS_SNI=www.google.com minc run examples/01_https_get.mc
```

## Troubleshooting

- **`minc compiler not found`** — install minc (see
  `install_minc.md`) or put `minc(.exe)` on PATH.
- **`missing lib/picotls.mc`** — you're running `minc run` from
  outside the dist root.
- **TLS handshake fails against a public server** — see
  [crypto_coverage.md](crypto_coverage.md).
