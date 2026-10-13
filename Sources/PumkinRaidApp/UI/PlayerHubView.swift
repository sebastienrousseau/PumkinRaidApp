import GameEngineLib
import SwiftUI

/// Player hub displaying progression status, active missions, and unlockable cosmetics.
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
