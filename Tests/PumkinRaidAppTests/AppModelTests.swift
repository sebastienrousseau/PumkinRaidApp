import GameEngineLib
import XCTest
@testable import PumkinRaidApp

@MainActor
final class AppModelTests: XCTestCase {
  private func makeDefaults() -> UserDefaults {
    let suite = "PumkinRaidAppTests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
  }

  func testDefaultsToStartScreenAndDefaultSettings() {
    let model = AppModel(defaults: makeDefaults())
    XCTAssertEqual(model.settings, GameSettings())
    if case .start = model.screen {} else { XCTFail("Expected start screen") }
  }

  func testSettingsPersistAcrossModels() {
    let defaults = makeDefaults()
    let first = AppModel(defaults: defaults)
    first.settings.musicEnabled = false
    first.settings.effectsEnabled = false
    let restored = AppModel(defaults: defaults)
    XCTAssertFalse(restored.settings.musicEnabled)
    XCTAssertFalse(restored.settings.effectsEnabled)
  }

  func testFinishedRunsAreRankedAndPersisted() {
    let defaults = makeDefaults()
    let model = AppModel(defaults: defaults)
    model.finishGame(score: 100)
    model.finishGame(score: 900)
    XCTAssertEqual(model.leaderboard.entries.map(\.score), [900, 100])
    XCTAssertEqual(AppModel(defaults: defaults).leaderboard.entries.map(\.score), [900, 100])
  }
}
