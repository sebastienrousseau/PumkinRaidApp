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
      case .tutorial:
        TutorialView()
      case .settings:
        SettingsView()
      case .modeSelection:
        ModeSelectionView()
      case .playerHub(let section):
        PlayerHubView(section: section)
      case .game(let mode):
        GameView(settings: model.settings, mode: mode) { summary in
          model.finishGame(summary)
        }
      case .gameOver(let summary, let progression, let leaderboard, let entryID):
        GameOverView(
          summary: summary,
          progression: progression,
          leaderboard: leaderboard,
          entryID: entryID
        )
      }
    }
    .id(model.screen.transitionID)
    .transition(.opacity.combined(with: .scale(scale: 0.985)))
    .animation(.easeInOut(duration: 0.32), value: model.screen.transitionID)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .onAppear { GameCenterService.shared.authenticate() }
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
            model.beginPlayFlow()
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

private struct TutorialView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var step = 0

  private let lessons: [(symbol: String, title: String, detail: String, accent: Color)] = [
    (
      "hand.draw.fill", "Move freely",
      "Drag the ghost with a finger or mouse. Arrow keys, WASD, a remote, and controllers work too.",
      .cyan
    ),
    (
      "arrow.up.forward.circle.fill", "Dash through pumpkins",
      "Swipe quickly or press Space. A dash turns movement into offense and builds your combo.",
      .orange
    ),
    (
      "waveform.path.ecg", "Shriek when surrounded",
      "Tap, click, or press Return to spend a shriek and clear nearby danger.", .purple
    ),
    (
      "sparkles", "Chase the flow",
      "Collect sweets, thread near misses, and chain targets. Every run advances missions and unlocks cosmetics.",
      .yellow
    ),
  ]

  var body: some View {
    let lesson = lessons[step]
    ZStack {
      GameArtwork(name: "background")
        .overlay(.black.opacity(0.5))
      VStack(spacing: 24) {
        Text("GHOST SCHOOL")
          .font(.system(size: 34, weight: .black, design: .rounded))
          .foregroundStyle(.orange)
        HStack(spacing: 7) {
          ForEach(lessons.indices, id: \.self) { index in
            Capsule()
              .fill(index <= step ? Color.orange : Color.white.opacity(0.22))
              .frame(width: index == step ? 34 : 12, height: 8)
          }
        }
        VStack(spacing: 20) {
          Image(systemName: lesson.symbol)
            .font(.system(size: 72, weight: .bold))
            .foregroundStyle(lesson.accent)
            .symbolEffect(.bounce, value: step)
          Text(lesson.title)
            .font(.system(size: 28, weight: .black, design: .rounded))
          Text(lesson.detail)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 470)
        }
        .id(step)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(systemReduceMotion ? nil : .spring(duration: 0.35), value: step)
        HStack(spacing: 14) {
          if step > 0 {
            Button("Back") { step -= 1 }
              .buttonStyle(.bordered)
          }
          Button(step == lessons.count - 1 ? "Choose a raid" : "Next") {
            if step == lessons.count - 1 {
              model.completeTutorial()
            } else {
              step += 1
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(.orange)
        }
        Button("Skip tutorial") { model.completeTutorial() }
          .buttonStyle(.plain)
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(32)
      .frame(maxWidth: 620)
      .foregroundStyle(.white)
      .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 28))
      .overlay(RoundedRectangle(cornerRadius: 28).stroke(.orange.opacity(0.7), lineWidth: 1.5))
      .padding(24)
    }
    .ignoresSafeArea()
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
          Toggle("Visual sound captions", isOn: $model.settings.captionsEnabled)
          Divider()
          Text("ACCESSIBILITY & CONTROLS")
            .font(.headline.weight(.black))
            .foregroundStyle(.orange)
          Toggle("Reduce motion", isOn: $model.settings.reducedMotionEnabled)
          Toggle("Screen shake", isOn: $model.settings.screenShakeEnabled)
            .disabled(model.settings.reducedMotionEnabled)
          Toggle("High contrast", isOn: $model.settings.highContrastEnabled)
          #if os(iOS)
            Toggle("Tilt controls", isOn: $model.settings.tiltControlsEnabled)
          #endif
          Toggle("Left-handed controls", isOn: $model.settings.leftHandedControls)
          Toggle("Assist mode (slower raid)", isOn: $model.settings.assistModeEnabled)
          VStack(alignment: .leading, spacing: 6) {
            Text("Input sensitivity")
              .font(.subheadline.weight(.semibold))
            #if os(tvOS)
              HStack(spacing: 16) {
                Button("Less") {
                  model.settings.inputSensitivity = max(
                    0.5,
                    model.settings.inputSensitivity - 0.1
                  )
                }
                .buttonStyle(.bordered)
                Button("More") {
                  model.settings.inputSensitivity = min(
                    1.5,
                    model.settings.inputSensitivity + 0.1
                  )
                }
                .buttonStyle(.bordered)
              }
            #else
              Slider(value: $model.settings.inputSensitivity, in: 0.5...1.5, step: 0.1)
            #endif
            Text("\(model.settings.inputSensitivity, specifier: "%.1fx")")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.white.opacity(0.7))
          }
          Divider()
          VStack(alignment: .leading, spacing: 12) {
            Label("Move with arrow keys, WASD, tilt, controller, or drag", systemImage: "move.3d")
            Label("Tap, click, or press Return to shriek", systemImage: "burst.fill")
            Label("Swipe or press Space to dash through pumpkins", systemImage: "scribble.variable")
            Label("Collect sweets and build your high score", systemImage: "star.fill")
          }
          .font(.callout.weight(.semibold))
          Button("Choose a mode") { model.showModeSelection() }
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

private struct ModeSelectionView: View {
  @EnvironmentObject private var model: AppModel

  private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

  var body: some View {
    ZStack {
      GameArtwork(name: "background")
        .overlay(.black.opacity(0.38))
      ScrollView {
        VStack(spacing: 22) {
          VStack(spacing: 6) {
            Text("CHOOSE YOUR RAID")
              .font(.system(size: 34, weight: .black, design: .rounded))
              .foregroundStyle(.orange)
            Text("Every mode uses the same responsive controls.")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.78))
          }
          HStack(spacing: 12) {
            Button {
              model.showPlayerHub(.profile)
            } label: {
              Label("Level \(model.progress.level)", systemImage: "person.crop.circle.fill")
            }
            Button {
              model.showPlayerHub(.missions)
            } label: {
              Label("Missions", systemImage: "checklist")
            }
            Button {
              model.showPlayerHub(.collection)
            } label: {
              Label("\(model.progress.ectoplasm)", systemImage: "sparkles")
            }
            Button {
              GameCenterService.shared.showDashboard()
            } label: {
              Label("Game Center", systemImage: "person.2.fill")
            }
          }
          .buttonStyle(.bordered)
          .tint(.orange)
          LazyVGrid(columns: columns, spacing: 16) {
            modeCard(
              .classicRaid,
              title: "Classic Raid",
              detail: "Survive escalating waves and protect every life.",
              symbol: "shield.lefthalf.filled"
            )
            modeCard(
              .moonRush,
              title: "Moon Rush",
              detail: "Score as much as possible in sixty seconds.",
              symbol: "timer"
            )
            modeCard(
              .spiritZen,
              title: "Spirit Zen",
              detail: "No game over—practice movement and flowing combos.",
              symbol: "moon.stars.fill"
            )
            modeCard(
              .dailyHaunt,
              title: "Daily Haunt",
              detail: "A repeatable daily ruleset built for fair competition.",
              symbol: "calendar"
            )
            modeCard(
              .bossRaid,
              title: "Boss Raid",
              detail: "Face heavy formations and master multi-hit targets.",
              symbol: "crown.fill"
            )
          }
          Button("Back") { model.showStart() }
            .buttonStyle(.bordered)
            .foregroundStyle(.white)
        }
        .padding(28)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
      }
    }
    .ignoresSafeArea()
  }

  private func modeCard(
    _ mode: GameMode,
    title: String,
    detail: String,
    symbol: String
  ) -> some View {
    Button {
      model.beginGame(mode: mode)
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: symbol)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.orange)
        Text(title)
          .font(.title3.weight(.black))
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.76))
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
        Label("Play", systemImage: "arrow.right.circle.fill")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.orange)
      }
      .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
      .padding(20)
      .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
      .overlay(
        RoundedRectangle(cornerRadius: 20).stroke(.orange.opacity(0.72), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title). \(detail)")
  }
}

private struct PlayerHubView: View {
  @EnvironmentObject private var model: AppModel
  let section: AppModel.HubSection

  var body: some View {
    ZStack {
      GameArtwork(name: "background")
        .overlay(.black.opacity(0.5))
      ScrollView {
        VStack(spacing: 20) {
          Text("GHOST LODGE")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(.orange)
          Picker("Lodge section", selection: sectionBinding) {
            ForEach(AppModel.HubSection.allCases, id: \.self) { item in
              Text(item.rawValue.capitalized).tag(item)
            }
          }
          .pickerStyle(.segmented)

          switch section {
          case .profile: profile
          case .missions: missions
          case .collection: collection
          }

          Button("Back to modes") { model.showModeSelection() }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(28)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
      }
    }
    .ignoresSafeArea()
  }

  private var sectionBinding: Binding<AppModel.HubSection> {
    Binding(get: { section }, set: { model.showPlayerHub($0) })
  }

  private var profile: some View {
    VStack(spacing: 16) {
      Image(systemName: "moon.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(.cyan)
      Text("LEVEL \(model.progress.level)")
        .font(.title.weight(.black))
      ProgressView(value: Double(model.progress.experienceWithinLevel), total: 500)
        .tint(.orange)
      Text("\(model.progress.experienceWithinLevel) / 500 XP")
        .font(.caption.monospacedDigit())
      HStack(spacing: 24) {
        lodgeMetric("Raids", model.progress.totalRuns)
        lodgeMetric("Ectoplasm", model.progress.ectoplasm)
        lodgeMetric("Unlocks", model.progress.unlockedCosmeticIDs.count)
      }
      Divider()
      ForEach(GameMode.allCases, id: \.self) { mode in
        HStack {
          Text(displayName(mode))
          Spacer()
          Text("BEST  \(model.progress.bestScores[mode] ?? 0)").monospacedDigit()
        }
      }
    }
    .lodgeCard()
  }

  private var missions: some View {
    VStack(spacing: 12) {
      ForEach(ProgressionCatalog.missions) { mission in
        let status =
          model.progress.missionStatuses.first(where: { $0.id == mission.id })
          ?? MissionStatus(id: mission.id)
        VStack(alignment: .leading, spacing: 7) {
          HStack {
            Image(systemName: status.isClaimed ? "checkmark.seal.fill" : "circle.dashed")
              .foregroundStyle(status.isClaimed ? .green : .orange)
            Text(mission.title).font(.headline)
            Spacer()
            Text("+\(mission.rewardEctoplasm)").foregroundStyle(.cyan)
          }
          ProgressView(
            value: Double(min(status.progress, mission.target)), total: Double(mission.target)
          )
          .tint(status.isClaimed ? .green : .orange)
          Text("\(min(status.progress, mission.target)) / \(mission.target)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.68))
        }
        .padding(15)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
      }
    }
    .lodgeCard()
  }

  private var collection: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
      ForEach(ProgressionCatalog.cosmetics) { item in
        let unlocked = model.progress.unlockedCosmeticIDs.contains(item.id)
        let equipped =
          item.id == model.progress.equippedGhostID
          || item.id == model.progress.equippedTrailID
        Button {
          model.equip(item)
        } label: {
          VStack(spacing: 10) {
            Image(systemName: unlocked ? "sparkles" : "lock.fill")
              .font(.system(size: 30, weight: .bold))
              .foregroundStyle(unlocked ? .cyan : .white.opacity(0.4))
            Text(item.name).font(.headline)
            Text(
              equipped
                ? "EQUIPPED" : unlocked ? "Tap to equip" : "Unlock at level \(item.unlockLevel)"
            )
            .font(.caption)
            .foregroundStyle(equipped ? .orange : .white.opacity(0.62))
          }
          .frame(maxWidth: .infinity, minHeight: 125)
          .padding(12)
          .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
          .overlay(
            RoundedRectangle(cornerRadius: 15)
              .stroke(equipped ? .orange : .white.opacity(0.12), lineWidth: 1.5)
          )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
      }
    }
    .lodgeCard()
  }

  private func lodgeMetric(_ title: String, _ value: Int) -> some View {
    VStack {
      Text("\(value)").font(.title3.bold()).monospacedDigit()
      Text(title).font(.caption).foregroundStyle(.white.opacity(0.65))
    }
  }

  private func displayName(_ mode: GameMode) -> String {
    switch mode {
    case .classicRaid: "Classic Raid"
    case .moonRush: "Moon Rush"
    case .spiritZen: "Spirit Zen"
    case .dailyHaunt: "Daily Haunt"
    case .bossRaid: "Boss Raid"
    }
  }
}

extension View {
  fileprivate func lodgeCard() -> some View {
    padding(20)
      .foregroundStyle(.white)
      .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).stroke(.orange.opacity(0.55), lineWidth: 1))
  }
}

private struct GameView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
  @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
  let settings: GameEngineLib.GameSettings
  let mode: GameMode
  let onGameOver: (RunSummary) -> Void
  @State private var scene: GameScene
  @State private var isPaused = false

  init(
    settings: GameEngineLib.GameSettings,
    mode: GameMode,
    onGameOver: @escaping (RunSummary) -> Void
  ) {
    self.settings = settings
    self.mode = mode
    self.onGameOver = onGameOver
    _scene = State(
      initialValue: GameScene(
        settings: settings,
        mode: mode,
        seed: mode == .dailyHaunt ? Self.dailySeed() : nil
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
              .background(.black.opacity(0.78), in: Circle())
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
            .font(.system(size: 30, weight: .black, design: .rounded))
          Text("Your run is safe. Continue when you are ready.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
          #if os(tvOS)
            Button("Resume") { scene.requestResume() }
              .buttonStyle(.borderedProminent)
              .tint(.orange)
          #else
            Button("Resume") { scene.requestResume() }
              .buttonStyle(.borderedProminent)
              .tint(.orange)
              .keyboardShortcut(.defaultAction)
          #endif
          Button("End run") { scene.abandonRun() }
            .buttonStyle(.bordered)
          Button("Choose another mode") { model.showModeSelection() }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
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

private struct GameOverView: View {
  @EnvironmentObject private var model: AppModel
  let summary: RunSummary
  let progression: ProgressionUpdate
  let leaderboard: Leaderboard
  let entryID: UUID

  var body: some View {
    GeometryReader { proxy in
      let cardWidth = min(560, max(300, proxy.size.width - 48))
      let visibleEntries = Array(leaderboard.entries.prefix(proxy.size.height < 620 ? 3 : 5))
      let rowHeight: CGFloat = proxy.size.height < 620 ? 40 : 48
      let cardHeight = 188 + rowHeight * CGFloat(max(1, visibleEntries.count))
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
          VStack(spacing: 5) {
            Text("\(summary.score)")
              .font(.system(size: 38, weight: .black, design: .rounded))
              .foregroundStyle(.white)
              .monospacedDigit()
            HStack(spacing: 10) {
              resultMetric("Smashed", summary.statistics.destroyed)
              resultMetric("Near misses", summary.statistics.nearMisses)
              resultMetric("Best combo", summary.statistics.bestCombo)
            }
            Text(
              "+\(progression.experienceAwarded) XP  •  +\(progression.ectoplasmAwarded) ectoplasm"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(.cyan)
            if summary.assisted {
              Text("ASSISTED RUN")
                .font(.caption2.weight(.black))
                .foregroundStyle(.yellow)
            } else if progression.isNewBest {
              Text("NEW PERSONAL BEST")
                .font(.caption2.weight(.black))
                .foregroundStyle(.yellow)
            }
          }
          .frame(height: 112)

          HStack {
            Label("\(modeTitle) LEADERBOARD", systemImage: "trophy.fill")
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
            model.beginGame(mode: summary.mode)
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
              ShareLink(item: "I scored \(summary.score) points in Pumkin Raid!") {
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

  private var modeTitle: String {
    switch summary.mode {
    case .classicRaid: "CLASSIC"
    case .moonRush: "MOON RUSH"
    case .spiritZen: "ZEN"
    case .dailyHaunt: "DAILY"
    case .bossRaid: "BOSS"
    }
  }

  private func resultMetric(_ title: String, _ value: Int) -> some View {
    VStack(spacing: 1) {
      Text("\(value)").font(.headline.monospacedDigit())
      Text(title).font(.caption2).foregroundStyle(.white.opacity(0.65))
    }
    .frame(maxWidth: .infinity)
  }

  private func leaderboardRow(rank: Int, entry: LeaderboardEntry) -> some View {
    ZStack {
      Text("\(entry.score)")
        .monospacedDigit()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

      HStack(spacing: 8) {
        Text("#\(rank)")
          .frame(width: 34, alignment: .leading)
          .foregroundStyle(rank == 1 ? .yellow : .white.opacity(0.65))
        Text(entry.playerName)
          .lineLimit(1)
        Spacer()
      }
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
