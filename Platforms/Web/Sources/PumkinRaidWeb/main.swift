import Foundation
import GameEngineLib
import JavaScriptEventLoop
import JavaScriptKit

private func markStartup(_ phase: String) {
  JSObject.global.document.documentElement.object?.dataset.object?.swiftPhase = .string(phase)
}

markStartup("executor")
JavaScriptEventLoop.installGlobalExecutor()
markStartup("game-construction")

private final class BrowserGame {
  private let window = JSObject.global
  private let document = JSObject.global.document
  private let canvas: JSObject
  private let context: JSObject
  private var simulation: GameSimulation
  private var currentMode = GameMode.classicRaid
  private var inputRouter = SemanticInputRouter()
  private var pointerIsActive = false
  private var lastTimestamp = 0.0
  private var accumulator = 0.0
  private var running = false
  private var frameClosure: JSClosure?
  private var eventClosures: [JSClosure] = []

  init?() {
    markStartup("simulation")
    let initialSimulation = GameSimulation(seed: 0)
    markStartup("dom")
    guard
      let canvas = document.getElementById("game").object,
      let context = canvas.getContext!("2d").object
    else { return nil }
    self.canvas = canvas
    self.context = context
    self.simulation = initialSimulation
    markStartup("input")
    installInput()
    markStartup("mode-buttons")
    installModeButtons()
    markStartup("resize")
    resize()
    markStartup("render")
    render()
    markStartup("ready")
  }

  private func installModeButtons() {
    let buttons: [(String, GameMode)] = [
      ("play", .classicRaid),
      ("moon", .moonRush),
      ("zen", .spiritZen),
      ("daily", .dailyHaunt),
      ("boss", .bossRaid),
    ]
    for (identifier, mode) in buttons {
      guard let button = document.getElementById(identifier).object else { continue }
      let closure = JSClosure { [weak self] _ in
        self?.start(mode: mode)
        return .undefined
      }
      button.onclick = JSValue.object(closure)
      eventClosures.append(closure)
    }
    updateBestScore()
  }

  private func installInput() {
    let keyDown = JSClosure { [weak self] arguments in
      guard let self, let event = arguments.first?.object, let key = event.key.string else {
        return .undefined
      }
      let normalized = key.lowercased()
      self.setKey(normalized, pressed: true, isRepeat: event.repeat.boolean == true)
      _ = event.preventDefault!()
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
      self.pointerIsActive = true
      self.inputRouter.beginPointer(
        at: point,
        timestamp: (event.timeStamp.number ?? 0) / 1_000,
        controlsGhost: true
      )
      _ = self.canvas.setPointerCapture?(event.pointerId)
      _ = event.preventDefault!()
      return .undefined
    }
    let pointerMove = JSClosure { [weak self] arguments in
      guard let self, self.pointerIsActive, let event = arguments.first?.object else {
        return .undefined
      }
      self.inputRouter.movePointer(to: self.normalizedPointer(event))
      _ = event.preventDefault!()
      return .undefined
    }
    let pointerUp = JSClosure { [weak self] arguments in
      guard let self, self.pointerIsActive, let event = arguments.first?.object else {
        return .undefined
      }
      let end = self.normalizedPointer(event)
      self.inputRouter.endPointer(at: end, timestamp: (event.timeStamp.number ?? 0) / 1_000)
      self.pointerIsActive = false
      _ = event.preventDefault!()
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
    _ = window.addEventListener!("keydown", keyDown)
    _ = window.addEventListener!("keyup", keyUp)
    _ = canvas.addEventListener!("pointerdown", pointerDown)
    _ = canvas.addEventListener!("pointermove", pointerMove)
    _ = window.addEventListener!("pointerup", pointerUp)
    _ = window.addEventListener!("pointercancel", pointerUp)
    _ = window.addEventListener!("resize", resizeClosure)
    _ = window.addEventListener!("blur", blur)
    eventClosures += [keyDown, keyUp, pointerDown, pointerMove, pointerUp, resizeClosure, blur]
  }

  private func start(mode: GameMode) {
    currentMode = mode
    let seed =
      mode == .dailyHaunt
      ? dailySeed()
      : UInt64(Date.now.timeIntervalSince1970 * 1_000_000)
    simulation = GameSimulation(seed: seed, mode: mode)
    inputRouter.cancelAll()
    pointerIsActive = false
    lastTimestamp = 0
    accumulator = 0
    running = true
    _ = document.getElementById("menu").object?.classList.add("hidden")
    _ = document.getElementById("music").object?.play?()
    scheduleFrame()
  }

  private func scheduleFrame() {
    frameClosure = JSClosure { [weak self] arguments in
      self?.tick(timestamp: arguments.first?.number ?? 0)
      return .undefined
    }
    _ = window.requestAnimationFrame!(frameClosure!)
  }

  private func tick(timestamp: Double) {
    guard running else { return }
    let frameDelta = lastTimestamp == 0 ? 0 : min(0.1, (timestamp - lastTimestamp) / 1_000)
    lastTimestamp = timestamp
    accumulator += frameDelta
    let fixedDelta = 1 / Double(simulation.configuration.ticksPerSecond)
    var steps = 0
    while accumulator >= fixedDelta, steps < 6 {
      let events = simulation.step(inputRouter.nextFrame())
      if events.contains(where: {
        if case .destroyed = $0 { return true }
        return false
      }) {
        let sound = document.getElementById("slice-sound").object
        sound?.currentTime = 0
        _ = sound?.play?()
      }
      accumulator -= fixedDelta
      steps += 1
    }
    render()
    updateHUD()
    if simulation.state.isGameOver {
      running = false
      saveBestScore(simulation.state.session.score)
      _ = document.getElementById("music").object?.pause?()
      _ = document.getElementById("menu").object?.classList.remove("hidden")
      document.getElementById("play").object?.innerText = .string("PLAY CLASSIC AGAIN")
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
    _ = context.clearRect!(0, 0, width, height)
    let gradient = context.createLinearGradient!(0, 0, 0, height).object!
    _ = gradient.addColorStop!(0, "rgba(7,16,33,.35)")
    _ = gradient.addColorStop!(1, "rgba(39,7,10,.72)")
    context.fillStyle = .object(gradient)
    _ = context.fillRect!(0, 0, width, height)
    context.fillStyle = .string(modeTint(currentMode))
    _ = context.fillRect!(0, 0, width, height)

    for pumpkin in simulation.state.pumpkins {
      let x = pumpkin.position.x * width
      let y = pumpkin.position.y * height
      let radius = pumpkin.radius * min(width, height)
      let frame = (Int(simulation.state.tick / 10 % 3) + pumpkin.id) % 3 + 1
      if let image = document.getElementById("pumpkin-sprite-\(frame)").object,
        image.complete.boolean == true
      {
        context.globalAlpha = pumpkin.kind == .target ? 1 : 0.72
        _ = context.drawImage!(image, x - radius, y - radius, radius * 2, radius * 2)
        context.globalAlpha = 1
      }
    }

    if let pickup = simulation.state.pickup {
      context.fillStyle = ["#ffe16a", "#64e8ff", "#ff72c6"][pickup.kind]
      _ = context.beginPath!()
      _ = context.arc!(
        pickup.position.x * width,
        pickup.position.y * height,
        min(width, height) * 0.027,
        0,
        Double.pi * 2
      )
      _ = context.fill!()
    }

    let ghost = simulation.state.ghost.position
    document.documentElement.object?.dataset.object?.ghostX = .string(String(ghost.x))
    document.documentElement.object?.dataset.object?.ghostY = .string(String(ghost.y))
    let x = ghost.x * width
    let y = ghost.y * height
    let radius = min(width, height) * 0.045
    if let image = document.getElementById("ghost-sprite").object,
      image.complete.boolean == true
    {
      _ = context.drawImage!(image, x - radius, y - radius, radius * 2, radius * 2)
    }
  }

  private func updateHUD() {
    let session = simulation.state.session
    document.getElementById("score").object?.innerText = .string("SCORE  \(session.score)")
    document.getElementById("lives").object?.innerText = .string("LIVES  \(session.lives)")
    document.getElementById("charges").object?.innerText = .string(
      "DASH  \(session.slices)  ·  SHRIEK  \(session.booms)"
    )
    document.getElementById("mode").object?.innerText = .string(modeTitle(currentMode))
  }

  private func modeTitle(_ mode: GameMode) -> String {
    switch mode {
    case .classicRaid: "CLASSIC RAID"
    case .moonRush: "MOON RUSH"
    case .spiritZen: "SPIRIT ZEN"
    case .dailyHaunt: "DAILY HAUNT"
    case .bossRaid: "BOSS RAID"
    }
  }

  private func modeTint(_ mode: GameMode) -> String {
    switch mode {
    case .classicRaid: "rgba(0,0,0,0)"
    case .moonRush: "rgba(255,86,10,.07)"
    case .spiritZen: "rgba(40,190,240,.07)"
    case .dailyHaunt: "rgba(130,40,220,.09)"
    case .bossRaid: "rgba(190,0,0,.12)"
    }
  }

  private func dailySeed() -> UInt64 {
    let days = Int(Date.now.timeIntervalSince1970 / 86_400)
    return UInt64(max(0, days)) ^ 0x4441_494C_595F_5241
  }

  private func saveBestScore(_ score: Int) {
    guard let storage = window.localStorage.object else { return }
    let key = "pumkinRaid.best.\(currentMode.rawValue)"
    let previous = Int(storage.getItem!(key).string ?? "0") ?? 0
    _ = storage.setItem!(key, String(max(score, previous)))
    updateBestScore()
  }

  private func updateBestScore() {
    guard let storage = window.localStorage.object else { return }
    let best =
      GameMode.allCases.map {
        Int(storage.getItem!("pumkinRaid.best.\($0.rawValue)").string ?? "0") ?? 0
      }.max() ?? 0
    document.getElementById("best").object?.innerText = .string(String(best))
  }
}

private let game = BrowserGame()
