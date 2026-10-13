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
  private var lastPointerPosition: Vector2?
  private var lastTimestamp = 0.0
  private var accumulator = 0.0
  private var running = false
  private let effects = VisualEffectsManager()
  private let leaderboard = WebLeaderboard()
  private var lastPumpkinPositions: [Int: (x: Double, y: Double, radius: Double)] = [:]
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
    eventClosures += leaderboard.installButtons(
      document: document,
      onShowScores: { [weak self] in
        guard let self else { return }
        self.leaderboard.showLeaderboard(
          document: self.document,
          mode: self.currentMode,
          bestScore: self.currentGlobalBest()
        )
      },
      onReplay: { [weak self] in
        guard let self else { return }
        self.start(mode: self.currentMode)
      }
    )
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
      self.lastPointerPosition = point
      self.inputRouter.beginPointer(
        at: point,
        timestamp: (event.timeStamp.number ?? 0) / 1_000,
        controlsGhost: true
      )
      let w = self.canvas.width.number ?? 1
      let h = self.canvas.height.number ?? 1
      self.effects.addBladePoint(x: point.x * w, y: point.y * h)
      _ = event.preventDefault!()
      return .undefined
    }
    let pointerMove = JSClosure { [weak self] arguments in
      guard let self, self.pointerIsActive, let event = arguments.first?.object else {
        return .undefined
      }
      let point = self.normalizedPointer(event)
      self.inputRouter.movePointer(to: point)
      if let last = self.lastPointerPosition {
        self.inputRouter.slice(from: last, to: point)
      }
      self.lastPointerPosition = point
      let w = self.canvas.width.number ?? 1
      let h = self.canvas.height.number ?? 1
      self.effects.addBladePoint(x: point.x * w, y: point.y * h)
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
      self.lastPointerPosition = nil
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
      self?.lastPointerPosition = nil
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
    // Safari/WebKit mouse automation and older desktop engines may not route
    // synthesized movement through Pointer Events. Duplicate delivery is safe:
    // down resets the same start point and up is guarded by pointerIsActive.
    _ = canvas.addEventListener!("mousedown", pointerDown)
    _ = window.addEventListener!("mousemove", pointerMove)
    _ = window.addEventListener!("mouseup", pointerUp)
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
    lastPointerPosition = nil
    lastTimestamp = 0
    accumulator = 0
    running = true
    _ = document.getElementById("gameover").object?.classList.add("hidden")
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
    let width = canvas.width.number ?? 1
    let height = canvas.height.number ?? 1
    effects.update(deltaTime: frameDelta)
    var steps = 0
    while accumulator >= fixedDelta, steps < 6 {
      let events = simulation.step(inputRouter.nextFrame())
      for event in events {
        handleEvent(event, width: width, height: height)
      }
      accumulator -= fixedDelta
      steps += 1
    }
    render()
    updateHUD()
    if simulation.state.isGameOver {
      running = false
      let score = simulation.state.session.score
      saveBestScore(score)
      _ = document.getElementById("music").object?.pause?()
      leaderboard.showGameOver(
        document: document,
        score: score,
        smashed: simulation.state.statistics.destroyed,
        combo: simulation.state.statistics.bestCombo,
        mode: currentMode,
        bestScore: currentGlobalBest()
      )
    } else {
      scheduleFrame()
    }
  }

  private func handleEvent(_ event: GameEvent, width: Double, height: Double) {
    let ghost = simulation.state.ghost.position
    let gx = ghost.x * width
    let gy = ghost.y * height
    switch event {
    case .destroyed(let id, let combo, let points):
      let pos = lastPumpkinPositions[id] ?? (x: gx, y: gy, radius: min(width, height) * 0.09)
      effects.spawnSlice(atX: pos.x, y: pos.y, size: pos.radius * 2, identity: id)
      let label =
        combo >= 3
        ? "\(combo)x COMBO! +\(points)" : (combo == 2 ? "2x COMBO! +\(points)" : "+\(points)")
      effects.spawnCallout(
        text: label, atX: pos.x, y: pos.y - 25, color: combo >= 3 ? "#ffd54f" : "#ff9a3c")
      playAudio("slice-sound")
    case .damaged:
      effects.triggerShake(intensity: 10)
      effects.spawnCallout(text: "OUCH!", atX: gx, y: gy - 20, color: "#ff4444")
      playAudio("hit-sound")
    case .armoredHit(let id, let remaining):
      let pos = lastPumpkinPositions[id] ?? (x: gx, y: gy, radius: min(width, height) * 0.04)
      effects.spawnCallout(text: "CRACK! \(remaining)", atX: pos.x, y: pos.y - 20, color: "#00e5ff")
      playAudio("hit-sound")
    case .cursedTriggered:
      effects.triggerShake(intensity: 12)
      effects.spawnCallout(text: "CURSED!", atX: gx, y: gy - 20, color: "#d05ce3")
      playAudio("explode-sound")
    case .nearMiss(_, let points):
      effects.spawnCallout(text: "NEAR MISS +\(points)", atX: gx, y: gy - 20, color: "#00e5ff")
    case .pickupCollected(_, _, let points):
      effects.spawnCallout(text: "SWEET +\(points)", atX: gx, y: gy - 20, color: "#ffd54f")
      playAudio("ding-sound")
    case .waveStarted(let index, let pattern):
      let title = pattern == .breathingSpace ? "BREATHE" : "WAVE \(index)"
      effects.spawnCallout(text: title, atX: width / 2, y: height * 0.4, color: "#ffffff")
    case .frenzyStarted:
      effects.triggerShake(intensity: 6)
      effects.spawnCallout(text: "FRENZY x2!", atX: width / 2, y: height * 0.35, color: "#ffd54f")
      playAudio("ding-sound")
    case .dashed(let from, let to):
      effects.addBladeSegment(
        fromX: from.x * width, fromY: from.y * height, toX: to.x * width, toY: to.y * height)
    case .shrieked(let origin, let count):
      guard count > 0 else { return }
      effects.triggerShake(intensity: 14)
      effects.spawnCallout(
        text: "SHRIEK x\(count)!", atX: origin.x * width, y: origin.y * height, color: "#ffd54f")
      playAudio("explode-sound")
    default: break
    }
  }

  private func playAudio(_ id: String) {
    guard let sound = document.getElementById(id).object else { return }
    sound.currentTime = 0
    _ = sound.play?()
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

    let hasShake = effects.shake > 0.1
    if hasShake {
      let shakeX = Double.random(in: -1...1) * effects.shake
      let shakeY = Double.random(in: -1...1) * effects.shake
      _ = context.save!()
      _ = context.translate!(shakeX, shakeY)
    }

    renderAtmosphere(width: width, height: height)
    effects.render(context: context, width: width, height: height, document: document)
    renderPumpkins(width: width, height: height)
    renderSweet(width: width, height: height)
    renderGhost(width: width, height: height)

    if hasShake {
      _ = context.restore!()
    }
  }

  private func renderAtmosphere(width: Double, height: Double) {
    let gradient = context.createLinearGradient!(0, 0, 0, height).object!
    _ = gradient.addColorStop!(0, "rgba(7,16,33,.35)")
    _ = gradient.addColorStop!(1, "rgba(39,7,10,.72)")
    context.fillStyle = .object(gradient)
    _ = context.fillRect!(0, 0, width, height)
    context.fillStyle = .string(modeTint(currentMode))
    _ = context.fillRect!(0, 0, width, height)
  }

  private func renderPumpkins(width: Double, height: Double) {
    lastPumpkinPositions.removeAll(keepingCapacity: true)
    for pumpkin in simulation.state.pumpkins {
      let x = pumpkin.position.x * width
      let y = pumpkin.position.y * height
      let radius = pumpkin.radius * min(width, height)
      let drawRadius = radius * 2.3
      lastPumpkinPositions[pumpkin.id] = (x: x, y: y, radius: drawRadius)
      let frame = (Int(simulation.state.tick / 10 % 3) + pumpkin.id) % 3 + 1
      guard let img = document.getElementById("pumpkin-sprite-\(frame)").object,
        img.complete.boolean == true
      else { continue }
      context.globalAlpha = pumpkin.kind == .target ? 1 : 0.72
      _ = context.drawImage!(
        img, x - drawRadius, y - drawRadius, drawRadius * 2, drawRadius * 2)
      context.globalAlpha = 1
    }
  }

  private func renderSweet(width: Double, height: Double) {
    guard let pickup = simulation.state.pickup else { return }
    let px = pickup.position.x * width
    let py = pickup.position.y * height
    let pRadius = min(width, height) * 0.072
    let frame = pickup.kind + 1
    _ = context.save!()
    context.fillStyle = .string("rgba(255, 215, 0, 0.22)")
    _ = context.beginPath!()
    _ = context.arc!(px, py, pRadius * 1.3, 0, Double.pi * 2)
    _ = context.fill!()
    if let image = document.getElementById("sweet-sprite-\(frame)").object,
      image.complete.boolean == true
    {
      _ = context.drawImage!(image, px - pRadius, py - pRadius, pRadius * 2, pRadius * 2)
    } else {
      context.fillStyle = ["#ffe16a", "#64e8ff", "#ff72c6"][pickup.kind]
      _ = context.beginPath!()
      _ = context.arc!(px, py, pRadius * 0.8, 0, Double.pi * 2)
      _ = context.fill!()
    }
    _ = context.restore!()
  }

  private func renderGhost(width: Double, height: Double) {
    let ghost = simulation.state.ghost.position
    document.documentElement.object?.dataset.object?.ghostX = .string(String(ghost.x))
    document.documentElement.object?.dataset.object?.ghostY = .string(String(ghost.y))
    let gx = ghost.x * width
    let gy = ghost.y * height
    let gRadius = min(width, height) * 0.08
    _ = context.save!()
    context.fillStyle = .string("rgba(135, 230, 255, 0.20)")
    _ = context.beginPath!()
    _ = context.arc!(gx, gy, gRadius * 1.25, 0, Double.pi * 2)
    _ = context.fill!()
    if let image = document.getElementById("ghost-sprite").object,
      image.complete.boolean == true
    {
      _ = context.drawImage!(image, gx - gRadius, gy - gRadius, gRadius * 2, gRadius * 2)
    }
    _ = context.restore!()
  }

  private func updateHUD() {
    let session = simulation.state.session
    document.getElementById("score").object?.innerText = .string("SCORE  \(session.score)")
    let strikes =
      session.lives >= 3
      ? "✕ ✕ ✕" : (session.lives == 2 ? "✕ ✕" : (session.lives == 1 ? "✕" : "0"))
    document.getElementById("lives").object?.innerText = .string(
      "LIVES  \(session.lives) [\(strikes)]")
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

  private func currentGlobalBest() -> Int {
    guard let storage = window.localStorage.object else { return 0 }
    return GameMode.allCases.compactMap {
      Int(storage.getItem!("pumkinRaid.best.\($0.rawValue)").string ?? "0")
    }.max() ?? 0
  }

  private func updateBestScore() {
    document.getElementById("best").object?.innerText = .string(String(currentGlobalBest()))
  }
}

private let game = BrowserGame()
