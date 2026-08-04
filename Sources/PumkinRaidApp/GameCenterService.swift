import Combine
import GameEngineLib
@preconcurrency import GameKit
import OSLog

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

@MainActor
protocol CompetitiveScoreSubmitting {
  func submit(_ summary: RunSummary)
}

@MainActor
final class GameCenterService: ObservableObject, CompetitiveScoreSubmitting {
  static let shared = GameCenterService()

  @Published private(set) var isAuthenticated = false
  @Published private(set) var playerName: String?

  private let logger = Logger(
    subsystem: "com.sebastienrousseau.PumkinRaidApp",
    category: "GameCenter"
  )

  private init() {}

  func authenticate() {
    GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
      Task { @MainActor [weak self] in
        if let controller { Self.present(controller) }
        if let error {
          self?.logger.info(
            "Game Center authentication unavailable: \(error.localizedDescription, privacy: .public)"
          )
        }
        self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        self?.playerName =
          GKLocalPlayer.local.isAuthenticated
          ? GKLocalPlayer.local.displayName : nil
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = GKLocalPlayer.local.isAuthenticated
        GKAccessPoint.shared.showHighlights = true
      }
    }
  }

  func submit(_ summary: RunSummary) {
    guard isAuthenticated, !summary.assisted, let identifier = leaderboardID(for: summary.mode)
    else {
      return
    }
    let context = Int(summary.replayDigest & 0x7FFF_FFFF)
    GKLeaderboard.submitScore(
      summary.score,
      context: context,
      player: GKLocalPlayer.local,
      leaderboardIDs: [identifier]
    ) { [weak self] error in
      if let error {
        self?.logger.error(
          "Leaderboard submission failed: \(error.localizedDescription, privacy: .public)")
      }
    }
    submitAchievements(summary)
  }

  func showDashboard() {
    guard isAuthenticated else {
      authenticate()
      return
    }
    let controller = GKGameCenterViewController(state: .leaderboards)
    controller.gameCenterDelegate = DashboardDelegate.shared
    Self.present(controller)
  }

  private func submitAchievements(_ summary: RunSummary) {
    let values: [(String, Double)] = [
      ("achievement.first_raid", 100),
      ("achievement.combo_10", min(100, Double(summary.statistics.bestCombo) / 10 * 100)),
      ("achievement.score_10000", min(100, Double(summary.score) / 10_000 * 100)),
      ("achievement.near_miss_10", min(100, Double(summary.statistics.nearMisses) / 10 * 100)),
    ]
    let achievements = values.map { identifier, percent in
      let achievement = GKAchievement(identifier: identifier)
      achievement.percentComplete = percent
      achievement.showsCompletionBanner = true
      return achievement
    }
    GKAchievement.report(achievements) { [weak self] error in
      if let error {
        self?.logger.error(
          "Achievement report failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func leaderboardID(for mode: GameMode) -> String? {
    switch mode {
    case .classicRaid: "leaderboard.classic"
    case .moonRush: "leaderboard.moon_rush"
    case .dailyHaunt: "leaderboard.daily"
    case .bossRaid: "leaderboard.boss"
    case .spiritZen: nil
    }
  }

  #if os(macOS)
    private static func present(_ controller: NSViewController) {
      guard let host = NSApp.keyWindow?.contentViewController,
        host.presentedViewControllers?.contains(controller) != true
      else { return }
      host.presentAsSheet(controller)
    }
  #else
    private static func present(_ controller: UIViewController) {
      guard
        let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
        let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
      else { return }
      var presenter = root
      while let presented = presenter.presentedViewController { presenter = presented }
      guard presenter !== controller else { return }
      presenter.present(controller, animated: true)
    }
  #endif
}

@MainActor
private final class DashboardDelegate: NSObject, @preconcurrency GKGameCenterControllerDelegate {
  static let shared = DashboardDelegate()

  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    #if os(macOS)
      gameCenterViewController.dismiss(nil)
    #else
      gameCenterViewController.dismiss(animated: true)
    #endif
  }
}
