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
  private var inputRouter = SemanticInputRouter()
  private var pointerIsActive = false
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
      self.setKey(normalized, pressed: true, isRepeat: event.repeat.boolean == true)
      event.preventDefault!()
      return .undefined
    }
    let keyUp = JSClosure { [weak self] arguments in
      guard let key = arguments.first?.object?.key.string else { return .undefined }
      self?.setKey(key.lowercased(), pressed: false, isRepeat: false)
      return .undefined
    }
    let pointerDown = JSClosure { [weak self] arguments in
      guard let self, let event = arguments.first?.object else { return .undefined }
      let point = self.normalizedPointer(event)
      let ghost = self.simulation.state.ghost.position
      let dx = point.x - ghost.x
      let dy = point.y - ghost.y
      self.pointerIsActive = true
      self.inputRouter.beginPointer(
        at: point,
        timestamp: (event.timeStamp.number ?? 0) / 1_000,
        controlsGhost: (dx * dx + dy * dy).squareRoot() <= 0.14
      )
      self.canvas.setPointerCapture?(event.pointerId)
      event.preventDefault!()
      return .undefined
    }
    let pointerMove = JSClosure { [weak self] arguments in
      guard let self, self.pointerIsActive, let event = arguments.first?.object else {
        return .undefined
      }
      self.inputRouter.movePointer(to: self.normalizedPointer(event))
      event.preventDefault!()
      return .undefined
    }
    let pointerUp = JSClosure { [weak self] arguments in
      guard let self, self.pointerIsActive, let event = arguments.first?.object else {
        return .undefined
      }
      let end = self.normalizedPointer(event)
      self.inputRouter.endPointer(at: end, timestamp: (event.timeStamp.number ?? 0) / 1_000)
      self.pointerIsActive = false
      event.preventDefault!()
      return .undefined
    }
    let resizeClosure = JSClosure { [weak self] _ in
      self?.resize()
      return .undefined
    }
    let blur = JSClosure { [weak self] _ in
      self?.inputRouter.cancelAll()
      self?.pointerIsActive = false
      if self?.running == true, self?.simulation.state.isPaused == false {
        self?.inputRouter.enqueue(.pause)
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
    inputRouter.cancelAll()
    pointerIsActive = false
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
      _ = simulation.step(inputRouter.nextFrame())
      accumulator -= fixedDelta
      steps += 1
    }
    render()
    updateHUD()
    if simulation.state.isGameOver {
      running = false
      document.getElementById("menu")?.object?.classList.remove!("hidden")
      document.getElementById("play")?.object?.innerText = "PLAY AGAIN"
    } else {
      scheduleFrame()
    }
  }

  private func setKey(_ key: String, pressed: Bool, isRepeat: Bool) {
    switch key {
    case "arrowleft", "a": inputRouter.set(.left, pressed: pressed)
    case "arrowright", "d": inputRouter.set(.right, pressed: pressed)
    case "arrowup", "w": inputRouter.set(.up, pressed: pressed)
    case "arrowdown", "s": inputRouter.set(.down, pressed: pressed)
    case " " where !isRepeat: inputRouter.set(.dash, pressed: pressed)
    case "enter" where !isRepeat: inputRouter.set(.shriek, pressed: pressed)
    case "escape" where !isRepeat: inputRouter.set(.pause, pressed: pressed)
    default: break
    }
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
      switch pumpkin.kind {
      case .armored: context.fillStyle = "#788596"
      case .cursed: context.fillStyle = "#9228b5"
      case .target:
        switch pumpkin.archetype {
        case .standard: context.fillStyle = "#ff7a00"
        case .swift: context.fillStyle = "#ffb000"
        case .drifting: context.fillStyle = "#ef4b22"
        case .heavy: context.fillStyle = "#9f3d12"
        }
      }
      context.beginPath!()
      context.ellipse!(x, y, radius, radius * 0.82, 0, 0, Double.pi * 2)
      context.fill!()
    }

    if let pickup = simulation.state.pickup {
      context.fillStyle = ["#ffe16a", "#64e8ff", "#ff72c6"][pickup.kind]
      context.beginPath!()
      context.arc!(
        pickup.position.x * width,
        pickup.position.y * height,
        min(width, height) * 0.027,
        0,
        Double.pi * 2
      )
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
