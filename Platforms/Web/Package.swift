// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PumkinRaidWeb",
  products: [
    .executable(name: "PumkinRaidWeb", targets: ["PumkinRaidWeb"])
  ],
  dependencies: [
    .package(path: "../.."),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.56.1"),
  ],
  targets: [
    .executableTarget(
      name: "PumkinRaidWeb",
      dependencies: [
        .product(name: "GameEngineLib", package: "PumkinRaidApp"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
      ]
    )
  ]
)
