#if os(macOS)
  import AppKit
  import SwiftUI

  struct KeyboardCaptureView: NSViewRepresentable {
    let move: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> KeyView {
      let view = KeyView()
      view.move = move
      return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
      nsView.move = move
      DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
    }
  }

  final class KeyView: NSView {
    var move: ((CGFloat, CGFloat) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.window?.makeFirstResponder(self)
      }
    }

    override func keyDown(with event: NSEvent) {
      let amount: CGFloat = event.isARepeat ? 12 : 20
      switch event.keyCode {
      case 123: move?(-amount, 0)
      case 124: move?(amount, 0)
      case 125: move?(0, -amount)
      case 126: move?(0, amount)
      default:
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "a": move?(-amount, 0)
        case "d": move?(amount, 0)
        case "s": move?(0, -amount)
        case "w": move?(0, amount)
        default: super.keyDown(with: event)
        }
      }
    }
  }
#endif
