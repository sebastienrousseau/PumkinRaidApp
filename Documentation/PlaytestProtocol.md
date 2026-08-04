# Playtest Protocol

Automated checks protect correctness, but a premium arcade game also needs observed
human evidence. Use this protocol for every release candidate and attach the results
to the release record.

## Participants and hardware

- At least 12 people who did not implement the current build.
- At least four first-time players and four occasional mobile-game players.
- One minimum-supported iPhone, one modern iPhone, one iPad, one Apple TV with remote,
  one keyboard-and-mouse Mac, and one touch and one desktop browser.
- Test portrait, landscape, 16:9, 4:3, and ultrawide layouts where supported.

## Success thresholds

| Measure | Release threshold |
| --- | ---: |
| Start the first raid without coaching | 11/12 participants |
| Move the ghost within five seconds | 12/12 participants |
| Discover dash and shriek during onboarding | 11/12 participants |
| Understand score, lives, and charges | 11/12 participants |
| Restart after game over without coaching | 12/12 participants |
| Report blocked, clipped, or edge-touching UI | 0 participants |
| Median input-to-visible-response | under 100 ms |
| Crash, hang, lost audio lifecycle, or stuck input | 0 occurrences |
| “Would play another run” response | at least 9/12 participants |

## Session script

1. Launch from a clean profile and say only: “Please play.”
2. Record time to start, time to first movement, control used, and tutorial errors.
3. Ask the player to switch input method and complete another run.
4. Resize or rotate during play, background and restore the app, then close the window.
5. Ask what each HUD value means and invite the player to find modes, missions,
   cosmetics, daily streak, leaderboard, and sharing without directions.
6. Record a one-to-five score for clarity, responsiveness, fairness, delight, audio,
   visual polish, and desire to replay. Capture exact problems, not leading opinions.

The UX gate is complete only when the thresholds pass and the dated evidence is linked
from the release checklist. Failed observations become tracked issues with platform,
resolution, reproduction steps, and severity.
