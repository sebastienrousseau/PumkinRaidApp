# Product and Design System

## Experience principles

1. One obvious action per screen.
2. Immediate visual, audio, and haptic response to every successful action.
3. Fair randomness: unpredictable positions without same-lane repetition.
4. HUD content stays within an 88% maximum safe width and never touches an edge.
5. Controls work without instructions, while concise guidance remains available.

## Responsive layout

- Compact portrait: original phone composition with 20-point minimum safe margins.
- Regular portrait: 768×1024 artwork and wider leaderboard rows.
- Landscape/television/desktop: panorama background with a centered play field.
- Browser: fluid canvas from 320 px through ultrawide, using normalized coordinates.

## Remaining art direction

The code supports the full flow, but a premium visual pass still needs source designs
for: mode selection, first-run tutorial, pause, named leaderboard entry, achievements,
and a detailed results/bonus breakdown. Provide these as layered files at compact
portrait, regular portrait, and 16:9; the adaptive asset resolver can add them without
changing gameplay code.
