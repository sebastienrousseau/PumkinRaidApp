<!-- SPDX-License-Identifier: Zlib -->

<h1 align="center">PumkinRaidApp</h1>

<p align="center">
  A pure-Swift Apple game and WebAssembly arcade experience powered by GameEngineLib.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/PumkinRaidApp/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/PumkinRaidApp/swift.yml?style=for-the-badge&logo=github" alt="Build" height="28" /></a>
  <a href="#platforms"><img src="https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20tvOS%20%7C%20macOS%20%7C%20Web-blue.svg?style=for-the-badge" alt="Platforms" height="28" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/PumkinRaidApp"><img src="https://img.shields.io/ossf-scorecard/github.com/sebastienrousseau/PumkinRaidApp?style=for-the-badge&label=OpenSSF%20Scorecard&logo=openssf" alt="OpenSSF Scorecard" height="28" /></a>
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-zlib-blue.svg?style=for-the-badge" alt="License: zlib" height="28" /></a>
  <a href="Package.swift"><img src="https://img.shields.io/badge/Swift-6.0+-93450a.svg?style=for-the-badge&logo=swift" alt="Swift 6.0+" height="28" /></a>
</p>

---

## Contents

**Getting started**

- [Overview](#overview) - high-level arcade loop and architecture
- [Platforms](#platforms) - controls and interactions per platform
- [Build and run](#build-and-run) - building for macOS, iOS, Apple TV, and HTML5

**Architecture & reference**

- [Highlights](#highlights) - key gameplay and technical capabilities
- [Repository layout](#repository-layout) - file and module structure
- [Validation](#validation) - linters, asset checks, and test suites

**Operational**

- [Development](#development) - development instructions
- [Security](#security) - reporting vulnerabilities
- [Documentation](#documentation) - reference guides
- [License and Assets](#license-and-assets) - zlib and asset notices

---

## Overview

Pumkin Raid is a pure-Swift Apple game with a Swift WebAssembly browser host and a first-party `GameEngineLib` package. Guide a ghost through an escalating raid using keyboard, pointer, touch, motion, or an Apple TV controller.

This repository is a modern rewrite of the original cocos2d game, rebuilt from scratch with clean architectural separation. The interaction benchmark is the immediacy and clarity of premium arcade games: fast restarts, readable HUDs, fair randomness, combos, responsive feedback, and short sessions that invite one more run.

---

## Highlights

- Pure-Swift reusable `GameEngineLib` for deterministic simulation, semantic input, replay verification, safe waves, scoring, combos, difficulty, and local rankings.
- SwiftUI navigation, SpriteKit gameplay, AVFoundation audio, Core Motion input, GameController support, and native AppKit keyboard event capture.
- Anti-repeat seven-lane spawn director with standard, swift, drifting, and heavy pumpkins; every run is unpredictable and reproducible from its seed.
- Responsive phone, tablet, desktop, TV, and ultrawide layouts with adaptive source artwork and normalized gameplay coordinates.
- Versioned profile progression, missions, cosmetic unlocks, and separate assisted and standard top-ten boards for every game mode.
- Optional Game Center leaderboards and achievements with replay-digest score context.
- First-run ghost school, pause/resume lifecycle, scalable accessibility controls, reduced motion, high contrast, captions, and input sensitivity.
- Swift WebAssembly Canvas host with keyboard, touch, and mouse controls, an optimized Vite release bundle, and real browser tests.
- UTC daily streaks, replay-backed friend challenges, functional cosmetic loadouts, five mechanically distinct modes, and deterministic same-seed competition.
- Swift 6 concurrency, deterministic unit tests, CI, security policy, and contributor documentation.

---

## Platforms

| Platform | Move | Attack |
| :--- | :--- | :--- |
| macOS | Arrow keys, WASD, or mouse drag | Click to boom; drag through to slice |
| iPhone / iPad | Finger drag, hardware keyboard, or tilt | Tap to boom; swipe to slice |
| Apple TV | Siri Remote D-pad or game controller | Remote/controller selection and gestures |
| HTML5 | Arrow keys, WASD, touch, or mouse | Browser interaction layer |

---

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

[`GameEngineLib`](https://github.com/sebastienrousseau/GameEngineLib) is a separate public package with no dependency on SpriteKit, SwiftUI, UIKit, or AppKit. See [Architecture](Documentation/Architecture.md).

---

## Build and run

### macOS

Open `Package.swift` with Xcode or run the CLI executable:

```bash
swift run PumkinRaidApp
```

### iPhone and iPad

The Swift package can be opened directly in Xcode. An optional generated project is also available:

```bash
brew install xcodegen
xcodegen generate
open PumkinRaidApp.xcodeproj
```

Choose a development team, then run the `PumkinRaidApp` scheme on iOS 17+.

### Apple TV

Open `Package.swift` in Xcode, select the `PumkinRaidApp` product and an Apple TV 17+ destination. The shared app source conditionally enables GameController and remote input without forking gameplay rules.

### HTML5 Web Target

The browser build runs via Swift WebAssembly and Vite:

```bash
cd Platforms/Web
npm install
npm run test:browsers
```

---

## Validation

```bash
swift format lint --strict --recursive Sources Tests
swift test
plutil -lint Sources/PumkinRaidApp/Resources/PrivacyInfo.xcprivacy
./Scripts/validate-assets.sh
```

---

## Development

Read our [Development Guide](DEVELOPMENT.md) and [Contributing Guide](CONTRIBUTING.md) for local environment setup.

---

## Security

Report vulnerabilities according to [`SECURITY.md`](SECURITY.md).

---

## Documentation

- [Architecture Guide](Documentation/Architecture.md)
- [Design System](Documentation/DesignSystem.md)
- [Web Guide](Documentation/Web.md)
- [Asset Provenance](Documentation/AssetProvenance.md)
- [Changelog](CHANGELOG.md)

---

## License and Assets

Copyright © 2026 <a href="https://sebastienrousseau.com/" rel="author">Sebastien Rousseau</a>. All rights reserved.

Source code is released under the [zlib License](LICENSE.txt). Artwork, fonts, sound effects, and music bundled under `Sources/PumkinRaidApp/Resources` are subject to the terms documented in [Asset Provenance](Documentation/AssetProvenance.md) and [NOTICE.md](NOTICE.md).
