# Type system optimization

## Understanding

- Optimize the shared type foundation and component-level typography.
- Use `Design/typesetting.json` as the visual reference rather than literal production CSS.
- Preserve the repository's current ThemeUI token generation and two-font brand pairing.
- Improve hierarchy, responsive scaling, rhythm, tracking, and readable line length.
- Keep layout, content, colour, and component behaviour unchanged.

## Assumptions

- Montserrat remains the body face and Clarity City remains the display and label face.
- The JSON desktop sizes are reference caps for a fluid, mobile-first scale.
- Inverse and muted styles vary by colour, not by typography.
- Icon font sizing is optical and remains outside the prose scale.

## Design

Typography flows through three layers: foundation tokens in `_theme.scss`, element and role defaults in `_typesetting.scss`, and semantic token mappings in components. The foundation owns font stacks, fluid sizes, line heights, tracking, weights, and readable measures. Components consume those tokens and retain local type rules only when they express a genuine role.

The JSON roles map to display, heading, lead, body, small body, label, eyebrow, navigation, footer, and quote roles. Duplicate inverse and muted entries share metrics. Helvetica footer entries use the body stack to avoid an undeclared dependency.

## Decision log

1. Preserve the existing ThemeUI vocabulary to avoid mixing token generations.
2. Optimize both foundations and components rather than applying a minimal cleanup.
3. Treat `Design/typesetting.json` as design intent, not literal fixed CSS.
4. Use semantic, fluid tokens with explicit metrics and desktop caps.
5. Keep Montserrat for body copy and Clarity City for display and labels.
6. Perform static and build verification without browser automation; the user owns visual review.
