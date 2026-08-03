# PumkinRaidApp

[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20Web-blue.svg)](#platforms)
[![CI](https://github.com/sebastienrousseau/PumkinRaidApp/actions/workflows/swift.yml/badge.svg)](https://github.com/sebastienrousseau/PumkinRaidApp/actions)

Pumkin Raid is a dependency-free Apple game written in Swift, with a Swift
WebAssembly browser host. Guide a ghost through an escalating pumpkin raid using
keyboard, pointer, touch, motion, or an Apple TV controller.

This repository is a modern rewrite of the original cocos2d game—not a wrapper.
The interaction benchmark is the immediacy and clarity of premium arcade games:
fast restarts, readable HUDs, fair randomness, combos, responsive feedback, and
short sessions that invite one more run.

## Highlights

- Pure-Swift reusable `GameEngineLib` for scoring, inventory, combos, seeded random
  spawning, difficulty, and local rankings.
- SwiftUI navigation, SpriteKit gameplay, AVFoundation audio, Core Motion input,
  GameController support, and native AppKit keyboard event capture.
- Anti-repeat seven-lane spawn director with standard, swift, drifting, and heavy
  pumpkins; every run is unpredictable and reproducible from its seed.
- Responsive phone, tablet, desktop, TV, and ultrawide layouts with adaptive source
  artwork and normalized gameplay coordinates.
- Persistent top-ten local leaderboard with stable ranking and current-run emphasis.
- Swift WebAssembly Canvas host with keyboard, touch, and mouse controls.
- Swift 6 concurrency, deterministic unit tests, CI, security policy, and contributor
  documentation.

## Platforms

| Platform | Move | Attack |
| --- | --- | --- |
| macOS | Arrow keys, WASD, or mouse drag | Click to boom; drag through to slice |
| iPhone/iPad | Finger drag, hardware keyboard, or tilt | Tap to boom; swipe to slice |
| Apple TV | Siri Remote D-pad or game controller | Remote/controller selection and gestures |
| HTML5 | Arrow keys, WASD, touch, or mouse | Browser interaction layer |

## Repository layout

```text
PumkinRaidApp/
├── .github/workflows/          Continuous integration
├── Documentation/              Architecture, design, and web guides
├── Platforms/Web/              Swift WebAssembly browser executable
├── Sources/GameEngineLib/      Reusable platform-neutral game engine
├── Sources/PumkinRaidApp/      Apple app, renderer, input, audio, resources
├── Tests/GameEngineLibTests/   Deterministic rules and simulation tests
├── Package.swift               Canonical Swift package
└── project.yml                 Optional generated iOS Xcode project
```

`GameEngineLib` is a public library product and has no dependency on SpriteKit,
SwiftUI, UIKit, or AppKit. See [Architecture](Documentation/Architecture.md).

## Build and run

### macOS

Open `Package.swift` with a current Xcode installation and run the
`PumkinRaidApp` executable, or:

```sh
swift run PumkinRaidApp
```

### iPhone and iPad

The Swift package can be opened directly in Xcode. An optional generated project is
also available:

```sh
brew install xcodegen
xcodegen generate
open PumkinRaidApp.xcodeproj
```

Choose a development team, then run the `PumkinRaidApp` scheme on iOS 17+.

### Apple TV

Open `Package.swift` in Xcode, select the `PumkinRaidApp` product and an Apple TV
17+ destination. The shared app source conditionally enables GameController and
remote input without forking gameplay rules.

### HTML5

The browser build requires Swift 6.2 or newer and its matching WebAssembly SDK. Follow the
[web build guide](Documentation/Web.md).

## Testing

```sh
swift test
```

Tests cover scoring and inventory boundaries, game-over safety, deterministic spawn
runs, safe position bounds, combo windows, extra lives, and leaderboard ordering.

## Product status

The game has a professional technical foundation and a complete playable loop. It
does not claim visual parity with a large commercial title using legacy art alone.
The highest-impact missing design deliverables are listed in the
[design system](Documentation/DesignSystem.md), allowing those screens to be produced
separately without reworking the engine.

## Assets and license

Source code uses the zlib license in [LICENSE.txt](LICENSE.txt). Artwork and audio are
excluded from that license and originate from the existing `pumpkinraid-v2` project;
confirm distribution rights before publishing or shipping them. See [NOTICE.md](NOTICE.md).

Contributions are welcome under [CONTRIBUTING.md](CONTRIBUTING.md). Please disclose
security issues according to [SECURITY.md](SECURITY.md).
