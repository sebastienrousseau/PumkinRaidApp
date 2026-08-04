# Quality Gates

Each phase is red until its automated checks and applicable human validation are
recorded. Compilation alone is not a green gate.

| Area | Green gate |
| --- | --- |
| Simulation | Reproducible replay digest; fixed timestep; fuzzed safe bounds |
| Input | Semantic action tests for keyboard, pointer, touch, remote, and controller |
| Gameplay | No unavoidable waves in 100,000 seeded simulations |
| UX | Snapshot matrix, accessibility audit, and external comprehension playtest |
| Performance | 60 fps minimum-hardware profile and bounded node/audio counts |
| Apple | macOS, iOS, iPadOS, and tvOS builds and lifecycle tests |
| Web | Wasm build plus Chromium, WebKit, and Firefox smoke tests |
| Persistence | Versioned save migration, corruption recovery, and offline behavior |
| Social | Authenticated/fallback leaderboards and replay-backed score validation |
| Release | Privacy manifest, archive validation, store assets, and clean CI matrix |

