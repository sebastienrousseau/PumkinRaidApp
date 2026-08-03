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
    .library(name: "GameEngineLib", targets: ["GameEngineLib"]),
  ],
  targets: [
    .target(name: "GameEngineLib"),
    .executableTarget(
      name: "PumkinRaidApp",
      dependencies: ["GameEngineLib"],
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "GameEngineLibTests",
      dependencies: ["GameEngineLib"]
    ),
  ]
)
