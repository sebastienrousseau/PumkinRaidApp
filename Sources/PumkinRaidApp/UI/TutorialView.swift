import SwiftUI

struct TutorialView: View {
  private enum Lesson: Int, CaseIterable {
    case move, dash, shriek, ready

    var title: String {
      switch self {
      case .move: "Move the ghost"
      case .dash: "Dash through danger"
      case .shriek: "Clear the circle"
      case .ready: "You are raid-ready"
      }
    }

    var detail: String {
      switch self {
      case .move: "Drag the ghost into the glowing target."
      case .dash: "Swipe quickly across the pumpkin or use the Dash button."
      case .shriek: "Tap the arena or use Shriek when pumpkins surround you."
      case .ready: "Chain dashes, collect sweets, and protect your lives."
      }
    }
  }

  @EnvironmentObject private var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var lesson = Lesson.move
  @State private var ghostPosition = CGPoint(x: 0.28, y: 0.72)
  @State private var actionPulse = false

  var body: some View {
    ZStack {
      GameArtwork(name: "background")
        .overlay(.black.opacity(0.48))

      VStack(spacing: 16) {
        RaidScreenHeading(title: "GHOST SCHOOL")

        lessonProgress

        RaidGlassPanel {
          VStack(spacing: 14) {
            Text(lesson.title)
              .font(RaidTypography.cardTitle)
            Text(lesson.detail)
              .font(RaidTypography.support)
              .foregroundStyle(.white.opacity(0.78))
              .multilineTextAlignment(.center)

            practiceArena

            #if os(tvOS)
              if lesson == .move {
                Button("MOVE TO TARGET") { advance() }
                  .buttonStyle(RaidPrimaryButtonStyle(tint: RaidTheme.moon))
              }
            #endif
            if lesson == .dash {
              dashButton
            } else if lesson == .shriek {
              shriekButton
            } else if lesson == .ready {
              Button("CHOOSE YOUR RAID") { model.completeTutorial() }
                .buttonStyle(RaidPrimaryButtonStyle())
            }
          }
          .foregroundStyle(.white)
        }
        .frame(maxWidth: 560)

        Button("Skip tutorial") { model.completeTutorial() }
          .buttonStyle(RaidSecondaryButtonStyle())
      }
      .padding(22)
    }
    .ignoresSafeArea()
  }

  private var lessonProgress: some View {
    HStack(spacing: 7) {
      ForEach(Lesson.allCases, id: \.rawValue) { item in
        Capsule()
          .fill(item.rawValue <= lesson.rawValue ? RaidTheme.orange : .white.opacity(0.22))
          .frame(width: item == lesson ? 38 : 12, height: 8)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Tutorial step \(lesson.rawValue + 1) of \(Lesson.allCases.count)")
  }

  private var practiceArena: some View {
    GeometryReader { proxy in
      let ghostPoint = CGPoint(
        x: ghostPosition.x * proxy.size.width,
        y: ghostPosition.y * proxy.size.height
      )
      ZStack {
        RoundedRectangle(cornerRadius: 20)
          .fill(RaidTheme.ink.opacity(0.82))
          .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.15)))

        if lesson == .move {
          Circle()
            .stroke(RaidTheme.moon, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            .frame(width: 74, height: 74)
            .position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.34)
        } else if lesson == .dash || lesson == .shriek {
          pumpkin
            .position(x: proxy.size.width * 0.7, y: proxy.size.height * 0.38)
          if lesson == .shriek {
            pumpkin
              .position(x: proxy.size.width * 0.26, y: proxy.size.height * 0.32)
          }
        } else {
          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 78, weight: .bold))
            .foregroundStyle(.green)
            .symbolEffect(.bounce, value: lesson)
        }

        if lesson != .ready {
          practiceGhost(at: ghostPoint, in: proxy.size)
        }
      }
    }
    .frame(height: 250)
  }

  @ViewBuilder
  private var dashButton: some View {
    #if os(tvOS)
      Button("DASH") { completeActionLesson() }
        .buttonStyle(RaidPrimaryButtonStyle())
    #else
      Button("DASH") { completeActionLesson() }
        .buttonStyle(RaidPrimaryButtonStyle())
        .keyboardShortcut(.space, modifiers: [])
    #endif
  }

  @ViewBuilder
  private var shriekButton: some View {
    #if os(tvOS)
      Button("SHRIEK") { completeActionLesson() }
        .buttonStyle(RaidPrimaryButtonStyle(tint: .purple))
    #else
      Button("SHRIEK") { completeActionLesson() }
        .buttonStyle(RaidPrimaryButtonStyle(tint: .purple))
        .keyboardShortcut(.return, modifiers: [])
    #endif
  }

  @ViewBuilder
  private func practiceGhost(at point: CGPoint, in size: CGSize) -> some View {
    #if os(tvOS)
      BundledImage(name: "phantom")
        .scaledToFit()
        .frame(width: 72, height: 72)
        .scaleEffect(actionPulse ? 1.18 : 1)
        .position(point)
        .accessibilityLabel("Practice ghost")
    #else
      BundledImage(name: "phantom")
        .scaledToFit()
        .frame(width: 72, height: 72)
        .scaleEffect(actionPulse ? 1.18 : 1)
        .position(point)
        .gesture(dragGesture(in: size))
        .accessibilityLabel("Practice ghost")
        .accessibilityHint("Drag toward the target")
    #endif
  }

  private var pumpkin: some View {
    BundledImage(name: "pumpkin1")
      .scaledToFit()
      .frame(width: 70, height: 70)
      .opacity(actionPulse ? 0 : 1)
  }

  #if !os(tvOS)
    private func dragGesture(in size: CGSize) -> some Gesture {
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          ghostPosition = CGPoint(
            x: min(0.9, max(0.1, value.location.x / max(1, size.width))),
            y: min(0.86, max(0.14, value.location.y / max(1, size.height)))
          )
        }
        .onEnded { value in
          if lesson == .move,
            value.location.x > size.width * 0.57,
            value.location.y < size.height * 0.54
          {
            advance()
          } else if lesson == .dash, value.translation.width > size.width * 0.24 {
            completeActionLesson()
          }
        }
    }
  #endif

  private func completeActionLesson() {
    withAnimation(reduceMotion ? nil : .spring(duration: 0.24)) { actionPulse = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.22)) {
      advance()
    }
  }

  private func advance() {
    guard let next = Lesson(rawValue: lesson.rawValue + 1) else { return }
    withAnimation(reduceMotion ? nil : .spring(duration: 0.34)) {
      lesson = next
      ghostPosition = CGPoint(x: 0.28, y: 0.72)
      actionPulse = false
    }
  }
}
