import Foundation
import GameEngineLib
import SpriteKit

/// SpriteKit rendering loadout and metrics configurations.
struct CosmeticLoadout: Equatable {
  var ghostID = "ghost.classic"
  var trailID = "trail.moonlight"
  var auraID = "aura.none"
}

struct GameplayArtworkMetrics: Equatable {
  let scale: CGFloat

  init(sceneSize: CGSize) {
    scale = min(
      2.45,
      max(1.15, min(sceneSize.width / 390, sceneSize.height / 600) * 1.15)
    )
  }

  var ghostSize: CGSize { CGSize(width: 80 * scale, height: 85 * scale) }
  var sweetSize: CGSize { CGSize(width: 58 * scale, height: 58 * scale) }

  func pumpkinSize(radiusScale: CGFloat) -> CGSize {
    CGSize(width: 88 * radiusScale * scale, height: 76 * radiusScale * scale)
  }
}

extension GameScene {
  var backgroundAssetName: String {
    let aspectRatio = size.width / max(1, size.height)
    return aspectRatio >= 1.15
      ? "background-wide" : (aspectRatio >= 0.7 ? "background-tablet" : "background")
  }

  func buildBackground() {
    let background = SKSpriteNode(texture: AssetLoader.texture(backgroundAssetName))
    background.name = "background"
    background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    background.zPosition = -10
    resizeBackground(background)
    world.addChild(background)
  }

  func buildAtmosphere() {
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

  func resizeBackground(_ background: SKSpriteNode) {
    let textureSize = background.texture?.size() ?? size
    guard textureSize.width > 0, textureSize.height > 0 else {
      background.size = size
      return
    }
    let scale = max(size.width / textureSize.width, size.height / textureSize.height)
    background.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
  }

  func buildHUD() {
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

  func layoutHUD() {
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

  func buildPhantom() {
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

  func resizePumpkin(_ node: SKSpriteNode) {
    let base = GameplayArtworkMetrics(sceneSize: size).pumpkinSize(radiusScale: 1.0)
    node.size = base
  }

  func modeTitle(_ mode: GameMode) -> String {
    switch mode {
    case .classicRaid: "CLASSIC RAID"
    case .moonRush: "MOON RUSH"
    case .spiritZen: "SPIRIT ZEN"
    case .dailyHaunt: "DAILY HAUNT"
    case .bossRaid: "BOSS RAID"
    }
  }
}
