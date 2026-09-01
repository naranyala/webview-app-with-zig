#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT_DIR/zig-out/bin/webview-app"

if ! command -v zig >/dev/null 2>&1; then
  printf 'error: Zig is required but was not found in PATH\n' >&2
  exit 1
fi

printf 'Building webview-app...\n'
cd "$ROOT_DIR"
zig build

if [[ ! -x "$APP" ]]; then
  printf 'error: build succeeded but executable was not found at %s\n' "$APP" >&2
  exit 1
fi

printf 'Launching webview-app...\n'
exec "$APP" "$@"
