# Contributing to PumkinRaidApp

Thanks for helping improve Pumkin Raid. Open an issue before beginning a large
feature so gameplay, visual direction, and platform behavior can be agreed first.

## Development

1. Fork and clone the repository.
2. Create a focused branch from `main`.
3. Keep gameplay rules in `GameEngineLib`; platform frameworks do not belong there.
4. Add deterministic tests for every scoring, progression, or spawning change.
5. Run `swift test` and test affected Apple platforms before opening a pull request.
6. Include screenshots or a short capture for visible changes.

Code should compile with Swift 6 strict concurrency. Preserve accessibility labels,
keyboard navigation, safe-area spacing, and reduced-motion behavior. Do not add new
artwork or audio unless its redistribution terms are documented.

Report bugs at https://github.com/sebastienrousseau/PumkinRaidApp/issues.
