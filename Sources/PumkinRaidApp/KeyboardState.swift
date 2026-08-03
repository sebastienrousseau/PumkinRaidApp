#if os(macOS)
  import AppKit

  @MainActor
  final class KeyboardState {
    static let shared = KeyboardState()

    private var pressedKeys: Set<UInt16> = []
    private let movementKeys: Set<UInt16> = [0, 1, 2, 13, 123, 124, 125, 126]

    private init() {}

    func handle(_ event: NSEvent) -> Bool {
      guard movementKeys.contains(event.keyCode) else { return false }
      switch event.type {
      case .keyDown:
        pressedKeys.insert(event.keyCode)
      case .keyUp:
        pressedKeys.remove(event.keyCode)
      default:
        return false
      }
      return true
    }

    func isPressed(_ keyCode: UInt16) -> Bool {
      pressedKeys.contains(keyCode)
    }

    func clear() {
      pressedKeys.removeAll()
    }
  }
#endif
