# HTML5 / WebAssembly

The web host runs game rules and its frame loop in Swift. JavaScriptKit is used only
as the browser bridge.

Requirements: Swift 6.2 or newer and the matching `wasm32-unknown-wasi` Swift SDK.

```sh
cd Platforms/Web
./Scripts/build.sh
```

The script builds an optimized Wasm bundle, resolves the pinned browser shim, and
uses Vite to produce a self-contained `dist` directory. Serve `dist` over HTTP;
browsers do not load WebAssembly correctly from `file://` URLs.

On macOS, the cross-compilation host must be the open-source Swift.org toolchain,
not Xcode's bundled compiler. Swiftly and the Wasm SDK must have matching versions.
