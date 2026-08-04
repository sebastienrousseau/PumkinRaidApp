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
      XCTAssertLessThanOrEqual(panel.frame.width, 764, "HUD becomes too wide at \(size)")

      for name in ["hud-score", "hud-lives", "hud-dashes", "hud-shrieks"] {
        let label = try XCTUnwrap(scene.childNode(withName: name) as? SKLabelNode)
        XCTAssertEqual(label.horizontalAlignmentMode, .center)
        XCTAssertEqual(label.verticalAlignmentMode, .center)
        XCTAssertTrue(panel.frame.insetBy(dx: -2, dy: -2).contains(label.position))
      }
    }
  }

  func testGameplayArtworkScalesUpAcrossResolutionClasses() throws {
    let compactMetrics = GameplayArtworkMetrics(sceneSize: CGSize(width: 390, height: 844))
    let largeMetrics = GameplayArtworkMetrics(sceneSize: CGSize(width: 1_920, height: 1_080))
    XCTAssertGreaterThanOrEqual(compactMetrics.ghostSize.width, 80)
    XCTAssertGreaterThanOrEqual(compactMetrics.pumpkinSize(radiusScale: 1).width, 79)
    XCTAssertGreaterThanOrEqual(compactMetrics.sweetSize.width, 56)
    XCTAssertGreaterThan(largeMetrics.ghostSize.width, compactMetrics.ghostSize.width * 1.55)
    XCTAssertGreaterThan(
      largeMetrics.pumpkinSize(radiusScale: 1).width,
      compactMetrics.pumpkinSize(radiusScale: 1).width * 1.55
    )
    XCTAssertGreaterThan(largeMetrics.sweetSize.width, compactMetrics.sweetSize.width * 1.55)

    let compact = GameScene(settings: silentSettings, seed: 7)
    compact.size = CGSize(width: 390, height: 844)
    compact.installSceneGraph()
    let compactGhost = try XCTUnwrap(compact.childNode(withName: "//phantom") as? SKSpriteNode)

    let large = GameScene(settings: silentSettings, seed: 7)
    large.size = CGSize(width: 1_920, height: 1_080)
    large.installSceneGraph()
    let largeGhost = try XCTUnwrap(large.childNode(withName: "//phantom") as? SKSpriteNode)

    XCTAssertEqual(compactGhost.size.width, compactMetrics.ghostSize.width, accuracy: 0.001)
    XCTAssertEqual(compactGhost.size.height, compactMetrics.ghostSize.height, accuracy: 0.001)
    XCTAssertGreaterThan(largeGhost.size.width, compactGhost.size.width * 1.55)
    XCTAssertEqual(largeGhost.size.width, largeMetrics.ghostSize.width, accuracy: 0.001)
    XCTAssertEqual(largeGhost.size.height, largeMetrics.ghostSize.height, accuracy: 0.001)
    XCTAssertLessThanOrEqual(largeGhost.size.width, 200)
  }

  func testStartContentNeverEntersPortraitCharacterZone() {
    let sizes = [
      CGSize(width: 320, height: 568),
      CGSize(width: 390, height: 844),
      CGSize(width: 768, height: 1_024),
      CGSize(width: 1_280, height: 720),
      CGSize(width: 1_920, height: 1_080),
      CGSize(width: 3_440, height: 1_440),
    ]

    for size in sizes {
      let layout = StartLayoutMetrics(size: size, safeTop: 24)
      XCTAssertGreaterThanOrEqual(layout.playSize, 88)
      XCTAssertLessThanOrEqual(layout.playSize, 124)
      XCTAssertGreaterThan(layout.contentRegionHeight, 0)
      if layout.isLandscape {
        XCTAssertLessThan(layout.contentCenter.x, size.width / 2)
        XCTAssertLessThanOrEqual(layout.contentWidth, size.width * 0.46)
      } else {
        XCTAssertLessThanOrEqual(
          layout.contentTop + layout.contentRegionHeight,
          size.height * 0.47,
          "Launch content enters character artwork at \(size)"
        )
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
    let before = scene.authoritativeState.ghost.position
    let start = CGPoint(x: scene.size.width * 0.2, y: scene.size.height * 0.65)
    let destination = CGPoint(x: start.x + 70, y: start.y + 24)

    scene.pointerDown(at: start, timestamp: 1)
    scene.pointerDragged(to: destination)
    scene.update(1)
    scene.update(1.02)
    scene.pointerUp(at: destination, timestamp: 1.1)

    XCTAssertLessThan(scene.authoritativeState.ghost.position.x, before.x)
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
