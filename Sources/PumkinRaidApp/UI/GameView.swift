import GameEngineLib
import SpriteKit
import SwiftUI

/// Active gameplay container hosting the SpriteKit simulation and pause HUD.
struct GameView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  let settings: GameEngineLib.GameSettings
  let mode: GameMode
  let seed: UInt64?
  let cosmetics: CosmeticLoadout
  let onGameOver: (RunSummary) -> Void
  @State private var scene: GameScene
  @State private var isPaused = false

  init(
    settings: GameEngineLib.GameSettings,
    mode: GameMode,
    seed: UInt64? = nil,
    cosmetics: CosmeticLoadout = CosmeticLoadout(),
    onGameOver: @escaping (RunSummary) -> Void
  ) {
    self.settings = settings
    self.mode = mode
    self.seed = seed
    self.cosmetics = cosmetics
    self.onGameOver = onGameOver
    _scene = State(
      initialValue: GameScene(
        settings: settings,
        mode: mode,
        seed: seed ?? (mode == .dailyHaunt ? Self.dailySeed() : nil),
        cosmetics: cosmetics
      )
    )
  }

  private static func dailySeed(now: Date = Date()) -> UInt64 {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = calendar.dateComponents([.year, .month, .day], from: now)
    let value =
      (components.year ?? 0) * 10_000
      + (components.month ?? 0) * 100
      + (components.day ?? 0)
    return UInt64(max(0, value)) ^ 0x4441_494C_595F_5241
  }

  var body: some View {
    ZStack {
      Group {
        #if os(macOS)
          GameSceneView(scene: scene)
            .ignoresSafeArea()
        #else
          SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .ignoresSafeArea()
        #endif
      }

      VStack {
        HStack {
          Spacer()
          Button {
            scene.requestPause()
          } label: {
            Image(systemName: "pause.fill")
              .font(.headline.weight(.black))
              .frame(width: 42, height: 42)
              .background(
                BundledImage(name: "leaderboard-panel")
                  .scaledToFill()
                  .clipShape(Circle())
              )
              .overlay(Circle().stroke(.orange.opacity(0.9), lineWidth: 1.5))
          }
          .buttonStyle(.plain)
          .foregroundStyle(.white)
          .accessibilityLabel("Pause game")
          .opacity(isPaused ? 0 : 1)
          .disabled(isPaused)
        }
        Spacer()
      }
      .padding(18)

      if isPaused {
        Color.black.opacity(0.62).ignoresSafeArea()
        VStack(spacing: 16) {
          Image(systemName: "moon.zzz.fill")
            .font(.system(size: 38, weight: .bold))
            .foregroundStyle(.orange)
          Text("RAID PAUSED")
            .font(RaidTypography.screenTitle)
          Text("Your run is safe. Continue when you are ready.")
            .font(RaidTypography.support)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
          #if os(tvOS)
            Button("Resume") { scene.requestResume() }
              .buttonStyle(RaidPrimaryButtonStyle())
          #else
            Button("Resume") { scene.requestResume() }
              .buttonStyle(RaidPrimaryButtonStyle())
              .keyboardShortcut(.defaultAction)
          #endif
          Button("End run") { scene.abandonRun() }
            .buttonStyle(RaidSecondaryButtonStyle())
          Button("Choose another mode") { model.showModeSelection() }
            .buttonStyle(RaidSecondaryButtonStyle())
        }
        .padding(30)
        .frame(maxWidth: 380)
        .foregroundStyle(.white)
        .background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.orange, lineWidth: 1.5))
        .padding(24)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }
    }
    .onAppear {
      model.activeGameScene = scene
      scene.gameOverHandler = onGameOver
      scene.challengeHandler = { model.captureChallenge($0) }
      scene.pauseChangedHandler = { paused in
        withAnimation(.easeOut(duration: 0.2)) { isPaused = paused }
      }
      scene.applySystemAccessibility(
        reduceMotion: accessibilityReduceMotion,
        highContrast: differentiateWithoutColor
      )
      AudioManager.shared.startMusic(enabled: settings.musicEnabled)
      #if os(macOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          scene.view?.window?.makeFirstResponder(scene.view)
        }
      #endif
    }
    .onDisappear {
      if model.activeGameScene === scene { model.activeGameScene = nil }
      scene.pauseChangedHandler = nil
      scene.challengeHandler = nil
      scene.stopMotionUpdates()
      AudioManager.shared.stopMusic()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { scene.requestPause() }
    }
    .onChange(of: accessibilityReduceMotion) { _, value in
      scene.applySystemAccessibility(reduceMotion: value, highContrast: differentiateWithoutColor)
    }
    .onChange(of: differentiateWithoutColor) { _, value in
      scene.applySystemAccessibility(reduceMotion: accessibilityReduceMotion, highContrast: value)
    }
  }
}
