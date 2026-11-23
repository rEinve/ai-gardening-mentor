# IntelliWebLab design guide

This guide translates the examples in [`brandkit.html`](brandkit.html) into rules for new IntelliWebLab pages. The requested `designkit.html` is not present in this repository; `brandkit.html` is the available design kit. The resolved `themeui-lab` package and this starter's theme files define the current token values and class names when an example in the HTML differs.

## Direction

**Simply Smarter Web.** Make complex ideas clear, show the next useful action, and keep technology approachable. The voice is intelligent, practical, curious, clear, and human. Explain the benefit in ordinary language before technical detail. Use real project evidence and approved testimonials; the activity panels and quotes in the kit are placeholders.

## Color

Use semantic ThemeUI v2 roles, so a page can change theme without rewriting components. A filled role always takes its matching foreground role.

| Role | Use | Foreground |
| --- | --- | --- |
| `background`, `surface` | Page canvas and reading areas | `on-background`, `on-surface` |
| `surface-container-low`, `surface-container`, `surface-container-highest`, `surface-variant` | Increasingly distinct neutral groups | Matching surface ink from the surface class |
| `primary` | Main brand emphasis and key moments | `on-primary` |
| `secondary` | Supporting emphasis | `on-secondary` |
| `tertiary` | Accent, links, and related features | `on-tertiary` |
| `primary-container`, `secondary-container`, `tertiary-container` | Softer brand panels | Matching `on-*-container` |
| `error` | Error and destructive states | `on-error` |
| `outline`, `outline-variant` | Borders and quiet separation | — |

### Current color values

These are the effective opaque colors authored in `src/scss/themes/_scheme-light.scss` and `src/scss/themes/_scheme-dark.scss`. The stylesheets write them as eight-digit hex with `ff` opacity; the table shows the equivalent six-digit hex. If a role appears more than once in a theme block, the last declaration is the effective value.

| Role | Light | Dark |
| --- | --- | --- |
| `primary` | `#555D68` | `#8CBAE6` |
| `on-primary` | `#FFFFFF` | `#0A2C4C` |
| `primary-container` | `#6D7581` | `#0D3B66` |
| `on-primary-container` | `#FDFCFF` | `#A6C7E6` |
| `secondary` | `#4A626C` | `#7FE6DA` |
| `on-secondary` | `#FFFFFF` | `#004C44` |
| `secondary-container` | `#D9F3FF` | `#00665B` |
| `on-secondary-container` | `#57707A` | `#9DE6DE` |
| `tertiary` | `#7B5900` | `#E6A989` |
| `on-tertiary` | `#FFFFFF` | `#4C1F08` |
| `tertiary-container` | `#FFDEAD` | `#662A0A` |
| `on-tertiary-container` | `#765500` | `#E6BBA4` |
| `error` | `#BA1A1A` | `#E6B1BA` |
| `on-error` | `#FFFFFF` | `#4C252C` |
| `error-container` | `#FFDAD6` | `#66323B` |
| `on-error-container` | `#93000A` | `#E6C0C7` |
| `background` | `#FFFDFA` | `#131314` |
| `on-background` | `#1A0F00` | `#E4E2E2` |
| `surface` | `#FCF9F9` | `#131314` |
| `on-surface` | `#1B1B1C` | `#E4E2E2` |
| `surface-container-low` | `#F6F3F3` | `#1B1B1C` |
| `surface-container` | `#F0EDEE` | `#1F1F20` |
| `surface-container-highest` | `#E4E2E2` | `#353535` |
| `surface-variant` | `#E0E3E3` | `#444748` |
| `on-surface-variant` | `#444748` | `#C4C7C7` |
| `outline` | `#747878` | `#9FA9B3` |
| `outline-variant` | `#C4C7C7` | `#4B5157` |

Compose a structural component with a surface class, for example `class="card surface-container-low"`. Use surface contrast, brand color, and fine outlines for depth. Keep shadows quiet. The palette image is a visual reference; the theme stylesheets define the current values.

## Typography

Clarity City is the display, heading, label, navigation, and button family. Montserrat is the body and lead family. Use the fluid tokens already defined in `src/scss/_theme.scss` and the semantic type classes in the package.

**Weight rule:** H1, H2, and H3, including their `.h1`–`.h3` presentation classes, use medium weight (`--weight-medium`, 500). Never use full bold (700) for those headline levels. Reserve full bold for explicit `<strong>` emphasis and H4–H6 when a smaller heading needs stronger emphasis. Ordinary body copy stays regular; labels, navigation, buttons, and other component text should not use full bold.

| Text | Kit reference | Treatment |
| --- | --- | --- |
| Display XL | `--display-xl`, `--lh-display`, `--ls-display` | Clarity City, weight 500 |
| H1 | `--step-5`, display line height and tracking | Clarity City, weight 500 |
| H2 | `--step-4`, display line height and tracking | Clarity City, weight 500 |
| H3 | `--step-3`, headline line height and tracking | Clarity City, weight 500 |
| H4 | `--step-2`, headline line height and tracking | Clarity City, weight 400 |
| Lead | `--text-leading`, `--lh-title`, `--measure-lead` | Montserrat, weight 400 |
| Body | `--step-0`, `--lh-body`, `--measure-prose` | Montserrat, weight 400 |
| Small body and labels | `--text-xs`, `--lh-label`, `--ls-label` | Montserrat body; Clarity City labels |

Keep headings short and descriptive. Use one semantic H1 per page, then follow the heading hierarchy. Type specimen classes such as `.display-xl`, `.lead`, `.body-s`, and `.label-s` are presentation aids; choose HTML elements for the content's meaning.

## Layout and rhythm

Compose every section as `section → .container → .grid → responsive span → component`. Put the component inside the spanned grid child, including forms such as the blog subscribe form. Sections own their vertical spacing. Use `.stack` for vertical rhythm, `.cluster` for wrapping inline groups, and package utilities for alignment and gaps. The kit shows the `--space-xs`, `--space-s`, `--space-m`, `--space-l`, `--space-xl`, and `--space-xxl` rhythm; use the live token values rather than copying a measured pixel value from a specimen.

The linked ThemeUI v2 grid has four viewport tiers:

| Tier | Width | Columns | Span classes |
| --- | --- | ---: | --- |
| Compact | Below 600px | 4 | `.col-1` through `.col-4` |
| Medium | 600–839px | 10 | `.md-col-*` |
| Expanded | 840–1199px | 12 | `.exp-col-*` |
| Large | 1200px and above | 12 | `.lg-col-*` |

Grid children fill the row by default. Add span classes where a narrower layout is useful, and inspect both compact and wide views. The kit's `.com-col-*` entry is legacy; use the v2 `.col-*` classes.

## Corners and depth

Use the active component radius tokens for inputs, buttons, cards, badges, and dialogs. The kit names `--input-radius`, `--button-radius`, `--card-radius`, `--badge-radius`, and `--modal-radius` as specimen references; verify current component tokens in the resolved package before using them in new CSS. Prefer a neutral surface change or `outline-variant` hairline border to a large shadow.

## Components and content patterns

- **Navigation:** use the shared `nav-main` pattern. Its compact menu needs an accessible toggle and visible focus.
- **Buttons:** use `.button` with the available primary, ghost, or link treatment. Make the primary action easy to find. Native `disabled` communicates unavailable actions.
- **Blog reading links:** use the shared `.learn-more` link and `.learn-more__icon` circular arrow for every Learn more or Read more action. Keep navigational back links separate.
- **Cards:** use `.card` for structure and a semantic surface class for color. Feature cards can group distinct kinds of work with primary, tertiary, or container roles. A media card uses `.card__media` and `.card__body` when the image explains the text.
- **Eyebrows, badges, and tags:** use them for concise context such as section numbers or categories, not as a substitute for headings.
- **Forms:** show visible labels and concise hints, use the shared `.input` styling, and retain a visible keyboard focus state.
- **Proof:** show actual product details and verified quotes. Label sample data clearly until it is replaced.

Keep primary controls at least 44 × 44px where the layout allows. Give meaningful images useful alternative text. Ensure each surface and its text use a matching role pair in light and dark themes.

## Implementation in this starter

Keep page composition in HTML, reusable styling in Sass partials, and interactions in JavaScript. Import `themeui-lab/styles.css` and initialize `initColorScheme`, `initTabs`, and `initCarousels` from the package entrypoint. Use the resolved package as the source of truth for primitives, utilities, and tokens. Avoid legacy `--color-*` and `.com-col-*` names, inline styles, and page-specific grid systems.
