import XCTest

@testable import PumkinRaidCore

final class GameSessionTests: XCTestCase {
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
