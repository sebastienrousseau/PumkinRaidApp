# Release Readiness

## Automated gates

- Strict Swift formatting, release build, tests, and coverage.
- Privacy manifest and localization-key validation.
- iOS, iPadOS, tvOS, and macOS source compilation.
- Deterministic, replay, fairness, persistence, resource, layout, and soak tests.
- Optimized Wasm/Vite build with Chromium, Firefox, and WebKit interaction tests.
- Pure-Swift source enforcement.

## App Store Connect setup

The generated Xcode project contains separate iOS/iPadOS, tvOS, and macOS application
targets with Game Center entitlements. Before archives can be signed and uploaded:

1. Assign the distribution team and managed signing profiles.
2. Create the four documented Game Center leaderboards and achievements.
3. Supply final app icons, screenshots, previews, description, support URL, and age rating.
4. Run the minimum-device performance matrix and attach MetricKit evidence.
5. Record accessibility, localization, tutorial-completion, and comprehension playtests.
6. Archive each target with the release Xcode version and validate it in Organizer.

Signing, App Store records, final marketing art, and human playtest evidence are external
release inputs. Repository automation must not claim those gates are green without the
corresponding credentials and evidence.
