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

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        GameArtwork(name: "splashscreen")
        Button {
          model.beginGame()
        } label: {
          ImageButton(name: "button-start", size: min(proxy.size.width * 0.38, 190))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start game")
        .position(x: proxy.size.width * 0.53, y: proxy.size.height * 0.62)

        Button {
          model.showSettings()
        } label: {
          ImageButton(name: "button-info", size: min(proxy.size.width * 0.085, 38))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings and game guide")
        .position(x: proxy.size.width - 34, y: 38)
      }
    }
    .ignoresSafeArea()
    .onAppear {
      AudioManager.shared.startMusic(enabled: model.settings.musicEnabled)
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
          Text(
            "Guide the phantom through the haunted night. Dodge pumpkins, collect sweets, tap pumpkins to boom them, or swipe through them to slice them."
          )
          .font(.body)
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

  init(settings: PumkinRaidCore.GameSettings, onGameOver: @escaping (Int) -> Void) {
    self.settings = settings
    self.onGameOver = onGameOver
    _scene = State(initialValue: GameScene(settings: settings))
  }

  var body: some View {
    ZStack {
      SpriteView(scene: scene, options: [.ignoresSiblingOrder])
        .ignoresSafeArea()
      #if os(macOS)
        KeyboardCaptureView { horizontal, vertical in
          scene.movePhantom(horizontal: horizontal, vertical: vertical)
        }
        .frame(width: 1, height: 1)
        keyboardShortcuts
      #endif
    }
    .onAppear {
      scene.gameOverHandler = onGameOver
      AudioManager.shared.startMusic(enabled: settings.musicEnabled)
      #if os(macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          scene.view?.window?.makeFirstResponder(scene.view)
        }
      #endif
    }
    .onDisappear {
      scene.stopMotionUpdates()
      AudioManager.shared.stopMusic()
    }
  }

  #if os(macOS)
    private var keyboardShortcuts: some View {
      ZStack {
        shortcutButton(.leftArrow, horizontal: -24, vertical: 0)
        shortcutButton(.rightArrow, horizontal: 24, vertical: 0)
        shortcutButton(.upArrow, horizontal: 0, vertical: 24)
        shortcutButton(.downArrow, horizontal: 0, vertical: -24)
        shortcutButton("a", horizontal: -24, vertical: 0)
        shortcutButton("d", horizontal: 24, vertical: 0)
        shortcutButton("w", horizontal: 0, vertical: 24)
        shortcutButton("s", horizontal: 0, vertical: -24)
      }
      .frame(width: 1, height: 1)
      .opacity(0.001)
      .accessibilityHidden(true)
    }

    private func shortcutButton(
      _ key: KeyEquivalent,
      horizontal: CGFloat,
      vertical: CGFloat
    ) -> some View {
      Button("") {
        scene.movePhantom(horizontal: horizontal, vertical: vertical)
      }
      .keyboardShortcut(key, modifiers: [])
    }
  #endif
}

private struct GameOverView: View {
  @EnvironmentObject private var model: AppModel
  let score: Int
  let highScore: Int

  var body: some View {
    ZStack {
      GameArtwork(name: "gameover")
      VStack(spacing: 12) {
        Spacer().frame(height: 70)
        Text("GAME OVER")
          .font(.system(size: 44, weight: .black, design: .rounded))
          .foregroundStyle(.orange)
        scoreRow("High Score", highScore)
        scoreRow("Most Recent Score", score)
        Spacer()
        Button {
          model.showStart()
        } label: {
          ImageButton(name: "button-death", size: 145)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play again")
        Text("Play again")
          .font(.headline)
        ShareLink(item: "I scored \(score) points in PumkinRaid!") {
          Label("Share score", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
        Spacer().frame(height: 40)
      }
      .padding(30)
      .foregroundStyle(.white)
    }
    .ignoresSafeArea()
  }

  private func scoreRow(_ title: String, _ value: Int) -> some View {
    HStack {
      Text(title)
      Spacer()
      Text("\(value) points")
    }
    .font(.title3.bold())
    .frame(maxWidth: 330)
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
