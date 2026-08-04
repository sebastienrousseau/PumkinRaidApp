# Performance and Stability Budgets

The game simulation is fixed at 60 ticks per second and never accepts display
dimensions or refresh rate as rules input. Rendering may skip presentation frames,
but simulation catch-up is capped at six ticks per rendered frame to prevent a
spiral of death.

## Runtime budgets

| Resource | Budget | Enforcement |
| --- | ---: | --- |
| Simulation | 60 deterministic ticks/s | Fixed timestep and one-hour soak test |
| Catch-up | 6 ticks/frame | `GameScene` and browser frame loops |
| Transient SpriteKit effects | 96 nodes | Oldest-first bounded effect layer |
| Simultaneous sound effects | 12 voices | Oldest-first audio voice eviction |
| Frame delta | 100 ms maximum | Foreground/background spike clamp |
| Web release module | 5 MB uncompressed target | `wasm-opt` plus Vite release report |

MetricKit captures Apple launch, responsiveness, memory, and diagnostic payloads.
OS signposts measure every simulation frame and include its fixed-step count. tvOS,
where MetricKit payload delivery is unavailable, retains the same signposts and CI
build gate.

Repository automation validates deterministic state, 100,000 fair wave windows,
a one-hour no-game-over simulation soak, bounded resources, Apple SDK compilation,
and real Chromium, Firefox, and WebKit WebAssembly/input smoke tests. Device
frame-rate acceptance still requires recorded runs on the minimum supported iPhone,
iPad, Mac, and Apple TV.
