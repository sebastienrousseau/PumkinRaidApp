import GameEngineLib
import XCTest

@testable import PumkinRaidApp

#if os(macOS)
  import AppKit
#endif

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

  func testEveryNavigationStateHasAStableTransitionIdentifier() {
    let model = makeModel()
    XCTAssertEqual(model.screen.transitionID, "start")
    model.showTutorial()
    XCTAssertEqual(model.screen.transitionID, "tutorial")
    model.showSettings()
    XCTAssertEqual(model.screen.transitionID, "settings")
    model.showModeSelection()
    XCTAssertEqual(model.screen.transitionID, "modeSelection")
    model.showPlayerHub(.missions)
    XCTAssertEqual(model.screen.transitionID, "hub-missions")
    model.beginGame(mode: .bossRaid)
    XCTAssertEqual(model.screen.transitionID, "game-bossRaid")
    XCTAssertTrue(model.shouldPlayMusic)
    model.finishGame(score: 1)
    XCTAssertEqual(model.screen.transitionID, "gameOver")
    XCTAssertFalse(model.shouldPlayMusic)
    model.showStart()
    XCTAssertEqual(model.screen.transitionID, "start")
  }

  func testLegacyHighScoreAndLeaderboardPayloadsMigrate() throws {
    let highScoreDefaults = makeDefaults()
    highScoreDefaults.set(321, forKey: "PumkinRaid.highScore")
    XCTAssertEqual(makeModel(defaults: highScoreDefaults).leaderboard.bestScore, 321)

    let boardDefaults = makeDefaults()
    let board = Leaderboard(entries: [LeaderboardEntry(playerName: "Legacy", score: 654)])
    boardDefaults.set(
      try JSONEncoder().encode(board),
      forKey: "PumkinRaidApp.leaderboard.v1"
    )
    let migrated = makeModel(defaults: boardDefaults)
    XCTAssertEqual(migrated.leaderboard.bestScore, 654)
    XCTAssertEqual(migrated.leaderboard(for: .classicRaid).bestScore, 654)
  }

  func testCosmeticsOnlyEquipWhenUnlockedAndUseTheirCategory() {
    let model = makeModel()
    let locked = CosmeticItem(id: "ghost.locked", name: "Locked", category: .ghost, unlockLevel: 99)
    model.equip(locked)
    XCTAssertEqual(model.progress.equippedGhostID, "ghost.classic")

    model.equip(ProgressionCatalog.cosmetics.first { $0.id == "ghost.classic" }!)
    model.equip(ProgressionCatalog.cosmetics.first { $0.id == "trail.moonlight" }!)
    XCTAssertEqual(model.progress.equippedGhostID, "ghost.classic")
    XCTAssertEqual(model.progress.equippedTrailID, "trail.moonlight")

    model.finishGame(score: 40_000)
    let aura = ProgressionCatalog.cosmetics.first { $0.id == "aura.frenzy" }!
    XCTAssertTrue(model.progress.unlockedCosmeticIDs.contains(aura.id))
    model.equip(aura)
  }

  func testInactiveSceneInputAdaptersAreSafeNoOps() {
    let model = makeModel()
    model.movePhantom(horizontal: 1, vertical: -1)
    #if os(macOS)
      let event = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
      )!
      XCTAssertFalse(model.handlePointerEvent(event))
    #endif
  }

  func testEmptyLeaderboardStoreCreatesBoardsOnDemandWithoutOverwritingMigration() {
    var store = LocalLeaderboardStore()
    XCTAssertEqual(store.leaderboard(for: .dailyHaunt).entries, [])
    let original = Leaderboard(entries: [LeaderboardEntry(playerName: "Original", score: 10)])
    store.migrateClassic(original)
    store.migrateClassic(Leaderboard(entries: [LeaderboardEntry(playerName: "New", score: 99)]))
    XCTAssertEqual(store.leaderboard(for: .classicRaid), original)
    XCTAssertEqual(
      store.submit(
        LeaderboardEntry(playerName: "Assisted", score: 12), mode: .bossRaid, assisted: true),
      1
    )
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
