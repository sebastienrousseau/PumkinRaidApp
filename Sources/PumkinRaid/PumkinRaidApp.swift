import SwiftUI

@main
struct PumkinRaidApp: App {
  @StateObject private var model = AppModel()
  #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
  #endif

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(model)
        .preferredColorScheme(.dark)
    }
    #if os(macOS)
      .windowStyle(.hiddenTitleBar)
      .defaultSize(width: 430, height: 720)
      .commands {
        CommandMenu("Controls") {
          Button("Start or Play Again") {
            if model.activeGameScene == nil { model.beginGame() }
          }
          .keyboardShortcut(.return, modifiers: [])
          Divider()
          movementCommand("Move Left", key: .leftArrow, horizontal: -24, vertical: 0)
          movementCommand("Move Right", key: .rightArrow, horizontal: 24, vertical: 0)
          movementCommand("Move Up", key: .upArrow, horizontal: 0, vertical: 24)
          movementCommand("Move Down", key: .downArrow, horizontal: 0, vertical: -24)
          Divider()
          movementCommand("Move Left (A)", key: "a", horizontal: -24, vertical: 0)
          movementCommand("Move Right (D)", key: "d", horizontal: 24, vertical: 0)
          movementCommand("Move Up (W)", key: "w", horizontal: 0, vertical: 24)
          movementCommand("Move Down (S)", key: "s", horizontal: 0, vertical: -24)
        }
      }
    #endif
  }

  #if os(macOS)
    private func movementCommand(
      _ title: String,
      key: KeyEquivalent,
      horizontal: CGFloat,
      vertical: CGFloat
    ) -> some View {
      Button(title) {
        model.movePhantom(horizontal: horizontal, vertical: vertical)
      }
      .keyboardShortcut(key, modifiers: [])
    }
  #endif
}
