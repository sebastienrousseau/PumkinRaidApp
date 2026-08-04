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
  var gameOverHandler: ((Int) -> Void)?

  private let settings: GameSettings
  private var simulation: GameSimulation
  private let world = SKNode()
  private let phantom = SKSpriteNode(texture: AssetLoader.texture("phantom"))
  private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let slicesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let boomsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let hudBackground = SKShapeNode()
  private var pumpkinNodes: [Int: SKSpriteNode] = [:]
  private var lastUpdateTime: TimeInterval = 0
  private var accumulatedTime: TimeInterval = 0
  private var pendingActions: [InputAction] = []
  private var directTarget: Vector2?
  private var gestureStart: CGPoint?
  private var gestureStartTime: TimeInterval = 0
  private var gestureLastPoint: CGPoint?
  private var draggingPhantom = false
  private var gameEnded = false
  #if os(iOS)
    private let motionManager = CMMotionManager()
    private var motionIntent = Vector2.zero
  #endif
  #if os(iOS) || os(tvOS)
    private var digitalHorizontal = 0.0
    private var digitalVertical = 0.0
  #endif
  #if os(tvOS)
    private var controllerDashPressed = false
    private var controllerShriekPressed = false
  #endif

  private var spriteScale: CGFloat {
    min(1.65, max(0.78, min(size.width / 430, size.height / 720)))
  }
  private var fixedDelta: TimeInterval {
    1 / Double(simulation.configuration.ticksPerSecond)
  }

  init(settings: GameSettings, seed: UInt64? = nil) {
    self.settings = settings
    let runSeed = seed
      ?? UInt64(Date().timeIntervalSince1970 * 1_000_000) ^ UInt64.random(in: .min ... .max)
    simulation = GameSimulation(seed: runSeed)
    super.init(size: CGSize(width: 320, height: 568))
    scaleMode = .resizeFill
    backgroundColor = .black
  }

  required init?(coder: NSCoder) { nil }

  override func didMove(to view: SKView) {
    guard children.isEmpty else { return }
    addChild(world)
    buildBackground()
    buildHUD()
    buildPhantom()
    syncNodesWithSimulation()
    renderAuthoritativeState()
    startMotionUpdates()
    AudioManager.shared.play("creaking_door", enabled: settings.effectsEnabled)
    #if os(macOS)
      DispatchQueue.main.async {
        view.window?.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
      }
    #endif
  }

  override func didChangeSize(_ oldSize: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    if let background = childNode(withName: "//background") as? SKSpriteNode {
      background.texture = AssetLoader.texture(backgroundAssetName)
      background.position = CGPoint(x: size.width / 2, y: size.height / 2)
      resizeBackground(background)
    }
    layoutHUD()
    phantom.size = CGSize(width: 72 * spriteScale, height: 76 * spriteScale)
    for node in pumpkinNodes.values { resizePumpkin(node) }
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

    var steps = 0
    while accumulatedTime >= fixedDelta, steps < 6 {
      var actions = continuousInputActions()
      actions.append(contentsOf: pendingActions)
      pendingActions.removeAll(keepingCapacity: true)
      let events = simulation.step(InputFrame(actions: actions))
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
    hudBackground.fillColor = SKColor.black.withAlphaComponent(0.68)
    hudBackground.strokeColor = SKColor.orange.withAlphaComponent(0.75)
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
    layoutHUD()
  }

  private func layoutHUD() {
    let inset = min(52, max(20, size.width * 0.08))
    let panelWidth = max(240, size.width - inset * 2)
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
    let fontSize = min(18, max(12, size.width * 0.035))
    for label in [scoreLabel, livesLabel, slicesLabel, boomsLabel] { label.fontSize = fontSize }
    scoreLabel.position = CGPoint(x: leftX, y: centerY + 15)
    livesLabel.position = CGPoint(x: leftX, y: centerY - 15)
    slicesLabel.position = CGPoint(x: rightX, y: centerY + 15)
    boomsLabel.position = CGPoint(x: rightX, y: centerY - 15)
  }

  private func buildPhantom() {
    phantom.name = "phantom"
    phantom.size = CGSize(width: 72 * spriteScale, height: 76 * spriteScale)
    phantom.zPosition = 5
    world.addChild(phantom)
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
      resizePumpkin(node)
      node.run(.repeatForever(.animate(with: textures, timePerFrame: 0.17)), withKey: "animation")
      world.addChild(node)
      pumpkinNodes[pumpkin.id] = node
    }
  }

  private func resizePumpkin(_ node: SKSpriteNode) {
    let scale = node.userData?["scale"] as? Double ?? 1
    node.size = CGSize(
      width: 71 * CGFloat(scale) * spriteScale,
      height: 61 * CGFloat(scale) * spriteScale
    )
  }

  private func renderAuthoritativeState() {
    phantom.position = scenePoint(simulation.state.ghost.position)
    for pumpkin in simulation.state.pumpkins {
      pumpkinNodes[pumpkin.id]?.position = scenePoint(pumpkin.position)
    }
    scoreLabel.text = "Score: \(simulation.state.session.score)"
    livesLabel.text = "Lives: \(simulation.state.session.lives)"
    slicesLabel.text = "Dashes: \(simulation.state.session.slices)"
    boomsLabel.text = "Shrieks: \(simulation.state.session.booms)"
  }

  private func handle(_ events: [GameEvent]) {
    for event in events {
      switch event {
      case let .destroyed(id, combo, points):
        guard let node = pumpkinNodes[id] else { continue }
        let label = combo > 1 ? "DASH x\(combo)  +\(points)" : "DASH!"
        showCallout(label, at: node.position, color: .orange)
        burst(at: node.position, color: .orange, identity: id)
        AudioManager.shared.play("slice", enabled: settings.effectsEnabled)
      case let .damaged(id, _):
        let position = pumpkinNodes[id]?.position ?? phantom.position
        showCallout("OUCH!", at: position, color: .red)
        burst(at: position, color: .red, identity: id)
        AudioManager.shared.play("bow_wah", enabled: settings.effectsEnabled)
        provideHitFeedback()
        phantom.run(
          .sequence([
            .moveBy(x: -7, y: 0, duration: 0.04),
            .moveBy(x: 14, y: 0, duration: 0.08),
            .moveBy(x: -7, y: 0, duration: 0.04),
          ]))
      case let .dashed(from, to):
        drawBladeTrail(from: scenePoint(from), to: scenePoint(to))
      case let .shrieked(origin, count):
        guard count > 0 else { continue }
        showCallout("SHRIEK x\(count)!", at: scenePoint(origin), color: .yellow)
        AudioManager.shared.play("explode", enabled: settings.effectsEnabled)
      case .paused:
        showCallout("PAUSED", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .white)
      case .resumed:
        showCallout("READY!", at: CGPoint(x: size.width / 2, y: size.height / 2), color: .white)
      case let .gameOver(score):
        finishGame(score: score)
      case .spawned, .avoided:
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
    run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.gameOverHandler?(score) }]))
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
    addChild(label)
    label.run(
      .sequence([
        .group([.moveBy(x: 0, y: 70, duration: 0.7), .fadeOut(withDuration: 0.7)]),
        .removeFromParent(),
      ]))
  }

  private func drawBladeTrail(from start: CGPoint, to end: CGPoint) {
    let path = CGMutablePath()
    path.move(to: start)
    path.addLine(to: end)
    let trail = SKShapeNode(path: path)
    trail.strokeColor = SKColor(red: 0.55, green: 0.92, blue: 1, alpha: 0.95)
    trail.glowWidth = 7
    trail.lineWidth = 4
    trail.zPosition = 40
    addChild(trail)
    trail.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
  }

  private func burst(at point: CGPoint, color: SKColor, identity: Int) {
    for index in 0..<14 {
      let particle = SKShapeNode(circleOfRadius: CGFloat(2 + (index % 5)))
      particle.fillColor = color
      particle.strokeColor = .clear
      particle.position = point
      particle.zPosition = 15
      addChild(particle)
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

  private func continuousInputActions() -> [InputAction] {
    var actions: [InputAction] = []
    if let directTarget { actions.append(.moveTo(x: directTarget.x, y: directTarget.y)) }
    #if os(macOS)
      let keyboard = KeyboardState.shared
      let x = Double((keyboard.isPressed(124) || keyboard.isPressed(2) ? 1 : 0)
        - (keyboard.isPressed(123) || keyboard.isPressed(0) ? 1 : 0))
      let y = Double((keyboard.isPressed(125) || keyboard.isPressed(1) ? 1 : 0)
        - (keyboard.isPressed(126) || keyboard.isPressed(13) ? 1 : 0))
      if x != 0 || y != 0 { actions.append(.move(x: x, y: y)) }
      for action in keyboard.consumeActions() {
        switch action {
        case .dash:
          let fallbackY = y == 0 && x == 0 ? -1 : y
          actions.append(.dash(x: x, y: fallbackY))
        case .shriek: actions.append(.shriek)
        case .pause: actions.append(simulation.state.isPaused ? .resume : .pause)
        }
      }
    #elseif os(iOS)
      let x = digitalHorizontal + motionIntent.x
      let y = digitalVertical + motionIntent.y
      if abs(x) > 0.01 || abs(y) > 0.01 { actions.append(.move(x: x, y: y)) }
    #elseif os(tvOS)
      var x = digitalHorizontal
      var y = digitalVertical
      if let gamepad = GCController.current?.extendedGamepad {
        x += Double(gamepad.leftThumbstick.xAxis.value + gamepad.dpad.xAxis.value)
        y -= Double(gamepad.leftThumbstick.yAxis.value + gamepad.dpad.yAxis.value)
        let dash = gamepad.buttonA.isPressed
        let shriek = gamepad.buttonB.isPressed
        if dash, !controllerDashPressed { actions.append(.dash(x: x, y: y == 0 && x == 0 ? -1 : y)) }
        if shriek, !controllerShriekPressed { actions.append(.shriek) }
        controllerDashPressed = dash
        controllerShriekPressed = shriek
      } else if let gamepad = GCController.current?.microGamepad {
        x += Double(gamepad.dpad.xAxis.value)
        y -= Double(gamepad.dpad.yAxis.value)
      }
      if abs(x) > 0.01 || abs(y) > 0.01 { actions.append(.move(x: x, y: y)) }
    #endif
    return actions
  }

  private func beginGesture(at point: CGPoint, timestamp: TimeInterval) {
    gestureStart = point
    gestureLastPoint = point
    gestureStartTime = timestamp
    draggingPhantom = phantom.frame.insetBy(dx: -48, dy: -48).contains(point)
    directTarget = draggingPhantom ? normalizedPoint(point) : nil
  }

  private func moveGesture(to point: CGPoint) {
    if draggingPhantom {
      directTarget = normalizedPoint(point)
      if let previous = gestureLastPoint { drawBladeTrail(from: previous, to: point) }
    }
    gestureLastPoint = point
  }

  private func endGesture(at point: CGPoint, timestamp: TimeInterval) {
    defer {
      gestureStart = nil
      gestureLastPoint = nil
      draggingPhantom = false
      directTarget = nil
    }
    guard let start = gestureStart else { return }
    let dx = point.x - start.x
    let dy = point.y - start.y
    let distance = hypot(dx, dy)
    let duration = max(0.001, timestamp - gestureStartTime)
    if distance >= 42, duration <= 0.55 {
      pendingActions.append(.dash(x: Double(dx / max(distance, 1)), y: Double(-dy / max(distance, 1))))
    } else if !draggingPhantom || distance < 18 {
      pendingActions.append(.shriek)
    }
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

  func movePhantom(horizontal: CGFloat, vertical: CGFloat) {
    let current = simulation.state.ghost.position
    pendingActions.append(
      .moveTo(
        x: current.x + Double(horizontal / max(1, size.width)),
        y: current.y - Double(vertical / max(1, size.height))
      ))
  }

  #if os(iOS) || os(tvOS)
    private func updateDigitalKey(_ keyCode: UIKeyboardHIDUsage, isPressed: Bool) {
      let value = isPressed ? 1.0 : 0.0
      switch keyCode {
      case .keyboardLeftArrow, .keyboardA: digitalHorizontal = -value
      case .keyboardRightArrow, .keyboardD: digitalHorizontal = value
      case .keyboardUpArrow, .keyboardW: digitalVertical = -value
      case .keyboardDownArrow, .keyboardS: digitalVertical = value
      case .keyboardSpacebar where isPressed:
        pendingActions.append(.dash(x: digitalHorizontal, y: digitalVertical == 0 && digitalHorizontal == 0 ? -1 : digitalVertical))
      case .keyboardReturnOrEnter where isPressed: pendingActions.append(.shriek)
      case .keyboardEscape where isPressed:
        pendingActions.append(simulation.state.isPaused ? .resume : .pause)
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
      guard motionManager.isAccelerometerAvailable else { return }
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

  #if os(macOS)
    func handleApplicationPointerEvent(_ event: NSEvent) -> Bool {
      guard let view, event.window === view.window else { return false }
      let point = convertPoint(fromView: view.convert(event.locationInWindow, from: nil))
      switch event.type {
      case .leftMouseDown: beginGesture(at: point, timestamp: event.timestamp)
      case .leftMouseDragged: moveGesture(to: point)
      case .leftMouseUp: endGesture(at: point, timestamp: event.timestamp)
      default: return false
      }
      return true
    }

    func handlePointerDown(at viewPoint: CGPoint) {
      beginGesture(at: convertPoint(fromView: viewPoint), timestamp: ProcessInfo.processInfo.systemUptime)
    }

    func handlePointerDragged(to viewPoint: CGPoint) {
      moveGesture(to: convertPoint(fromView: viewPoint))
    }

    func handlePointerUp(at viewPoint: CGPoint) {
      endGesture(at: convertPoint(fromView: viewPoint), timestamp: ProcessInfo.processInfo.systemUptime)
    }
  #endif
}
