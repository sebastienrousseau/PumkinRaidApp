#if os(macOS)
  import AppKit
  import SpriteKit
  import SwiftUI

  struct GameSceneView: NSViewRepresentable {
    let scene: GameScene

    func makeNSView(context: Context) -> KeyboardGameView {
      let view = KeyboardGameView(frame: .zero)
      view.gameScene = scene
      view.ignoresSiblingOrder = true
      view.preferredFramesPerSecond = 60
      view.presentScene(scene)
      return view
    }

    func updateNSView(_ view: KeyboardGameView, context: Context) {
      view.gameScene = scene
      if view.scene !== scene {
        view.presentScene(scene)
      }
      DispatchQueue.main.async {
        view.window?.makeFirstResponder(view)
      }
    }

    static func dismantleNSView(_ view: KeyboardGameView, coordinator: Void) {
      view.detachKeyboardMonitor()
      view.presentScene(nil)
    }
  }

  final class KeyboardGameView: SKView {
    weak var gameScene: GameScene?
    private var keyMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateKeyMonitor()
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.window?.makeFirstResponder(self)
      }
    }

    override func mouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
      if !handleMovementKey(event) { super.keyDown(with: event) }
    }

    private func updateKeyMonitor() {
      if window == nil {
        detachKeyboardMonitor()
      } else if keyMonitor == nil {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
          guard let self, NSApp.isActive, self.window?.isKeyWindow == true else { return event }
          return self.handleMovementKey(event) ? nil : event
        }
      }
    }

    func detachKeyboardMonitor() {
      guard let keyMonitor else { return }
      NSEvent.removeMonitor(keyMonitor)
      self.keyMonitor = nil
    }

    private func handleMovementKey(_ event: NSEvent) -> Bool {
      guard let gameScene else { return false }
      let distance: CGFloat = event.isARepeat ? 12 : 22
      switch event.keyCode {
      case 123:
        gameScene.movePhantom(horizontal: -distance, vertical: 0)
        return true
      case 124:
        gameScene.movePhantom(horizontal: distance, vertical: 0)
        return true
      case 125:
        gameScene.movePhantom(horizontal: 0, vertical: -distance)
        return true
      case 126:
        gameScene.movePhantom(horizontal: 0, vertical: distance)
        return true
      default:
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "a": gameScene.movePhantom(horizontal: -distance, vertical: 0)
        case "d": gameScene.movePhantom(horizontal: distance, vertical: 0)
        case "s": gameScene.movePhantom(horizontal: 0, vertical: -distance)
        case "w": gameScene.movePhantom(horizontal: 0, vertical: distance)
        default: return false
        }
        return true
      }
    }

  }
#endif
