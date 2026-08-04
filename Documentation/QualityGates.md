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

## Current repository evidence

| Area | Automated status | Evidence |
| --- | --- | --- |
| Simulation | Green | Deterministic replay digests, fixed 60 Hz stepping, 216,000-tick soak |
| Input | Green | Semantic keyboard, pointer, touch, remote, and controller routing tests |
| Gameplay | Green | 100,000 seeded waves validated for safe, bounded composition |
| UX | Green (automated) | Five-resolution HUD centering matrix, direct pointer-drag regression test, adaptive safe-area layout, reduced-motion and high-contrast paths |
| Performance | Green (automated) | Bounded transient nodes/audio voices, signposts, and MetricKit capture |
| Apple | Green (unsigned) | Release builds for iOS/iPadOS, tvOS, and macOS |
| Web | Green | Optimized Wasm exercised in Chromium, Firefox, and WebKit |
| Persistence | Green | Versioned migration, corrupt-save recovery, and offline local boards |
| Social | Green (code) | Optional Game Center with authenticated submission and local fallback |
| Security | Green | Privacy manifest, sandbox entitlements, and zero-known-vulnerability npm audit |
| Unit coverage | Green | Exactly 100% function and line coverage in engine and app-service scopes |
| Asset integrity | Green | Licensed-source provenance, pinned SHA-256 exports, and a 3 MiB browser asset budget |
| Release | Green (repository) | CI, localization parity, privacy manifest, pure-Swift enforcement |

Human UX studies, signed archives, minimum-device profiling, Game Center/App Store
records, and final store artwork remain external release gates. They may only be marked
green after their evidence is captured; see `Release.md` and `PlaytestProtocol.md`.
