#if os(macOS)
  import AppKit
  import SwiftUI

  @MainActor
  final class PumkinRaidApplication: NSApplication {
    var gameplayIsActive: (() -> Bool)?
    var movementKeyDown: ((UInt16) -> Void)?
    var gameplayPointerEvent: ((NSEvent) -> Bool)?

    override func sendEvent(_ event: NSEvent) {
      if gameplayIsActive?() == true,
        [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type),
        gameplayPointerEvent?(event) == true
      {
        return
      }
      if gameplayIsActive?() == true, KeyboardState.shared.handle(event) {
        if event.type == .keyDown, !event.isARepeat {
          movementKeyDown?(event.keyCode)
        }
        return
      }
      super.sendEvent(event)
    }
  }

  @MainActor
  final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
      let root = RootView()
        .environmentObject(model)
        .preferredColorScheme(.dark)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 430, height: 720),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window.title = "Pumkin Raid"
      window.titleVisibility = .hidden
      window.titlebarAppearsTransparent = true
      window.minSize = NSSize(width: 320, height: 568)
      window.contentView = NSHostingView(rootView: root)
      window.center()
      window.makeKeyAndOrderFront(nil)
      self.window = window

      let application = PumkinRaidApplication.shared as! PumkinRaidApplication
      application.gameplayIsActive = { [weak model] in
        model?.activeGameScene != nil
      }
      application.movementKeyDown = { [weak model] keyCode in
        switch keyCode {
        case 0, 123: model?.movePhantom(horizontal: -24, vertical: 0)
        case 2, 124: model?.movePhantom(horizontal: 24, vertical: 0)
        case 1, 125: model?.movePhantom(horizontal: 0, vertical: -24)
        case 13, 126: model?.movePhantom(horizontal: 0, vertical: 24)
        default: break
        }
      }
      application.gameplayPointerEvent = { [weak model] event in
        model?.handlePointerEvent(event) ?? false
      }
      buildMainMenu()
      NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
      AudioManager.shared.startMusic(
        enabled: model.settings.musicEnabled && model.shouldPlayMusic
      )
    }

    func applicationDidResignActive(_ notification: Notification) {
      KeyboardState.shared.clear()
      AudioManager.shared.stopAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
      true
    }

    func applicationWillTerminate(_ notification: Notification) {
      KeyboardState.shared.clear()
      AudioManager.shared.stopAll()
    }

    private func buildMainMenu() {
      let mainMenu = NSMenu()
      let applicationItem = NSMenuItem()
      let applicationMenu = NSMenu(title: "Pumkin Raid")
      let settingsItem = NSMenuItem(
        title: "Settings & Guide…",
        action: #selector(showGuide),
        keyEquivalent: ","
      )
      settingsItem.target = self
      applicationMenu.addItem(settingsItem)
      applicationMenu.addItem(.separator())
      applicationMenu.addItem(
        withTitle: "Quit Pumkin Raid",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
      )
      applicationItem.submenu = applicationMenu
      mainMenu.addItem(applicationItem)

      let viewItem = NSMenuItem()
      let viewMenu = NSMenu(title: "View")
      let fullScreenItem = NSMenuItem(
        title: "Toggle Full Screen",
        action: #selector(NSWindow.toggleFullScreen(_:)),
        keyEquivalent: "f"
      )
      fullScreenItem.keyEquivalentModifierMask = [.command, .control]
      fullScreenItem.target = window
      viewMenu.addItem(fullScreenItem)
      viewItem.submenu = viewMenu
      mainMenu.addItem(viewItem)

      let controlsItem = NSMenuItem()
      let controlsMenu = NSMenu(title: "Controls")
      let startItem = NSMenuItem(
        title: "Start or Play Again",
        action: #selector(startGame),
        keyEquivalent: "\r"
      )
      startItem.target = self
      controlsMenu.addItem(startItem)
      controlsItem.submenu = controlsMenu
      mainMenu.addItem(controlsItem)
      NSApp.mainMenu = mainMenu
    }

    @objc private func startGame() {
      guard model.activeGameScene == nil else { return }
      model.beginGame()
    }

    @objc private func showGuide() {
      guard model.activeGameScene == nil else { return }
      model.showSettings()
    }
  }
#endif
