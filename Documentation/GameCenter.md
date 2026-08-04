# Game Center Configuration

The application contains a local/offline leaderboard fallback and submits
non-assisted runs to Game Center when the player is authenticated.

Configure these leaderboard identifiers in App Store Connect before release:

- `leaderboard.classic`
- `leaderboard.moon_rush`
- `leaderboard.daily`
- `leaderboard.boss`

Configure these achievement identifiers:

- `achievement.first_raid`
- `achievement.combo_10`
- `achievement.score_10000`
- `achievement.near_miss_10`

Competitive submissions include the low 31 bits of the deterministic replay
digest as leaderboard context. Assisted runs remain in a separate local board and
are never submitted to competitive Game Center leaderboards.
