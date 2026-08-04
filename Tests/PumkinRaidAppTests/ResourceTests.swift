import Foundation
import XCTest

@testable import PumkinRaidApp

@MainActor
final class ResourceTests: XCTestCase {
  func testRequiredArtworkAndAudioArePackaged() {
    let resources: [(String, String)] = [
      ("background", "png"),
      ("background-tablet", "jpg"),
      ("background-wide", "jpg"),
      ("splashscreen", "png"),
      ("splash-backdrop-tablet", "png"),
      ("gameover-backdrop-tablet", "png"),
      ("leaderboard-panel", "png"),
      ("button-start", "png"),
      ("button-start-pressed", "png"),
      ("button-arrow", "png"),
      ("button-arrow-pressed", "png"),
      ("button-info", "png"),
      ("skull-toggle-on", "png"),
      ("skull-toggle-off", "png"),
      ("phantom", "png"),
      ("pumpkin1", "png"),
      ("pumpkin2", "png"),
      ("pumpkin3", "png"),
      ("mysterious_house", "mp3"),
      ("slice", "wav"),
      ("explode", "wav"),
      ("ding", "wav"),
      ("female_scream", "wav"),
    ]
    for (name, fileExtension) in resources {
      XCTAssertNotNil(
        Bundle.pumkinRaidResources.url(forResource: name, withExtension: fileExtension),
        "Missing required resource: \(name).\(fileExtension)"
      )
    }
  }

  func testSupportedLocalizationsArePackaged() {
    let expected = Set(["de", "en", "es", "fr", "it", "ja", "ko", "pt-br", "zh-hans"])
    let packaged = Set(Bundle.pumkinRaidResources.localizations.map { $0.lowercased() })
    XCTAssertTrue(expected.isSubset(of: packaged))
  }

  func testRuntimeResourceBudgetsAreExplicitlyBounded() {
    XCTAssertEqual(AudioManager.maximumEffectVoices, 12)
    XCTAssertEqual(GameScene.maximumTransientEffects, 96)
  }
}
