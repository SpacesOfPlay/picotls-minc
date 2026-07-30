# build.ps1 — build (and run) a picotls-minc example.
#
# Usage:
#   ./build.ps1                          # run examples/01_https_get.mc
#   ./build.ps1 <main.mc>                # run any .mc file
#   ./build.ps1 <main.mc> -NoRun         # just compile, don't run
#
# Examples:
#   ./build.ps1 examples/02_in_memory_handshake.mc
#   ./build.ps1 hello.mc
#
# Your `main.mc` just writes:
#
#   import pico_https;   # or `import picotls;` for the low-level TLS API
#   i32 main() { ... pico_https_get(...) ... }
#
# This script locates the minc compiler, drops the exe in `build/`,
# and runs it. Picotls examples are single .mc files (no per-example
# asset directories like raylib has), so we accept a file path
# directly — no main.mc convention.

param(
    [Parameter(Position=0)]
    [string]$Source,
    [switch]$NoRun
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Locate minc: $env:MINC (install dir, or a direct binary path),
# then PATH, then next to this script.
$minc = $env:MINC
if ($minc -and (Test-Path $minc -PathType Container)) { $minc = Join-Path $minc 'minc.exe' }
if (-not $minc) {
    $minc = (Get-Command minc.exe -ErrorAction SilentlyContinue).Source
}
if (-not $minc) { $minc = Join-Path $root 'minc.exe' }
if (-not (Test-Path $minc)) {
    Write-Host ''
    Write-Host 'minc compiler not found.' -ForegroundColor Red
    Write-Host 'Install it:  powershell -c "irm minc.dev/install.ps1 | iex"'
    Write-Host 'or set $env:MINC (see install_minc.md).'
    Write-Host 'See README.md.'
    exit 1
}

# No argument → run the HTTPS GET example. Reaches out to
# www.google.com:443 (override with TLS_HOST / TLS_PORT / TLS_SNI).
if (-not $Source) {
    $Source = "examples\01_https_get.mc"
    Write-Host "no source given — running default example: $Source"
    Write-Host "  other examples:"
    Get-ChildItem (Join-Path $root 'examples') -Filter *.mc |
        Where-Object { $_.Name -ne '01_https_get.mc' } |
        ForEach-Object { Write-Host "    ./build.ps1 examples/$($_.Name)" }
    Write-Host ""
}

$src = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $root $Source }
if (-not (Test-Path $src)) {
    Write-Error "source file not found: $src"
    exit 1
}

$libDir = Join-Path $root 'lib'
if (-not (Test-Path (Join-Path $libDir 'picotls.mc'))) {
    Write-Error "missing $libDir\picotls.mc — dist is corrupt"; exit 1
}

$name     = [System.IO.Path]::GetFileNameWithoutExtension($src)
$buildDir = Join-Path $root 'build'
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }
$exe = Join-Path $buildDir "$name.exe"

# Run minc with the dist root as CWD so `import picotls;` resolves to
# the lib/picotls.mc router.
Write-Host "compiling $name..."
Push-Location $root
try {
    & $minc $src -o $exe
    if ($LASTEXITCODE -ne 0) {
        Write-Error "minc compile failed."
        exit $LASTEXITCODE
    }
} finally { Pop-Location }

Write-Host "built $exe"

if (-not $NoRun) {
    Write-Host "running..."
    Push-Location $buildDir
    try {
        & $exe
        exit $LASTEXITCODE
    } finally { Pop-Location }
}
