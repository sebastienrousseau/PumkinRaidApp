// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PumkinRaidApp",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .tvOS(.v17),
  ],
  products: [
    .executable(name: "PumkinRaidApp", targets: ["PumkinRaidApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/sebastienrousseau/GameEngineLib.git", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "PumkinRaidApp",
      dependencies: [.product(name: "GameEngineLib", package: "GameEngineLib")],
      resources: [.process("Resources")]
    ),
  ]
)
