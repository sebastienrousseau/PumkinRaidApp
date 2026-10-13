import Foundation
import GameEngineLib
import SpriteKit

#if os(iOS)
  import CoreMotion
  import UIKit
#elseif os(macOS)
  import AppKit
#elseif os(tvOS)
  import GameController
  import UIKit
#endif

/// SpriteKit rendering host for the authoritative GameEngineLib simulation.
/// This type renders state and translates physical controls; it does not score,
/// spawn, or resolve collisions independently.
@MainActor
final class GameScene: SKScene {
  static let maximumTransientEffects = 96
  var gameOverHandler: ((RunSummary) -> Void)?
  var challengeHandler: ((RaidChallenge) -> Void)?
  var pauseChangedHandler: ((Bool) -> Void)?
  var authoritativeState: GameState { simulation.state }

  let settings: GameSettings
  let cosmetics: CosmeticLoadout
  var simulation: GameSimulation
  let world = SKNode()
  let effectsLayer = SKNode()
  let atmosphere = SKShapeNode()
  let phantom = SKSpriteNode(texture: AssetLoader.texture("phantom"))
  let scoreLabel = SKLabelNode(fontNamed: "GangofThree")
  let livesLabel = SKLabelNode(fontNamed: "GangofThree")
  let slicesLabel = SKLabelNode(fontNamed: "GangofThree")
  let boomsLabel = SKLabelNode(fontNamed: "GangofThree")
  let statusLabel = SKLabelNode(fontNamed: "GangofThree")
  let hudBackground = SKShapeNode()
  var pumpkinNodes: [Int: SKSpriteNode] = [:]
  var pickupNode: SKSpriteNode?
  var lastUpdateTime: TimeInterval = 0
  var accumulatedTime: TimeInterval = 0
  var inputRouter = SemanticInputRouter()
  var gestureLastPoint: CGPoint?
  var draggingPhantom = false
  var gameEnded = false
  var systemReducedMotion = false
  var systemHighContrast = false
  #if os(iOS)
    let motionManager = CMMotionManager()
    var motionIntent = Vector2.zero
  #endif

  var spriteScale: CGFloat {
    GameplayArtworkMetrics(sceneSize: size).scale
  }
  var fixedDelta: TimeInterval {
    1 / Double(simulation.configuration.ticksPerSecond)
  }
  var shouldReduceMotion: Bool { settings.reducedMotionEnabled || systemReducedMotion }
  var shouldUseHighContrast: Bool { settings.highContrastEnabled || systemHighContrast }

  init(
    settings: GameSettings,
    mode: GameMode = .classicRaid,
    seed: UInt64? = nil,
    cosmetics: CosmeticLoadout = CosmeticLoadout()
  ) {
    self.settings = settings
    self.cosmetics = cosmetics
    let runSeed =
      seed
      ?? UInt64(Date().timeIntervalSince1970 * 1_000_000) ^ UInt64.random(in: .min ... .max)
    simulation = GameSimulation(
      seed: runSeed,
      mode: mode,
      configuration: SimulationConfiguration(
        movementSpeed: 0.72 * min(1.5, max(0.5, settings.inputSensitivity)),
        difficultyScale: settings.assistModeEnabled ? 0.72 : 1
      )
    )
    super.init(size: CGSize(width: 320, height: 568))
    scaleMode = .resizeFill
    backgroundColor = .black
  }

  required init?(coder: NSCoder) { nil }

  override func didMove(to view: SKView) {
    installSceneGraph()
    startMotionUpdates()
    AudioManager.shared.play("creaking_door", enabled: settings.effectsEnabled)
    #if os(macOS)
      DispatchQueue.main.async {
        view.window?.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
      }
    #endif
  }

  func installSceneGraph() {
    removeAllChildren()
    world.removeAllChildren()
    effectsLayer.removeAllChildren()
    pumpkinNodes.removeAll()
    pickupNode = nil
    addChild(world)
    addChild(effectsLayer)
    buildBackground()
    buildAtmosphere()
    buildHUD()
    buildPhantom()
    layoutHUD()
  }

  override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    if let background = world.childNode(withName: "background") as? SKSpriteNode {
      resizeBackground(background)
    }
    atmosphere.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    layoutHUD()
    phantom.size = GameplayArtworkMetrics(sceneSize: size).ghostSize
    for (_, node) in pumpkinNodes {
      resizePumpkin(node)
    }
  }

  override func update(_ currentTime: TimeInterval) {
    guard lastUpdateTime > 0 else {
      lastUpdateTime = currentTime
      return
    }
    let dt = min(0.1, currentTime - lastUpdateTime)
    lastUpdateTime = currentTime
    accumulatedTime += dt

    let signpost = FrameSignpost.begin()
    var steps = 0
    defer { FrameSignpost.end(signpost, steps: steps) }
    while accumulatedTime >= fixedDelta, steps < 6 {
      let events = simulation.step(continuousInputFrame())
      handle(events)
      accumulatedTime -= fixedDelta
      steps += 1
    }
    syncNodesWithSimulation()
    renderAuthoritativeState()
  }

  private func syncNodesWithSimulation() {
    let currentIDs = Set(simulation.state.pumpkins.map(\.id))
    for (id, node) in pumpkinNodes where !currentIDs.contains(id) {
      node.removeFromParent()
      pumpkinNodes.removeValue(forKey: id)
    }
    for pumpkin in simulation.state.pumpkins where pumpkinNodes[pumpkin.id] == nil {
      let assetName: String
      switch pumpkin.kind {
      case .target:
        let variant = (pumpkin.id % 3) + 1
        assetName = "pumpkin\(variant)"
      case .armored:
        assetName = "pumpkin3"
      case .cursed:
        assetName = "pumpkin1"
      }
      let node = SKSpriteNode(texture: AssetLoader.texture(assetName))
      resizePumpkin(node)
      node.position = scenePoint(pumpkin.position)
      node.zPosition = 10
      if pumpkin.kind == .cursed {
        node.color = SKColor(red: 0.62, green: 0.18, blue: 0.94, alpha: 1)
        node.colorBlendFactor = 0.55
      } else if pumpkin.kind == .armored {
        node.color = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 1)
        node.colorBlendFactor = 0.35
      }
      world.addChild(node)
      pumpkinNodes[pumpkin.id] = node
    }
    if let pickup = simulation.state.pickup {
      if pickupNode == nil {
        let variant = (pickup.id % 3) + 1
        let node = SKSpriteNode(texture: AssetLoader.texture("sweet\(variant)"))
        node.size = GameplayArtworkMetrics(sceneSize: size).sweetSize
        node.position = scenePoint(pickup.position)
        node.zPosition = 8
        world.addChild(node)
        pickupNode = node
      }
    } else if let existing = pickupNode {
      existing.removeFromParent()
      pickupNode = nil
    }
  }

  private func renderAuthoritativeState() {
    phantom.position = scenePoint(simulation.state.ghost.position)
    for pumpkin in simulation.state.pumpkins {
      pumpkinNodes[pumpkin.id]?.position = scenePoint(pumpkin.position)
    }
    if let pickup = simulation.state.pickup { pickupNode?.position = scenePoint(pickup.position) }
    scoreLabel.text = "Score: \(simulation.state.session.score)"
    livesLabel.text = "Lives: \(simulation.state.session.lives)"
    slicesLabel.text = "Dashes: \(simulation.state.session.slices)"
    boomsLabel.text = "Shrieks: \(simulation.state.session.booms)"
    let state = simulation.state
    AudioManager.shared.setIntensity(
      state.frenzyTicksRemaining > 0 ? 1 : min(0.9, Double(state.waveIndex) / 18)
    )
    if state.frenzyTicksRemaining > 0 {
      statusLabel.text = "FRENZY x2"
      statusLabel.fontColor = .yellow
    } else if let ticks = state.remainingTicks {
      let seconds = Int(ceil(Double(ticks) / Double(simulation.configuration.ticksPerSecond)))
      statusLabel.text = "MOON RUSH  •  \(seconds)s"
      statusLabel.fontColor = .white
    } else {
      statusLabel.text = "WAVE \(max(1, state.waveIndex))  •  \(modeTitle(state.mode))"
      statusLabel.fontColor = .white
    }
  }

  private func handle(_ events: [GameEvent]) {
    for event in events {
      handleCombatEvent(event)
      handlePacingEvent(event)
    }
  }

  private func handleCombatEvent(_ event: GameEvent) {
    switch event {
    case .destroyed(let id, let combo, let points):
      guard let node = pumpkinNodes[id] else { return }
      let label =
        combo >= 3
        ? "\(combo)x COMBO!  +\(points)" : combo == 2 ? "2x COMBO!  +\(points)" : "+\(points)"
      showCallout(label, at: node.position, color: combo >= 3 ? .yellow : .orange)
      burst(at: node.position, color: .orange, identity: id)
      pumpkinFragments(at: node.position, identity: id)
      juiceSplatter(at: node.position, identity: id)
      AudioManager.shared.play("slice", enabled: settings.effectsEnabled)
      provideSuccessFeedback(combo: combo)
    case .damaged(let id, _):
      let position = pumpkinNodes[id]?.position ?? phantom.position
      showCallout("OUCH!", at: position, color: .red)
      burst(at: position, color: .red, identity: id)
      AudioManager.shared.play("bow_wah", enabled: settings.effectsEnabled)
      provideHitFeedback()
      impactFlash(color: .red)
      phantom.run(
        .sequence([
          .scale(to: 0.84, duration: 0.05),
          .scale(to: 1.12, duration: 0.09),
          .scale(to: 1, duration: 0.12),
        ]),
        withKey: "impact"
      )
      if settings.screenShakeEnabled, !shouldReduceMotion {
        phantom.run(
          .sequence([
            .moveBy(x: -7, y: 0, duration: 0.04),
            .moveBy(x: 14, y: 0, duration: 0.08),
            .moveBy(x: -7, y: 0, duration: 0.04),
          ]))
      }
    case .armoredHit(let id, let remaining):
      guard let node = pumpkinNodes[id] else { return }
      showCallout("CRACK!  \(remaining) HIT", at: node.position, color: .cyan)
      node.run(.sequence([.scale(to: 1.18, duration: 0.06), .scale(to: 1, duration: 0.1)]))
      AudioManager.shared.play("bow_wah", enabled: settings.effectsEnabled)
    case .cursedTriggered(let id, _):
      let position = pumpkinNodes[id]?.position ?? phantom.position
      showCallout("CURSED!", at: position, color: .purple)
      burst(at: position, color: .purple, identity: id)
      AudioManager.shared.play("explode", enabled: settings.effectsEnabled)
      provideHitFeedback()
    case .nearMiss(let id, let points):
      let position = pumpkinNodes[id]?.position ?? phantom.position
      showCallout("NEAR MISS +\(points)", at: position, color: .cyan)
    default:
      break
    }
  }

  private func handlePacingEvent(_ event: GameEvent) {
    switch event {
    case .pickupCollected(let id, _, let points):
      let position = pickupNode?.position ?? phantom.position
      showCallout("SWEET +\(points)", at: position, color: .yellow)
      burst(at: position, color: .yellow, identity: id)
      AudioManager.shared.play("ding", enabled: settings.effectsEnabled)
      provideSuccessFeedback(combo: 1)
    case .waveStarted(let index, let pattern):
      let title = pattern == .breathingSpace ? "BREATHE" : "WAVE \(index)"
      showCallout(title, at: CGPoint(x: size.width / 2, y: size.height * 0.68), color: .white)
    case .frenzyStarted:
      showCallout(
        "FRENZY x2!", at: CGPoint(x: size.width / 2, y: size.height * 0.58), color: .yellow)
      AudioManager.shared.play("ding", enabled: settings.effectsEnabled)
      impactFlash(color: .yellow)
    case .lastChance:
      showCallout(
        "LAST CHANCE!", at: CGPoint(x: size.width / 2, y: size.height * 0.5), color: .red)
    case .dashed(let from, let to):
      drawBladeTrail(from: scenePoint(from), to: scenePoint(to))
    case .shrieked(let origin, let count):
      guard count > 0 else { return }
      showCallout("SHRIEK x\(count)!", at: scenePoint(origin), color: .yellow)
      AudioManager.shared.play("explode", enabled: settings.effectsEnabled)
    case .paused:
      pauseChangedHandler?(true)
      showCallout("PAUSED", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .white)
    case .resumed:
      pauseChangedHandler?(false)
      showCallout("READY!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .white)
    case .gameOver(let score):
      finishGame(score: score)
    default:
      break
    }
  }

  private func finishGame(score: Int) {
    guard !gameEnded else { return }
    gameEnded = true
    stopMotionUpdates()
    AudioManager.shared.stopMusic()
    AudioManager.shared.play("female_scream", enabled: settings.effectsEnabled)
    challengeHandler?(
      RaidChallenge(
        seed: simulation.state.seed,
        mode: simulation.state.mode,
        targetScore: score,
        replayDigest: simulation.digest
      )
    )
    run(
      .sequence([
        .wait(forDuration: 0.6),
        .run { [weak self] in
          guard let self else { return }
          self.gameOverHandler?(self.runSummary(score: score))
        },
      ]))
  }

  func requestPause() {
    guard !simulation.state.isPaused else { return }
    inputRouter.enqueue(.pause)
  }

  func applySystemAccessibility(reduceMotion: Bool, highContrast: Bool) {
    systemReducedMotion = reduceMotion
    systemHighContrast = highContrast
    hudBackground.fillColor = SKColor.black.withAlphaComponent(shouldUseHighContrast ? 0.92 : 0.68)
    hudBackground.strokeColor = SKColor.orange.withAlphaComponent(shouldUseHighContrast ? 1 : 0.75)
  }

  func requestResume() {
    guard simulation.state.isPaused else { return }
    inputRouter.enqueue(.resume)
  }

  func abandonRun() {
    guard !gameEnded else { return }
    gameEnded = true
    stopMotionUpdates()
    AudioManager.shared.stopMusic()
    gameOverHandler?(runSummary(score: simulation.state.session.score))
  }

  private func runSummary(score: Int) -> RunSummary {
    RunSummary(
      mode: simulation.state.mode,
      score: score,
      statistics: simulation.state.statistics,
      durationTicks: simulation.state.tick,
      replayDigest: simulation.digest,
      assisted: settings.assistModeEnabled
    )
  }

  #if os(iOS) || os(tvOS)
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      var handled = false
      for press in presses where press.key != nil {
        updateDigitalKey(press.key!.keyCode, isPressed: true)
        handled = true
      }
      if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      var handled = false
      for press in presses where press.key != nil {
        updateDigitalKey(press.key!.keyCode, isPressed: false)
        handled = true
      }
      if !handled { super.pressesEnded(presses, with: event) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else { return }
      beginGesture(at: touch.location(in: self), timestamp: touch.timestamp)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      for touch in touches {
        moveGesture(to: touch.location(in: self))
      }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else { return }
      endGesture(at: touch.location(in: self), timestamp: touch.timestamp)
    }
  #endif
}
