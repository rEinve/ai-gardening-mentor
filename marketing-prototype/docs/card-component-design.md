# Card component design

## Understanding

- Add a reusable media-card anatomy based on `Design/card.component.json`.
- Extend the existing `.card` component without breaking text-only cards.
- Keep page placement in layout primitives and card styling inside the component.
- Translate the fixed design geometry into responsive, token-bound CSS.
- Demonstrate the result in `brandkit.html` and leave `index.html` unchanged.

## Assumptions

- The design's 500 by 719 frame is a proportion reference, not a fixed size.
- Card media may be meaningful or decorative and must use appropriate alternative text.
- Surface and foreground roles are composed through ThemeUI utility classes.
- The component has no interaction or data requirements.

## Design

The existing `.card` remains a vertical interior container. Optional `.card__media`, `.card__media-frame`, and `.card__body` elements add the full-width media anatomy. The media frame uses a responsive four-to-three proportion; the body uses the design system's spacing, headline, and body-copy tokens. Long content grows the card naturally.

## Decision log

1. Extend `.card` with the explicit `.card--media` modifier while leaving default ThemeUI cards unchanged.
2. Keep media optional so text-only cards remain compatible.
3. Compose surface appearance with utilities rather than hardcoding a fill.
4. Use responsive proportions instead of the source design's fixed dimensions.
5. Add one Brand Kit specimen using an existing local image asset.
