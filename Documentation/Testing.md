# Testing Strategy

## Unit coverage

CI requires 100% function coverage and 100% line coverage for both unit-test layers:

- `GameEngineLib`: every deterministic simulation, input, replay, progression,
  leaderboard, wave, and settings source file.
- `PumkinRaidApp`: application state/navigation, save migration, local leaderboard,
  and resource-loading services.

Run `./Scripts/check-coverage.sh` in either repository to reproduce the enforced
measurement. The scripts fail if either percentage drops below exactly 100.00%.

## Integration coverage

SwiftUI view builders and adapters owned by SpriteKit, GameKit, AVFoundation,
MetricKit, AppKit, and application lifecycle frameworks are not described as unit
coverage. They are validated through resolution-layout tests, packaged-resource
tests, real unsigned Apple Release builds, and Chromium/Firefox/WebKit interaction
tests. Keeping this boundary explicit prevents generated SwiftUI code from inflating
or distorting the unit-coverage metric.
