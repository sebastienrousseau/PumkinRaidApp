# PumkinRaidApp

[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20Web-blue.svg)](#platforms)
[![CI](https://github.com/sebastienrousseau/PumkinRaidApp/actions/workflows/swift.yml/badge.svg)](https://github.com/sebastienrousseau/PumkinRaidApp/actions)

Pumkin Raid is a pure-Swift Apple game with a Swift WebAssembly browser host and
a first-party `GameEngineLib` package. Guide a ghost through an escalating raid using
keyboard, pointer, touch, motion, or an Apple TV controller.

This repository is a modern rewrite of the original cocos2d game—not a wrapper.
The interaction benchmark is the immediacy and clarity of premium arcade games:
fast restarts, readable HUDs, fair randomness, combos, responsive feedback, and
short sessions that invite one more run.

## Highlights

- Pure-Swift reusable `GameEngineLib` for deterministic simulation, semantic input,
  replay verification, safe waves, scoring, combos, difficulty, and local rankings.
- SwiftUI navigation, SpriteKit gameplay, AVFoundation audio, Core Motion input,
  GameController support, and native AppKit keyboard event capture.
- Anti-repeat seven-lane spawn director with standard, swift, drifting, and heavy
  pumpkins; every run is unpredictable and reproducible from its seed.
- Responsive phone, tablet, desktop, TV, and ultrawide layouts with adaptive source
  artwork and normalized gameplay coordinates.
- Versioned profile progression, missions, cosmetic unlocks, and separate assisted
  and standard top-ten boards for every game mode.
- Optional Game Center leaderboards and achievements with replay-digest score context.
- First-run ghost school, pause/resume lifecycle, scalable accessibility controls,
  reduced motion, high contrast, captions, and input sensitivity.
- Swift WebAssembly Canvas host with keyboard, touch, and mouse controls, an optimized
  Vite release bundle, and real Chromium, Firefox, and WebKit movement tests.
- UTC daily streaks, replay-backed friend challenges, functional cosmetic loadouts,
  five mechanically distinct modes, and deterministic same-seed competition.
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
├── Sources/PumkinRaidApp/      Apple app, renderer, input, audio, resources
├── Package.swift               Canonical Swift package
└── project.yml                 Optional generated iOS Xcode project
```

[`GameEngineLib`](https://github.com/sebastienrousseau/GameEngineLib) is a separate
public package with no dependency on SpriteKit, SwiftUI, UIKit, or AppKit. See
[Architecture](Documentation/Architecture.md).

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

## Validation

```sh
swift format lint --strict --recursive Sources Tests
swift test
plutil -lint Sources/PumkinRaidApp/Resources/PrivacyInfo.xcprivacy
./Scripts/validate-assets.sh
```

The public `GameEngineLib` package owns deterministic rules and fuzz tests. This
repository additionally tests lifecycle, persistence migration and corruption
recovery, progression, input routing, scene resizing, Apple SDK compilation, and
browser startup/input behavior.

## Product status

The game has a professional technical foundation and a complete playable loop. It
does not claim visual parity with a large commercial title using legacy art alone.
The highest-impact missing design deliverables are listed in the
[design system](Documentation/DesignSystem.md), allowing those screens to be produced
separately without reworking the engine. Repository gates and the human release
protocol deliberately distinguish automated confidence from subjective market proof.

## Assets and license

Source code uses the zlib license in [LICENSE.txt](LICENSE.txt). Artwork and audio are
excluded from that license and originate from the existing `pumpkinraid-v2` project;
are distributed under rights confirmed by the repository owner. Their provenance and
integrity records are documented in [AssetProvenance](Documentation/AssetProvenance.md)
and [NOTICE.md](NOTICE.md).

Contributions are welcome under [CONTRIBUTING.md](CONTRIBUTING.md). Please disclose
security issues according to [SECURITY.md](SECURITY.md).
