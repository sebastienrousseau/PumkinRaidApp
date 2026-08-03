# Architecture

PumkinRaidApp uses a functional-core, imperative-shell architecture.

```text
Input (keyboard / touch / pointer / remote)
                    |
                    v
        Apple SpriteKit or Web Canvas
                    |
                    v
 GameEngineLib (rules, spawn plans, combos, ranking)
                    |
                    v
       Render state + local persistence
```

## Modules

- `GameEngineLib` is pure Swift and contains no UI, device, or rendering imports.
  Its seeded random generator makes a run reproducible in tests and future replays.
- `PumkinRaidApp` is the Apple host. SwiftUI owns navigation, SpriteKit owns the
  real-time scene, and AVFoundation/CoreMotion/GameController adapt each device.
- `Platforms/Web` is a Swift WebAssembly executable. JavaScriptKit only bridges
  Swift to browser Canvas, DOM events, and animation frames.

Renderer coordinates are normalized at the engine boundary. Spawn plans describe
intent (position, speed, drift, scale, archetype), not pixels. This keeps difficulty
identical at phone, tablet, television, desktop, and browser resolutions.

## Extraction boundary

`GameEngineLib` is already a public Swift package product. It deliberately remains
in this repository until its API and replay format reach 1.0; it can then be moved
to a standalone repository without changing the app-facing import.
