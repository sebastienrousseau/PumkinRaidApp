import Foundation
import XCTest

@testable import PumkinRaidApp

final class DailyChallengeStateTests: XCTestCase {
  func testDailyCompletionBuildsAStreakWithoutDuplicateRewards() {
    var state = DailyChallengeState()
    XCTAssertEqual(state.complete(day: 100, score: 900), 35)
    XCTAssertEqual(state.streak, 1)
    XCTAssertEqual(state.bestScore, 900)
    XCTAssertEqual(state.complete(day: 100, score: 1_200), 0)
    XCTAssertEqual(state.streak, 1)
    XCTAssertEqual(state.bestScore, 1_200)
    XCTAssertEqual(state.complete(day: 101, score: 800), 45)
    XCTAssertEqual(state.streak, 2)
  }

  func testDailyCompletionResetsAfterAGapAndCapsReward() {
    var state = DailyChallengeState(lastCompletedDay: 1, streak: 40, bestScore: -1)
    XCTAssertEqual(state.bestScore, 0)
    XCTAssertEqual(state.complete(day: 9, score: -20), 35)
    XCTAssertEqual(state.streak, 1)

    state = DailyChallengeState(lastCompletedDay: 10, streak: 30, bestScore: 1)
    XCTAssertEqual(state.complete(day: 11, score: 2), 250)
  }

  func testUTCDayUsesWholeEpochDays() {
    XCTAssertEqual(DailyChallengeState.utcDay(at: Date(timeIntervalSince1970: 172_801)), 2)
  }

  func testInitialValuesAreSanitized() {
    let state = DailyChallengeState(lastCompletedDay: nil, streak: -4, bestScore: -8)
    XCTAssertNil(state.lastCompletedDay)
    XCTAssertEqual(state.streak, 0)
    XCTAssertEqual(state.bestScore, 0)
  }
}
