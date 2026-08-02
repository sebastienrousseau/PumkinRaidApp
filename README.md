# PumkinRaid

A pure-Swift revival of the original PumpkinRaid cocos2d game. The app uses SwiftUI for navigation and settings, SpriteKit for gameplay, Core Motion for tilt control, and AVFoundation for audio. It has no third-party dependencies and contains no C, C++, or Objective-C source.

## Gameplay

- Drag or tilt the phantom to dodge falling pumpkins and collect sweets.
- Tap a pumpkin to spend a boom and destroy it.
- Swipe through a pumpkin to spend a slice and destroy it.
- Avoided pumpkins award 5 points; destroyed pumpkins award 10 points.
- Sweets award 500, 750, or 1,000 points.
- Every 10,000 points grants an extra life.

### Controls

| Platform | Move | Boom | Slice |
| --- | --- | --- | --- |
| macOS | Arrow keys, WASD, or drag | Click a pumpkin | Drag through a pumpkin |
| iPhone/iPad | Tilt or drag | Tap a pumpkin | Swipe through a pumpkin |

The original artwork and sounds are reused from `pumpkinraid-v2`; the game logic was rewritten in Swift rather than wrapping the old cocos2d implementation.

## Architecture

- `PumkinRaidCore` contains deterministic scoring, lives, inventory, and recharge rules with no UI dependencies.
- `PumkinRaid` uses SwiftUI for app navigation and settings, SpriteKit for the game loop, AVFoundation for audio, and Core Motion on iOS.
- Settings and high scores persist through `UserDefaults`.
- The macOS app supports keyboard, mouse, audio lifecycle cleanup, and quit-on-last-window-close behavior.
- The iOS project includes a complete app icon, portrait configuration, touch controls, tilt controls, and haptic feedback.

## Quality checks

The repository includes unit coverage for scoring, inventories, extra lives, invalid bonuses, recharge bounds, and game-over behavior. GitHub Actions builds and tests every push and pull request on macOS.

## Run

For iPhone or iPad, generate the dependency-free Xcode project from the checked-in `project.yml`, then open it:

```sh
brew install xcodegen # only when XcodeGen is not already installed
xcodegen generate
open PumkinRaid.xcodeproj
```

Select your development team in Signing & Capabilities, then run the `PumkinRaid` scheme on an iOS 17+ device or simulator.

The Swift package also provides a macOS build. Open `Package.swift` in Xcode or run:

```sh
swift run
```

Run the cross-platform rules tests with:

```sh
swift test
```

## Assets

The bundled artwork and audio originate from the existing `pumpkinraid-v2` project. Confirm distribution rights for those assets before publishing this repository or shipping the app; see [`NOTICE.md`](NOTICE.md).
