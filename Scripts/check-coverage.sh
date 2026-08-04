#!/bin/sh
set -eu

swift test --enable-code-coverage

BIN_PATH="$(swift build --show-bin-path)"
PROFILE="$BIN_PATH/codecov/default.profdata"
TEST_BINARY="$BIN_PATH/PumkinRaidAppPackageTests.xctest/Contents/MacOS/PumkinRaidAppPackageTests"

# Unit coverage intentionally measures deterministic application services. SwiftUI
# view builders and OS-owned SpriteKit, Game Center, audio, input, and lifecycle
# adapters are exercised by the platform build and browser/integration matrix.
IGNORE='(Tests|\.build|GameEngineLib|AudioManager\.swift|GameCenterService\.swift|GameScene\.swift|GameSceneView\.swift|KeyboardState\.swift|MacAppDelegate\.swift|PerformanceMonitor\.swift|PumkinRaidApp\.swift|RootView\.swift|UI/)'
REPORT="$(
  xcrun llvm-cov report "$TEST_BINARY" \
    -instr-profile="$PROFILE" \
    -ignore-filename-regex="$IGNORE"
)"
printf '%s\n' "$REPORT"

TOTAL="$(printf '%s\n' "$REPORT" | awk '/^TOTAL/{print $0}')"
FUNCTION_COVERAGE="$(printf '%s\n' "$TOTAL" | awk '{print $7}')"
LINE_COVERAGE="$(printf '%s\n' "$TOTAL" | awk '{print $10}')"

if [ "$FUNCTION_COVERAGE" != "100.00%" ] || [ "$LINE_COVERAGE" != "100.00%" ]; then
  echo "Coverage gate failed: functions=$FUNCTION_COVERAGE lines=$LINE_COVERAGE" >&2
  exit 1
fi

echo "Coverage gate passed: functions=100.00% lines=100.00%"
