import GameEngineLib
import XCTest

@testable import PumkinRaidApp

@MainActor
final class AppModelTests: XCTestCase {
  private final class ScoreSubmitterSpy: CompetitiveScoreSubmitting {
    var summaries: [RunSummary] = []
    func submit(_ summary: RunSummary) { summaries.append(summary) }
  }

  private func makeDefaults() -> UserDefaults {
    let suite = "PumkinRaidAppTests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
  }

  private func makeModel(defaults: UserDefaults? = nil) -> AppModel {
    AppModel(defaults: defaults ?? makeDefaults(), scoreSubmitter: ScoreSubmitterSpy())
  }

  func testDefaultsToStartScreenAndDefaultSettings() {
    let model = makeModel()
    XCTAssertEqual(model.settings, GameSettings())
    if case .start = model.screen {} else { XCTFail("Expected start screen") }
  }

  func testFirstPlayPresentsTutorialThenRemembersCompletion() {
    let defaults = makeDefaults()
    let model = makeModel(defaults: defaults)
    model.beginPlayFlow()
    if case .tutorial = model.screen {} else { XCTFail("Expected first-run tutorial") }
    model.completeTutorial()
    if case .modeSelection = model.screen {} else { XCTFail("Expected mode selection") }

    let restored = makeModel(defaults: defaults)
    restored.beginPlayFlow()
    if case .modeSelection = restored.screen {} else { XCTFail("Tutorial should remain complete") }
  }

  func testSettingsPersistAcrossModels() {
    let defaults = makeDefaults()
    let first = makeModel(defaults: defaults)
    first.settings.musicEnabled = false
    first.settings.effectsEnabled = false
    let restored = makeModel(defaults: defaults)
    XCTAssertFalse(restored.settings.musicEnabled)
    XCTAssertFalse(restored.settings.effectsEnabled)
  }

  func testLegacyUnversionedSettingsMigrate() throws {
    let defaults = makeDefaults()
    let legacy = GameSettings(musicEnabled: false, inputSensitivity: 1.3)
    defaults.set(
      try JSONEncoder().encode(legacy),
      forKey: "PumkinRaidApp.settings.v1"
    )
    let restored = makeModel(defaults: defaults)
    XCTAssertFalse(restored.settings.musicEnabled)
    XCTAssertEqual(restored.settings.inputSensitivity, 1.3)
  }

  func testCorruptSavesRecoverToSafeDefaults() {
    let defaults = makeDefaults()
    let corrupt = Data("not-json".utf8)
    defaults.set(corrupt, forKey: "PumkinRaidApp.settings.v1")
    defaults.set(corrupt, forKey: "PumkinRaidApp.leaderboards.v2")
    defaults.set(corrupt, forKey: "PumkinRaidApp.progress.v1")
    let model = makeModel(defaults: defaults)
    XCTAssertEqual(model.settings, GameSettings())
    XCTAssertEqual(model.leaderboard.entries, [])
    XCTAssertEqual(model.progress, PlayerProgress())
  }

  func testFinishedRunsAreRankedAndPersisted() {
    let defaults = makeDefaults()
    let model = makeModel(defaults: defaults)
    model.finishGame(score: 100)
    model.finishGame(score: 900)
    XCTAssertEqual(model.leaderboard.entries.map(\.score), [900, 100])
    XCTAssertEqual(makeModel(defaults: defaults).leaderboard.entries.map(\.score), [900, 100])
  }

  func testModeSelectionAndChosenModeAreExplicitStates() {
    let model = makeModel()
    model.showModeSelection()
    if case .modeSelection = model.screen {} else { XCTFail("Expected mode selection") }
    model.beginGame(mode: .moonRush)
    if case .game(mode: .moonRush) = model.screen {} else { XCTFail("Expected Moon Rush") }
  }

  func testRunProgressAndModeLeaderboardPersist() {
    let defaults = makeDefaults()
    let model = makeModel(defaults: defaults)
    let summary = RunSummary(
      mode: .moonRush,
      score: 2_400,
      statistics: SessionStatistics(destroyed: 20, nearMisses: 3, bestCombo: 6),
      durationTicks: 3_600,
      replayDigest: 99,
      assisted: false
    )
    model.finishGame(summary)
    XCTAssertEqual(model.leaderboard(for: .moonRush).bestScore, 2_400)
    XCTAssertEqual(model.leaderboard(for: .classicRaid).bestScore, 0)
    XCTAssertEqual(model.progress.totalRuns, 1)
    let restored = makeModel(defaults: defaults)
    XCTAssertEqual(restored.leaderboard(for: .moonRush).bestScore, 2_400)
    XCTAssertEqual(restored.progress, model.progress)
  }

  func testAssistedLeaderboardIsSeparate() {
    let model = makeModel()
    model.finishGame(
      RunSummary(
        mode: .classicRaid,
        score: 999,
        statistics: SessionStatistics(),
        durationTicks: 10,
        replayDigest: 1,
        assisted: true
      ))
    XCTAssertEqual(model.leaderboard(for: .classicRaid).bestScore, 0)
    XCTAssertEqual(model.leaderboard(for: .classicRaid, assisted: true).bestScore, 999)
  }
}
