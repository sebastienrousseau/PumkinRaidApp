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
    #endif
  }
}
