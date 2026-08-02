#if os(macOS)
  import AppKit

  @MainActor
  final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var keyboardMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
      keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        MacKeyboardRouter.shared.handle(event) ? nil : event
      }
      NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
      true
    }

    func applicationWillTerminate(_ notification: Notification) {
      AudioManager.shared.stopAll()
      if let keyboardMonitor {
        NSEvent.removeMonitor(keyboardMonitor)
      }
    }
  }

  @MainActor
  final class MacKeyboardRouter {
    static let shared = MacKeyboardRouter()
    weak var scene: GameScene?

    func handle(_ event: NSEvent) -> Bool {
      guard let scene else { return false }
      let amount: CGFloat = event.isARepeat ? 12 : 20
      switch event.keyCode {
      case 123: scene.movePhantom(horizontal: -amount, vertical: 0)
      case 124: scene.movePhantom(horizontal: amount, vertical: 0)
      case 125: scene.movePhantom(horizontal: 0, vertical: -amount)
      case 126: scene.movePhantom(horizontal: 0, vertical: amount)
      default:
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "a": scene.movePhantom(horizontal: -amount, vertical: 0)
        case "d": scene.movePhantom(horizontal: amount, vertical: 0)
        case "s": scene.movePhantom(horizontal: 0, vertical: -amount)
        case "w": scene.movePhantom(horizontal: 0, vertical: amount)
        default: return false
        }
      }
      return true
    }
  }
#endif
