# Pumkin Raid Product Definition

## Product promise

Pumkin Raid is a fast, friendly supernatural arcade game about turning movement
into offense. The player guides a playful ghost through a moonlit pumpkin raid,
building flowing dash combos while avoiding direct collisions.

The game must be understandable from motion alone: move the ghost, dash through
pumpkins, and use a charged shriek when the screen becomes dangerous.

## Audience and session

- Primary audience: players aged 9+ who enjoy accessible score-attack games.
- First successful action: within five seconds of entering gameplay.
- Typical run: three to seven minutes.
- Mastery: route planning, timing, risk, near misses, and multi-target dashes.
- Business model: premium, subscription-catalogue, or free trial with one-time
  unlock. Competitive power is never sold.
- Offline contract: the full solo game remains playable without a network.

## Canonical actions

All platform input is translated into these semantic actions before it reaches
the simulation:

1. **Move** positions or steers the ghost.
2. **Dash** moves rapidly through a direction and destroys crossed pumpkins.
3. **Shriek** spends a limited charge to clear nearby threats.
4. **Pause** suspends simulation time without changing the run.

Touch, mouse, keyboard, controller, motion, remote, and browser input may use
different physical gestures, but they may not invent platform-specific rules.

## Fairness contract

- A run is reproducible from its rules version, seed, and semantic input stream.
- Display resolution and refresh rate never alter movement or difficulty.
- Newly spawned hazards provide a readable reaction window.
- The director rejects unavoidable formations.
- Randomness creates variation while authored wave budgets create rhythm.
- Submitted competitive scores carry a deterministic replay digest.

## Quality gates

Phase 0 is green when the product and action contracts are represented in both
documentation and public engine types. Later phases additionally require:

- 90% of external playtesters understand the primary action without prose.
- 85% complete the interactive tutorial.
- Fewer than 5% of captured actions are unintended.
- Stable 60 fps on the minimum supported Apple hardware.
- Identical final replay digests across Apple and WebAssembly builds.
- All claimed platforms build and pass automated input and lifecycle tests.

External playtest gates cannot be self-certified by repository automation. They
remain release blockers until recorded test evidence is attached to a milestone.

