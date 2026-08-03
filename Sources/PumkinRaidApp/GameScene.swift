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

@MainActor
final class GameScene: SKScene {
  var gameOverHandler: ((Int) -> Void)?

  private let settings: GameSettings
  private var session = GameSession()
  private var spawnDirector: SpawnDirector
  private var comboTracker = ComboTracker()
  #if os(iOS)
    private let motionManager = CMMotionManager()
  #endif
  private let world = SKNode()
  private let phantom = SKSpriteNode(texture: AssetLoader.texture("phantom"))
  private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let livesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let slicesLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let boomsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
  private let hudBackground = SKShapeNode()
  private var enemies: [SKSpriteNode] = []
  private var bonus: SKSpriteNode?
  private var bonusKind = 0
  private var lastUpdateTime: TimeInterval = 0
  private var bonusElapsed: TimeInterval = 0
  private var sliceRechargeElapsed: TimeInterval = 0
  private var boomRechargeElapsed: TimeInterval = 0
  private var survivalElapsed: TimeInterval = 0
  private var nextBonusDelay: TimeInterval = 3
  #if os(iOS) || os(tvOS)
    private var digitalHorizontal: CGFloat = 0
    private var digitalVertical: CGFloat = 0
  #endif
  private var dragStart: CGPoint?
  private var lastGesturePoint: CGPoint?
  private var draggingPhantom = false
  private var phantomDragOffset = CGPoint.zero
  private var gestureHitCount = 0
  private var gameEnded = false
  private var needsInitialPhantomPlacement = true

  private var verticalPlayfieldScale: CGFloat { max(0.72, size.height / 568) }
  private var horizontalPlayfieldScale: CGFloat { max(0.72, size.width / 320) }
  private var spriteScale: CGFloat {
    min(1.65, max(0.78, min(size.width / 430, size.height / 720)))
  }

  init(settings: GameSettings) {
    self.settings = settings
    let seed = UInt64(Date().timeIntervalSince1970 * 1_000_000) ^ UInt64.random(in: .min ... .max)
    spawnDirector = SpawnDirector(seed: seed)
    super.init(size: CGSize(width: 320, height: 568))
    scaleMode = .resizeFill
    backgroundColor = .black
  }

  required init?(coder: NSCoder) { nil }

  override func didMove(to view: SKView) {
    guard children.isEmpty else { return }
    anchorPoint = .zero
    addChild(world)
    buildBackground()
    buildHUD()
    buildPhantom()
    DispatchQueue.main.async { [weak self] in
      self?.placePhantomAtStartIfNeeded()
    }
    buildEnemiesIfPossible()
    nextBonusDelay = spawnDirector.nextBonusDelay()
    startMotionUpdates()
    AudioManager.shared.play("creaking_door", enabled: settings.effectsEnabled)
    #if os(macOS)
      DispatchQueue.main.async {
        view.window?.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
      }
    #endif
  }

  private func buildBackground() {
    let aspectRatio = size.width / max(1, size.height)
    let assetName = aspectRatio >= 1.15 ? "background-wide" : (aspectRatio >= 0.7 ? "background-tablet" : "background")
    let background = SKSpriteNode(texture: AssetLoader.texture(assetName))
    background.name = "background"
    background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    background.zPosition = -10
    resizeBackground(background)
    world.addChild(background)
  }

  private func buildHUD() {
    hudBackground.fillColor = SKColor.black.withAlphaComponent(0.68)
    hudBackground.strokeColor = SKColor.orange.withAlphaComponent(0.75)
    hudBackground.lineWidth = 1.5
    hudBackground.zPosition = 19
    addChild(hudBackground)

    let labels = [scoreLabel, livesLabel, slicesLabel, boomsLabel]
    for label in labels {
      label.fontSize = 15
      label.fontColor = .orange
      label.horizontalAlignmentMode = .center
      label.zPosition = 20
      addChild(label)
    }
    layoutHUD()
    refreshHUD()
  }

  private func layoutHUD() {
    let inset = min(52, max(20, size.width * 0.08))
    let panelWidth = size.width - inset * 2
    let panelHeight: CGFloat = 66
    let topMargin = max(68, min(88, size.height * 0.12))
    let labelSize = min(18, max(12, size.width * 0.035))
    hudBackground.path = CGPath(
      roundedRect: CGRect(
        x: -panelWidth / 2, y: -panelHeight / 2, width: panelWidth, height: panelHeight),
      cornerWidth: 13,
      cornerHeight: 13,
      transform: nil
    )
    hudBackground.position = CGPoint(x: size.width / 2, y: size.height - topMargin)

    let leftX = size.width / 2 - panelWidth * 0.25
    let rightX = size.width / 2 + panelWidth * 0.25
    for label in [scoreLabel, livesLabel, slicesLabel, boomsLabel] {
      label.fontSize = labelSize
    }
    scoreLabel.position = CGPoint(x: leftX, y: size.height - topMargin + 10)
    livesLabel.position = CGPoint(x: leftX, y: size.height - topMargin - 13)
    slicesLabel.position = CGPoint(x: rightX, y: size.height - topMargin + 10)
    boomsLabel.position = CGPoint(x: rightX, y: size.height - topMargin - 13)
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

  private func buildPhantom() {
    phantom.name = "phantom"
    resizePhantom()
    phantom.position = CGPoint(x: size.width / 2, y: 70)
    phantom.zPosition = 5
    world.addChild(phantom)
  }

  private func buildEnemiesIfPossible() {
    guard enemies.isEmpty, world.parent != nil, size.width > 100, size.height > 100 else {
      return
    }
    let textures = (1...3).map { AssetLoader.texture("pumpkin\($0)") }
    for index in 0..<GameRules.enemyCount {
      let enemy = SKSpriteNode(texture: textures[0])
      enemy.name = "pumpkin"
      enemy.size = CGSize(width: 71, height: 61)
      enemy.userData = NSMutableDictionary()
      enemy.zPosition = 3
      configureSpawn(enemy, initialOffset: Double(index) * 82, textures: textures)
      enemies.append(enemy)
      world.addChild(enemy)
    }
  }

  override func didChangeSize(_ oldSize: CGSize) {
    remapGameplay(from: oldSize)
    if let background = childNode(withName: "//background") as? SKSpriteNode {
      let aspectRatio = size.width / max(1, size.height)
      let assetName = aspectRatio >= 1.15 ? "background-wide" : (aspectRatio >= 0.7 ? "background-tablet" : "background")
      background.texture = AssetLoader.texture(assetName)
      resizeBackground(background)
      background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }
    layoutHUD()
    resizePhantom()
    resizeDynamicNodes()
    buildEnemiesIfPossible()
    placePhantomAtStartIfNeeded()
    phantom.position = clampedPhantomPosition(phantom.position)
  }

  private func remapGameplay(from oldSize: CGSize) {
    guard oldSize.width > 0, oldSize.height > 0, oldSize != size else { return }
    let horizontalRatio = size.width / oldSize.width
    let verticalRatio = size.height / oldSize.height

    for enemy in enemies {
      enemy.position.x *= horizontalRatio
      enemy.position.y = enemy.position.y > oldSize.height
        ? size.height + (enemy.position.y - oldSize.height) * verticalRatio
        : enemy.position.y * verticalRatio
    }
    if let bonus {
      bonus.position.x *= horizontalRatio
      bonus.position.y = bonus.position.y > oldSize.height
        ? size.height + (bonus.position.y - oldSize.height) * verticalRatio
        : bonus.position.y * verticalRatio
    }
    if !needsInitialPhantomPlacement {
      phantom.position = CGPoint(
        x: phantom.position.x * horizontalRatio,
        y: phantom.position.y * verticalRatio
      )
    }
  }

  private func resizePhantom() {
    phantom.size = CGSize(width: 72 * spriteScale, height: 76 * spriteScale)
  }

  private func resizeDynamicNodes() {
    for enemy in enemies {
      let planScale = enemy.userData?["spawnScale"] as? CGFloat ?? 1
      enemy.size = CGSize(
        width: 71 * planScale * spriteScale,
        height: 61 * planScale * spriteScale
      )
    }
    bonus?.size = CGSize(width: 50 * spriteScale, height: 50 * spriteScale)
  }

  private func placePhantomAtStartIfNeeded() {
    guard needsInitialPhantomPlacement, phantom.parent != nil, size.width > 100, size.height > 100
    else { return }
    phantom.position = CGPoint(x: size.width / 2, y: 70)
    needsInitialPhantomPlacement = false
  }

  override func update(_ currentTime: TimeInterval) {
    guard !gameEnded else { return }
    let delta = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 0.1)
    lastUpdateTime = currentTime
    guard delta > 0 else { return }
    #if os(macOS)
      movePhantomFromHardwareKeyboard(delta: delta)
    #elseif os(iOS) || os(tvOS)
      movePhantomFromDigitalInput(delta: delta)
    #endif
    survivalElapsed += delta
    moveEnemies(by: delta)
    moveBonus(by: delta)
    updateRechargeTimers(by: delta)
    checkForGameOver()
  }

  private func moveEnemies(by delta: TimeInterval) {
    let difficultyMultiplier = min(1.6, 1 + CGFloat(survivalElapsed / 150))
    for enemy in enemies {
      let speed = enemy.userData?["speed"] as? CGFloat ?? 100
      enemy.position.y -= speed * verticalPlayfieldScale * difficultyMultiplier * CGFloat(delta)
      let drift = enemy.userData?["drift"] as? CGFloat ?? 0
      enemy.position.x += drift * horizontalPlayfieldScale * CGFloat(delta)
      let halfWidth = enemy.size.width / 2
      if enemy.position.x < halfWidth || enemy.position.x > size.width - halfWidth {
        enemy.userData?["drift"] = -drift
        enemy.position.x = min(max(enemy.position.x, halfWidth), size.width - halfWidth)
      }

      if enemy.frame.insetBy(dx: 10, dy: 8).intersects(phantom.frame.insetBy(dx: 12, dy: 10)) {
        session.collideWithPumpkin()
        comboTracker.breakCombo()
        AudioManager.shared.play("bow_wah", enabled: settings.effectsEnabled)
        provideHitFeedback()
        showCallout("OUCH!", at: phantom.position, color: .red)
        respawn(enemy)
        phantom.run(
          .sequence([
            .moveBy(x: -7, y: 0, duration: 0.04),
            .moveBy(x: 14, y: 0, duration: 0.08),
            .moveBy(x: -7, y: 0, duration: 0.04),
          ]))
        refreshHUD()
      } else if enemy.position.y < -enemy.size.height {
        session.avoidPumpkin()
        respawn(enemy)
        refreshHUD()
      }
    }
  }

  private func respawn(_ enemy: SKSpriteNode) {
    let textures = (1...3).map { AssetLoader.texture("pumpkin\($0)") }
    configureSpawn(enemy, textures: textures)
  }

  private func configureSpawn(
    _ enemy: SKSpriteNode, initialOffset: Double = 0, textures: [SKTexture]
  ) {
    let plan = spawnDirector.nextPlan(elapsedTime: survivalElapsed, score: session.score)
    let baseSize = CGSize(width: 71 * spriteScale, height: 61 * spriteScale)
    enemy.size = CGSize(
      width: baseSize.width * plan.scale,
      height: baseSize.height * plan.scale
    )
    enemy.position = CGPoint(
      x: CGFloat(plan.horizontalPosition) * size.width,
      y: size.height + (70 + CGFloat(plan.verticalOffset + initialOffset)) * verticalPlayfieldScale
    )
    enemy.userData?["speed"] = CGFloat(plan.speed)
    enemy.userData?["drift"] = CGFloat(plan.horizontalDrift)
    enemy.userData?["spawnScale"] = CGFloat(plan.scale)
    enemy.removeAction(forKey: "animation")
    enemy.run(
      .repeatForever(.animate(with: textures, timePerFrame: plan.animationRate)),
      withKey: "animation"
    )
  }

  private func moveBonus(by delta: TimeInterval) {
    bonusElapsed += delta
    if bonus == nil, bonusElapsed >= nextBonusDelay {
      spawnBonus()
      bonusElapsed = 0
      nextBonusDelay = spawnDirector.nextBonusDelay()
    }
    guard let bonus else { return }
    bonus.position.y -= 82 * verticalPlayfieldScale * CGFloat(delta)
    if bonus.frame.intersects(phantom.frame) {
      let points = session.collectSweet(kind: bonusKind)
      showCallout("+\(points)", at: bonus.position, color: .yellow)
      AudioManager.shared.play("ding", enabled: settings.effectsEnabled)
      bonus.removeFromParent()
      self.bonus = nil
      refreshHUD()
    } else if bonus.position.y < -bonus.size.height {
      bonus.removeFromParent()
      self.bonus = nil
    }
  }

  private func spawnBonus() {
    bonusKind = spawnDirector.nextBonusKind(count: GameRules.sweetScores.count)
    let prefix = bonusKind == 0 ? "" : "\(bonusKind + 1)"
    let textures = (1...3).map { AssetLoader.texture("\(prefix)sweet\($0)") }
    let node = SKSpriteNode(texture: textures[0])
    node.name = "sweet"
    node.size = CGSize(width: 50 * spriteScale, height: 50 * spriteScale)
    let plan = spawnDirector.nextPlan(elapsedTime: survivalElapsed, score: session.score)
    node.position = CGPoint(
      x: CGFloat(plan.horizontalPosition) * size.width,
      y: size.height + (70 + CGFloat(plan.verticalOffset)) * verticalPlayfieldScale
    )
    node.zPosition = 4
    node.run(.repeatForever(.animate(with: textures, timePerFrame: 0.2)))
    world.addChild(node)
    bonus = node
  }

  private func updateRechargeTimers(by delta: TimeInterval) {
    sliceRechargeElapsed += delta
    boomRechargeElapsed += delta
    if sliceRechargeElapsed >= 6 {
      session.rechargeSlices()
      sliceRechargeElapsed = 0
      refreshHUD()
    }
    if boomRechargeElapsed >= 3 {
      session.rechargeBooms()
      boomRechargeElapsed = 0
      refreshHUD()
    }
  }

  private func checkForGameOver() {
    guard session.isGameOver, !gameEnded else { return }
    gameEnded = true
    stopMotionUpdates()
    AudioManager.shared.stopMusic()
    AudioManager.shared.play("female_scream", enabled: settings.effectsEnabled)
    let score = session.score
    run(
      .sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.gameOverHandler?(score) }]))
  }

  private func refreshHUD() {
    scoreLabel.text = "Score: \(session.score)"
    livesLabel.text = "Lives: \(session.lives)"
    slicesLabel.text = "Slices: \(session.slices)"
    boomsLabel.text = "Booms: \(session.booms)"
  }

  private func showCallout(_ text: String, at position: CGPoint, color: SKColor) {
    let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    label.text = text
    label.fontSize = 22
    label.fontColor = color
    label.position = position
    label.zPosition = 30
    addChild(label)
    label.run(
      .sequence([
        .group([.moveBy(x: 0, y: 70, duration: 0.7), .fadeOut(withDuration: 0.7)]),
        .removeFromParent(),
      ]))
  }

  private func beginGesture(at point: CGPoint) {
    dragStart = point
    lastGesturePoint = point
    draggingPhantom = phantom.frame.insetBy(dx: -45, dy: -45).contains(point)
    phantomDragOffset = draggingPhantom
      ? CGPoint(x: phantom.position.x - point.x, y: phantom.position.y - point.y)
      : .zero
    gestureHitCount = 0
  }

  private func moveGesture(to point: CGPoint) {
    guard let dragStart, let previous = lastGesturePoint else { return }
    defer { lastGesturePoint = point }
    if draggingPhantom {
      phantom.position = clampedPhantomPosition(
        CGPoint(x: point.x + phantomDragOffset.x, y: point.y + phantomDragOffset.y)
      )
      return
    }
    drawBladeTrail(from: previous, to: point)
    let distance = hypot(point.x - dragStart.x, point.y - dragStart.y)
    guard distance >= 36 else { return }
    gestureHitCount += destroyPumpkins(from: previous, to: point)
  }

  private func endGesture(at point: CGPoint) {
    defer {
      dragStart = nil
      lastGesturePoint = nil
      draggingPhantom = false
      phantomDragOffset = .zero
      gestureHitCount = 0
    }
    guard !draggingPhantom, gestureHitCount == 0, let dragStart else { return }
    let distance = hypot(point.x - dragStart.x, point.y - dragStart.y)
    if distance < 50 { _ = destroyPumpkin(near: point, usingSlice: false) }
  }

  private func destroyPumpkins(from start: CGPoint, to end: CGPoint) -> Int {
    let targets = enemies.filter {
      distance(from: $0.position, toSegmentFrom: start, to: end) <= max($0.size.width, $0.size.height) * 0.62
    }
    var hitCount = 0
    for enemy in targets where destroyPumpkin(enemy, usingSlice: true) {
      hitCount += 1
    }
    return hitCount
  }

  private func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let lengthSquared = dx * dx + dy * dy
    guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }
    let projection = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
    return hypot(point.x - (start.x + projection * dx), point.y - (start.y + projection * dy))
  }

  private func drawBladeTrail(from start: CGPoint, to end: CGPoint) {
    let path = CGMutablePath()
    path.move(to: start)
    path.addLine(to: end)
    let trail = SKShapeNode(path: path)
    trail.strokeColor = SKColor(red: 0.55, green: 0.92, blue: 1, alpha: 0.95)
    trail.glowWidth = 7
    trail.lineWidth = 3
    trail.zPosition = 40
    addChild(trail)
    trail.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
  }

  @discardableResult
  private func destroyPumpkin(near point: CGPoint, usingSlice: Bool) -> Bool {
    let hitArea = CGRect(x: point.x - 55, y: point.y - 55, width: 110, height: 110)
    guard let enemy = enemies.first(where: { hitArea.contains($0.position) }) else { return false }
    return destroyPumpkin(enemy, usingSlice: usingSlice)
  }

  @discardableResult
  private func destroyPumpkin(_ enemy: SKSpriteNode, usingSlice: Bool) -> Bool {
    let succeeded = usingSlice ? session.slicePumpkin() : session.boomPumpkin()
    guard succeeded else { return false }
    let combo = comboTracker.registerHit(at: CACurrentMediaTime())
    let comboBonus = session.awardBonus(combo.bonus)
    let action = usingSlice ? "SLICED!" : "BOOM!"
    let callout =
      comboBonus > 0
      ? action + "  x" + String(combo.count) + "  +" + String(comboBonus)
      : action
    let sound = usingSlice ? "slice" : "explode"
    showCallout(callout, at: enemy.position, color: .orange)
    AudioManager.shared.play(sound, enabled: settings.effectsEnabled)
    burst(at: enemy.position, color: usingSlice ? .orange : .yellow)
    respawn(enemy)
    refreshHUD()
    return true
  }

  private func burst(at point: CGPoint, color: SKColor) {
    for index in 0..<14 {
      let particle = SKShapeNode(circleOfRadius: CGFloat(2 + (index % 5)))
      particle.fillColor = color
      particle.strokeColor = .clear
      particle.position = point
      particle.zPosition = 15
      addChild(particle)
      let velocity = spawnDirector.particleVelocity()
      let vector = CGVector(dx: CGFloat(velocity.x), dy: CGFloat(velocity.y))
      particle.run(
        .sequence([
          .group([.move(by: vector, duration: 0.45), .fadeOut(withDuration: 0.45)]),
          .removeFromParent(),
        ]))
    }
  }

  private func clampedPhantomPosition(_ point: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(point.x, phantom.size.width / 2), size.width - phantom.size.width / 2),
      y: min(max(point.y, phantom.size.height / 2), size.height - phantom.size.height / 2)
    )
  }

  func movePhantom(horizontal: CGFloat, vertical: CGFloat) {
    phantom.position = clampedPhantomPosition(
      CGPoint(x: phantom.position.x + horizontal, y: phantom.position.y + vertical)
    )
  }

  #if os(macOS)
    private func movePhantomFromHardwareKeyboard(delta: TimeInterval) {
      let keyboard = KeyboardState.shared
      let left = keyboard.isPressed(123) || keyboard.isPressed(0)
      let right = keyboard.isPressed(124) || keyboard.isPressed(2)
      let down = keyboard.isPressed(125) || keyboard.isPressed(1)
      let up = keyboard.isPressed(126) || keyboard.isPressed(13)

      var horizontal = CGFloat((right ? 1 : 0) - (left ? 1 : 0))
      var vertical = CGFloat((up ? 1 : 0) - (down ? 1 : 0))
      guard horizontal != 0 || vertical != 0 else { return }
      if horizontal != 0, vertical != 0 {
        horizontal *= 0.707
        vertical *= 0.707
      }
      let distance = CGFloat(delta) * 260
      movePhantom(
        horizontal: horizontal * distance * horizontalPlayfieldScale,
        vertical: vertical * distance * verticalPlayfieldScale
      )
    }

  #endif

  #if os(iOS) || os(tvOS)
    private func movePhantomFromDigitalInput(delta: TimeInterval) {
      var horizontal = digitalHorizontal
      var vertical = digitalVertical

      #if os(tvOS)
        if let gamepad = GCController.current?.extendedGamepad {
          horizontal += CGFloat(gamepad.leftThumbstick.xAxis.value + gamepad.dpad.xAxis.value)
          vertical += CGFloat(gamepad.leftThumbstick.yAxis.value + gamepad.dpad.yAxis.value)
        } else if let gamepad = GCController.current?.microGamepad {
          horizontal += CGFloat(gamepad.dpad.xAxis.value)
          vertical += CGFloat(gamepad.dpad.yAxis.value)
        }
      #endif

      let magnitude = hypot(horizontal, vertical)
      guard magnitude > 0.01 else { return }
      if magnitude > 1 {
        horizontal /= magnitude
        vertical /= magnitude
      }
      movePhantom(
        horizontal: horizontal * CGFloat(delta) * 300 * horizontalPlayfieldScale,
        vertical: vertical * CGFloat(delta) * 300 * verticalPlayfieldScale
      )
    }

    private func updateDigitalKey(_ keyCode: UIKeyboardHIDUsage, isPressed: Bool) {
      let value: CGFloat = isPressed ? 1 : 0
      switch keyCode {
      case .keyboardLeftArrow, .keyboardA:
        digitalHorizontal = -value
      case .keyboardRightArrow, .keyboardD:
        digitalHorizontal = value
      case .keyboardUpArrow, .keyboardW:
        digitalVertical = value
      case .keyboardDownArrow, .keyboardS:
        digitalVertical = -value
      default:
        break
      }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      var handled = false
      for press in presses {
        guard let key = press.key else { continue }
        updateDigitalKey(key.keyCode, isPressed: true)
        handled = true
      }
      if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      var handled = false
      for press in presses {
        guard let key = press.key else { continue }
        updateDigitalKey(key.keyCode, isPressed: false)
        handled = true
      }
      if !handled { super.pressesEnded(presses, with: event) }
    }
  #endif

  func startMotionUpdates() {
    #if os(iOS)
      guard motionManager.isAccelerometerAvailable else { return }
      motionManager.accelerometerUpdateInterval = 1.0 / 60.0
      motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let self, let acceleration = data?.acceleration, !self.draggingPhantom else { return }
        let target = CGPoint(
          x: self.phantom.position.x + CGFloat(acceleration.x) * 9,
          y: self.phantom.position.y + CGFloat(acceleration.y) * 6
        )
        self.phantom.position = self.clampedPhantomPosition(target)
      }
    #endif
  }

  func stopMotionUpdates() {
    #if os(iOS)
      motionManager.stopAccelerometerUpdates()
    #endif
  }

  private func provideHitFeedback() {
    #if os(iOS)
      guard settings.vibrationEnabled else { return }
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    #endif
  }

  #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else { return }
      beginGesture(at: touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else { return }
      moveGesture(to: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else { return }
      endGesture(at: touch.location(in: self))
    }
  #elseif os(macOS)
    func handleApplicationPointerEvent(_ event: NSEvent) -> Bool {
      guard let view, event.window === view.window else { return false }
      let viewPoint = view.convert(event.locationInWindow, from: nil)
      switch event.type {
      case .leftMouseDown:
        handlePointerDown(at: viewPoint)
      case .leftMouseDragged:
        handlePointerDragged(to: viewPoint)
      case .leftMouseUp:
        handlePointerUp(at: viewPoint)
      default:
        return false
      }
      return true
    }

    func handlePointerDown(at viewPoint: CGPoint) {
      beginGesture(at: convertPoint(fromView: viewPoint))
    }

    func handlePointerDragged(to viewPoint: CGPoint) {
      moveGesture(to: convertPoint(fromView: viewPoint))
    }

    func handlePointerUp(at viewPoint: CGPoint) {
      endGesture(at: convertPoint(fromView: viewPoint))
    }
  #endif
}
