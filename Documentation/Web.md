# HTML5 / WebAssembly

The web host runs game rules and its frame loop in Swift. JavaScriptKit is used only
as the browser bridge.

Requirements: Swift 6.2 or newer and the matching `wasm32-unknown-wasi` Swift SDK.

```sh
cd Platforms/Web
swift package js --product PumkinRaidWeb
```

Use `Web/index.html` as the custom page and copy `Web/styles.css` beside the generated
bundle. Serve the output over HTTP; browsers do not load WebAssembly correctly from
`file://` URLs.
