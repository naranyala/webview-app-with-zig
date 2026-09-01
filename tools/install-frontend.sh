#!/usr/bin/env bash
set -euo pipefail

if npm ci --no-bin-links; then
  exit 0
fi

printf 'warning: npm ci failed; retrying with npm install\n' >&2
rm -rf node_modules
npm install --no-bin-links
