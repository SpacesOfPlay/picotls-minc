#!/usr/bin/env bash
# build.sh — build (and run) a picotls-minc example on Linux/macOS.
#
# Usage:
#   ./build.sh                           # run examples/01_https_get.mc
#   ./build.sh <main.mc>                 # run any .mc file
#   ./build.sh <main.mc> --no-run        # just compile, don't run
#
# Your `main.mc` just writes:
#
#   import pico_https;   # or `import picotls;` for the low-level TLS API
#   i32 main() { ... pico_https_get(...) ... }
#
# Script locates minc, runs it from the dist root (so `import picotls;`
# resolves), drops the binary in `build/`, and runs the result.

set -e

root="$(cd "$(dirname "$0")" && pwd)"

# minc: $MINC override (install dir, or a direct binary path), else
# PATH (installed toolchain), else next
# to this script (manual zip layout). Install from https://minc.dev.
if [ -n "${MINC:-}" ]; then
    if [ -d "$MINC" ]; then minc="$MINC/minc"; else minc="$MINC"; fi
elif command -v minc >/dev/null 2>&1; then
    minc="$(command -v minc)"
else
    minc="$root/minc"
fi
if [ ! -x "$minc" ]; then
    echo "minc compiler not found. Install it:" >&2
    echo "  curl -fsSL https://minc.dev/install | bash" >&2
    echo "or set MINC (see install_minc.md)." >&2
    exit 1
fi

# No argument → run the HTTPS GET example. Reaches out to
# www.google.com:443 (override with TLS_HOST / TLS_PORT / TLS_SNI).
if [ $# -lt 1 ]; then
    src_rel="examples/01_https_get.mc"
    echo "no source given — running default example: $src_rel"
    echo "  other examples:"
    for f in "$root/examples"/*.mc; do
        name="$(basename "$f")"
        if [ "$name" != "01_https_get.mc" ]; then
            echo "    ./build.sh examples/$name"
        fi
    done
    echo
    src="$root/$src_rel"
    no_run=0
else
    src="$1"
    no_run=0
    if [ "${2:-}" = "--no-run" ]; then no_run=1; fi
    case "$src" in
        /*) ;;
        *)  src="$root/$src" ;;
    esac
fi

if [ ! -f "$src" ]; then
    echo "source file not found: $src" >&2
    exit 1
fi

lib_dir="$root/lib"
[ -f "$lib_dir/picotls.mc" ] || { echo "missing $lib_dir/picotls.mc — dist is corrupt" >&2; exit 1; }

name="$(basename "${src%.*}")"
build_dir="$root/build"
mkdir -p "$build_dir"
exe="$build_dir/$name"

echo "compiling $name..."
(cd "$root" && "$minc" "$src" -o "$exe")

echo "built $exe"

if [ "$no_run" -eq 0 ]; then
    echo "running..."
    (cd "$build_dir" && "$exe")
fi
