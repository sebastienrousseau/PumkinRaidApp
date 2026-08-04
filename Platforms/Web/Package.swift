// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PumkinRaidWeb",
  products: [
    .executable(name: "PumkinRaidWeb", targets: ["PumkinRaidWeb"])
  ],
  dependencies: [
    .package(url: "https://github.com/sebastienrousseau/GameEngineLib.git", from: "0.2.0"),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.56.1"),
  ],
  targets: [
    .executableTarget(
      name: "PumkinRaidWeb",
      dependencies: [
        .product(name: "GameEngineLib", package: "GameEngineLib"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ]
    )
  ]
)
