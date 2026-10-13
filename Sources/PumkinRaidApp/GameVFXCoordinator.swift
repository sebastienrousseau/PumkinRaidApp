import Foundation
import GameEngineLib
import SpriteKit

#if os(iOS)
  import UIKit
#endif

extension GameScene {
  func showCallout(_ text: String, at position: CGPoint, color: SKColor) {
    let label = SKLabelNode(fontNamed: "GangofThree")
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
      label.setScale(0.6)
      label.run(
        .sequence([
          .group([
            .sequence([
              .scale(to: 1.28, duration: 0.1),
              .scale(to: 1.0, duration: 0.08),
            ]),
            .moveBy(x: 0, y: 65, duration: 0.65),
            .sequence([
              .wait(forDuration: 0.35),
              .fadeOut(withDuration: 0.3),
            ]),
          ]),
          .removeFromParent(),
        ]))
    }
  }

  func drawBladeTrail(from start: CGPoint, to end: CGPoint) {
    let path = CGMutablePath()
    path.move(to: start)
    path.addLine(to: end)
    let trail = SKShapeNode(path: path)
    trail.strokeColor = trailColor
    trail.glowWidth = 8
    trail.lineWidth = 5
    trail.zPosition = 40
    addTransientEffect(trail)
    trail.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))

    let core = SKShapeNode(path: path)
    core.strokeColor = .white
    core.lineWidth = 2.5
    core.zPosition = 41
    addTransientEffect(core)
    core.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
  }

  var trailColor: SKColor {
    switch cosmetics.trailID {
    case "trail.ember": SKColor(red: 1, green: 0.34, blue: 0.04, alpha: 0.98)
    case "trail.cursed": SKColor(red: 0.72, green: 0.22, blue: 1, alpha: 0.98)
    default: SKColor(red: 0.55, green: 0.92, blue: 1, alpha: 0.95)
    }
  }

  func pumpkinFragments(at point: CGPoint, identity: Int) {
    guard !shouldReduceMotion else { return }
    for index in 0..<2 {
      let fragment = SKSpriteNode(texture: AssetLoader.texture("pumpkin_piece\(index + 1)"))
      fragment.size = CGSize(width: 66 * spriteScale, height: 88 * spriteScale)
      fragment.position = point
      fragment.zPosition = 18
      addTransientEffect(fragment)
      let direction: CGFloat = index == 0 ? -1 : 1
      let dx = direction * CGFloat(70 + identity % 28)
      let arc = SKAction.customAction(withDuration: 0.55) { node, elapsedTime in
        let progress = elapsedTime / 0.55
        let xOffset = dx * progress
        let yOffset = (40 * progress) - (140 * progress * progress)
        node.position = CGPoint(x: point.x + xOffset, y: point.y + yOffset)
      }
      fragment.run(
        .sequence([
          .group([
            arc,
            .rotate(byAngle: direction * .pi * 2.4, duration: 0.55),
            .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.3)]),
          ]),
          .removeFromParent(),
        ])
      )
    }

    // Spawn 5 flying pumpkin seeds
    for index in 0..<5 {
      let seed = SKSpriteNode(texture: AssetLoader.texture("pumpkin_seed"))
      seed.size = CGSize(width: 15 * spriteScale, height: 23 * spriteScale)
      seed.position = point
      seed.zPosition = 17
      addTransientEffect(seed)
      let angle = CGFloat((identity * 43 + index * 71) % 360) * .pi / 180
      let speed = CGFloat(65 + (identity * 13 + index * 29) % 70)
      let dx = cos(angle) * speed
      let dy = sin(angle) * speed
      let spin = (index % 2 == 0 ? 1 : -1) * CGFloat.pi * 3
      seed.run(
        .sequence([
          .group([
            .move(by: CGVector(dx: dx * 0.48, dy: dy * 0.48 - 30), duration: 0.48),
            .rotate(byAngle: spin, duration: 0.48),
            .fadeOut(withDuration: 0.48),
          ]),
          .removeFromParent(),
        ]))
    }
  }

  func juiceSplatter(at point: CGPoint, identity: Int) {
    guard !shouldReduceMotion else { return }
    let radius = CGFloat(36 + (identity % 22)) * spriteScale
    let splat = SKShapeNode(circleOfRadius: radius)
    splat.fillColor = SKColor(red: 1.0, green: 0.48, blue: 0.04, alpha: 0.42)
    splat.strokeColor = .clear
    splat.position = point
    splat.zPosition = 3
    addTransientEffect(splat)

    // Satellite droplets
    for i in 0..<4 {
      let angle = CGFloat(i) * .pi / 2 + 0.3
      let dist = radius * 1.35
      let drop = SKShapeNode(circleOfRadius: radius * 0.26)
      drop.fillColor = SKColor(red: 1.0, green: 0.48, blue: 0.04, alpha: 0.38)
      drop.strokeColor = .clear
      drop.position = CGPoint(x: point.x + cos(angle) * dist, y: point.y + sin(angle) * dist)
      drop.zPosition = 3
      addTransientEffect(drop)
      drop.run(
        .sequence([
          .scale(to: 1.25, duration: 0.08),
          .wait(forDuration: 1.0),
          .fadeOut(withDuration: 0.7),
          .removeFromParent(),
        ])
      )
    }

    splat.run(
      .sequence([
        .scale(to: 1.3, duration: 0.08),
        .wait(forDuration: 1.2),
        .fadeOut(withDuration: 0.8),
        .removeFromParent(),
      ])
    )
  }

  func impactFlash(color: SKColor) {
    let flash = SKShapeNode(rectOf: size)
    flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
    flash.fillColor = color.withAlphaComponent(0.16)
    flash.strokeColor = .clear
    flash.zPosition = 90
    addTransientEffect(flash)
    flash.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
  }

  func burst(at point: CGPoint, color: SKColor, identity: Int) {
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

  func addTransientEffect(_ node: SKNode) {
    while effectsLayer.children.count >= Self.maximumTransientEffects {
      effectsLayer.children.first?.removeFromParent()
    }
    effectsLayer.addChild(node)
    assert(effectsLayer.children.count <= Self.maximumTransientEffects)
  }

  func provideHitFeedback() {
    #if os(iOS)
      guard settings.vibrationEnabled else { return }
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    #endif
  }

  func provideSuccessFeedback(combo: Int) {
    guard settings.vibrationEnabled else { return }
    #if os(iOS)
      UIImpactFeedbackGenerator(style: combo >= 4 ? .heavy : .light).impactOccurred(
        intensity: combo >= 4 ? 0.9 : 0.55
      )
    #endif
  }
}
