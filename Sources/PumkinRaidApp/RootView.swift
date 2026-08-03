import GameEngineLib
import SpriteKit
import SwiftUI

struct RootView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      switch model.screen {
      case .start:
        StartView()
      case .settings:
        SettingsView()
      case .game:
        GameView(settings: model.settings) { score in
          model.finishGame(score: score)
        }
      case .gameOver(let score, let leaderboard, let entryID):
        GameOverView(score: score, leaderboard: leaderboard, entryID: entryID)
      }
    }
    .id(model.screen.transitionID)
    .transition(.opacity.combined(with: .scale(scale: 0.985)))
    .animation(.easeInOut(duration: 0.32), value: model.screen.transitionID)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .onChange(of: model.settings.musicEnabled) { _, enabled in
      if enabled, model.shouldPlayMusic {
        AudioManager.shared.startMusic(enabled: true)
      } else {
        AudioManager.shared.stopMusic()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .active:
        AudioManager.shared.startMusic(
          enabled: model.settings.musicEnabled && model.shouldPlayMusic
        )
      case .inactive, .background:
        AudioManager.shared.stopAll()
      @unknown default:
        AudioManager.shared.stopAll()
      }
    }
  }
}

private struct StartView: View {
  @EnvironmentObject private var model: AppModel
  @State private var playPulse = false

  var body: some View {
    GeometryReader { proxy in
      let sourceSize = CGSize(width: 640, height: 960)
      let artworkScale = min(
        proxy.size.width / sourceSize.width,
        proxy.size.height / sourceSize.height
      )
      let playSize = min(proxy.size.width * 0.34, 160)
      let labelOffset = min(105, proxy.size.height * 0.15)
      ZStack {
        GameArtwork(name: "splashscreen")
          .scaleEffect(1.08)
          .blur(radius: 18)
          .overlay(.black.opacity(0.14))

        ZStack {
          BundledImage(name: "splashscreen")
            .frame(width: sourceSize.width, height: sourceSize.height)

          Button {
            model.beginGame()
          } label: {
            ImageButton(name: "button-start", size: playSize / artworkScale)
              .scaleEffect(playPulse ? 1.08 : 0.96)
              .shadow(
                color: .cyan.opacity(0.9),
                radius: (playPulse ? 20 : 9) / artworkScale
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Start game")
          .position(x: 329, y: 352)

          Text("Tap or click the arrow to play")
            .font(.system(size: 17 / artworkScale, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16 / artworkScale)
            .padding(.vertical, 9 / artworkScale)
            .background(.black.opacity(0.68), in: Capsule())
            .overlay(
              Capsule().stroke(.orange.opacity(0.8), lineWidth: 1 / artworkScale)
            )
            .position(x: 329, y: 352 + labelOffset / artworkScale)
            .accessibilityHidden(true)
        }
        .frame(width: sourceSize.width, height: sourceSize.height)
        .scaleEffect(artworkScale)
        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

        Button {
          model.showSettings()
        } label: {
          Image(systemName: "info")
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(.orange.opacity(0.9), lineWidth: 1.5))
            .shadow(color: .orange.opacity(0.28), radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings and game guide")
        .position(
          x: proxy.size.width - max(26, proxy.safeAreaInsets.trailing + 26),
          y: max(30, proxy.safeAreaInsets.top + 25)
        )
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .clipped()
    }
    .ignoresSafeArea()
    .onAppear {
      AudioManager.shared.startMusic(enabled: model.settings.musicEnabled)
      withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
        playPulse = true
      }
    }
  }

}

private struct SettingsView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ZStack {
      GameArtwork(name: "setting_background")
      ScrollView {
        VStack(spacing: 18) {
          Text("SETTINGS")
            .font(.system(size: 38, weight: .black, design: .rounded))
            .foregroundStyle(.orange)
          Toggle("Background music", isOn: $model.settings.musicEnabled)
          Toggle("Special effects", isOn: $model.settings.effectsEnabled)
          Toggle("Vibration", isOn: $model.settings.vibrationEnabled)
          Divider()
          VStack(alignment: .leading, spacing: 12) {
            Label("Move with arrow keys, WASD, tilt, or drag", systemImage: "move.3d")
            Label("Tap or click pumpkins to use a boom", systemImage: "burst.fill")
            Label("Swipe through pumpkins to slice them", systemImage: "scribble.variable")
            Label("Collect sweets and build your high score", systemImage: "star.fill")
          }
          .font(.callout.weight(.semibold))
          Button("Get started!") { model.beginGame() }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
          Button("Back") { model.showStart() }
            .buttonStyle(.bordered)
        }
        .padding(28)
        .foregroundStyle(.white)
      }
      .frame(maxWidth: 520)
      .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 24))
      .padding(24)
    }
    .ignoresSafeArea()
  }
}

private struct GameView: View {
  @EnvironmentObject private var model: AppModel
  let settings: GameEngineLib.GameSettings
  let onGameOver: (Int) -> Void
  @State private var scene: GameScene

  init(settings: GameEngineLib.GameSettings, onGameOver: @escaping (Int) -> Void) {
    self.settings = settings
    self.onGameOver = onGameOver
    _scene = State(initialValue: GameScene(settings: settings))
  }

  var body: some View {
    Group {
      #if os(macOS)
        GameSceneView(scene: scene)
          .ignoresSafeArea()
      #else
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
          .ignoresSafeArea()
      #endif
    }
    .onAppear {
      model.activeGameScene = scene
      scene.gameOverHandler = onGameOver
      AudioManager.shared.startMusic(enabled: settings.musicEnabled)
      #if os(macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          scene.view?.window?.makeFirstResponder(scene.view)
        }
      #endif
    }
    .onDisappear {
      if model.activeGameScene === scene { model.activeGameScene = nil }
      scene.stopMotionUpdates()
      AudioManager.shared.stopMusic()
    }
  }
}

private struct GameOverView: View {
  @EnvironmentObject private var model: AppModel
  let score: Int
  let leaderboard: Leaderboard
  let entryID: UUID

  var body: some View {
    GeometryReader { proxy in
      let cardWidth = min(560, max(300, proxy.size.width - 48))
      let visibleEntries = Array(leaderboard.entries.prefix(proxy.size.height < 620 ? 3 : 5))
      let rowHeight: CGFloat = proxy.size.height < 620 ? 40 : 48
      let cardHeight = 76 + rowHeight * CGFloat(max(1, visibleEntries.count))
      let centerY = proxy.size.height / 2
      ZStack {
        GameArtwork(name: "gameover")
        Text("GAME OVER")
          .font(
            .system(
              size: min(42, max(32, proxy.size.width * 0.1)),
              weight: .black,
              design: .rounded
            )
          )
          .foregroundStyle(.orange)
          .shadow(color: .black.opacity(0.75), radius: 4, y: 2)
          .position(x: proxy.size.width / 2, y: max(58, centerY - cardHeight / 2 - 52))

        VStack(spacing: 0) {
          HStack {
            Label("LOCAL LEADERBOARD", systemImage: "trophy.fill")
            Spacer()
            Text("BEST  \(leaderboard.bestScore)")
              .monospacedDigit()
          }
          .font(.subheadline.weight(.heavy))
          .foregroundStyle(.orange)
          .frame(height: 50)

          Divider().overlay(.white.opacity(0.25))

          if visibleEntries.isEmpty {
            Text("Complete a run to claim the first place.")
              .foregroundStyle(.white.opacity(0.8))
              .frame(height: rowHeight)
          } else {
            ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
              leaderboardRow(rank: index + 1, entry: entry)
                .frame(height: rowHeight)
            }
          }
        }
        .padding(.horizontal, min(30, cardWidth * 0.07))
        .padding(.vertical, 12)
        .frame(width: cardWidth, height: cardHeight)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(.orange.opacity(0.9), lineWidth: 1.5)
        )
        .position(x: proxy.size.width / 2, y: centerY)

        VStack(spacing: 14) {
          Button {
            model.beginGame()
          } label: {
            Label("Play again", systemImage: "arrow.clockwise.circle.fill")
              .font(.title3.bold())
              .frame(maxWidth: 230)
              .padding(.vertical, 10)
          }
          .buttonStyle(.borderedProminent)
          .tint(.orange)
          .accessibilityLabel("Play again")

          HStack(spacing: 12) {
            Button("Home") { model.showStart() }
              .buttonStyle(.bordered)
            #if !os(tvOS)
              ShareLink(item: "I scored \(score) points in Pumkin Raid!") {
                Label("Share", systemImage: "square.and.arrow.up")
              }
              .buttonStyle(.bordered)
            #endif
          }
        }
        .foregroundStyle(.white)
        .position(
          x: proxy.size.width / 2,
          y: min(proxy.size.height - 70, centerY + cardHeight / 2 + 88)
        )
      }
    }
    .ignoresSafeArea()
  }

  private func leaderboardRow(rank: Int, entry: LeaderboardEntry) -> some View {
    HStack {
      Text("#\(rank)")
        .frame(width: 34, alignment: .leading)
        .foregroundStyle(rank == 1 ? .yellow : .white.opacity(0.65))
      Text(entry.playerName)
      Spacer()
      Text("\(entry.score)")
        .monospacedDigit()
    }
    .font(.headline.weight(entry.id == entryID ? .heavy : .semibold))
    .foregroundStyle(entry.id == entryID ? .orange : .white)
    .padding(.horizontal, 8)
    .background(
      entry.id == entryID ? Color.orange.opacity(0.14) : .clear,
      in: RoundedRectangle(cornerRadius: 9)
    )
  }
}

private struct GameArtwork: View {
  let name: String

  var body: some View {
    GeometryReader { proxy in
      let aspect = proxy.size.width / max(1, proxy.size.height)
      let candidate = adaptiveName(for: aspect)
      BundledImage(name: AssetLoader.imageURL(candidate) == nil ? name : candidate)
        .scaledToFill()
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
    }
  }

  private func adaptiveName(for aspect: CGFloat) -> String {
    if name == "background", aspect >= 1.15 { return "background-wide" }
    guard aspect >= 0.7 else { return name }
    switch name {
    case "background": return "background-tablet"
    case "splashscreen": return "splashscreen-tablet"
    case "gameover": return "gameover-tablet"
    case "setting_background": return "setting-background-tablet"
    default: return name
    }
  }
}

private struct ImageButton: View {
  let name: String
  let size: CGFloat

  var body: some View {
    BundledImage(name: name)
      .scaledToFit()
      .frame(width: size, height: size)
      .contentShape(Rectangle())
  }
}

private struct BundledImage: View {
  let name: String

  var body: some View {
    #if os(iOS) || os(tvOS)
      if let image = AssetLoader.image(name) {
        Image(uiImage: image)
          .resizable()
      } else {
        missingImage
      }
    #elseif os(macOS)
      if let image = AssetLoader.image(name) {
        Image(nsImage: image)
          .resizable()
      } else {
        missingImage
      }
    #endif
  }

  private var missingImage: some View {
    ZStack {
      Color(red: 0.18, green: 0.04, blue: 0.02)
      Text("Missing: \(name)")
        .font(.caption)
        .foregroundStyle(.orange)
    }
  }
}
