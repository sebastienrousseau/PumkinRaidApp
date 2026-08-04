import GameEngineLib
import XCTest

@testable import PumkinRaidApp

final class RaidChallengeTests: XCTestCase {
  func testChallengeRoundTripsThroughShareCode() {
    let challenge = RaidChallenge(seed: 42, mode: .bossRaid, targetScore: 8_000, replayDigest: 99)
    XCTAssertEqual(RaidChallenge.decode(challenge.code), challenge)
    XCTAssertTrue(challenge.shareText.contains("8000-point"))
    XCTAssertTrue(challenge.shareText.contains(challenge.code))
  }

  func testChallengeRejectsInvalidCodesAndSanitizesScore() {
    XCTAssertNil(RaidChallenge.decode("not a challenge"))
    XCTAssertNil(RaidChallenge.decode("e30"))
    let challenge = RaidChallenge(seed: 1, mode: .classicRaid, targetScore: -9, replayDigest: 0)
    XCTAssertEqual(challenge.targetScore, 0)
  }
}
