import Combine
import Foundation
import PumkinRaidCore

@MainActor
final class AppModel: ObservableObject {
  enum Screen {
    case start
    case settings
    case game
    case gameOver(score: Int, highScore: Int)
  }

  @Published var screen: Screen = .start
  @Published var settings: GameSettings { didSet { saveSettings() } }

  private let defaults: UserDefaults
  private static let settingsKey = "PumkinRaid.settings"
  private static let highScoreKey = "PumkinRaid.highScore"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
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
    let highScore = max(score, defaults.integer(forKey: Self.highScoreKey))
    defaults.set(highScore, forKey: Self.highScoreKey)
    screen = .gameOver(score: score, highScore: highScore)
  }

  private func saveSettings() {
    guard let data = try? JSONEncoder().encode(settings) else { return }
    defaults.set(data, forKey: Self.settingsKey)
  }
}
