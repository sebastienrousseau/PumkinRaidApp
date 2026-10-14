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

/// Flying pumpkin seed particle scattered upon slicing.
struct PumpkinSeedParticle {
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var angle: Double
  var vAngle: Double
  var size: Double
  var alpha: Double
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

/// Ethereal ghost cloud puff trailing the blade.
struct SpiritCloudParticle {
  var x: Double
  var y: Double
  var vx: Double
  var vy: Double
  var radius: Double
  var growth: Double
  var alpha: Double
  var color: String
}

/// Authoritative manager of visual effects for the WebAssembly canvas.
final class VisualEffectsManager {
  var sliceImages: [JSObject?] = []
  var seedImage: JSObject?
  private(set) var slices: [PumpkinSlice] = []
  private(set) var seeds: [PumpkinSeedParticle] = []
  private(set) var particles: [JuiceParticle] = []
  private(set) var splats: [JuiceSplat] = []
  private(set) var callouts: [VisualCallout] = []
  private(set) var bladePoints: [BladePoint] = []
  private(set) var spiritClouds: [SpiritCloudParticle] = []
  var shake: Double = 0

  func addBladePoint(x: Double, y: Double) {
    bladePoints.append(BladePoint(x: x, y: y, age: 0))
    if bladePoints.count > 20 { bladePoints.removeFirst() }
    spawnSpiritCloud(atX: x, y: y)
  }

  func addBladeSegment(fromX: Double, fromY: Double, toX: Double, toY: Double) {
    for step in 0...3 {
      let fraction = Double(step) / 3.0
      let px = fromX + (toX - fromX) * fraction
      let py = fromY + (toY - fromY) * fraction
      bladePoints.append(BladePoint(x: px, y: py, age: 0))
      if step % 2 == 0 {
        spawnSpiritCloud(atX: px, y: py)
      }
    }
    if bladePoints.count > 20 { bladePoints.removeFirst(bladePoints.count - 20) }
  }

  private func spawnSpiritCloud(atX x: Double, y: Double) {
    let colors = ["#8beaff", "#b388ff", "#e0f7fa", "#80deea"]
    let color = colors[spiritClouds.count % colors.count]
    let angle = Double(spiritClouds.count % 8) * (.pi / 4.0)
    let speed = 15.0 + Double(Int(x + y) % 25)
    spiritClouds.append(
      SpiritCloudParticle(
        x: x + cos(angle) * 4.0,
        y: y + sin(angle) * 4.0,
        vx: cos(angle) * speed,
        vy: -25.0 - Double(Int(x) % 20),
        radius: 8.0,
        growth: 22.0,
        alpha: 0.65,
        color: color
      )
    )
    if spiritClouds.count > 24 { spiritClouds.removeFirst(spiritClouds.count - 24) }
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
    if slices.count > 10 { slices.removeFirst(slices.count - 10) }

    // Spawn 4 flying pumpkin seeds bursting out
    for i in 0..<4 {
      let angle = Double(i) * (.pi * 2.0 / 4.0) + Double(identity % 17) * 0.1
      let speed = 120.0 + Double((identity * 19 + i * 29) % 120)
      seeds.append(
        PumpkinSeedParticle(
          x: x,
          y: y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 60.0,
          angle: Double(i),
          vAngle: (i % 2 == 0 ? 1.0 : -1.0) * (6.0 + Double(i)),
          size: 22.0,
          alpha: 1.0
        )
      )
    }
    if seeds.count > 16 { seeds.removeFirst(seeds.count - 16) }

    // Spawn 8 juice droplets
    let colors = ["#ff7a00", "#ffa726", "#ff5722", "#ffd54f"]
    for i in 0..<8 {
      let angle = Double(i) * (.pi * 2.0 / 8.0) + Double(identity % 20) * 0.05
      let speed = 90.0 + Double((identity * 17 + i * 23) % 120)
      particles.append(
        JuiceParticle(
          x: x,
          y: y,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 40.0,
          radius: 4.0 + Double(i % 4),
          alpha: 1.0,
          color: colors[i % colors.count]
        )
      )
    }
    if particles.count > 36 { particles.removeFirst(particles.count - 36) }

    // Lingering juice splat on backdrop
    splats.append(
      JuiceSplat(x: x, y: y, radius: 26.0 + Double(identity % 16), alpha: 0.45)
    )
    if splats.count > 10 { splats.removeFirst(splats.count - 10) }
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

    // Update flying pumpkin seeds with gravity
    seeds = seeds.compactMap { seed in
      var s = seed
      s.vy += 380.0 * dt
      s.x += s.vx * dt
      s.y += s.vy * dt
      s.angle += s.vAngle * dt
      s.alpha -= 1.3 * dt
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

    // Update ethereal spirit cloud particles
    spiritClouds = spiritClouds.compactMap { cloud in
      var c = cloud
      c.x += c.vx * dt
      c.y += c.vy * dt
      c.radius += c.growth * dt
      c.alpha -= 1.6 * dt
      return c.alpha > 0.02 ? c : nil
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

  func render(context: JSObject, width: Double, height: Double) {
    renderSplats(context: context)
    renderSlices(context: context)
    renderSeeds(context: context)
    renderParticles(context: context)
    renderBladeTrail(context: context)
    renderCallouts(context: context, width: width)
  }

  private func renderSplats(context: JSObject) {
    for splat in splats {
      context.fillStyle = .string("rgba(235, 110, 0, \(splat.alpha * 0.42))")
      _ = context.beginPath!()
      _ = context.arc!(splat.x, splat.y, splat.radius, 0, Double.pi * 2)
      let satDist = splat.radius * 1.35
      let satRadius = splat.radius * 0.32
      let satellites: [(Double, Double)] = [
        (-satDist, -satDist * 0.4),
        (satDist * 0.9, -satDist * 0.6),
        (satDist * 0.5, satDist * 0.8),
        (-satDist * 0.7, satDist * 0.7),
      ]
      for (dx, dy) in satellites {
        _ = context.moveTo!(splat.x + dx + satRadius, splat.y + dy)
        _ = context.arc!(splat.x + dx, splat.y + dy, satRadius, 0, Double.pi * 2)
      }
      _ = context.fill!()
    }
  }

  private func renderSlices(context: JSObject) {
    for slice in slices {
      let idx = slice.pieceIndex - 1
      guard idx >= 0, idx < sliceImages.count,
        let img = sliceImages[idx], img.complete.boolean == true
      else { continue }
      _ = context.save!()
      _ = context.translate!(slice.x, slice.y)
      _ = context.rotate!(slice.angle)
      context.globalAlpha = .number(slice.alpha)
      let w = slice.size * 0.82
      let h = slice.size * 1.12
      _ = context.drawImage!(img, -w / 2, -h / 2, w, h)
      _ = context.restore!()
    }
  }

  private func renderSeeds(context: JSObject) {
    guard let seedImg = seedImage, seedImg.complete.boolean == true else { return }
    for seed in seeds {
      _ = context.save!()
      _ = context.translate!(seed.x, seed.y)
      _ = context.rotate!(seed.angle)
      context.globalAlpha = .number(seed.alpha)
      let sw = seed.size * 0.67
      let sh = seed.size
      _ = context.drawImage!(seedImg, -sw / 2, -sh / 2, sw, sh)
      _ = context.restore!()
    }
  }

  private func renderParticles(context: JSObject) {
    guard !particles.isEmpty else { return }
    _ = context.save!()
    context.fillStyle = .string("#ffa726")
    for p in particles {
      context.globalAlpha = .number(p.alpha)
      _ = context.beginPath!()
      _ = context.arc!(p.x, p.y, p.radius, 0, Double.pi * 2)
      _ = context.fill!()
    }
    _ = context.restore!()
  }

  private func renderBladeTrail(context: JSObject) {
    for cloud in spiritClouds {
      _ = context.save!()
      context.fillStyle = .string(cloud.color)
      context.globalAlpha = .number(cloud.alpha * 0.4)
      context.shadowColor = .string("#40e0d0")
      context.shadowBlur = .number(12.0)
      _ = context.beginPath!()
      _ = context.arc!(cloud.x, cloud.y, cloud.radius, 0, Double.pi * 2)
      _ = context.fill!()
      _ = context.restore!()
    }
    guard bladePoints.count >= 2 else { return }
    let count = bladePoints.count
    _ = context.save!()
    context.lineCap = .string("round")
    context.lineJoin = .string("round")
    for i in 1..<count {
      let progress = Double(i) / Double(count - 1)
      context.strokeStyle = .string("rgba(90, 230, 255, \(max(0.08, 0.45 * progress)))")
      context.shadowColor = .string("#00e5ff")
      context.shadowBlur = .number(16.0 * progress)
      context.lineWidth = .number(max(2.0, 22.0 * progress))
      _ = context.beginPath!()
      _ = context.moveTo!(bladePoints[i - 1].x, bladePoints[i - 1].y)
      _ = context.lineTo!(bladePoints[i].x, bladePoints[i].y)
      _ = context.stroke!()
    }
    for i in 1..<count {
      let progress = Double(i) / Double(count - 1)
      context.strokeStyle = .string("rgba(175, 245, 255, \(max(0.12, 0.85 * progress)))")
      context.shadowColor = .string("#ffffff")
      context.shadowBlur = .number(6.0 * progress)
      context.lineWidth = .number(max(1.5, 9.0 * progress))
      _ = context.beginPath!()
      _ = context.moveTo!(bladePoints[i - 1].x, bladePoints[i - 1].y)
      _ = context.lineTo!(bladePoints[i].x, bladePoints[i].y)
      _ = context.stroke!()
    }
    for i in 1..<count {
      let progress = Double(i) / Double(count - 1)
      context.strokeStyle = .string("rgba(255, 255, 255, \(max(0.15, 0.95 * progress)))")
      context.shadowBlur = .number(2.0)
      context.lineWidth = .number(max(1.0, 3.2 * progress))
      _ = context.beginPath!()
      _ = context.moveTo!(bladePoints[i - 1].x, bladePoints[i - 1].y)
      _ = context.lineTo!(bladePoints[i].x, bladePoints[i].y)
      _ = context.stroke!()
    }
    _ = context.restore!()
  }

  private func renderCallouts(context: JSObject, width: Double) {
    for callout in callouts {
      _ = context.save!()
      let fontSize = max(18.0, min(42.0, width * 0.042)) * callout.scale
      let fontFamily = "'Gang of Three', ui-rounded, 'Avenir Next', system-ui, sans-serif"
      context.font = .string("900 \(fontSize)px \(fontFamily)")
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
