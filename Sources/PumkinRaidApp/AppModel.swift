import Combine
import Foundation
import GameEngineLib

#if os(macOS)
  import AppKit
#endif

@MainActor
final class AppModel: ObservableObject {
  enum HubSection: String, CaseIterable { case profile, missions, collection }

  enum Screen {
    case start
    case tutorial
    case settings
    case modeSelection
    case playerHub(section: HubSection)
    case game(mode: GameMode)
    case gameOver(
      summary: RunSummary,
      progression: ProgressionUpdate,
      leaderboard: Leaderboard,
      entryID: UUID
    )

    var transitionID: String {
      switch self {
      case .start: "start"
      case .tutorial: "tutorial"
      case .settings: "settings"
      case .modeSelection: "modeSelection"
      case .playerHub(let section): "hub-\(section.rawValue)"
      case .game(let mode): "game-\(mode.rawValue)"
      case .gameOver: "gameOver"
      }
    }
  }

  @Published var screen: Screen = .start
  @Published var settings: GameSettings { didSet { saveSettings() } }
  @Published private(set) var leaderboard: Leaderboard
  @Published private(set) var progress: PlayerProgress
  @Published private(set) var hasCompletedTutorial: Bool
  private var leaderboardStore: LocalLeaderboardStore
  private let scoreSubmitter: any CompetitiveScoreSubmitting
  weak var activeGameScene: GameScene?

  private let defaults: UserDefaults
  private static let settingsKey = "PumkinRaidApp.settings.v1"
  private static let leaderboardKey = "PumkinRaidApp.leaderboard.v1"
  private static let legacyHighScoreKey = "PumkinRaid.highScore"
  private static let leaderboardStoreKey = "PumkinRaidApp.leaderboards.v2"
  private static let progressKey = "PumkinRaidApp.progress.v1"
  private static let tutorialKey = "PumkinRaidApp.tutorial.v1"

  init(
    defaults: UserDefaults = .standard,
    scoreSubmitter: any CompetitiveScoreSubmitting = GameCenterService.shared
  ) {
    self.defaults = defaults
    self.scoreSubmitter = scoreSubmitter
    hasCompletedTutorial = defaults.bool(forKey: Self.tutorialKey)
    if let data = defaults.data(forKey: Self.leaderboardStoreKey),
      let decoded = VersionedSave<LocalLeaderboardStore>.decode(data)
    {
      leaderboardStore = decoded
      leaderboard = decoded.leaderboard(for: .classicRaid)
    } else if let data = defaults.data(forKey: Self.leaderboardKey),
      let decoded = try? JSONDecoder().decode(Leaderboard.self, from: data)
    {
      leaderboard = decoded
      leaderboardStore = LocalLeaderboardStore()
      leaderboardStore.migrateClassic(decoded)
    } else {
      let legacyScore = defaults.integer(forKey: Self.legacyHighScoreKey)
      let migratedLeaderboard = Leaderboard(
        entries: legacyScore > 0
          ? [LeaderboardEntry(playerName: "Local Best", score: legacyScore)] : []
      )
      leaderboard = migratedLeaderboard
      leaderboardStore = LocalLeaderboardStore()
      leaderboardStore.migrateClassic(migratedLeaderboard)
    }
    if let data = defaults.data(forKey: Self.progressKey),
      let decoded = VersionedSave<PlayerProgress>.decode(data)
    {
      progress = decoded
    } else {
      progress = PlayerProgress()
    }
    if let data = defaults.data(forKey: Self.settingsKey),
      let decoded = VersionedSave<GameSettings>.decode(data)
    {
      settings = decoded
    } else {
      settings = GameSettings()
    }
  }

  func showModeSelection() { screen = .modeSelection }
  func beginPlayFlow() { screen = hasCompletedTutorial ? .modeSelection : .tutorial }
  func showTutorial() { screen = .tutorial }
  func completeTutorial() {
    hasCompletedTutorial = true
    defaults.set(true, forKey: Self.tutorialKey)
    screen = .modeSelection
  }
  func showPlayerHub(_ section: HubSection = .profile) { screen = .playerHub(section: section) }
  func beginGame(mode: GameMode = .classicRaid) { screen = .game(mode: mode) }
  func showSettings() { screen = .settings }
  func showStart() { screen = .start }

  var shouldPlayMusic: Bool {
    if case .gameOver = screen { return false }
    return true
  }

  func finishGame(_ summary: RunSummary) {
    #if os(macOS)
      KeyboardState.shared.clear()
    #endif
    activeGameScene = nil
    let entry = LeaderboardEntry(
      playerName: summary.assisted ? "You • Assisted" : "You", score: summary.score)
    leaderboardStore.submit(entry, mode: summary.mode, assisted: summary.assisted)
    leaderboard = leaderboardStore.leaderboard(for: summary.mode, assisted: summary.assisted)
    let progression = ProgressionSystem.apply(summary, to: &progress)
    scoreSubmitter.submit(summary)
    persistProfile()
    screen = .gameOver(
      summary: summary,
      progression: progression,
      leaderboard: leaderboard,
      entryID: entry.id
    )
  }

  func finishGame(score: Int, mode: GameMode = .classicRaid) {
    finishGame(
      RunSummary(
        mode: mode,
        score: score,
        statistics: SessionStatistics(),
        durationTicks: 0,
        replayDigest: 0,
        assisted: settings.assistModeEnabled
      ))
  }

  func leaderboard(for mode: GameMode, assisted: Bool = false) -> Leaderboard {
    leaderboardStore.leaderboard(for: mode, assisted: assisted)
  }

  func equip(_ item: CosmeticItem) {
    guard progress.unlockedCosmeticIDs.contains(item.id) else { return }
    switch item.category {
    case .ghost: progress.equippedGhostID = item.id
    case .trail: progress.equippedTrailID = item.id
    case .aura: break
    }
    persistProfile()
  }

  func movePhantom(horizontal: CGFloat, vertical: CGFloat) {
    activeGameScene?.movePhantom(horizontal: horizontal, vertical: vertical)
  }

  #if os(macOS)
    func handlePointerEvent(_ event: NSEvent) -> Bool {
      activeGameScene?.handleApplicationPointerEvent(event) ?? false
    }
  #endif

  private func saveSettings() {
    guard let data = VersionedSave<GameSettings>.encode(settings) else { return }
    defaults.set(data, forKey: Self.settingsKey)
  }

  private func persistProfile() {
    if let data = VersionedSave<LocalLeaderboardStore>.encode(leaderboardStore) {
      defaults.set(data, forKey: Self.leaderboardStoreKey)
    }
    if let data = VersionedSave<PlayerProgress>.encode(progress) {
      defaults.set(data, forKey: Self.progressKey)
    }
  }
}
