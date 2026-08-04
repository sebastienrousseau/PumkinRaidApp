import GameEngineLib
import SpriteKit
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

  func testHUDRemainsInsetAndLabelsCenteredAcrossResolutionMatrix() throws {
    let sizes = [
      CGSize(width: 320, height: 568),
      CGSize(width: 390, height: 844),
      CGSize(width: 1_024, height: 768),
      CGSize(width: 1_920, height: 1_080),
      CGSize(width: 3_440, height: 1_440),
    ]
    for size in sizes {
      let scene = GameScene(settings: silentSettings, seed: 7)
      scene.size = size
      scene.installSceneGraph()
      let panel = try XCTUnwrap(scene.childNode(withName: "hud-background"))
      XCTAssertGreaterThanOrEqual(panel.frame.minX, 16, "HUD clips at \(size)")
      XCTAssertLessThanOrEqual(panel.frame.maxX, size.width - 16, "HUD clips at \(size)")
      XCTAssertLessThanOrEqual(panel.frame.maxY, size.height - 20, "HUD too high at \(size)")

      for name in ["hud-score", "hud-lives", "hud-dashes", "hud-shrieks"] {
        let label = try XCTUnwrap(scene.childNode(withName: name) as? SKLabelNode)
        XCTAssertEqual(label.horizontalAlignmentMode, .center)
        XCTAssertEqual(label.verticalAlignmentMode, .center)
        XCTAssertTrue(panel.frame.insetBy(dx: -2, dy: -2).contains(label.position))
      }
    }
  }

  func testProgrammaticMovementRoutesThroughSimulation() {
    let scene = GameScene(settings: silentSettings, seed: 8)
    let before = scene.authoritativeState.ghost.position
    scene.movePhantom(horizontal: 80, vertical: 0)
    scene.update(1)
    scene.update(1.02)
    XCTAssertGreaterThan(scene.authoritativeState.ghost.position.x, before.x)
  }

  func testPointerDragMovesGhostThroughSemanticInput() throws {
    let scene = GameScene(settings: silentSettings, seed: 18)
    scene.installSceneGraph()
    let phantom = try XCTUnwrap(scene.childNode(withName: "//phantom"))
    let before = scene.authoritativeState.ghost.position
    let destination = CGPoint(x: phantom.position.x + 70, y: phantom.position.y + 24)

    scene.pointerDown(at: phantom.position, timestamp: 1)
    scene.pointerDragged(to: destination)
    scene.update(1)
    scene.update(1.02)
    scene.pointerUp(at: destination, timestamp: 1.1)

    XCTAssertGreaterThan(scene.authoritativeState.ghost.position.x, before.x)
    XCTAssertNotEqual(scene.authoritativeState.ghost.position.y, before.y)
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

  func testPauseAndResumeFlowThroughAuthoritativeEvents() {
    let scene = GameScene(settings: silentSettings, seed: 15)
    var pauseStates: [Bool] = []
    scene.pauseChangedHandler = { pauseStates.append($0) }
    scene.update(1)
    scene.requestPause()
    scene.update(1.02)
    XCTAssertTrue(scene.authoritativeState.isPaused)
    scene.requestResume()
    scene.update(1.04)
    XCTAssertFalse(scene.authoritativeState.isPaused)
    XCTAssertEqual(pauseStates, [true, false])
  }
}
