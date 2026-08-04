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
  static let screenTitle = Font.custom("Creepsville", size: 48, relativeTo: .largeTitle)
  static let sectionTitle = Font.custom("GapstownAHBold", size: 28, relativeTo: .title2)
  static let cardTitle = Font.custom("GapstownAHBold", size: 27, relativeTo: .title2)
  static let body = Font.system(size: 20, weight: .medium, design: .rounded)
  static let support = Font.system(size: 18, weight: .semibold, design: .rounded)
  static let caption = Font.system(size: 16, weight: .semibold, design: .rounded)
  static let action = Font.custom("GapstownAHBold", size: 25, relativeTo: .title3)
}

enum RaidMetrics {
  static let compactSpacing: CGFloat = 8
  static let standardSpacing: CGFloat = 16
  static let sectionSpacing: CGFloat = 24
  static let contentPadding: CGFloat = 24
  static let cardRadius: CGFloat = 20
  static let panelRadius: CGFloat = 24
  static let controlHeight: CGFloat = 64
}

struct StartLayoutMetrics: Equatable {
  let size: CGSize
  let safeTop: CGFloat

  var isLandscape: Bool { size.width / max(1, size.height) > 1.15 }
  var isExpandedLandscape: Bool { isLandscape && min(size.width, size.height) >= 700 }
  var isCompact: Bool { min(size.width, size.height) < 600 }
  var playSize: CGFloat {
    if isExpandedLandscape { return min(210, max(156, min(size.width, size.height) * 0.18)) }
    return min(124, max(88, min(size.width, size.height) * 0.25))
  }
  var titleSize: CGFloat {
    if isExpandedLandscape { return min(104, max(82, min(size.width, size.height) * 0.09)) }
    return isCompact ? 48 : 72
  }
  var actionScale: CGFloat {
    isExpandedLandscape ? min(1.35, max(1.15, min(size.width, size.height) / 800)) : 1
  }
  var guideSize: CGFloat { isExpandedLandscape ? 82 : 62 }
  var contentTop: CGFloat { max(16, safeTop + 12) }
  var contentRegionHeight: CGFloat {
    if isExpandedLandscape { return min(620, size.height * 0.64) }
    if isLandscape { return min(size.height - contentTop * 2, 390) }
    return min(size.height * 0.47 - contentTop, isCompact ? 300 : 390)
  }
  var contentCenter: CGPoint {
    let defaultY = contentTop + max(1, contentRegionHeight) / 2
    return CGPoint(
      x: isLandscape ? size.width * 0.28 : size.width / 2,
      y: isExpandedLandscape ? max(defaultY, size.height * 0.43) : defaultY
    )
  }
  var contentWidth: CGFloat {
    if isExpandedLandscape { return min(680, size.width * 0.46) }
    return isLandscape ? min(440, size.width * 0.46) : min(520, size.width - 32)
  }
  var ghostArtworkWidth: CGFloat { min(420, size.height * 0.43) }
  var pumpkinArtworkWidth: CGFloat { min(330, size.height * 0.33) }
}

struct GameOverLayoutMetrics: Equatable {
  let size: CGSize
  let safeTop: CGFloat
  let safeBottom: CGFloat

  var isLandscape: Bool { size.width / max(1, size.height) >= 1.15 }
  var isWideDesktop: Bool { size.width >= 1_200 && size.height >= 700 }
  var cardWidth: CGFloat {
    isLandscape
      ? min(isWideDesktop ? 620 : 520, max(340, size.width * 0.44))
      : min(560, max(300, size.width - 48))
  }
  var topInset: CGFloat {
    isLandscape ? max(76, safeTop + 18) : max(170, size.height * 0.19)
  }
  var bottomInset: CGFloat { max(24, safeBottom + 16) }
  var availableHeight: CGFloat { max(1, size.height - topInset - bottomInset) }
}

struct RaidTitle: View {
  let fontSize: CGFloat

  var body: some View {
    VStack(spacing: fontSize < 60 ? -8 : -12) {
      Text("PUMKIN")
      Text("RAID")
    }
    .font(.custom("Creepsville", size: fontSize, relativeTo: .largeTitle))
    .tracking(0.5)
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
  @Environment(\.isFocused) private var isFocused
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var tint = RaidTheme.orange

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(RaidTypography.action)
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .shadow(color: .black.opacity(0.9), radius: 2, y: 2)
      .frame(minWidth: 180, minHeight: 72)
      .padding(.horizontal, 72)
      .background(
        BundledImage(name: "raid-primary-button-v2")
          .scaledToFit()
          .brightness(configuration.isPressed ? -0.16 : 0)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : (isFocused ? 1.055 : 1))
      .shadow(color: tint.opacity(isFocused ? 0.82 : 0.5), radius: isFocused ? 22 : 12, y: 6)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

struct RaidSecondaryButtonStyle: ButtonStyle {
  @Environment(\.isFocused) private var isFocused
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(RaidTypography.action)
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .shadow(color: .black.opacity(0.9), radius: 2, y: 2)
      .frame(minWidth: 180, minHeight: 66)
      .padding(.horizontal, 68)
      .background(
        BundledImage(name: "raid-secondary-button-v2")
          .scaledToFit()
          .brightness(configuration.isPressed ? -0.15 : 0)
      )
      .scaleEffect(configuration.isPressed ? 0.96 : (isFocused ? 1.05 : 1))
      .shadow(color: RaidTheme.moon.opacity(isFocused ? 0.72 : 0.3), radius: isFocused ? 20 : 8)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

struct RaidArtworkIconButtonStyle: ButtonStyle {
  @Environment(\.isFocused) private var isFocused
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : (isFocused ? 1.08 : 1))
      .brightness(configuration.isPressed ? -0.14 : 0)
      .shadow(color: RaidTheme.orange.opacity(isFocused ? 0.8 : 0.35), radius: 12)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

struct RaidArtworkIconLabel: View {
  let artName: String
  let title: String
  var size: CGFloat = 62

  var body: some View {
    VStack(spacing: 4) {
      BundledImage(name: artName)
        .scaledToFit()
        .frame(width: size, height: size)
      Text(title)
        .font(.custom("GapstownAHBold", size: 19, relativeTo: .headline))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .shadow(color: .black, radius: 2, y: 2)
    }
    .frame(minWidth: max(76, size + 14), minHeight: size + 28)
    .contentShape(Rectangle())
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
    .accessibilityElement(children: .combine)
    .accessibilityValue(configuration.isOn ? "On" : "Off")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { configuration.isOn.toggle() }
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
