import Foundation
import GameEngineLib

/// Historical record of a completed run session.
struct HistoricalRunEntry: Identifiable, Equatable, Codable, Sendable {
  let id: UUID
  let mode: GameMode
  let score: Int
  let assisted: Bool
  let date: Date

  init(
    id: UUID = UUID(),
    mode: GameMode,
    score: Int,
    assisted: Bool = false,
    date: Date = Date()
  ) {
    self.id = id
    self.mode = mode
    self.score = score
    self.assisted = assisted
    self.date = date
  }
}

/// Stores per-mode leaderboards and bounded historical run telemetry.
struct LocalLeaderboardStore: Equatable, Codable {
  static let maximumHistoricalRuns = 50

  private(set) var historicalRuns: [HistoricalRunEntry]
  private var boards: [String: Leaderboard]

  init(
    boards: [String: Leaderboard] = [:],
    historicalRuns: [HistoricalRunEntry] = []
  ) {
    self.boards = boards
    self.historicalRuns = Array(historicalRuns.suffix(Self.maximumHistoricalRuns))
  }

  enum CodingKeys: String, CodingKey {
    case boards
    case historicalRuns
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.boards = try container.decodeIfPresent([String: Leaderboard].self, forKey: .boards) ?? [:]
    let runs =
      try container.decodeIfPresent([HistoricalRunEntry].self, forKey: .historicalRuns) ?? []
    self.historicalRuns = Array(runs.suffix(Self.maximumHistoricalRuns))
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(boards, forKey: .boards)
    try container.encode(historicalRuns, forKey: .historicalRuns)
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
    appendHistoricalRun(
      mode: mode,
      score: entry.score,
      assisted: assisted,
      date: entry.achievedAt
    )
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

  private mutating func appendHistoricalRun(
    mode: GameMode,
    score: Int,
    assisted: Bool,
    date: Date
  ) {
    historicalRuns.append(
      HistoricalRunEntry(mode: mode, score: score, assisted: assisted, date: date)
    )
    if historicalRuns.count > Self.maximumHistoricalRuns {
      historicalRuns.removeFirst(historicalRuns.count - Self.maximumHistoricalRuns)
    }
  }

  private func key(mode: GameMode, assisted: Bool) -> String {
    "\(mode.rawValue).\(assisted ? "assisted" : "standard")"
  }
}
