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
      case .game(let mode, let seed):
        GameView(
          settings: model.settings,
          mode: mode,
          seed: seed,
          cosmetics: CosmeticLoadout(
            ghostID: model.progress.equippedGhostID,
            trailID: model.progress.equippedTrailID,
            auraID: model.equippedAuraID
          )
        ) { summary in
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
