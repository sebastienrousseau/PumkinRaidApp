import Foundation
import GameEngineLib
import SpriteKit

#if os(iOS)
  import CoreMotion
  import UIKit
#elseif os(macOS)
  import AppKit
#elseif os(tvOS)
  import GameController
  import UIKit
#endif

extension GameScene {
  func continuousInputFrame() -> InputFrame {
    #if os(macOS)
      let keyboard = KeyboardState.shared
      inputRouter.set(.left, pressed: keyboard.isPressed(123) || keyboard.isPressed(0))
      inputRouter.set(.right, pressed: keyboard.isPressed(124) || keyboard.isPressed(2))
      inputRouter.set(.down, pressed: keyboard.isPressed(125) || keyboard.isPressed(1))
      inputRouter.set(.up, pressed: keyboard.isPressed(126) || keyboard.isPressed(13))
      for action in keyboard.consumeActions() {
        switch action {
        case .dash:
          inputRouter.set(.dash, pressed: false)
          inputRouter.set(.dash, pressed: true)
        case .shriek:
          inputRouter.set(.shriek, pressed: false)
          inputRouter.set(.shriek, pressed: true)
        case .pause:
          inputRouter.set(.pause, pressed: false)
          inputRouter.set(.pause, pressed: true)
        }
      }
    #elseif os(iOS)
      if abs(motionIntent.x) > 0.01 || abs(motionIntent.y) > 0.01 {
        inputRouter.enqueue(.move(x: motionIntent.x, y: motionIntent.y))
      }
    #elseif os(tvOS)
      var x = 0.0
      var y = 0.0
      if let gamepad = GCController.current?.extendedGamepad {
        x += Double(gamepad.leftThumbstick.xAxis.value + gamepad.dpad.xAxis.value)
        y -= Double(gamepad.leftThumbstick.yAxis.value + gamepad.dpad.yAxis.value)
        inputRouter.set(.dash, pressed: gamepad.buttonA.isPressed)
        inputRouter.set(.shriek, pressed: gamepad.buttonB.isPressed)
      } else if let gamepad = GCController.current?.microGamepad {
        x += Double(gamepad.dpad.xAxis.value)
        y -= Double(gamepad.dpad.yAxis.value)
      }
      inputRouter.set(.left, pressed: x < -0.08)
      inputRouter.set(.right, pressed: x > 0.08)
      inputRouter.set(.up, pressed: y < -0.08)
      inputRouter.set(.down, pressed: y > 0.08)
    #endif
    return inputRouter.nextFrame()
  }

  func beginGesture(at point: CGPoint, timestamp: TimeInterval) {
    gestureLastPoint = point
    draggingPhantom = true
    inputRouter.beginPointer(
      at: normalizedPoint(point),
      timestamp: timestamp,
      controlsGhost: true
    )
  }

  /// Semantic pointer entry point shared by the macOS event bridge and tests.
  func pointerDown(at scenePoint: CGPoint, timestamp: TimeInterval) {
    beginGesture(at: scenePoint, timestamp: timestamp)
  }

  func pointerDragged(to scenePoint: CGPoint) {
    moveGesture(to: scenePoint)
  }

  func pointerUp(at scenePoint: CGPoint, timestamp: TimeInterval) {
    endGesture(at: scenePoint, timestamp: timestamp)
  }

  func moveGesture(to point: CGPoint) {
    if draggingPhantom {
      inputRouter.movePointer(to: normalizedPoint(point))
      if let previous = gestureLastPoint {
        drawBladeTrail(from: previous, to: point)
        inputRouter.slice(from: normalizedPoint(previous), to: normalizedPoint(point))
      }
    }
    gestureLastPoint = point
  }

  func endGesture(at point: CGPoint, timestamp: TimeInterval) {
    defer {
      gestureLastPoint = nil
      draggingPhantom = false
    }
    inputRouter.endPointer(at: normalizedPoint(point), timestamp: timestamp)
  }

  func normalizedPoint(_ point: CGPoint) -> Vector2 {
    Vector2(
      x: Double(min(1, max(0, point.x / max(1, size.width)))),
      y: Double(min(1, max(0, 1 - point.y / max(1, size.height))))
    )
  }

  func scenePoint(_ point: Vector2) -> CGPoint {
    CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(1 - point.y) * size.height)
  }

  func movePhantom(horizontal: CGFloat, vertical: CGFloat) {
    let current = simulation.state.ghost.position
    inputRouter.enqueue(
      .moveTo(
        x: current.x + Double(horizontal / max(1, size.width)),
        y: current.y - Double(vertical / max(1, size.height))
      ))
  }

  func startMotionUpdates() {
    #if os(iOS)
      guard settings.tiltControlsEnabled, motionManager.isAccelerometerAvailable else { return }
      motionManager.accelerometerUpdateInterval = 1 / 60
      motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let self, let acceleration = data?.acceleration, !self.draggingPhantom else { return }
        self.motionIntent = Vector2(x: acceleration.x * 0.7, y: acceleration.y * 0.5)
      }
    #endif
  }

  func stopMotionUpdates() {
    #if os(iOS)
      motionManager.stopAccelerometerUpdates()
      motionIntent = .zero
    #endif
  }

  #if os(iOS) || os(tvOS)
    func updateDigitalKey(_ keyCode: UIKeyboardHIDUsage, isPressed: Bool) {
      switch keyCode {
      case .keyboardLeftArrow, .keyboardA: inputRouter.set(.left, pressed: isPressed)
      case .keyboardRightArrow, .keyboardD: inputRouter.set(.right, pressed: isPressed)
      case .keyboardUpArrow, .keyboardW: inputRouter.set(.up, pressed: isPressed)
      case .keyboardDownArrow, .keyboardS: inputRouter.set(.down, pressed: isPressed)
      case .keyboardSpacebar where isPressed:
        inputRouter.set(.dash, pressed: false)
        inputRouter.set(.dash, pressed: true)
      case .keyboardReturnOrEnter where isPressed:
        inputRouter.set(.shriek, pressed: false)
        inputRouter.set(.shriek, pressed: true)
      case .keyboardEscape where isPressed:
        inputRouter.set(.pause, pressed: false)
        inputRouter.set(.pause, pressed: true)
      default: break
      }
    }
  #endif

  #if os(macOS)
    func handleApplicationPointerEvent(_ event: NSEvent) -> Bool {
      guard let view, event.window === view.window else { return false }
      let point = convertPoint(fromView: view.convert(event.locationInWindow, from: nil))
      switch event.type {
      case .leftMouseDown: pointerDown(at: point, timestamp: event.timestamp)
      case .leftMouseDragged: pointerDragged(to: point)
      case .leftMouseUp: pointerUp(at: point, timestamp: event.timestamp)
      default: return false
      }
      return true
    }

    func handlePointerDown(at viewPoint: CGPoint) {
      pointerDown(
        at: convertPoint(fromView: viewPoint), timestamp: ProcessInfo.processInfo.systemUptime)
    }

    func handlePointerDragged(to viewPoint: CGPoint) {
      pointerDragged(to: convertPoint(fromView: viewPoint))
    }

    func handlePointerUp(at viewPoint: CGPoint) {
      pointerUp(
        at: convertPoint(fromView: viewPoint), timestamp: ProcessInfo.processInfo.systemUptime)
    }
  #endif
}
