import GameEngineLib
import SpriteKit
import SwiftUI

struct StartView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var playPulse = false

  var body: some View {
    GeometryReader { proxy in
      let layout = StartLayoutMetrics(size: proxy.size, safeTop: proxy.safeAreaInsets.top)
      ZStack {
        startBackdrop(landscape: layout.isLandscape, size: proxy.size)

        VStack(spacing: layout.isCompact ? 10 : 16) {
          RaidTitle(compact: layout.isCompact)

          MoonPlayButton(size: layout.playSize, pulsing: playPulse) {
            model.beginPlayFlow()
          }

          Button {
            model.beginPlayFlow()
          } label: {
            VStack(spacing: 2) {
              Text("ENTER THE RAID")
              Text("Tap, click, or press Return")
                .font(RaidTypography.caption)
                .foregroundStyle(.white.opacity(0.82))
            }
          }
          .buttonStyle(RaidSecondaryButtonStyle())
          .accessibilityHint("Opens game mode selection")
        }
        .frame(width: layout.contentWidth, height: layout.contentRegionHeight, alignment: .top)
        .position(layout.contentCenter)

        Button {
          model.showSettings()
        } label: {
          RaidArtworkIconLabel(artName: "setting_tutorial_button", title: "Guide", size: 62)
        }
        .buttonStyle(RaidArtworkIconButtonStyle())
        .accessibilityLabel("Settings and game guide")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, max(14, proxy.safeAreaInsets.top))
        .padding(.trailing, max(16, proxy.safeAreaInsets.trailing + 10))
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .clipped()
      .onSubmit { model.beginPlayFlow() }
    }
    .ignoresSafeArea()
    .onAppear {
      AudioManager.shared.startMusic(enabled: model.settings.musicEnabled)
      withAnimation(
        reduceMotion ? nil : .easeInOut(duration: 0.92).repeatForever(autoreverses: true)
      ) {
        playPulse = true
      }
    }
  }

  @ViewBuilder
  private func startBackdrop(landscape: Bool, size: CGSize) -> some View {
    if landscape {
      BundledImage(name: "background-wide")
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(.black.opacity(0.18))
      ZStack(alignment: .bottom) {
        BundledImage(name: "pumpkin1")
          .scaledToFit()
          .frame(width: min(180, size.height * 0.25))
          .offset(x: -min(90, size.width * 0.045), y: -12)
        BundledImage(name: "phantom")
          .scaledToFit()
          .frame(width: min(230, size.height * 0.34))
          .offset(x: min(80, size.width * 0.04), y: -min(95, size.height * 0.1))
      }
      .frame(width: size.width * 0.46, height: size.height * 0.72)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      .padding(.trailing, max(20, size.width * 0.04))
    } else {
      BundledImage(name: "splash-backdrop-tablet")
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(
          LinearGradient(
            colors: [.black.opacity(0.16), .clear, .black.opacity(0.22)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        guideBackdrop(size: proxy.size)
        ScrollView {
          VStack(spacing: 18) {
            RaidScreenHeading(title: "SETTINGS")
            Toggle("Background music", isOn: $model.settings.musicEnabled)
            Toggle("Special effects", isOn: $model.settings.effectsEnabled)
            Toggle("Vibration", isOn: $model.settings.vibrationEnabled)
            Toggle("Visual sound captions", isOn: $model.settings.captionsEnabled)
            Divider()
            Text("ACCESSIBILITY & CONTROLS")
              .font(RaidTypography.sectionTitle)
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
                .font(RaidTypography.support)
              #if os(tvOS)
                HStack(spacing: 16) {
                  Button("Less") {
                    model.settings.inputSensitivity = max(
                      0.5,
                      model.settings.inputSensitivity - 0.1
                    )
                  }
                  .buttonStyle(RaidSecondaryButtonStyle())
                  Button("More") {
                    model.settings.inputSensitivity = min(
                      1.5,
                      model.settings.inputSensitivity + 0.1
                    )
                  }
                  .buttonStyle(RaidSecondaryButtonStyle())
                }
              #else
                Slider(value: $model.settings.inputSensitivity, in: 0.5...1.5, step: 0.1)
              #endif
              Text("\(model.settings.inputSensitivity, specifier: "%.1fx")")
                .font(RaidTypography.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
              Label("Move with arrow keys, WASD, tilt, controller, or drag", systemImage: "move.3d")
              Label("Tap, click, or press Return to shriek", systemImage: "burst.fill")
              Label(
                "Swipe or press Space to dash through pumpkins", systemImage: "scribble.variable")
              Label("Collect sweets and build your high score", systemImage: "star.fill")
            }
            .font(RaidTypography.support)
            Button("Choose a mode") { model.showModeSelection() }
              .buttonStyle(RaidPrimaryButtonStyle())
            Button("Back") { model.showStart() }
              .buttonStyle(RaidSecondaryButtonStyle())
          }
          .font(RaidTypography.body)
          .toggleStyle(SkullToggleStyle())
          .padding(proxy.size.width < 500 ? 22 : 32)
          .foregroundStyle(.white)
          .frame(maxWidth: 720)
          .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: 784, maxHeight: .infinity)
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 28))
        .overlay(
          RoundedRectangle(cornerRadius: 28)
            .stroke(RaidTheme.orange.opacity(0.82), lineWidth: 2)
        )
        .padding(.horizontal, max(16, proxy.safeAreaInsets.leading + 12))
        .padding(.vertical, max(16, proxy.safeAreaInsets.top + 8))
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .ignoresSafeArea()
  }

  @ViewBuilder
  private func guideBackdrop(size: CGSize) -> some View {
    if size.width / max(1, size.height) >= 1.15 {
      BundledImage(name: "background-wide")
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(Color(red: 0.24, green: 0.025, blue: 0.015).opacity(0.58))
        .overlay(
          LinearGradient(
            colors: [.black.opacity(0.28), .clear, .black.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    } else {
      GameArtwork(name: "setting_background")
    }
  }
}

struct ModeSelectionView: View {
  @EnvironmentObject private var model: AppModel
  @State private var showsChallengeEntry = false
  @State private var challengeCode = ""
  @State private var challengeError = false

  private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]
  private let actionColumns = [GridItem(.adaptive(minimum: 320), spacing: 16)]

  var body: some View {
    ZStack {
      GameArtwork(name: "background")
        .overlay(.black.opacity(0.38))
      ScrollView {
        VStack(spacing: 22) {
          RaidScreenHeading(
            title: "CHOOSE YOUR RAID",
            subtitle: "Every mode uses the same responsive controls."
          )
          LazyVGrid(columns: actionColumns, spacing: 12) {
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
          .buttonStyle(RaidSecondaryButtonStyle())
          Button {
            showsChallengeEntry = true
          } label: {
            Label("Friend challenge", systemImage: "person.2.wave.2.fill")
          }
          .buttonStyle(RaidPrimaryButtonStyle(tint: .purple))
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
              detail:
                "One shared seed each day • \(model.dailyChallenge.streak)-day streak • Best \(model.dailyChallenge.bestScore)",
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
            .buttonStyle(RaidSecondaryButtonStyle())
        }
        .font(RaidTypography.body)
        .padding(28)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
      }
    }
    .ignoresSafeArea()
    .sheet(isPresented: $showsChallengeEntry) {
      RaidGlassPanel {
        VStack(spacing: 16) {
          Text("FRIEND CHALLENGE")
            .font(RaidTypography.cardTitle)
            .foregroundStyle(RaidTheme.orange)
          Text("Paste a challenge code to replay the same seed and beat its target score.")
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.75))
          TextField("Challenge code", text: $challengeCode)
            #if os(tvOS)
              .textFieldStyle(.plain)
            #else
              .textFieldStyle(.roundedBorder)
            #endif
            .accessibilityLabel("Friend challenge code")
          if challengeError {
            Label("That challenge code is not valid.", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.yellow)
          }
          Button("START CHALLENGE") {
            guard let challenge = RaidChallenge.decode(challengeCode) else {
              challengeError = true
              return
            }
            challengeError = false
            showsChallengeEntry = false
            model.beginGame(mode: challenge.mode, seed: challenge.seed)
          }
          .buttonStyle(RaidPrimaryButtonStyle())
          Button("Cancel") { showsChallengeEntry = false }
            .buttonStyle(RaidSecondaryButtonStyle())
        }
        .padding(10)
      }
      .padding(24)
      .frame(minWidth: 320, minHeight: 360)
      .background(RaidTheme.ink)
    }
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
          .font(RaidTypography.cardTitle)
        Text(detail)
          .font(RaidTypography.support)
          .foregroundStyle(.white.opacity(0.76))
          .multilineTextAlignment(.leading)
        Spacer(minLength: 0)
        HStack(spacing: 8) {
          Text("Play")
          BundledImage(name: "button-arrow")
            .scaledToFit()
            .frame(width: 34, height: 34)
        }
        .font(RaidTypography.action)
        .foregroundStyle(.orange)
      }
      .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
      .padding(20)
      .background(
        BundledImage(name: "leaderboard-panel")
          .scaledToFill()
          .opacity(0.84)
          .clipShape(RoundedRectangle(cornerRadius: RaidMetrics.cardRadius))
      )
      .overlay(
        RoundedRectangle(cornerRadius: RaidMetrics.cardRadius)
          .stroke(RaidTheme.orange.opacity(0.72), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title). \(detail)")
  }
}

struct PlayerHubView: View {
  @EnvironmentObject private var model: AppModel
  let section: AppModel.HubSection

  var body: some View {
    ZStack {
      GameArtwork(name: "background")
        .overlay(.black.opacity(0.5))
      ScrollView {
        VStack(spacing: 20) {
          RaidScreenHeading(title: "GHOST LODGE")
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
            .buttonStyle(RaidPrimaryButtonStyle())
        }
        .font(RaidTypography.body)
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
        .font(RaidTypography.screenTitle)
      ProgressView(value: Double(model.progress.experienceWithinLevel), total: 500)
        .tint(.orange)
      Text("\(model.progress.experienceWithinLevel) / 500 XP")
        .font(RaidTypography.caption.monospacedDigit())
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
            Text(mission.title).font(RaidTypography.sectionTitle)
            Spacer()
            Text("+\(mission.rewardEctoplasm)").foregroundStyle(.cyan)
          }
          ProgressView(
            value: Double(min(status.progress, mission.target)), total: Double(mission.target)
          )
          .tint(status.isClaimed ? .green : .orange)
          Text("\(min(status.progress, mission.target)) / \(mission.target)")
            .font(RaidTypography.caption.monospacedDigit())
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
          || item.id == model.equippedAuraID
        Button {
          model.equip(item)
        } label: {
          VStack(spacing: 10) {
            Image(systemName: unlocked ? "sparkles" : "lock.fill")
              .font(.system(size: 30, weight: .bold))
              .foregroundStyle(unlocked ? .cyan : .white.opacity(0.4))
            Text(item.name).font(RaidTypography.sectionTitle)
            Text(
              equipped
                ? "EQUIPPED" : unlocked ? "Tap to equip" : "Unlock at level \(item.unlockLevel)"
            )
            .font(RaidTypography.caption)
            .foregroundStyle(equipped ? .orange : .white.opacity(0.62))
          }
          .frame(maxWidth: .infinity, minHeight: 125)
          .padding(12)
          .background(
            BundledImage(name: "leaderboard-panel")
              .scaledToFill()
              .opacity(unlocked ? 0.72 : 0.48)
              .clipShape(RoundedRectangle(cornerRadius: 15))
          )
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
      Text("\(value)").font(RaidTypography.cardTitle).monospacedDigit()
      Text(title).font(RaidTypography.caption).foregroundStyle(.white.opacity(0.72))
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

struct GameOverView: View {
  @EnvironmentObject private var model: AppModel
  let summary: RunSummary
  let progression: ProgressionUpdate
  let leaderboard: Leaderboard
  let entryID: UUID

  var body: some View {
    GeometryReader { proxy in
      let isLandscape = proxy.size.width / max(1, proxy.size.height) >= 1.15
      let cardWidth =
        isLandscape
        ? min(520, max(340, proxy.size.width * 0.5))
        : min(560, max(300, proxy.size.width - 48))
      let entryLimit = proxy.size.height < 760 ? 2 : proxy.size.height < 980 ? 3 : 5
      let visibleEntries = Array(leaderboard.entries.prefix(entryLimit))
      let rowHeight: CGFloat = proxy.size.height < 760 ? 44 : 54
      ZStack {
        gameOverBackdrop(isLandscape: isLandscape, size: proxy.size)
        if isLandscape {
          Text("GAME OVER")
            .font(RaidTypography.screenTitle)
            .foregroundStyle(.orange)
            .shadow(color: .black.opacity(0.75), radius: 4, y: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
        }

        ScrollView {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
              leaderboardCard(
                width: cardWidth,
                rowHeight: rowHeight,
                visibleEntries: visibleEntries
              )
              gameOverActions
            }
            VStack(spacing: 18) {
              leaderboardCard(
                width: cardWidth,
                rowHeight: rowHeight,
                visibleEntries: visibleEntries
              )
              gameOverActions
            }
          }
          .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
          .padding(.horizontal, 24)
          .padding(.top, isLandscape ? 82 : max(170, proxy.size.height * 0.19))
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
      }
    }
    .ignoresSafeArea()
  }

  private func leaderboardCard(
    width: CGFloat,
    rowHeight: CGFloat,
    visibleEntries: [LeaderboardEntry]
  ) -> some View {
    VStack(spacing: 0) {
      VStack(spacing: 5) {
        Text("\(summary.score)")
          .font(.custom("GapstownAHBold", size: 48, relativeTo: .largeTitle))
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
        .font(RaidTypography.support)
        .foregroundStyle(.cyan)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        if summary.assisted {
          Text("ASSISTED RUN")
            .font(RaidTypography.caption)
            .foregroundStyle(.yellow)
        } else if progression.isNewBest {
          Text("NEW PERSONAL BEST")
            .font(RaidTypography.caption)
            .foregroundStyle(.yellow)
        }
      }
      .frame(minHeight: 128)

      HStack {
        Label("\(modeTitle) LEADERBOARD", systemImage: "trophy.fill")
        Spacer()
        Text("BEST  \(leaderboard.bestScore)")
          .monospacedDigit()
      }
      .font(RaidTypography.support)
      .foregroundStyle(.orange)
      .frame(height: 56)

      Divider().overlay(.white.opacity(0.25))

      if visibleEntries.isEmpty {
        Text("Complete a run to claim the first place.")
          .font(RaidTypography.support)
          .foregroundStyle(.white.opacity(0.82))
          .frame(height: rowHeight)
      } else {
        ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
          leaderboardRow(rank: index + 1, entry: entry)
            .frame(height: rowHeight)
        }
      }
    }
    .padding(.horizontal, min(30, width * 0.07))
    .padding(.vertical, 12)
    .frame(width: width)
    .background {
      ZStack {
        RoundedRectangle(cornerRadius: 20)
          .fill(.black.opacity(0.9))
        BundledImage(name: "leaderboard-panel")
          .scaledToFill()
          .opacity(0.5)
          .clipShape(RoundedRectangle(cornerRadius: 20))
        LinearGradient(
          colors: [.black.opacity(0.08), .black.opacity(0.48)],
          startPoint: .top,
          endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(.orange.opacity(0.9), lineWidth: 1.5)
    )
  }

  private var gameOverActions: some View {
    VStack(spacing: 12) {
      Button("Play again") { model.beginGame(mode: summary.mode) }
        .buttonStyle(RaidPrimaryButtonStyle())
      HStack(spacing: 18) {
        Button {
          model.showStart()
        } label: {
          RaidArtworkIconLabel(artName: "setting_started_button", title: "Home")
        }
        .buttonStyle(RaidArtworkIconButtonStyle())
        #if !os(tvOS)
          ShareLink(
            item: model.lastChallenge?.shareText
              ?? "I scored \(summary.score) points in Pumkin Raid!"
          ) {
            RaidArtworkIconLabel(artName: "sweet2", title: "Share")
          }
          .buttonStyle(RaidArtworkIconButtonStyle())
        #endif
      }
    }
    .foregroundStyle(.white)
  }

  @ViewBuilder
  private func gameOverBackdrop(isLandscape: Bool, size: CGSize) -> some View {
    if isLandscape {
      BundledImage(name: "background-wide")
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay(Color(red: 0.22, green: 0.02, blue: 0.01).opacity(0.52))
      BundledImage(name: "button-death")
        .scaledToFit()
        .frame(width: min(size.width * 0.24, 300))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, max(18, size.width * 0.035))
        .padding(.bottom, 12)
        .opacity(0.78)
    } else {
      BundledImage(name: "gameover-backdrop-tablet")
        .scaledToFill()
        .frame(width: size.width, height: size.height)
        .clipped()
    }
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
      Text("\(value)").font(RaidTypography.sectionTitle.monospacedDigit())
      Text(title)
        .font(RaidTypography.caption)
        .foregroundStyle(.white.opacity(0.72))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
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
    .font(RaidTypography.body.weight(entry.id == entryID ? .heavy : .semibold))
    .foregroundStyle(entry.id == entryID ? .orange : .white)
    .padding(.horizontal, 8)
    .background(
      entry.id == entryID ? Color.orange.opacity(0.14) : .clear,
      in: RoundedRectangle(cornerRadius: 9)
    )
  }
}
