// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "PumkinRaid",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .executable(name: "PumkinRaid", targets: ["PumkinRaid"]),
    .library(name: "PumkinRaidCore", targets: ["PumkinRaidCore"]),
  ],
  targets: [
    .target(name: "PumkinRaidCore"),
    .executableTarget(
      name: "PumkinRaid",
      dependencies: ["PumkinRaidCore"],
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "PumkinRaidCoreTests",
      dependencies: ["PumkinRaidCore"]
    ),
  ]
)
