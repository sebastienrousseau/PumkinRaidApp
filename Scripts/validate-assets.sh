#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 -c Configuration/AssetManifest.sha256
else
  sha256sum -c Configuration/AssetManifest.sha256
fi

WEB_BYTES="$(find Platforms/Web/Web/assets -type f -exec stat -f '%z' {} + 2>/dev/null | awk '{sum += $1} END {print sum + 0}')"
if [ "$WEB_BYTES" = "0" ]; then
  WEB_BYTES="$(find Platforms/Web/Web/assets -type f -printf '%s\n' | awk '{sum += $1} END {print sum + 0}')"
fi

# Keep first-load art and audio below 3 MiB. The optimized Wasm module has its own 5 MiB gate.
if [ "$WEB_BYTES" -gt 3145728 ]; then
  echo "Web asset budget exceeded: $WEB_BYTES bytes" >&2
  exit 1
fi

echo "Asset integrity and web budget passed: $WEB_BYTES bytes"
