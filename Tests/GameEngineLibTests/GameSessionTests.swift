import Foundation
import XCTest

@testable import GameEngineLib

final class GameSessionTests: XCTestCase {
  func testSeededSpawnRunsAreExactlyReproducible() {
    var first = SpawnDirector(seed: 0xCAFE_BABE)
    var second = SpawnDirector(seed: 0xCAFE_BABE)
    let firstRun = (0..<40).map { first.nextPlan(elapsedTime: Double($0), score: $0 * 120) }
    let secondRun = (0..<40).map { second.nextPlan(elapsedTime: Double($0), score: $0 * 120) }
    XCTAssertEqual(firstRun, secondRun)
  }

  func testSpawnDirectorStaysInsideSafeHorizontalBounds() {
    var director = SpawnDirector(seed: 42)
    for index in 0..<1_000 {
      let plan = director.nextPlan(elapsedTime: Double(index), score: index * 10)
      XCTAssertGreaterThanOrEqual(plan.horizontalPosition, 0.05)
      XCTAssertLessThanOrEqual(plan.horizontalPosition, 0.95)
      XCTAssertGreaterThan(plan.speed, 0)
      XCTAssertGreaterThan(plan.scale, 0)
    }
  }

  func testComboWindowAndBonusAreDeterministic() {
    var combo = ComboTracker(window: 1.5)
    XCTAssertEqual(combo.registerHit(at: 1), ComboResult(count: 1, bonus: 0))
    XCTAssertEqual(combo.registerHit(at: 2), ComboResult(count: 2, bonus: 10))
    XCTAssertEqual(combo.registerHit(at: 2.4), ComboResult(count: 3, bonus: 15))
    XCTAssertEqual(combo.registerHit(at: 5), ComboResult(count: 1, bonus: 0))
  }

  func testLeaderboardRanksScoresAndCapsCapacity() {
    let now = Date(timeIntervalSince1970: 1_000)
    var board = Leaderboard(capacity: 3)
    board.submit(LeaderboardEntry(playerName: "A", score: 200, achievedAt: now))
    board.submit(LeaderboardEntry(playerName: "B", score: 900, achievedAt: now))
    board.submit(LeaderboardEntry(playerName: "C", score: 500, achievedAt: now))
    XCTAssertNil(board.submit(LeaderboardEntry(playerName: "D", score: 10, achievedAt: now)))
    XCTAssertEqual(board.entries.map(\.score), [900, 500, 200])
    XCTAssertEqual(board.bestScore, 900)
  }

  func testOriginalStartingInventoryIsPreserved() {
    let session = GameSession()
    XCTAssertEqual(session.lives, 10)
    XCTAssertEqual(session.slices, 30)
    XCTAssertEqual(session.booms, 50)
  }

  func testPumpkinActionsMatchOriginalScoring() {
    var session = GameSession()
    XCTAssertTrue(session.slicePumpkin())
    XCTAssertTrue(session.boomPumpkin())
    session.avoidPumpkin()
    XCTAssertEqual(session.score, 25)
    XCTAssertEqual(session.slices, 29)
    XCTAssertEqual(session.booms, 49)
  }

  func testSweetsAndExtraLivesAreAwarded() {
    var session = GameSession()
    for _ in 0..<10 { session.collectSweet(kind: 2) }
    XCTAssertEqual(session.score, 10_000)
    XCTAssertEqual(session.lives, 11)
    XCTAssertEqual(session.pointsTowardExtraLife, 0)
  }

  func testInventoriesRechargeWithoutExceedingTheirCaps() {
    var session = GameSession()
    XCTAssertTrue(session.slicePumpkin())
    XCTAssertTrue(session.boomPumpkin())
    session.rechargeSlices(20)
    session.rechargeBooms(20)
    XCTAssertEqual(session.slices, 30)
    XCTAssertEqual(session.booms, 50)
  }

  func testInvalidSweetKindDoesNotChangeScore() {
    var session = GameSession()
    XCTAssertEqual(session.collectSweet(kind: -1), 0)
    XCTAssertEqual(session.collectSweet(kind: 99), 0)
    XCTAssertEqual(session.score, 0)
  }

  func testActionsAreRejectedAfterGameOver() {
    var session = GameSession()
    for _ in 0..<GameRules.initialLives {
      XCTAssertTrue(session.collideWithPumpkin())
    }
    XCTAssertTrue(session.isGameOver)
    XCTAssertFalse(session.collideWithPumpkin())
    XCTAssertFalse(session.slicePumpkin())
    XCTAssertFalse(session.boomPumpkin())
    XCTAssertEqual(session.collectSweet(kind: 0), 0)
  }

  func testRechargeIgnoresNegativeAmounts() {
    var session = GameSession()
    XCTAssertTrue(session.slicePumpkin())
    XCTAssertTrue(session.boomPumpkin())
    session.rechargeSlices(-10)
    session.rechargeBooms(-10)
    XCTAssertEqual(session.slices, 29)
    XCTAssertEqual(session.booms, 49)
  }

  func testExcessPointsCarryTowardTheNextExtraLife() {
    var session = GameSession()
    for _ in 0..<11 { session.collectSweet(kind: 2) }
    XCTAssertEqual(session.lives, 11)
    XCTAssertEqual(session.pointsTowardExtraLife, 1_000)
  }

  func testComboBonusUsesTheSameScoreAndExtraLifeRules() {
    var session = GameSession()
    XCTAssertEqual(session.awardBonus(125), 125)
    XCTAssertEqual(session.score, 125)
    XCTAssertEqual(session.pointsTowardExtraLife, 125)
    XCTAssertEqual(session.awardBonus(-10), 0)
    XCTAssertEqual(session.score, 125)
  }
}
