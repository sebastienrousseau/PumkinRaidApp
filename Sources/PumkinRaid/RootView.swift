import PumkinRaidCore
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
      case .gameOver(let score, let highScore):
        GameOverView(score: score, highScore: highScore)
      }
    }
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
      ZStack {
        GameArtwork(name: "splashscreen")

        Button {
          model.beginGame()
        } label: {
          ImageButton(name: "button-start", size: min(proxy.size.width * 0.34, 160))
            .scaleEffect(playPulse ? 1.08 : 0.96)
            .shadow(color: .cyan.opacity(0.9), radius: playPulse ? 20 : 9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start game")
        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.36)

        Text("Tap or click the arrow to play")
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 9)
          .background(.black.opacity(0.68), in: Capsule())
          .overlay(Capsule().stroke(.orange.opacity(0.8), lineWidth: 1))
          .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.48)
          .accessibilityHidden(true)

        Button {
          model.showSettings()
        } label: {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 21, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .orange)
            .frame(width: 42, height: 42)
            .background(.black.opacity(0.58), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings and game guide")
        .position(x: proxy.size.width - 34, y: 46)
      }
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
  let settings: PumkinRaidCore.GameSettings
  let onGameOver: (Int) -> Void
  @State private var scene: GameScene
  @State private var showsControlHint = true

  init(settings: PumkinRaidCore.GameSettings, onGameOver: @escaping (Int) -> Void) {
    self.settings = settings
    self.onGameOver = onGameOver
    _scene = State(initialValue: GameScene(settings: settings))
  }

  var body: some View {
    ZStack {
      #if os(macOS)
        GameSceneView(scene: scene)
          .ignoresSafeArea()
      #else
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
          .ignoresSafeArea()
      #endif

      if showsControlHint {
        VStack {
          Spacer()
          #if os(macOS)
            Label(
              "Move: arrow keys or WASD • Drag the ghost • Click or swipe pumpkins",
              systemImage: "keyboard")
          #else
            Label("Tilt or drag the ghost • Tap or swipe pumpkins", systemImage: "hand.draw.fill")
          #endif
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.72), in: Capsule())
        .padding(.bottom, 18)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .allowsHitTesting(false)
      }
    }
    .onAppear {
      scene.gameOverHandler = onGameOver
      AudioManager.shared.startMusic(enabled: settings.musicEnabled)
      #if os(macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          scene.view?.window?.makeFirstResponder(scene.view)
        }
      #endif
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(5))
        withAnimation(.easeOut(duration: 0.4)) {
          showsControlHint = false
        }
      }
    }
    .onDisappear {
      scene.stopMotionUpdates()
      AudioManager.shared.stopMusic()
    }
  }
}

private struct GameOverView: View {
  @EnvironmentObject private var model: AppModel
  let score: Int
  let highScore: Int

  var body: some View {
    GeometryReader { _ in
      ZStack {
        GameArtwork(name: "gameover")
        VStack(spacing: 16) {
          Text("GAME OVER")
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(.orange)
            .shadow(color: .black.opacity(0.75), radius: 4, y: 2)

          VStack(spacing: 16) {
            scoreRow("High Score", highScore, icon: "trophy.fill")
            Divider().overlay(.white.opacity(0.22))
            scoreRow("This Run", score, icon: "flag.checkered")
          }
          .padding(22)
          .frame(maxWidth: 350)
          .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(.orange.opacity(0.85), lineWidth: 1.5)
          )

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
            ShareLink(item: "I scored \(score) points in PumkinRaid!") {
              Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
          }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .foregroundStyle(.white)
      }
    }
    .ignoresSafeArea()
  }

  private func scoreRow(_ title: String, _ value: Int, icon: String) -> some View {
    HStack {
      Label(title, systemImage: icon)
      Spacer()
      Text("\(value) points")
        .monospacedDigit()
    }
    .font(.headline.bold())
  }
}

private struct GameArtwork: View {
  let name: String

  var body: some View {
    BundledImage(name: name)
      .scaledToFill()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
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
    #if os(iOS)
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
