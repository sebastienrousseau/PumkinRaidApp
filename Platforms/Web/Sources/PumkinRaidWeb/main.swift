import Foundation
import GameEngineLib
import JavaScriptEventLoop
import JavaScriptKit

JavaScriptEventLoop.installGlobalExecutor()

private final class BrowserGame {
  private let window = JSObject.global
  private let document = JSObject.global.document
  private let canvas: JSObject
  private let context: JSObject
  private var simulation = GameSimulation(seed: 0)
  private var pressedKeys: Set<String> = []
  private var pendingActions: [InputAction] = []
  private var pointerTarget: Vector2?
  private var pointerStart: Vector2?
  private var pointerStartTime = 0.0
  private var lastTimestamp = 0.0
  private var accumulator = 0.0
  private var running = false
  private var frameClosure: JSClosure?
  private var eventClosures: [JSClosure] = []

  init?() {
    guard
      let canvas = document.getElementById("game")?.object,
      let context = canvas.getContext!("2d").object
    else { return nil }
    self.canvas = canvas
    self.context = context
    installInput()
    installStartButton()
    resize()
    render()
  }

  private func installStartButton() {
    guard let button = document.getElementById("play")?.object else { return }
    let closure = JSClosure { [weak self] _ in
      self?.start()
      return .undefined
    }
    button.onclick = .object(closure)
    eventClosures.append(closure)
  }

  private func installInput() {
    let keyDown = JSClosure { [weak self] arguments in
      guard let self, let event = arguments.first?.object, let key = event.key.string else {
        return .undefined
      }
      let normalized = key.lowercased()
      self.pressedKeys.insert(normalized)
      if event.repeat.boolean != true {
        switch normalized {
        case " ": self.pendingActions.append(.dash(x: self.keyboardX, y: self.keyboardY))
        case "enter": self.pendingActions.append(.shriek)
        case "escape":
          self.pendingActions.append(self.simulation.state.isPaused ? .resume : .pause)
        default: break
        }
      }
      event.preventDefault!()
      return .undefined
    }
    let keyUp = JSClosure { [weak self] arguments in
      guard let key = arguments.first?.object?.key.string else { return .undefined }
      self?.pressedKeys.remove(key.lowercased())
      return .undefined
    }
    let pointerDown = JSClosure { [weak self] arguments in
      guard let self, let event = arguments.first?.object else { return .undefined }
      let point = self.normalizedPointer(event)
      self.pointerStart = point
      self.pointerTarget = point
      self.pointerStartTime = event.timeStamp.number ?? 0
      self.canvas.setPointerCapture?(event.pointerId)
      event.preventDefault!()
      return .undefined
    }
    let pointerMove = JSClosure { [weak self] arguments in
      guard let self, self.pointerStart != nil, let event = arguments.first?.object else {
        return .undefined
      }
      self.pointerTarget = self.normalizedPointer(event)
      event.preventDefault!()
      return .undefined
    }
    let pointerUp = JSClosure { [weak self] arguments in
      guard let self, let event = arguments.first?.object, let start = self.pointerStart else {
        return .undefined
      }
      let end = self.normalizedPointer(event)
      let dx = end.x - start.x
      let dy = end.y - start.y
      let distance = (dx * dx + dy * dy).squareRoot()
      let duration = (event.timeStamp.number ?? 0) - self.pointerStartTime
      if distance >= 0.08, duration <= 550 {
        self.pendingActions.append(.dash(x: dx, y: dy))
      } else if distance < 0.035 {
        self.pendingActions.append(.shriek)
      }
      self.pointerStart = nil
      self.pointerTarget = nil
      event.preventDefault!()
      return .undefined
    }
    let resizeClosure = JSClosure { [weak self] _ in
      self?.resize()
      return .undefined
    }
    let blur = JSClosure { [weak self] _ in
      self?.pressedKeys.removeAll()
      self?.pointerStart = nil
      self?.pointerTarget = nil
      if self?.running == true, self?.simulation.state.isPaused == false {
        self?.pendingActions.append(.pause)
      }
      return .undefined
    }
    window.addEventListener!("keydown", keyDown)
    window.addEventListener!("keyup", keyUp)
    canvas.addEventListener!("pointerdown", pointerDown)
    canvas.addEventListener!("pointermove", pointerMove)
    window.addEventListener!("pointerup", pointerUp)
    window.addEventListener!("pointercancel", pointerUp)
    window.addEventListener!("resize", resizeClosure)
    window.addEventListener!("blur", blur)
    eventClosures += [keyDown, keyUp, pointerDown, pointerMove, pointerUp, resizeClosure, blur]
  }

  private func start() {
    let seed = UInt64(Date.now.timeIntervalSince1970 * 1_000_000)
    simulation = GameSimulation(seed: seed)
    pendingActions.removeAll(keepingCapacity: true)
    pressedKeys.removeAll()
    pointerTarget = nil
    pointerStart = nil
    lastTimestamp = 0
    accumulator = 0
    running = true
    document.getElementById("menu")?.object?.classList.add!("hidden")
    scheduleFrame()
  }

  private func scheduleFrame() {
    frameClosure = JSClosure { [weak self] arguments in
      self?.tick(timestamp: arguments.first?.number ?? 0)
      return .undefined
    }
    window.requestAnimationFrame!(frameClosure!)
  }

  private func tick(timestamp: Double) {
    guard running else { return }
    let frameDelta = lastTimestamp == 0 ? 0 : min(0.1, (timestamp - lastTimestamp) / 1_000)
    lastTimestamp = timestamp
    accumulator += frameDelta
    let fixedDelta = 1 / Double(simulation.configuration.ticksPerSecond)
    var steps = 0
    while accumulator >= fixedDelta, steps < 6 {
      var actions: [InputAction] = []
      if keyboardX != 0 || keyboardY != 0 { actions.append(.move(x: keyboardX, y: keyboardY)) }
      if let pointerTarget { actions.append(.moveTo(x: pointerTarget.x, y: pointerTarget.y)) }
      actions.append(contentsOf: pendingActions)
      pendingActions.removeAll(keepingCapacity: true)
      _ = simulation.step(InputFrame(actions: actions))
      accumulator -= fixedDelta
      steps += 1
    }
    render()
    updateHUD()
    if simulation.state.session.isGameOver {
      running = false
      document.getElementById("menu")?.object?.classList.remove!("hidden")
      document.getElementById("play")?.object?.innerText = "PLAY AGAIN"
    } else {
      scheduleFrame()
    }
  }

  private var keyboardX: Double {
    Double((pressedKeys.contains("arrowright") || pressedKeys.contains("d") ? 1 : 0)
      - (pressedKeys.contains("arrowleft") || pressedKeys.contains("a") ? 1 : 0))
  }

  private var keyboardY: Double {
    let value = Double((pressedKeys.contains("arrowdown") || pressedKeys.contains("s") ? 1 : 0)
      - (pressedKeys.contains("arrowup") || pressedKeys.contains("w") ? 1 : 0))
    return keyboardX == 0 && value == 0 ? -1 : value
  }

  private func normalizedPointer(_ event: JSObject) -> Vector2 {
    let rect = canvas.getBoundingClientRect!().object!
    let width = max(1, rect.width.number ?? 1)
    let height = max(1, rect.height.number ?? 1)
    return Vector2(
      x: min(1, max(0, ((event.clientX.number ?? 0) - (rect.left.number ?? 0)) / width)),
      y: min(1, max(0, ((event.clientY.number ?? 0) - (rect.top.number ?? 0)) / height))
    )
  }

  private func resize() {
    let ratio = window.devicePixelRatio.number ?? 1
    let rect = canvas.getBoundingClientRect!().object!
    canvas.width = .number((rect.width.number ?? 640) * ratio)
    canvas.height = .number((rect.height.number ?? 960) * ratio)
    render()
  }

  private func render() {
    let width = canvas.width.number ?? 1
    let height = canvas.height.number ?? 1
    let gradient = context.createLinearGradient!(0, 0, 0, height).object!
    gradient.addColorStop!(0, "#071021")
    gradient.addColorStop!(1, "#27070a")
    context.fillStyle = .object(gradient)
    context.fillRect!(0, 0, width, height)

    for pumpkin in simulation.state.pumpkins {
      let x = pumpkin.position.x * width
      let y = pumpkin.position.y * height
      let radius = pumpkin.radius * min(width, height)
      switch pumpkin.archetype {
      case .standard: context.fillStyle = "#ff7a00"
      case .swift: context.fillStyle = "#ffb000"
      case .drifting: context.fillStyle = "#ef4b22"
      case .heavy: context.fillStyle = "#9f3d12"
      }
      context.beginPath!()
      context.ellipse!(x, y, radius, radius * 0.82, 0, 0, Double.pi * 2)
      context.fill!()
    }

    let ghost = simulation.state.ghost.position
    let x = ghost.x * width
    let y = ghost.y * height
    let radius = min(width, height) * 0.045
    context.fillStyle = "rgba(210, 239, 255, .92)"
    context.beginPath!()
    context.arc!(x, y, radius, 0, Double.pi * 2)
    context.fill!()
    context.fillStyle = "#071021"
    context.beginPath!()
    context.arc!(x - radius * 0.34, y - radius * 0.12, radius * 0.1, 0, Double.pi * 2)
    context.arc!(x + radius * 0.34, y - radius * 0.12, radius * 0.1, 0, Double.pi * 2)
    context.fill!()
  }

  private func updateHUD() {
    let session = simulation.state.session
    document.getElementById("score")?.object?.innerText = "SCORE  \(session.score)"
    document.getElementById("lives")?.object?.innerText = "LIVES  \(session.lives)"
  }
}

private let game = BrowserGame()
