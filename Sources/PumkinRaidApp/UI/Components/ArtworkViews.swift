import SwiftUI

struct GameArtwork: View {
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

enum RaidTheme {
  static let orange = Color(red: 1, green: 0.43, blue: 0.08)
  static let amber = Color(red: 1, green: 0.76, blue: 0.22)
  static let moon = Color(red: 0.73, green: 0.94, blue: 1)
  static let ink = Color(red: 0.025, green: 0.035, blue: 0.10)
}

enum RaidTypography {
  static let screenTitle = Font.system(.largeTitle, design: .rounded, weight: .black)
  static let sectionTitle = Font.system(.title3, design: .rounded, weight: .black)
  static let cardTitle = Font.system(.title2, design: .rounded, weight: .black)
  static let body = Font.system(.title3, design: .rounded, weight: .medium)
  static let support = Font.system(.body, design: .rounded, weight: .semibold)
  static let caption = Font.system(.subheadline, design: .rounded, weight: .semibold)
  static let action = Font.system(.title3, design: .rounded, weight: .black)
}

enum RaidMetrics {
  static let compactSpacing: CGFloat = 8
  static let standardSpacing: CGFloat = 16
  static let sectionSpacing: CGFloat = 24
  static let contentPadding: CGFloat = 24
  static let cardRadius: CGFloat = 20
  static let panelRadius: CGFloat = 24
  static let controlHeight: CGFloat = 48
}

struct StartLayoutMetrics: Equatable {
  let size: CGSize
  let safeTop: CGFloat

  var isLandscape: Bool { size.width / max(1, size.height) > 1.15 }
  var isCompact: Bool { min(size.width, size.height) < 600 || isLandscape }
  var playSize: CGFloat { min(124, max(88, min(size.width, size.height) * 0.25)) }
  var contentTop: CGFloat { max(16, safeTop + 12) }
  var contentRegionHeight: CGFloat {
    if isLandscape { return min(size.height - contentTop * 2, 390) }
    return min(size.height * 0.47 - contentTop, isCompact ? 300 : 390)
  }
  var contentCenter: CGPoint {
    CGPoint(
      x: isLandscape ? size.width * 0.28 : size.width / 2,
      y: contentTop + max(1, contentRegionHeight) / 2
    )
  }
  var contentWidth: CGFloat {
    isLandscape ? min(440, size.width * 0.46) : min(520, size.width - 32)
  }
}

struct RaidTitle: View {
  var compact = false

  var body: some View {
    VStack(spacing: compact ? -8 : -12) {
      Text("PUMKIN")
      Text("RAID")
    }
    .font(.system(size: compact ? 42 : 62, weight: .black, design: .rounded))
    .tracking(-2)
    .foregroundStyle(
      LinearGradient(
        colors: [RaidTheme.amber, RaidTheme.orange],
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .shadow(color: .black.opacity(0.85), radius: 2, y: 3)
    .shadow(color: RaidTheme.orange.opacity(0.42), radius: 18)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Pumkin Raid")
  }
}

struct RaidScreenHeading: View {
  let title: String
  var subtitle: String?

  var body: some View {
    VStack(spacing: RaidMetrics.compactSpacing) {
      Text(title)
        .font(RaidTypography.screenTitle)
        .foregroundStyle(RaidTheme.orange)
        .multilineTextAlignment(.center)
      if let subtitle {
        Text(subtitle)
          .font(RaidTypography.support)
          .foregroundStyle(.white.opacity(0.78))
          .multilineTextAlignment(.center)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

struct RaidPrimaryButtonStyle: ButtonStyle {
  var tint = RaidTheme.orange

  func makeBody(configuration: Configuration) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) {
        pumpkinButtonArt
        configuration.label
        sweetButtonArt
      }
      HStack(spacing: 9) {
        pumpkinButtonArt
        configuration.label
      }
      configuration.label
    }
    .font(RaidTypography.action)
    .foregroundStyle(.white)
    .lineLimit(1)
    .minimumScaleFactor(0.82)
    .frame(minHeight: 58)
    .padding(.horizontal, 18)
    .background(
      BundledImage(name: "leaderboard-panel")
        .scaledToFill()
        .opacity(configuration.isPressed ? 0.72 : 0.94)
        .overlay(tint.opacity(configuration.isPressed ? 0.28 : 0.16))
        .clipShape(Capsule())
    )
    .overlay(Capsule().stroke(tint.opacity(0.92), lineWidth: 2))
    .scaleEffect(configuration.isPressed ? 0.97 : 1)
    .shadow(color: tint.opacity(0.42), radius: 12, y: 6)
  }

  private var pumpkinButtonArt: some View {
    BundledImage(name: "setting_started_button")
      .scaledToFit()
      .frame(width: 42, height: 42)
  }

  private var sweetButtonArt: some View {
    BundledImage(name: "sweet1")
      .scaledToFit()
      .frame(width: 28, height: 28)
  }
}

struct RaidSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 9) {
        BundledImage(name: "sweet1")
          .scaledToFit()
          .frame(width: 26, height: 26)
        configuration.label
      }
      configuration.label
    }
    .font(RaidTypography.support)
    .foregroundStyle(.white)
    .lineLimit(1)
    .minimumScaleFactor(0.82)
    .frame(minHeight: 52)
    .padding(.horizontal, 18)
    .background(
      BundledImage(name: "leaderboard-panel")
        .scaledToFill()
        .opacity(configuration.isPressed ? 0.82 : 0.7)
        .clipShape(Capsule())
    )
    .overlay(Capsule().stroke(RaidTheme.orange.opacity(0.72), lineWidth: 1))
    .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}

struct SkullToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 18) {
      configuration.label
        .font(RaidTypography.body)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button {
        configuration.isOn.toggle()
      } label: {
        BundledImage(name: configuration.isOn ? "skull-toggle-on" : "skull-toggle-off")
          .scaledToFit()
          .frame(width: 116, height: 60)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(configuration.isOn ? "Turn off" : "Turn on")
      .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
    .frame(minHeight: 66)
    .contentShape(Rectangle())
  }
}

private struct MoonArtworkButtonStyle: ButtonStyle {
  let size: CGFloat
  let pulsing: Bool

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [.white, RaidTheme.moon, Color(red: 0.52, green: 0.68, blue: 0.68)],
            center: .topLeading,
            startRadius: 3,
            endRadius: size * 0.58
          )
        )
      Circle()
        .stroke(.white.opacity(0.9), lineWidth: 2)
      Circle()
        .fill(.black.opacity(0.08))
        .frame(width: size * 0.18)
        .offset(x: -size * 0.18, y: -size * 0.16)
      BundledImage(name: configuration.isPressed ? "button-arrow-pressed" : "button-arrow")
        .scaledToFit()
        .frame(width: size * 0.72, height: size * 0.72)
    }
    .frame(width: size, height: size)
    .contentShape(Circle())
    .scaleEffect(configuration.isPressed ? 0.94 : (pulsing ? 1.045 : 0.97))
    .shadow(color: RaidTheme.moon.opacity(0.9), radius: pulsing ? 28 : 14)
    .shadow(color: .white.opacity(0.65), radius: 7)
  }
}

struct MoonPlayButton: View {
  let size: CGFloat
  let pulsing: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) { Color.clear }
      .buttonStyle(MoonArtworkButtonStyle(size: size, pulsing: pulsing))
      .accessibilityLabel("Play Pumkin Raid")
      .accessibilityHint("Opens game mode selection")
  }
}

struct RaidGlassPanel<Content: View>: View {
  @ViewBuilder let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(RaidMetrics.sectionSpacing)
      .background(
        .black.opacity(0.76), in: RoundedRectangle(cornerRadius: RaidMetrics.panelRadius)
      )
      .background(
        .ultraThinMaterial, in: RoundedRectangle(cornerRadius: RaidMetrics.panelRadius)
      )
      .overlay(
        RoundedRectangle(cornerRadius: RaidMetrics.panelRadius)
          .stroke(
            LinearGradient(
              colors: [
                RaidTheme.amber, RaidTheme.orange.opacity(0.42), RaidTheme.moon.opacity(0.7),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1.5
          )
      )
      .shadow(color: .black.opacity(0.45), radius: 28, y: 12)
  }
}

struct ImageButton: View {
  let name: String
  let size: CGFloat

  var body: some View {
    BundledImage(name: name)
      .scaledToFit()
      .frame(width: size, height: size)
      .contentShape(Rectangle())
  }
}

struct BundledImage: View {
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
