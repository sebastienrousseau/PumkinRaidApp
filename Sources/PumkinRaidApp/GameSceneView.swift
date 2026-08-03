#if os(macOS)
  import AppKit
  import SpriteKit
  import SwiftUI

  struct GameSceneView: NSViewRepresentable {
    let scene: GameScene

    func makeNSView(context: Context) -> KeyboardGameView {
      let view = KeyboardGameView(frame: .zero)
      view.ignoresSiblingOrder = true
      view.preferredFramesPerSecond = 60
      view.presentScene(scene)
      return view
    }

    func updateNSView(_ view: KeyboardGameView, context: Context) {
      if view.scene !== scene {
        view.presentScene(scene)
      }
      DispatchQueue.main.async {
        view.window?.makeFirstResponder(view)
      }
    }

    static func dismantleNSView(_ view: KeyboardGameView, coordinator: Void) {
      view.presentScene(nil)
    }
  }

  final class KeyboardGameView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.window?.makeFirstResponder(self)
      }
    }

    override func mouseDown(with event: NSEvent) {
      window?.makeFirstResponder(self)
      guard let scene = scene as? GameScene else {
        super.mouseDown(with: event)
        return
      }
      scene.handlePointerDown(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
      guard let scene = scene as? GameScene else {
        super.mouseDragged(with: event)
        return
      }
      scene.handlePointerDragged(to: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
      guard let scene = scene as? GameScene else {
        super.mouseUp(with: event)
        return
      }
      scene.handlePointerUp(at: convert(event.locationInWindow, from: nil))
    }

  }
#endif
