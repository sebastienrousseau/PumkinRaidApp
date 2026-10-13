import Foundation
import JavaScriptKit

/// Visual effect particle representing juicy pumpkin droplets.
struct JuiceParticle {
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var radius: Double
  var alpha: Double
  var color: String
}

/// Lingering juice splat on the backdrop wall.
struct JuiceSplat {
  var x: Double
  var y: Double
  var radius: Double
  var alpha: Double
}

/// Sliced half of a pumpkin that rotates and falls with gravity.
struct PumpkinSlice {
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var angle: Double
  var vAngle: Double
  var size: Double
  var alpha: Double
  var pieceIndex: Int
}

/// Floating arcade combo callout.
struct VisualCallout {
  var text: String
  var x: Double
  var y: Double
  var vy: Double
  var alpha: Double
  var scale: Double
  var color: String
}

/// Blade trail point along swipe or dash path.
struct BladePoint {
  var x: Double
  var y: Double
  var age: Double
}

/// Authoritative manager of visual effects for the WebAssembly canvas.
final class VisualEffectsManager {
  private(set) var slices: [PumpkinSlice] = []
  private(set) var particles: [JuiceParticle] = []
  private(set) var splats: [JuiceSplat] = []
  private(set) var callouts: [VisualCallout] = []
  private(set) var bladePoints: [BladePoint] = []
  var shake: Double = 0

  func addBladePoint(x: Double, y: Double) {
    bladePoints.append(BladePoint(x: x, y: y, age: 0))
    if bladePoints.count > 24 { bladePoints.removeFirst() }
  }

  func addBladeSegment(fromX: Double, fromY: Double, toX: Double, toY: Double) {
    for step in 0...4 {
      let fraction = Double(step) / 4.0
      bladePoints.append(
        BladePoint(
          x: fromX + (toX - fromX) * fraction,
          y: fromY + (toY - fromY) * fraction,
          age: 0
        ))
    }
  }

  func spawnSlice(atX x: Double, y: Double, size: Double, identity: Int) {
    let baseSpeed = 160.0
    for piece in 1...2 {
      let direction = piece == 1 ? -1.0 : 1.0
      slices.append(
        PumpkinSlice(
          x: x,
          y: y,
          vx: direction * (baseSpeed + Double(identity % 40)),
          vy: -80.0 - Double((identity * 13) % 50),
          angle: 0,
          vAngle: direction * (4.0 + Double(identity % 5)),
          size: size,
          alpha: 1.0,
          pieceIndex: piece
        )
      )
    }

    // Spawn 16 juice droplets
    let colors = ["#ff7a00", "#ffa726", "#ff5722", "#ffd54f"]
    for i in 0..<16 {
      let angle = Double(i) * (.pi * 2.0 / 16.0) + Double(identity % 20) * 0.05
      let speed = 90.0 + Double((identity * 17 + i * 23) % 140)
      particles.append(
        JuiceParticle(
          x: x,
          y: y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 40.0,
          radius: 2.5 + Double(i % 4),
          alpha: 1.0,
          color: colors[i % colors.count]
        )
      )
    }

    // Lingering juice splat on backdrop
    splats.append(
      JuiceSplat(x: x, y: y, radius: 18.0 + Double(identity % 14), alpha: 0.45)
    )
    if splats.count > 18 { splats.removeFirst() }
  }

  func spawnCallout(text: String, atX x: Double, y: Double, color: String = "#ff9a3c") {
    callouts.append(
      VisualCallout(text: text, x: x, y: y, vy: -55.0, alpha: 1.0, scale: 1.25, color: color)
    )
    if callouts.count > 12 { callouts.removeFirst() }
  }

  func triggerShake(intensity: Double = 6.0) {
    shake = max(shake, intensity)
  }

  func update(deltaTime: Double) {
    let dt = min(0.1, deltaTime)

    // Decay camera shake
    shake *= max(0.0, 1.0 - dt * 10.0)

    // Age blade trail points
    bladePoints = bladePoints.compactMap { point in
      var next = point
      next.age += dt
      return next.age < 0.22 ? next : nil
    }

    // Update pumpkin slices with gravity
    let gravity = 420.0
    slices = slices.compactMap { slice in
      var s = slice
      s.vy += gravity * dt
      s.x += s.vx * dt
      s.y += s.vy * dt
      s.angle += s.vAngle * dt
      s.alpha -= 1.4 * dt
      return s.alpha > 0.02 ? s : nil
    }

    // Update juice particles
    particles = particles.compactMap { particle in
      var p = particle
      p.vy += 320.0 * dt
      p.x += p.vx * dt
      p.y += p.vy * dt
      p.alpha -= 1.8 * dt
      return p.alpha > 0.02 ? p : nil
    }

    // Fade juice splats slowly
    splats = splats.compactMap { splat in
      var sp = splat
      sp.alpha -= 0.18 * dt
      return sp.alpha > 0.02 ? sp : nil
    }

    // Update floating callouts
    callouts = callouts.compactMap { callout in
      var c = callout
      c.y += c.vy * dt
      c.scale = max(1.0, c.scale - dt * 0.5)
      c.alpha -= 1.3 * dt
      return c.alpha > 0.02 ? c : nil
    }
  }

  func render(context: JSObject, width: Double, height: Double, document: JSValue) {
    // 1. Render lingering background juice splats
    for splat in splats {
      context.fillStyle = .string("rgba(255, 122, 0, \(splat.alpha))")
      _ = context.beginPath!()
      _ = context.arc!(splat.x, splat.y, splat.radius, 0, Double.pi * 2)
      _ = context.fill!()
    }

    // 2. Render sliced pumpkin halves (tumbling apart)
    for slice in slices {
      let id = "pumpkin-piece-\(slice.pieceIndex)"
      guard let img = document.getElementById(id).object, img.complete.boolean == true else {
        continue
      }
      _ = context.save!()
      _ = context.translate!(slice.x, slice.y)
      _ = context.rotate!(slice.angle)
      context.globalAlpha = .number(slice.alpha)
      let w = slice.size * 0.95
      let h = slice.size * 1.35
      _ = context.drawImage!(img, -w / 2, -h / 2, w, h)
      _ = context.restore!()
    }

    // 3. Render juice particles
    for p in particles {
      context.fillStyle = .string(p.color)
      context.globalAlpha = .number(p.alpha)
      _ = context.beginPath!()
      _ = context.arc!(p.x, p.y, p.radius, 0, Double.pi * 2)
      _ = context.fill!()
    }
    context.globalAlpha = .number(1.0)

    // 4. Render glowing sword blade trail
    if bladePoints.count >= 2 {
      _ = context.save!()
      // Outer glow pass
      context.strokeStyle = .string("rgba(255, 170, 0, 0.75)")
      context.shadowColor = .string("#ffaa00")
      context.shadowBlur = .number(14.0)
      context.lineCap = .string("round")
      context.lineJoin = .string("round")
      context.lineWidth = .number(7.0)
      _ = context.beginPath!()
      _ = context.moveTo!(bladePoints[0].x, bladePoints[0].y)
      for i in 1..<bladePoints.count {
        _ = context.lineTo!(bladePoints[i].x, bladePoints[i].y)
      }
      _ = context.stroke!()

      // Inner white core pass
      context.strokeStyle = .string("rgba(255, 255, 255, 0.95)")
      context.shadowBlur = .number(4.0)
      context.lineWidth = .number(3.0)
      _ = context.beginPath!()
      _ = context.moveTo!(bladePoints[0].x, bladePoints[0].y)
      for i in 1..<bladePoints.count {
        _ = context.lineTo!(bladePoints[i].x, bladePoints[i].y)
      }
      _ = context.stroke!()
      _ = context.restore!()
    }

    // 5. Render floating combo text callouts
    for callout in callouts {
      _ = context.save!()
      let fontSize = max(16.0, min(36.0, width * 0.038)) * callout.scale
      context.font = .string("900 \(fontSize)px ui-rounded, 'Avenir Next', system-ui, sans-serif")
      context.textAlign = .string("center")
      context.textBaseline = .string("middle")
      context.shadowColor = .string("#000000")
      context.shadowBlur = .number(8.0)
      context.fillStyle = .string(callout.color)
      context.globalAlpha = .number(callout.alpha)
      _ = context.fillText!(callout.text, callout.x, callout.y)
      _ = context.restore!()
    }
  }
}
