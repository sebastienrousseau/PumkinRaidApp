import CoreMotion
import Foundation
import PumkinRaidCore
import SpriteKit

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

@MainActor
final class GameScene: SKScene {
  var gameOverHandler: ((Int) -> Void)?

  private let settings: GameSettings
  private var session = GameSession()
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
  private var comboCount = 0
  private var lastPumpkinDestroyedAt: TimeInterval = 0
  private var dragStart: CGPoint?
  private var draggingPhantom = false
  private var didSliceDuringGesture = false
  private var gameEnded = false
  private var needsInitialPhantomPlacement = true

  init(settings: GameSettings) {
    self.settings = settings
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
    buildEnemies()
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
    let background = SKSpriteNode(texture: AssetLoader.texture("background"))
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
    let inset: CGFloat = max(52, size.width * 0.12)
    let panelWidth = size.width - inset * 2
    let panelHeight: CGFloat = 66
    hudBackground.path = CGPath(
      roundedRect: CGRect(
        x: -panelWidth / 2, y: -panelHeight / 2, width: panelWidth, height: panelHeight),
      cornerWidth: 13,
      cornerHeight: 13,
      transform: nil
    )
    hudBackground.position = CGPoint(x: size.width / 2, y: size.height - 88)

    let leftX = size.width * 0.3
    let rightX = size.width * 0.7
    scoreLabel.position = CGPoint(x: leftX, y: size.height - 78)
    livesLabel.position = CGPoint(x: leftX, y: size.height - 101)
    slicesLabel.position = CGPoint(x: rightX, y: size.height - 78)
    boomsLabel.position = CGPoint(x: rightX, y: size.height - 101)
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
    phantom.size = CGSize(width: 72, height: 76)
    phantom.position = CGPoint(x: size.width / 2, y: 70)
    phantom.zPosition = 5
    world.addChild(phantom)
  }

  private func buildEnemies() {
    let textures = (1...3).map { AssetLoader.texture("pumpkin\($0)") }
    for index in 0..<GameRules.enemyCount {
      let enemy = SKSpriteNode(texture: textures[0])
      enemy.name = "pumpkin"
      enemy.size = CGSize(width: 71, height: 61)
      enemy.position = spawnPosition(offset: CGFloat(index) * 95)
      enemy.userData = NSMutableDictionary()
      enemy.userData?["speed"] = CGFloat(76 + index * 23)
      enemy.zPosition = 3
      enemy.run(
        .repeatForever(.animate(with: textures, timePerFrame: 0.18 + Double(index) * 0.025)))
      enemies.append(enemy)
      world.addChild(enemy)
    }
  }

  private func spawnPosition(offset: CGFloat = 0) -> CGPoint {
    CGPoint(
      x: CGFloat.random(in: 40...max(41, size.width - 40)),
      y: size.height + 70 + offset
    )
  }

  override func didChangeSize(_ oldSize: CGSize) {
    if let background = childNode(withName: "//background") as? SKSpriteNode {
      resizeBackground(background)
      background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }
    layoutHUD()
    placePhantomAtStartIfNeeded()
    phantom.position.x = min(
      max(phantom.position.x, phantom.size.width / 2), size.width - phantom.size.width / 2)
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
      enemy.position.y -= speed * difficultyMultiplier * CGFloat(delta)

      if enemy.frame.insetBy(dx: 10, dy: 8).intersects(phantom.frame.insetBy(dx: 12, dy: 10)) {
        session.collideWithPumpkin()
        comboCount = 0
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
    enemy.position = spawnPosition(offset: CGFloat.random(in: 0...180))
  }

  private func moveBonus(by delta: TimeInterval) {
    bonusElapsed += delta
    if bonus == nil, bonusElapsed >= Double.random(in: 2.5...5.5) {
      spawnBonus()
      bonusElapsed = 0
    }
    guard let bonus else { return }
    bonus.position.y -= 82 * CGFloat(delta)
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
    bonusKind = Int.random(in: 0..<GameRules.sweetScores.count)
    let prefix = bonusKind == 0 ? "" : "\(bonusKind + 1)"
    let textures = (1...3).map { AssetLoader.texture("\(prefix)sweet\($0)") }
    let node = SKSpriteNode(texture: textures[0])
    node.name = "sweet"
    node.size = CGSize(width: 50, height: 50)
    node.position = spawnPosition()
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
    draggingPhantom = phantom.frame.insetBy(dx: -45, dy: -45).contains(point)
    didSliceDuringGesture = false
  }

  private func moveGesture(to point: CGPoint) {
    guard let dragStart else { return }
    if draggingPhantom {
      phantom.position = clampedPhantomPosition(point)
      return
    }
    let distance = hypot(point.x - dragStart.x, point.y - dragStart.y)
    guard distance >= 50, !didSliceDuringGesture else { return }
    didSliceDuringGesture = destroyPumpkin(near: point, usingSlice: true)
  }

  private func endGesture(at point: CGPoint) {
    defer {
      dragStart = nil
      draggingPhantom = false
      didSliceDuringGesture = false
    }
    guard !draggingPhantom, !didSliceDuringGesture, let dragStart else { return }
    let distance = hypot(point.x - dragStart.x, point.y - dragStart.y)
    if distance < 50 { _ = destroyPumpkin(near: point, usingSlice: false) }
  }

  @discardableResult
  private func destroyPumpkin(near point: CGPoint, usingSlice: Bool) -> Bool {
    let hitArea = CGRect(x: point.x - 55, y: point.y - 55, width: 110, height: 110)
    guard let enemy = enemies.first(where: { hitArea.contains($0.position) }) else { return false }
    let succeeded = usingSlice ? session.slicePumpkin() : session.boomPumpkin()
    guard succeeded else { return false }
    let now = CACurrentMediaTime()
    comboCount = now - lastPumpkinDestroyedAt <= 1.8 ? comboCount + 1 : 1
    lastPumpkinDestroyedAt = now
    let comboBonus = comboCount >= 2 ? session.awardBonus(min(comboCount, 10) * 5) : 0
    let action = usingSlice ? "SLICED!" : "BOOM!"
    let callout =
      comboBonus > 0
      ? action + "  x" + String(comboCount) + "  +" + String(comboBonus)
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
    for _ in 0..<14 {
      let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
      particle.fillColor = color
      particle.strokeColor = .clear
      particle.position = point
      particle.zPosition = 15
      addChild(particle)
      let vector = CGVector(dx: CGFloat.random(in: -70...70), dy: CGFloat.random(in: -70...70))
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

  #if os(iOS)
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
    private func sceneLocation(for event: NSEvent) -> CGPoint {
      guard let view else { return .zero }
      let viewPoint = view.convert(event.locationInWindow, from: nil)
      return convertPoint(fromView: viewPoint)
    }

    override func mouseDown(with event: NSEvent) { beginGesture(at: sceneLocation(for: event)) }
    override func mouseDragged(with event: NSEvent) { moveGesture(to: sceneLocation(for: event)) }
    override func mouseUp(with event: NSEvent) { endGesture(at: sceneLocation(for: event)) }
  #endif
}
