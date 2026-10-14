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
        startBackdrop(layout: layout)

        VStack(spacing: layout.isCompact ? 10 : 16) {
          RaidTitle(fontSize: layout.titleSize)

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
          .scaleEffect(layout.actionScale)
          .padding(.vertical, 34 * (layout.actionScale - 1))
          .accessibilityHint("Opens game mode selection")
        }
        .frame(width: layout.contentWidth, height: layout.contentRegionHeight, alignment: .top)
        .position(layout.contentCenter)

        Button {
          model.showSettings()
        } label: {
          RaidArtworkIconLabel(
            artName: "setting_tutorial_button", title: "Guide", size: layout.guideSize)
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
  private func startBackdrop(layout: StartLayoutMetrics) -> some View {
    if layout.isLandscape {
      BundledImage(name: "background-wide")
        .scaledToFill()
        .frame(width: layout.size.width, height: layout.size.height)
        .clipped()
        .overlay(.black.opacity(0.18))
      ZStack(alignment: .bottom) {
        BundledImage(name: "pumpkin1")
          .scaledToFit()
          .frame(width: layout.pumpkinArtworkWidth)
          .offset(x: -min(120, layout.size.width * 0.055), y: -12)
        BundledImage(name: "phantom")
          .scaledToFit()
          .frame(width: layout.ghostArtworkWidth)
          .offset(
            x: min(110, layout.size.width * 0.05),
            y: -min(130, layout.size.height * 0.12)
          )
      }
      .frame(width: layout.size.width * 0.48, height: layout.size.height * 0.76)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      .padding(.trailing, max(20, layout.size.width * 0.035))
    } else {
      BundledImage(name: "splash-backdrop-tablet")
        .scaledToFill()
        .frame(width: layout.size.width, height: layout.size.height)
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
      let horizontalInset = max(16, proxy.safeAreaInsets.leading + 12)
      let verticalInset = max(16, proxy.safeAreaInsets.top + 8)
      let guideWidth: CGFloat = proxy.size.width >= 1_200 ? 900 : 784
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
          .frame(maxWidth: guideWidth - 64)
          .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .frame(
          maxWidth: guideWidth,
          maxHeight: min(900, max(320, proxy.size.height - verticalInset * 2))
        )
        .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 28))
        .overlay(
          RoundedRectangle(cornerRadius: 28)
            .stroke(RaidTheme.orange.opacity(0.82), lineWidth: 2)
        )
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
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
              detail: "No game over: practice movement and flowing combos.",
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
