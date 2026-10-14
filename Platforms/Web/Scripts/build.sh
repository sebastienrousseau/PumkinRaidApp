#!/bin/sh
set -eu

SDK_ID="${SWIFT_WASM_SDK:-swift-6.4.0-RELEASE_wasm}"
PUMKIN_SWIFT="${PUMKIN_SWIFT:-swift}"
"$PUMKIN_SWIFT" package --disable-sandbox --swift-sdk "$SDK_ID" js --product PumkinRaidWeb -c release

OUTPUT=".build/plugins/PackageToJS/outputs/Package"
node Scripts/ensure-wasi-shim.mjs "$OUTPUT"

if command -v wasm-opt >/dev/null 2>&1; then
  echo "Optimizing WebAssembly binary with wasm-opt (-Oz --strip-debug --strip-producers)..."
  wasm-opt -Oz --strip-debug --strip-producers "$OUTPUT/PumkinRaidWeb.wasm" -o "$OUTPUT/PumkinRaidWeb.wasm"
fi

npm install --no-audit --no-fund
npx vite build Web --outDir ../dist --base ./ --emptyOutDir

echo "Web release ready at dist/index.html (Swift package: $OUTPUT)"
