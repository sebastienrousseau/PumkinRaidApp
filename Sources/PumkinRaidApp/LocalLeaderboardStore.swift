import Foundation
import GameEngineLib

struct LocalLeaderboardStore: Equatable, Codable {
  private var boards: [String: Leaderboard]

  init(boards: [String: Leaderboard] = [:]) {
    self.boards = boards
  }

  func leaderboard(for mode: GameMode, assisted: Bool = false) -> Leaderboard {
    boards[key(mode: mode, assisted: assisted)] ?? Leaderboard()
  }

  @discardableResult
  mutating func submit(
    _ entry: LeaderboardEntry,
    mode: GameMode,
    assisted: Bool = false
  ) -> Int? {
    let boardKey = key(mode: mode, assisted: assisted)
    var board = boards[boardKey] ?? Leaderboard()
    let rank = board.submit(entry)
    boards[boardKey] = board
    return rank
  }

  mutating func migrateClassic(_ leaderboard: Leaderboard) {
    let boardKey = key(mode: .classicRaid, assisted: false)
    if boards[boardKey] == nil { boards[boardKey] = leaderboard }
  }

  private func key(mode: GameMode, assisted: Bool) -> String {
    "\(mode.rawValue).\(assisted ? "assisted" : "standard")"
  }
}
