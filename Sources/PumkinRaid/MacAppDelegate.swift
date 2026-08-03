#if os(macOS)
  import AppKit

  @MainActor
  final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
      NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
      true
    }

    func applicationWillTerminate(_ notification: Notification) {
      AudioManager.shared.stopAll()
    }
  }
#endif
