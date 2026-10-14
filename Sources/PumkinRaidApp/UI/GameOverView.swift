import GameEngineLib
import SwiftUI

/// Plaque and leaderboard results screen shown after a run completes.
struct GameOverView: View {
  @EnvironmentObject private var model: AppModel
  let summary: RunSummary
  let progression: ProgressionUpdate
  let leaderboard: Leaderboard
  let entryID: UUID

  var body: some View {
    GeometryReader { proxy in
      let layout = GameOverLayoutMetrics(
        size: proxy.size,
        safeTop: proxy.safeAreaInsets.top,
        safeBottom: proxy.safeAreaInsets.bottom
      )
      let entryLimit = proxy.size.height < 680 ? 3 : proxy.size.height < 860 ? 5 : 7
      let visibleEntries = Array(leaderboard.entries.prefix(entryLimit))
      let rowHeight: CGFloat = proxy.size.height < 760 ? 50 : 58
      ZStack {
        gameOverBackdrop(isLandscape: layout.isLandscape, size: proxy.size)
        if layout.isLandscape {
          Text("GAME OVER")
            .font(.custom("Gang of Three", size: 40, relativeTo: .largeTitle))
            .foregroundStyle(
              LinearGradient(
                colors: [
                  Color(red: 1.0, green: 0.98, blue: 0.8),
                  Color(red: 1.0, green: 0.78, blue: 0.2),
                  Color(red: 0.92, green: 0.24, blue: 0.02),
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .shadow(color: .black.opacity(0.85), radius: 5, y: 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 10)
        }

        ScrollView {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
              leaderboardCard(
                width: layout.cardWidth,
                rowHeight: rowHeight,
                visibleEntries: visibleEntries
              )
              gameOverActions
            }
            VStack(spacing: 18) {
              leaderboardCard(
                width: layout.cardWidth,
                rowHeight: rowHeight,
                visibleEntries: visibleEntries
              )
              gameOverActions
            }
          }
          .frame(maxWidth: .infinity, minHeight: layout.availableHeight, alignment: .center)
          .padding(.horizontal, 24)
          .padding(.top, layout.topInset)
          .padding(.bottom, layout.bottomInset)
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
      VStack(spacing: 6) {
        Text("\(summary.score)")
          .font(.system(size: 64, weight: .black, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [
                Color(red: 1.0, green: 0.98, blue: 0.82),
                Color(red: 1.0, green: 0.8, blue: 0.2),
                Color(red: 1.0, green: 0.45, blue: 0.0),
              ],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .shadow(color: .black.opacity(0.8), radius: 3, y: 3)
          .monospacedDigit()
        HStack(spacing: 12) {
          resultMetric("Smashed", summary.statistics.destroyed)
          resultMetric("Near misses", summary.statistics.nearMisses)
          resultMetric("Best combo", summary.statistics.bestCombo)
        }
        Text(
          "+\(progression.experienceAwarded) XP  •  +\(progression.ectoplasmAwarded) ectoplasm"
        )
        .font(RaidTypography.support)
        .foregroundStyle(Color(red: 1.0, green: 0.88, blue: 0.55))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        if progression.isNewBest {
          Text("★ NEW HIGH SCORE! ★")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(.yellow)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(Color.yellow.opacity(0.6), lineWidth: 1))
        } else if summary.assisted {
          Text("ASSISTED RUN")
            .font(RaidTypography.caption)
            .foregroundStyle(.yellow)
        }
      }
      .frame(minHeight: 140)

      HStack {
        Label("\(modeTitle) HIGH SCORES", systemImage: "trophy.fill")
          .font(.custom("Gang of Three", size: 19))
        Spacer()
        Text("RECORD  \(leaderboard.bestScore)")
          .font(.custom("Gang of Three", size: 17))
          .foregroundStyle(.yellow)
          .monospacedDigit()
      }
      .foregroundStyle(.orange)
      .frame(height: 48)

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
    .padding(.vertical, 14)
    .frame(width: width)
    .background {
      ZStack {
        RoundedRectangle(cornerRadius: 20)
          .fill(.black.opacity(0.92))
        BundledImage(name: "leaderboard-panel")
          .scaledToFill()
          .opacity(0.65)
          .clipShape(RoundedRectangle(cornerRadius: 20))
        LinearGradient(
          colors: [.black.opacity(0.06), .black.opacity(0.55)],
          startPoint: .top,
          endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(
          LinearGradient(
            colors: [Color.yellow.opacity(0.9), Color.orange.opacity(0.9), Color.red.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 2
        )
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
    HStack(spacing: 12) {
      rankMedallion(rank)
      HStack(spacing: 6) {
        Text(entry.playerName)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .lineLimit(1)
        if entry.id == entryID {
          Text("YOU")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange, in: Capsule())
        }
      }
      Spacer()
      Text("\(entry.score)")
        .font(.system(size: 22, weight: .heavy, design: .rounded))
        .foregroundStyle(Color.yellow)
        .monospacedDigit()
    }
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      entry.id == entryID ? Color.orange.opacity(0.18) : Color.white.opacity(0.04),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(entry.id == entryID ? Color.orange : Color.white.opacity(0.08), lineWidth: 1)
    )
  }

  @ViewBuilder
  private func rankMedallion(_ rank: Int) -> some View {
    switch rank {
    case 1:
      podiumBadge(
        rank: 1,
        colors: [Color(red: 1.0, green: 0.9, blue: 0.3), Color(red: 0.95, green: 0.65, blue: 0.0)],
        size: 28,
        fontSize: 15,
        shadowColor: .yellow.opacity(0.5)
      )
    case 2:
      podiumBadge(
        rank: 2,
        colors: [Color(white: 0.95), Color(white: 0.7)],
        size: 26,
        fontSize: 14
      )
    case 3:
      podiumBadge(
        rank: 3,
        colors: [
          Color(red: 0.9, green: 0.6, blue: 0.3), Color(red: 0.65, green: 0.35, blue: 0.15),
        ],
        size: 26,
        fontSize: 14
      )
    default:
      Text("#\(rank)")
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.55))
        .frame(width: 26, alignment: .center)
    }
  }

  private func podiumBadge(
    rank: Int,
    colors: [Color],
    size: CGFloat,
    fontSize: CGFloat,
    shadowColor: Color = .clear
  ) -> some View {
    ZStack {
      Circle()
        .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
        .frame(width: size, height: size)
        .shadow(color: shadowColor, radius: 4)
      Text("\(rank)")
        .font(.system(size: fontSize, weight: .black, design: .rounded))
        .foregroundStyle(.black)
    }
  }
}
