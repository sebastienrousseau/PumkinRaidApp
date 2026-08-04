#if os(macOS)
  import AppKit

  @MainActor
  final class KeyboardState {
    enum Action { case dash, shriek, pause }

    static let shared = KeyboardState()

    private var pressedKeys: Set<UInt16> = []
    private var actions: [Action] = []
    private let handledKeys: Set<UInt16> = [0, 1, 2, 13, 36, 49, 53, 123, 124, 125, 126]

    private init() {}

    func handle(_ event: NSEvent) -> Bool {
      guard handledKeys.contains(event.keyCode) else { return false }
      switch event.type {
      case .keyDown:
        pressedKeys.insert(event.keyCode)
        if !event.isARepeat {
          switch event.keyCode {
          case 49: actions.append(.dash)
          case 36: actions.append(.shriek)
          case 53: actions.append(.pause)
          default: break
          }
        }
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
      actions.removeAll()
    }

    func consumeActions() -> [Action] {
      defer { actions.removeAll(keepingCapacity: true) }
      return actions
    }
  }
#endif
