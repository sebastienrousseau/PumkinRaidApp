import Foundation

struct DailyChallengeState: Equatable, Codable {
  private(set) var lastCompletedDay: Int?
  private(set) var streak: Int
  private(set) var bestScore: Int

  init(lastCompletedDay: Int? = nil, streak: Int = 0, bestScore: Int = 0) {
    self.lastCompletedDay = lastCompletedDay
    self.streak = max(0, streak)
    self.bestScore = max(0, bestScore)
  }

  static func utcDay(at date: Date = .now) -> Int {
    Int(floor(date.timeIntervalSince1970 / 86_400))
  }

  mutating func complete(day: Int, score: Int) -> Int {
    bestScore = max(bestScore, score)
    guard lastCompletedDay != day else { return 0 }
    streak = lastCompletedDay == day - 1 ? streak + 1 : 1
    lastCompletedDay = day
    return min(250, 25 + streak * 10)
  }
}
