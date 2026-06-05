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

# Locate minc — look in tools/minc/ (local fetched-via-get_minc
# copy) first, then PATH. If neither, print install instructions
# + exit.
minc=""
if [ -x "$root/tools/minc/minc" ]; then
    minc="$root/tools/minc/minc"
fi
if [ -z "$minc" ]; then
    minc="$(command -v minc 2>/dev/null || true)"
fi
if [ -z "$minc" ]; then
    cat >&2 <<'EOF'

minc compiler not found.

Options:
  1. Auto-fetch the pinned closed-source binary (~1.7 MB):
       ./tools/get_minc.sh
     (drops a tools/minc/minc; gitignored; license at tools/minc/LICENSE.md)

  2. Install manually from
       https://github.com/SpacesOfPlay/minc-dev/releases
     and put minc on PATH.

See README.md (Prerequisites) and LICENSE.md (minc is separately licensed).
EOF
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
