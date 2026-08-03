import GameEngineLib
import Foundation
import JavaScriptEventLoop
import JavaScriptKit

JavaScriptEventLoop.installGlobalExecutor()

private struct FallingPumpkin {
  var x: Double
  var y: Double
  var speed: Double
  var drift: Double
  var radius: Double
}

private final class BrowserGame {
  private let window = JSObject.global
  private let document = JSObject.global.document
  private let canvas: JSObject
  private let context: JSObject
  private var session = GameSession()
  private var director = SpawnDirector(seed: UInt64(Date.now.timeIntervalSince1970 * 1_000))
  private var pumpkins: [FallingPumpkin] = []
  private var ghostX = 0.5
  private var ghostY = 0.84
  private var pressedKeys: Set<String> = []
  private var lastTimestamp = 0.0
  private var elapsed = 0.0
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
      guard let key = arguments.first?.object?.key.string else { return .undefined }
      self?.pressedKeys.insert(key.lowercased())
      arguments.first?.object?.preventDefault!()
      return .undefined
    }
    let keyUp = JSClosure { [weak self] arguments in
      guard let key = arguments.first?.object?.key.string else { return .undefined }
      self?.pressedKeys.remove(key.lowercased())
      return .undefined
    }
    let pointer = JSClosure { [weak self] arguments in
      guard let self, let event = arguments.first?.object else { return .undefined }
      let rect = self.canvas.getBoundingClientRect!().object!
      let width = max(1, rect.width.number ?? 1)
      let height = max(1, rect.height.number ?? 1)
      self.ghostX = min(0.96, max(0.04, ((event.clientX.number ?? 0) - (rect.left.number ?? 0)) / width))
      self.ghostY = min(0.96, max(0.08, ((event.clientY.number ?? 0) - (rect.top.number ?? 0)) / height))
      return .undefined
    }
    let resizeClosure = JSClosure { [weak self] _ in
      self?.resize()
      return .undefined
    }
    window.addEventListener!("keydown", keyDown)
    window.addEventListener!("keyup", keyUp)
    canvas.addEventListener!("pointerdown", pointer)
    canvas.addEventListener!("pointermove", pointer)
    window.addEventListener!("resize", resizeClosure)
    eventClosures = [keyDown, keyUp, pointer, resizeClosure]
  }

  private func start() {
    session = GameSession()
    pumpkins.removeAll(keepingCapacity: true)
    elapsed = 0
    lastTimestamp = 0
    running = true
    for _ in 0..<GameRules.enemyCount { spawn() }
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
    let delta = lastTimestamp == 0 ? 0 : min(0.1, (timestamp - lastTimestamp) / 1_000)
    lastTimestamp = timestamp
    elapsed += delta
    moveGhost(delta: delta)

    let width = canvas.width.number ?? 1
    let height = canvas.height.number ?? 1
    for index in pumpkins.indices.reversed() {
      pumpkins[index].y += pumpkins[index].speed * delta
      pumpkins[index].x += pumpkins[index].drift * delta
      let dx = pumpkins[index].x - ghostX * width
      let dy = pumpkins[index].y - ghostY * height
      if hypot(dx, dy) < pumpkins[index].radius + min(width, height) * 0.045 {
        _ = session.collideWithPumpkin()
        pumpkins.remove(at: index)
        spawn()
      } else if pumpkins[index].y > height + pumpkins[index].radius {
        _ = session.avoidPumpkin()
        pumpkins.remove(at: index)
        spawn()
      }
    }
    render()
    updateHUD()
    if session.isGameOver {
      running = false
      document.getElementById("menu")?.object?.classList.remove!("hidden")
      document.getElementById("play")?.object?.innerText = "PLAY AGAIN"
    } else {
      scheduleFrame()
    }
  }

  private func moveGhost(delta: Double) {
    let speed = delta * 0.72
    if pressedKeys.contains("arrowleft") || pressedKeys.contains("a") { ghostX -= speed }
    if pressedKeys.contains("arrowright") || pressedKeys.contains("d") { ghostX += speed }
    if pressedKeys.contains("arrowup") || pressedKeys.contains("w") { ghostY -= speed }
    if pressedKeys.contains("arrowdown") || pressedKeys.contains("s") { ghostY += speed }
    ghostX = min(0.96, max(0.04, ghostX))
    ghostY = min(0.96, max(0.08, ghostY))
  }

  private func spawn() {
    let plan = director.nextPlan(elapsedTime: elapsed, score: session.score)
    let width = canvas.width.number ?? 1
    let height = canvas.height.number ?? 1
    pumpkins.append(
      FallingPumpkin(
        x: plan.horizontalPosition * width,
        y: -40 - plan.verticalOffset,
        speed: plan.speed * max(0.8, height / 760),
        drift: plan.horizontalDrift,
        radius: 27 * plan.scale
      )
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

    context.fillStyle = "#ff7a00"
    for pumpkin in pumpkins {
      context.beginPath!()
      context.ellipse!(pumpkin.x, pumpkin.y, pumpkin.radius, pumpkin.radius * 0.82, 0, 0, Double.pi * 2)
      context.fill!()
    }

    let x = ghostX * width
    let y = ghostY * height
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
    document.getElementById("score")?.object?.innerText = "SCORE  \(session.score)"
    document.getElementById("lives")?.object?.innerText = "LIVES  \(session.lives)"
  }
}

private let game = BrowserGame()
