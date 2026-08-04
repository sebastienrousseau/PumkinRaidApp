# ADR-001: Deterministic Shared Simulation

- Status: Accepted
- Date: 2026-08-03

## Context

The SpriteKit and browser hosts currently advance related but separate gameplay
loops. That makes platform parity, replay verification, input testing, balancing,
and trustworthy leaderboards impossible to guarantee.

## Decision

`GameEngineLib` owns the authoritative fixed-timestep simulation. Platform hosts
translate physical controls into semantic `InputAction` values and render
`GameState` plus `GameEvent` output. Renderers do not calculate scores, collisions,
difficulty, or spawn timing.

The simulation uses normalized playfield coordinates and integer ticks. Replay
files include a rules version, seed, mode, and tick-addressed inputs. A quantized
state digest provides a platform-independent verification value.

## Consequences

- Window size and display refresh rate cannot alter game difficulty.
- Apple and Web builds share gameplay behavior.
- Input, renderer, audio, persistence, and online services can be tested through
  narrow interfaces.
- Existing `GameScene` behavior must migrate incrementally to engine events.
- Visual interpolation remains a renderer responsibility.

