#if os(macOS)
  import AppKit

  @main
  enum PumkinRaidApp {
    @MainActor
    static func main() {
      let application = PumkinRaidApplication.shared as! PumkinRaidApplication
      let delegate = MacAppDelegate()
      application.delegate = delegate
      application.setActivationPolicy(.regular)
      application.run()
    }
  }
#else
  import SwiftUI

  @main
  struct PumkinRaidApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
      WindowGroup {
        RootView()
          .environmentObject(model)
          .preferredColorScheme(.dark)
      }
    }
  }
#endif
