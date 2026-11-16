#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/mobile/ios/NEPKorea/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
# Build the iOS icon from the existing approved NEP logo.
sips -z 1024 1024 "$ROOT/icons/nep-v29-512.png" --out "$OUT" >/dev/null
