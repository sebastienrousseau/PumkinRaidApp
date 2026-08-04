# Asset Provenance

The runtime artwork and audio are derived from the project owner's licensed source
archive, `pumpkinraid-v2/Assets`. Those source PSD, AI, PNG, JPG, font, and audio files
remain outside this private application repository because the editable archive is
large and contains unrelated themes.

## Current exports

| Runtime asset | Source family | Transformation |
| --- | --- | --- |
| `splash-backdrop-tablet.png` | Theme 1 home PSD, `back` layer | Text-free layer export, edge cleanup, lossless PNG |
| `gameover-backdrop-tablet.png` | Theme 1 leaderboard PSD, `back` layer | Score-panel-free layer export, transparent pasteboard crop, lossless PNG |
| `leaderboard-panel.png` | Theme 1 leaderboard PSD, empty panel layer | Direct lossless layer export for live localized scores and asset-backed controls |
| `skull-toggle-on.png`, `skull-toggle-off.png` | Theme 1 settings screen runtime masters | Direct owned iPad exports matching the paired skull controls in `640X960_Setting.psd` |
| `button-arrow.png`, `button-arrow-pressed.png` | Theme 1 start-button runtime masters | Lossless transparent-canvas trim so the painted arrow can be optically centered and scaled |
| `background-wide.jpg` | Theme 1 game background | Existing owned wide export copied for browser parity |
| `phantom.png` | Theme 1 character art | Existing transparent runtime export |
| `pumpkin1.png`–`pumpkin3.png` | Theme 1 pumpkin animation | Existing transparent animation frames |
| `mysterious_house.mp3` | Original game audio | Existing compressed music master |
| `slice.wav` | Original game audio | Existing lossless effects master |

`Configuration/AssetManifest.sha256` pins every newly introduced export. CI runs
`Scripts/validate-assets.sh` to detect accidental replacement, corruption, or an
oversized browser payload. When an asset is intentionally re-exported, review the
visual result, update this table if its transformation changed, and then update its
recorded digest in the same commit.

No third-party competitor artwork is included. Competitor screenshots are reference
material for interaction and quality analysis only.
