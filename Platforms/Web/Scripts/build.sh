#!/bin/sh
set -eu

SDK_ID="${SWIFT_WASM_SDK:-swift-6.3.3-RELEASE_wasm}"
PUMKIN_SWIFT="${PUMKIN_SWIFT:-swift}"
"$PUMKIN_SWIFT" package --disable-sandbox --swift-sdk "$SDK_ID" js --product PumkinRaidWeb -c release

OUTPUT=".build/plugins/PackageToJS/outputs/Package"
npm ci --no-audit --no-fund
npx vite build Web --outDir ../dist --emptyOutDir

echo "Web release ready at dist/index.html (Swift package: $OUTPUT)"
