import GameEngineLib
import XCTest
@testable import PumkinRaidApp

@MainActor
final class GameSceneTests: XCTestCase {
  private var silentSettings: GameSettings {
    var settings = GameSettings()
    settings.musicEnabled = false
    settings.effectsEnabled = false
    settings.vibrationEnabled = false
    return settings
  }

  func testSceneResizeDoesNotChangeAuthoritativeState() {
    let scene = GameScene(settings: silentSettings, seed: 7)
    let before = scene.authoritativeState
    scene.size = CGSize(width: 1_920, height: 1_080)
    XCTAssertEqual(scene.authoritativeState, before)
  }

  func testProgrammaticMovementRoutesThroughSimulation() {
    let scene = GameScene(settings: silentSettings, seed: 8)
    let before = scene.authoritativeState.ghost.position
    scene.movePhantom(horizontal: 80, vertical: 0)
    scene.update(1)
    scene.update(1.02)
    XCTAssertGreaterThan(scene.authoritativeState.ghost.position.x, before.x)
  }

  func testSameSeedAndFrameSequenceProducesSameSceneState() {
    let first = GameScene(settings: silentSettings, seed: 99)
    let second = GameScene(settings: silentSettings, seed: 99)
    first.update(1)
    second.update(1)
    for frame in 1...600 {
      let time = 1 + Double(frame) / 60
      first.update(time)
      second.update(time)
    }
    XCTAssertEqual(first.authoritativeState, second.authoritativeState)
  }
}
