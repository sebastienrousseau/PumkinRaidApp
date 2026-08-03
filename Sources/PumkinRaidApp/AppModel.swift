import Combine
import Foundation
import GameEngineLib

#if os(macOS)
  import AppKit
#endif

@MainActor
final class AppModel: ObservableObject {
  enum Screen {
    case start
    case settings
    case game
    case gameOver(score: Int, leaderboard: Leaderboard, entryID: UUID)

    var transitionID: String {
      switch self {
      case .start: "start"
      case .settings: "settings"
      case .game: "game"
      case .gameOver: "gameOver"
      }
    }
  }

  @Published var screen: Screen = .start
  @Published var settings: GameSettings { didSet { saveSettings() } }
  @Published private(set) var leaderboard: Leaderboard
  weak var activeGameScene: GameScene?

  private let defaults: UserDefaults
  private static let settingsKey = "PumkinRaidApp.settings.v1"
  private static let leaderboardKey = "PumkinRaidApp.leaderboard.v1"
  private static let legacyHighScoreKey = "PumkinRaid.highScore"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.leaderboardKey),
      let decoded = try? JSONDecoder().decode(Leaderboard.self, from: data)
    {
      leaderboard = decoded
    } else {
      let legacyScore = defaults.integer(forKey: Self.legacyHighScoreKey)
      leaderboard = Leaderboard(
        entries: legacyScore > 0
          ? [LeaderboardEntry(playerName: "Local Best", score: legacyScore)] : []
      )
    }
    if let data = defaults.data(forKey: Self.settingsKey),
      let decoded = try? JSONDecoder().decode(GameSettings.self, from: data)
    {
      settings = decoded
    } else {
      settings = GameSettings()
    }
  }

  func beginGame() { screen = .game }
  func showSettings() { screen = .settings }
  func showStart() { screen = .start }

  var shouldPlayMusic: Bool {
    if case .gameOver = screen { return false }
    return true
  }

  func finishGame(score: Int) {
    #if os(macOS)
      KeyboardState.shared.clear()
    #endif
    activeGameScene = nil
    let entry = LeaderboardEntry(playerName: "You", score: score)
    leaderboard.submit(entry)
    if let data = try? JSONEncoder().encode(leaderboard) {
      defaults.set(data, forKey: Self.leaderboardKey)
    }
    screen = .gameOver(score: score, leaderboard: leaderboard, entryID: entry.id)
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
    guard let data = try? JSONEncoder().encode(settings) else { return }
    defaults.set(data, forKey: Self.settingsKey)
  }
}
