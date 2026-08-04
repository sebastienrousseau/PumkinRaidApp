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
struct CosmeticLoadout: Equatable {
  var ghostID = "ghost.classic"
  var trailID = "trail.moonlight"
  var auraID = "aura.none"
}

struct GameplayArtworkMetrics: Equatable {
  let scale: CGFloat

  init(sceneSize: CGSize) {
    scale = min(
      2.65,
      max(0.95, min(sceneSize.width / 390, sceneSize.height / 600) * 1.12)
    )
  }

  var ghostSize: CGSize { CGSize(width: 72 * scale, height: 76 * scale) }
  var sweetSize: CGSize { CGSize(width: 50 * scale, height: 50 * scale) }

  func pumpkinSize(radiusScale: CGFloat) -> CGSize {
    CGSize(width: 71 * radiusScale * scale, height: 61 * radiusScale * scale)
  }
}

@MainActor
final class GameScene: SKScene {
  static let maximumTransientEffects = 96
  var gameOverHandler: ((RunSummary) -> Void)?
  var challengeHandler: ((RaidChallenge) -> Void)?
  var pauseChangedHandler: ((Bool) -> Void)?
  var authoritativeState: GameState { simulation.state }

  private let settings: GameSettings
  private let cosmetics: CosmeticLoadout
  private var simulation: GameSimulation
  private let world = SKNode()
  private let effectsLayer = SKNode()
  private let atmosphere = SKShapeNode()
  private let phantom = SKSpriteNode(texture: AssetLoader.texture("phantom"))
  private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let slicesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let boomsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
  private let hudBackground = SKShapeNode()
  private var pumpkinNodes: [Int: SKSpriteNode] = [:]
  private var pickupNode: SKSpriteNode?
  private var lastUpdateTime: TimeInterval = 0
  private var accumulatedTime: TimeInterval = 0
  private var inputRouter = SemanticInputRouter()
  private var gestureLastPoint: CGPoint?
  private var draggingPhantom = false
  private var gameEnded = false
  private var systemReducedMotion = false
  private var systemHighContrast = false
  #if os(iOS)
    private let motionManager = CMMotionManager()
    private var motionIntent = Vector2.zero
  #endif

  private var spriteScale: CGFloat {
    GameplayArtworkMetrics(sceneSize: size).scale
  }
  private var fixedDelta: TimeInterval {
    1 / Double(simulation.configuration.ticksPerSecond)
  }
  private var shouldReduceMotion: Bool { settings.reducedMotionEnabled || systemReducedMotion }
  private var shouldUseHighContrast: Bool { settings.highContrastEnabled || systemHighContrast }

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
    guard children.isEmpty else { return }
    addChild(world)
    addChild(effectsLayer)
    buildBackground()
    buildAtmosphere()
    buildHUD()
    buildPhantom()
    syncNodesWithSimulation()
    renderAuthoritativeState()
  }

  override func didChangeSize(_ oldSize: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    if let background = childNode(withName: "//background") as? SKSpriteNode {
      background.texture = AssetLoader.texture(backgroundAssetName)
      background.position = CGPoint(x: size.width / 2, y: size.height / 2)
      resizeBackground(background)
    }
    atmosphere.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    layoutHUD()
    phantom.size = GameplayArtworkMetrics(sceneSize: size).ghostSize
    for node in pumpkinNodes.values { resizePumpkin(node) }
    pickupNode?.size = GameplayArtworkMetrics(sceneSize: size).sweetSize
    renderAuthoritativeState()
  }

  override func update(_ currentTime: TimeInterval) {
    guard !gameEnded else { return }
    if lastUpdateTime == 0 {
      lastUpdateTime = currentTime
      return
    }
    accumulatedTime += min(0.1, max(0, currentTime - lastUpdateTime))
    lastUpdateTime = currentTime

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

  private var backgroundAssetName: String {
    let aspectRatio = size.width / max(1, size.height)
    return aspectRatio >= 1.15
      ? "background-wide" : (aspectRatio >= 0.7 ? "background-tablet" : "background")
  }

  private func buildBackground() {
    let background = SKSpriteNode(texture: AssetLoader.texture(backgroundAssetName))
    background.name = "background"
    background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    background.zPosition = -10
    resizeBackground(background)
    world.addChild(background)
  }

  private func buildAtmosphere() {
    atmosphere.name = "mode-atmosphere"
    atmosphere.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
    atmosphere.strokeColor = .clear
    atmosphere.zPosition = -5
    switch simulation.state.mode {
    case .classicRaid:
      atmosphere.fillColor = .clear
    case .moonRush:
      atmosphere.fillColor = SKColor(red: 1, green: 0.36, blue: 0.04, alpha: 0.08)
    case .spiritZen:
      atmosphere.fillColor = SKColor(red: 0.12, green: 0.72, blue: 0.94, alpha: 0.08)
    case .dailyHaunt:
      atmosphere.fillColor = SKColor(red: 0.52, green: 0.14, blue: 0.82, alpha: 0.1)
    case .bossRaid:
      atmosphere.fillColor = SKColor(red: 0.72, green: 0.02, blue: 0.02, alpha: 0.14)
    }
    world.addChild(atmosphere)
    guard !shouldReduceMotion, simulation.state.mode != .classicRaid else { return }
    atmosphere.run(
      .repeatForever(
        .sequence([
          .fadeAlpha(to: 0.45, duration: 1.2),
          .fadeAlpha(to: 1, duration: 1.2),
        ])
      )
    )
  }

  private func resizeBackground(_ background: SKSpriteNode) {
    let textureSize = background.texture?.size() ?? size
    guard textureSize.width > 0, textureSize.height > 0 else {
      background.size = size
      return
    }
    let scale = max(size.width / textureSize.width, size.height / textureSize.height)
    background.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
  }

  private func buildHUD() {
    hudBackground.name = "hud-background"
    hudBackground.fillColor = SKColor.black.withAlphaComponent(shouldUseHighContrast ? 0.92 : 0.68)
    hudBackground.strokeColor = SKColor.orange.withAlphaComponent(shouldUseHighContrast ? 1 : 0.75)
    hudBackground.lineWidth = 1.5
    hudBackground.zPosition = 19
    addChild(hudBackground)
    for label in [scoreLabel, livesLabel, slicesLabel, boomsLabel] {
      label.fontColor = .orange
      label.horizontalAlignmentMode = .center
      label.verticalAlignmentMode = .center
      label.zPosition = 20
      addChild(label)
    }
    scoreLabel.name = "hud-score"
    livesLabel.name = "hud-lives"
    slicesLabel.name = "hud-dashes"
    boomsLabel.name = "hud-shrieks"
    statusLabel.fontColor = .white
    statusLabel.horizontalAlignmentMode = .center
    statusLabel.verticalAlignmentMode = .center
    statusLabel.zPosition = 20
    addChild(statusLabel)
    layoutHUD()
  }

  private func layoutHUD() {
    let inset = min(52, max(20, size.width * 0.08))
    let panelWidth = min(760, max(240, size.width - inset * 2))
    let panelHeight: CGFloat = 66
    let topMargin = max(68, min(88, size.height * 0.12))
    let centerY = size.height - topMargin
    hudBackground.path = CGPath(
      roundedRect: CGRect(
        x: -panelWidth / 2,
        y: -panelHeight / 2,
        width: panelWidth,
        height: panelHeight
      ),
      cornerWidth: 13,
      cornerHeight: 13,
      transform: nil
    )
    hudBackground.position = CGPoint(x: size.width / 2, y: centerY)
    let leftX = size.width / 2 - panelWidth * 0.25
    let rightX = size.width / 2 + panelWidth * 0.25
    let fontSize = min(20, max(13, panelWidth * 0.024))
    for label in [scoreLabel, livesLabel, slicesLabel, boomsLabel] { label.fontSize = fontSize }
    scoreLabel.position = CGPoint(x: leftX, y: centerY + 15)
    livesLabel.position = CGPoint(x: leftX, y: centerY - 15)
    slicesLabel.position = CGPoint(x: rightX, y: centerY + 15)
    boomsLabel.position = CGPoint(x: rightX, y: centerY - 15)
    statusLabel.fontSize = min(15, max(11, panelWidth * 0.019))
    statusLabel.position = CGPoint(x: size.width / 2, y: centerY - panelHeight / 2 - 14)
  }

  private func buildPhantom() {
    phantom.name = "phantom"
    phantom.size = GameplayArtworkMetrics(sceneSize: size).ghostSize
    phantom.zPosition = 5
    switch cosmetics.ghostID {
    case "ghost.frost":
      phantom.color = SKColor(red: 0.42, green: 0.86, blue: 1, alpha: 1)
      phantom.colorBlendFactor = 0.32
    case "ghost.king":
      phantom.color = SKColor(red: 1, green: 0.76, blue: 0.2, alpha: 1)
      phantom.colorBlendFactor = 0.28
    default:
      phantom.colorBlendFactor = 0
    }
    world.addChild(phantom)
    if cosmetics.auraID == "aura.frenzy" {
      let aura = SKShapeNode(circleOfRadius: 46 * spriteScale)
      aura.name = "phantom-aura"
      aura.fillColor = SKColor(red: 1, green: 0.46, blue: 0.04, alpha: 0.12)
      aura.strokeColor = SKColor(red: 1, green: 0.72, blue: 0.18, alpha: 0.82)
      aura.glowWidth = 14
      aura.zPosition = -1
      phantom.addChild(aura)
      guard shouldReduceMotion else {
        aura.run(
          .repeatForever(
            .sequence([
              .scale(to: 1.13, duration: 0.52),
              .scale(to: 0.94, duration: 0.52),
            ])
          )
        )
        return
      }
    }
    guard !shouldReduceMotion else { return }
    phantom.run(
      .repeatForever(
        .sequence([
          .scale(to: 1.025, duration: 0.7),
          .scale(to: 0.985, duration: 0.7),
        ])
      ),
      withKey: "idle"
    )
  }

  private func syncNodesWithSimulation() {
    let liveIDs = Set(simulation.state.pumpkins.map(\.id))
    for id in pumpkinNodes.keys.filter({ !liveIDs.contains($0) }) {
      pumpkinNodes.removeValue(forKey: id)?.removeFromParent()
    }
    for pumpkin in simulation.state.pumpkins where pumpkinNodes[pumpkin.id] == nil {
      let textures = (1...3).map { AssetLoader.texture("pumpkin\($0)") }
      let node = SKSpriteNode(texture: textures[0])
      node.name = "pumpkin-\(pumpkin.id)"
      node.userData = ["scale": pumpkin.radius / 0.04]
      node.zPosition = 3
      switch pumpkin.kind {
      case .target:
        node.colorBlendFactor = 0
      case .armored:
        node.color = SKColor(red: 0.42, green: 0.49, blue: 0.58, alpha: 1)
        node.colorBlendFactor = 0.48
      case .cursed:
        node.color = SKColor(red: 0.55, green: 0.12, blue: 0.72, alpha: 1)
        node.colorBlendFactor = 0.64
      }
      resizePumpkin(node)
      node.run(.repeatForever(.animate(with: textures, timePerFrame: 0.17)), withKey: "animation")
      world.addChild(node)
      pumpkinNodes[pumpkin.id] = node
    }
    if let pickup = simulation.state.pickup {
      if pickupNode?.userData?["id"] as? Int != pickup.id {
        pickupNode?.removeFromParent()
        let prefix = pickup.kind == 0 ? "" : "\(pickup.kind + 1)"
        let textures = (1...3).map { AssetLoader.texture("\(prefix)sweet\($0)") }
        let node = SKSpriteNode(texture: textures[0])
        node.name = "pickup-\(pickup.id)"
        node.userData = ["id": pickup.id]
        node.size = GameplayArtworkMetrics(sceneSize: size).sweetSize
        node.zPosition = 4
        node.run(.repeatForever(.animate(with: textures, timePerFrame: 0.2)))
        world.addChild(node)
        pickupNode = node
      }
    } else {
      pickupNode?.removeFromParent()
      pickupNode = nil
    }
  }

  private func resizePumpkin(_ node: SKSpriteNode) {
    let scale = node.userData?["scale"] as? Double ?? 1
    node.size = GameplayArtworkMetrics(sceneSize: size).pumpkinSize(radiusScale: CGFloat(scale))
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
      switch event {
      case .destroyed(let id, let combo, let points):
        guard let node = pumpkinNodes[id] else { continue }
        let label = combo > 1 ? "DASH x\(combo)  +\(points)" : "DASH!"
        showCallout(label, at: node.position, color: .orange)
        burst(at: node.position, color: .orange, identity: id)
        pumpkinFragments(at: node.position, identity: id)
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
        guard let node = pumpkinNodes[id] else { continue }
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
        guard count > 0 else { continue }
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
      case .spawned, .avoided, .pickupSpawned, .pickupMissed:
        break
      }
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

  private func showCallout(_ text: String, at position: CGPoint, color: SKColor) {
    let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    label.text = text
    label.fontSize = min(28, max(18, size.width * 0.05))
    label.fontColor = color
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    label.position = position
    label.zPosition = 30
    addTransientEffect(label)
    if shouldReduceMotion {
      label.run(
        .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.18), .removeFromParent()]))
    } else {
      label.run(
        .sequence([
          .group([.moveBy(x: 0, y: 70, duration: 0.7), .fadeOut(withDuration: 0.7)]),
          .removeFromParent(),
        ]))
    }
  }

  private func drawBladeTrail(from start: CGPoint, to end: CGPoint) {
    let path = CGMutablePath()
    path.move(to: start)
    path.addLine(to: end)
    let trail = SKShapeNode(path: path)
    trail.strokeColor = trailColor
    trail.glowWidth = 7
    trail.lineWidth = 4
    trail.zPosition = 40
    addTransientEffect(trail)
    trail.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
  }

  private var trailColor: SKColor {
    switch cosmetics.trailID {
    case "trail.ember": SKColor(red: 1, green: 0.34, blue: 0.04, alpha: 0.98)
    case "trail.cursed": SKColor(red: 0.72, green: 0.22, blue: 1, alpha: 0.98)
    default: SKColor(red: 0.55, green: 0.92, blue: 1, alpha: 0.95)
    }
  }

  private func pumpkinFragments(at point: CGPoint, identity: Int) {
    guard !shouldReduceMotion else { return }
    for index in 0..<2 {
      let fragment = SKSpriteNode(texture: AssetLoader.texture("pumpkin_piece\(index + 1)"))
      fragment.size = CGSize(width: 34 * spriteScale, height: 48 * spriteScale)
      fragment.position = point
      fragment.zPosition = 18
      addTransientEffect(fragment)
      let direction: CGFloat = index == 0 ? -1 : 1
      fragment.run(
        .sequence([
          .group([
            .moveBy(x: direction * CGFloat(52 + identity % 24), y: 36, duration: 0.34),
            .rotate(byAngle: direction * .pi * 1.2, duration: 0.34),
            .fadeOut(withDuration: 0.34),
          ]),
          .removeFromParent(),
        ])
      )
    }
  }

  private func impactFlash(color: SKColor) {
    let flash = SKShapeNode(rectOf: size)
    flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
    flash.fillColor = color.withAlphaComponent(0.16)
    flash.strokeColor = .clear
    flash.zPosition = 90
    addTransientEffect(flash)
    flash.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
  }

  private func burst(at point: CGPoint, color: SKColor, identity: Int) {
    guard !shouldReduceMotion else { return }
    for index in 0..<14 {
      let particle = SKShapeNode(circleOfRadius: CGFloat(2 + (index % 5)))
      particle.fillColor = color
      particle.strokeColor = .clear
      particle.position = point
      particle.zPosition = 15
      addTransientEffect(particle)
      let angle = CGFloat((identity * 31 + index * 137) % 360) * .pi / 180
      let speed = CGFloat(55 + (identity * 17 + index * 23) % 70)
      particle.run(
        .sequence([
          .group([
            .move(by: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed), duration: 0.45),
            .fadeOut(withDuration: 0.45),
          ]),
          .removeFromParent(),
        ]))
    }
  }

  private func addTransientEffect(_ node: SKNode) {
    while effectsLayer.children.count >= Self.maximumTransientEffects {
      effectsLayer.children.first?.removeFromParent()
    }
    effectsLayer.addChild(node)
    assert(effectsLayer.children.count <= Self.maximumTransientEffects)
  }

  private func continuousInputFrame() -> InputFrame {
    #if os(macOS)
      let keyboard = KeyboardState.shared
      inputRouter.set(.left, pressed: keyboard.isPressed(123) || keyboard.isPressed(0))
      inputRouter.set(.right, pressed: keyboard.isPressed(124) || keyboard.isPressed(2))
      inputRouter.set(.down, pressed: keyboard.isPressed(125) || keyboard.isPressed(1))
      inputRouter.set(.up, pressed: keyboard.isPressed(126) || keyboard.isPressed(13))
      for action in keyboard.consumeActions() {
        switch action {
        case .dash:
          inputRouter.set(.dash, pressed: false)
          inputRouter.set(.dash, pressed: true)
        case .shriek:
          inputRouter.set(.shriek, pressed: false)
          inputRouter.set(.shriek, pressed: true)
        case .pause:
          inputRouter.set(.pause, pressed: false)
          inputRouter.set(.pause, pressed: true)
        }
      }
    #elseif os(iOS)
      if abs(motionIntent.x) > 0.01 || abs(motionIntent.y) > 0.01 {
        inputRouter.enqueue(.move(x: motionIntent.x, y: motionIntent.y))
      }
    #elseif os(tvOS)
      var x = 0.0
      var y = 0.0
      if let gamepad = GCController.current?.extendedGamepad {
        x += Double(gamepad.leftThumbstick.xAxis.value + gamepad.dpad.xAxis.value)
        y -= Double(gamepad.leftThumbstick.yAxis.value + gamepad.dpad.yAxis.value)
        inputRouter.set(.dash, pressed: gamepad.buttonA.isPressed)
        inputRouter.set(.shriek, pressed: gamepad.buttonB.isPressed)
      } else if let gamepad = GCController.current?.microGamepad {
        x += Double(gamepad.dpad.xAxis.value)
        y -= Double(gamepad.dpad.yAxis.value)
      }
      inputRouter.set(.left, pressed: x < -0.08)
      inputRouter.set(.right, pressed: x > 0.08)
      inputRouter.set(.up, pressed: y < -0.08)
      inputRouter.set(.down, pressed: y > 0.08)
    #endif
    return inputRouter.nextFrame()
  }

  private func beginGesture(at point: CGPoint, timestamp: TimeInterval) {
    gestureLastPoint = point
    // Direct manipulation begins anywhere in the arena. A stationary press still
    // becomes a shriek in SemanticInputRouter, while a drag steers the ghost and
    // a fast swipe becomes a dash. This avoids tiny moving hit targets on touch.
    draggingPhantom = true
    inputRouter.beginPointer(
      at: normalizedPoint(point),
      timestamp: timestamp,
      controlsGhost: true
    )
  }

  /// Semantic pointer entry point shared by the macOS event bridge and tests.
  /// Keeping this independent of an attached `SKView` protects drag controls
  /// against responder-chain regressions.
  func pointerDown(at scenePoint: CGPoint, timestamp: TimeInterval) {
    beginGesture(at: scenePoint, timestamp: timestamp)
  }

  func pointerDragged(to scenePoint: CGPoint) {
    moveGesture(to: scenePoint)
  }

  func pointerUp(at scenePoint: CGPoint, timestamp: TimeInterval) {
    endGesture(at: scenePoint, timestamp: timestamp)
  }

  private func moveGesture(to point: CGPoint) {
    if draggingPhantom {
      inputRouter.movePointer(to: normalizedPoint(point))
      if let previous = gestureLastPoint { drawBladeTrail(from: previous, to: point) }
    }
    gestureLastPoint = point
  }

  private func endGesture(at point: CGPoint, timestamp: TimeInterval) {
    defer {
      gestureLastPoint = nil
      draggingPhantom = false
    }
    inputRouter.endPointer(at: normalizedPoint(point), timestamp: timestamp)
  }

  private func normalizedPoint(_ point: CGPoint) -> Vector2 {
    Vector2(
      x: Double(min(1, max(0, point.x / max(1, size.width)))),
      y: Double(min(1, max(0, 1 - point.y / max(1, size.height))))
    )
  }

  private func scenePoint(_ point: Vector2) -> CGPoint {
    CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(1 - point.y) * size.height)
  }

  private func modeTitle(_ mode: GameMode) -> String {
    switch mode {
    case .classicRaid: "CLASSIC"
    case .moonRush: "MOON RUSH"
    case .spiritZen: "ZEN"
    case .dailyHaunt: "DAILY"
    case .bossRaid: "BOSS"
    }
  }

  func movePhantom(horizontal: CGFloat, vertical: CGFloat) {
    let current = simulation.state.ghost.position
    inputRouter.enqueue(
      .moveTo(
        x: current.x + Double(horizontal / max(1, size.width)),
        y: current.y - Double(vertical / max(1, size.height))
      ))
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
    private func updateDigitalKey(_ keyCode: UIKeyboardHIDUsage, isPressed: Bool) {
      switch keyCode {
      case .keyboardLeftArrow, .keyboardA: inputRouter.set(.left, pressed: isPressed)
      case .keyboardRightArrow, .keyboardD: inputRouter.set(.right, pressed: isPressed)
      case .keyboardUpArrow, .keyboardW: inputRouter.set(.up, pressed: isPressed)
      case .keyboardDownArrow, .keyboardS: inputRouter.set(.down, pressed: isPressed)
      case .keyboardSpacebar where isPressed:
        inputRouter.set(.dash, pressed: false)
        inputRouter.set(.dash, pressed: true)
      case .keyboardReturnOrEnter where isPressed:
        inputRouter.set(.shriek, pressed: false)
        inputRouter.set(.shriek, pressed: true)
      case .keyboardEscape where isPressed:
        inputRouter.set(.pause, pressed: false)
        inputRouter.set(.pause, pressed: true)
      default: break
      }
    }

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
      guard let touch = touches.first else { return }
      moveGesture(to: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else { return }
      endGesture(at: touch.location(in: self), timestamp: touch.timestamp)
    }
  #endif

  func startMotionUpdates() {
    #if os(iOS)
      guard settings.tiltControlsEnabled, motionManager.isAccelerometerAvailable else { return }
      motionManager.accelerometerUpdateInterval = 1 / 60
      motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let self, let acceleration = data?.acceleration, !self.draggingPhantom else { return }
        self.motionIntent = Vector2(x: acceleration.x * 0.7, y: acceleration.y * 0.5)
      }
    #endif
  }

  func stopMotionUpdates() {
    #if os(iOS)
      motionManager.stopAccelerometerUpdates()
      motionIntent = .zero
    #endif
  }

  private func provideHitFeedback() {
    #if os(iOS)
      guard settings.vibrationEnabled else { return }
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    #endif
  }

  private func provideSuccessFeedback(combo: Int) {
    guard settings.vibrationEnabled else { return }
    #if os(iOS)
      UIImpactFeedbackGenerator(style: combo >= 4 ? .heavy : .light).impactOccurred(
        intensity: combo >= 4 ? 0.9 : 0.55
      )
    #endif
  }

  #if os(macOS)
    func handleApplicationPointerEvent(_ event: NSEvent) -> Bool {
      guard let view, event.window === view.window else { return false }
      let point = convertPoint(fromView: view.convert(event.locationInWindow, from: nil))
      switch event.type {
      case .leftMouseDown: pointerDown(at: point, timestamp: event.timestamp)
      case .leftMouseDragged: pointerDragged(to: point)
      case .leftMouseUp: pointerUp(at: point, timestamp: event.timestamp)
      default: return false
      }
      return true
    }

    func handlePointerDown(at viewPoint: CGPoint) {
      pointerDown(
        at: convertPoint(fromView: viewPoint), timestamp: ProcessInfo.processInfo.systemUptime)
    }

    func handlePointerDragged(to viewPoint: CGPoint) {
      pointerDragged(to: convertPoint(fromView: viewPoint))
    }

    func handlePointerUp(at viewPoint: CGPoint) {
      pointerUp(
        at: convertPoint(fromView: viewPoint), timestamp: ProcessInfo.processInfo.systemUptime)
    }
  #endif
}
