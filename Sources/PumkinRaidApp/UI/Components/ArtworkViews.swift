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

struct MoonPlayButton: View {
  let size: CGFloat
  let pulsing: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
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
        Image(systemName: "arrow.right")
          .font(.system(size: size * 0.31, weight: .black, design: .rounded))
          .foregroundStyle(RaidTheme.ink)
          .offset(x: size * 0.025)
      }
      .frame(width: size, height: size)
      .contentShape(Circle())
      .scaleEffect(pulsing ? 1.045 : 0.97)
      .shadow(color: RaidTheme.moon.opacity(0.9), radius: pulsing ? 28 : 14)
      .shadow(color: .white.opacity(0.65), radius: 7)
    }
    .buttonStyle(.plain)
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
      .padding(22)
      .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 24))
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
      .overlay(
        RoundedRectangle(cornerRadius: 24)
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
