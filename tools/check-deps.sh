#!/usr/bin/env bash
# Verifies the native + JS toolchains needed for a clean-machine build.
# Used by contributors and CI before `zig build test` / `zig build`.
set -euo pipefail

missing=0
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing: %s (%s)\n' "$1" "$2" >&2
    missing=1
  else
    printf 'found: %s\n' "$1"
  fi
}

need zig "Zig 0.16.0+ (https://ziglang.org/download)"
need node "Node.js 18+ (https://nodejs.org)"
need npm "npm (bundled with Node.js)"

case "$(uname -s 2>/dev/null || true)" in
  Linux*)
    need pkg-config "pkg-config for GTK/WebKitGTK detection (Linux)"
    if command -v pkg-config >/dev/null 2>&1; then
      for pc in gtk+-3.0 webkit2gtk-4.1; do
        if pkg-config --exists "$pc"; then
          printf 'found: %s\n' "$pc"
        else
          printf 'missing: %s (Linux: install libgtk-3-dev libwebkit2gtk-4.1-dev)\n' "$pc" >&2
          missing=1
        fi
      done
    fi
    ;;
esac

if [[ "$missing" -ne 0 ]]; then
  printf 'dependency check failed\n' >&2
  exit 1
fi
printf 'all dependencies present\n'
