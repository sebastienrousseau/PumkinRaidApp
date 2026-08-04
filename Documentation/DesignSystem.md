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
- Results use `ViewThatFits` and a scroll-safe fallback: board and actions sit side by
  side when they genuinely fit, then become one centered column without coordinates.
- Dense action groups use adaptive 320-point columns rather than shrinking labels.

## Typography and controls

- Creepsville is reserved for major screen identity; Gapstown is used for concise
  display labels; long descriptions retain a highly readable rounded system face.
- Custom fonts use SwiftUI relative text styles, so Dynamic Type continues to scale.
- Primary actions use the source-derived pumpkin/candy plate. Secondary actions use
  the skull/peppermint plate. Compact navigation uses recognizable owned character art.
- Interactive targets are at least 66 points high, support visible tvOS focus, preserve
  keyboard activation, and provide pressed feedback without motion when Reduce Motion
  is enabled.
- White text sits on a dark quiet center with high-luminance borders; toggle state is
  conveyed through selection, brightness, and an announced On/Off value—not color alone.

## Future screen-specific art

The shared system is production-ready. Bespoke layered compositions can still deepen
mode selection, first-run tutorial, pause, achievements, and bonus breakdown screens.
Provide compact portrait, regular portrait, and 16:9 masters; the adaptive resolver can
add them without changing gameplay or accessibility semantics.
