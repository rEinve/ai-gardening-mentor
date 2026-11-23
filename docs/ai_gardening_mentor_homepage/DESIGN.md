---
name: Botanical Mentor
colors:
  surface: '#f7fbf2'
  surface-dim: '#d7dbd3'
  surface-bright: '#f7fbf2'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f5ec'
  surface-container: '#ebf0e6'
  surface-container-high: '#e6eae1'
  surface-container-highest: '#e0e5db'
  on-surface: '#181d18'
  on-surface-variant: '#424940'
  inverse-surface: '#2d322c'
  inverse-on-surface: '#eef2e9'
  outline: '#72796f'
  outline-variant: '#c2c9bd'
  surface-tint: '#1f6c38'
  primary: '#005223'
  on-primary: '#ffffff'
  primary-container: '#a6f5b1'
  on-primary-container: '#00210a'
  inverse-primary: '#8bd898'
  secondary: '#526350'
  on-secondary: '#ffffff'
  secondary-container: '#d5e8cf'
  on-secondary-container: '#101f10'
  tertiary: '#1e4d50'
  on-tertiary: '#ffffff'
  tertiary-container: '#bcebee'
  on-tertiary-container: '#002022'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#410002'
  primary-fixed: '#a6f4b2'
  primary-fixed-dim: '#8bd898'
  on-primary-fixed: '#00210a'
  on-primary-fixed-variant: '#005224'
  secondary-fixed: '#d5e8d0'
  secondary-fixed-dim: '#b9ccb5'
  on-secondary-fixed: '#101f10'
  on-secondary-fixed-variant: '#3b4b39'
  tertiary-fixed: '#bcebee'
  tertiary-fixed-dim: '#a0cfd2'
  on-tertiary-fixed: '#002022'
  on-tertiary-fixed-variant: '#1f4d50'
  background: '#f7fbf2'
  on-background: '#181d18'
  surface-variant: '#dee5d9'
typography:
  display-lg:
    fontFamily: Roboto Flex
    fontSize: 3.75rem
    fontWeight: '700'
    lineHeight: '1.15'
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Roboto Flex
    fontSize: 2.5rem
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Roboto Flex
    fontSize: 2rem
    fontWeight: '600'
    lineHeight: '1.25'
    letterSpacing: -0.01em
  headline-md-mobile:
    fontFamily: Roboto Flex
    fontSize: 1.75rem
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  title-lg:
    fontFamily: Roboto Flex
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: '1.35'
  title-md:
    fontFamily: Roboto Flex
    fontSize: 1.25rem
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Inter
    fontSize: 1.125rem
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Inter
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: '1.6'
  label-lg:
    fontFamily: Inter
    fontSize: 0.875rem
    fontWeight: '500'
    lineHeight: '1.25'
    letterSpacing: 0.1px
  label-sm:
    fontFamily: Inter
    fontSize: 0.75rem
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.5px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 1rem
  margin: 2rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system embodies an authoritative, scientifically grounded botanical experience built directly upon modern Material Design 3 (M3) principles. Designed for an AI Gardening Mentor, it replaces the panic, second-guessing, and cognitive overload of novice plant care with calm clarity, reassuring guidance, and biological precision. 

The aesthetic is clean, organic, and methodical—combining tactile tonal container nesting with crisp agricultural science cues. Interfaces feel living and breathy without resorting to playful or juvenile tropes. Surfaces emulate fertile loam, morning mist, and crisp foliage, utilizing deep emeralds, serene sage, and warm mineral undertones to evoke composure, trust, and natural vitality.

## Colors

The palette establishes an authentic Material Design 3 dynamic tonal system centered on agricultural health:
- **Primary (`#1e6b37`)**: A deep botanical emerald representing chlorophyllic vitality, used for high-emphasis actions, primary buttons, and critical progress milestones.
- **Secondary (`#526350`)**: Muted sage foliage, delivering grounded supporting structure, category metadata, and auxiliary interactive layers.
- **Tertiary (`#386568`)**: Deep mineral slate-teal, balancing plant greens with a cool moisture and soil-chemistry feel for comparative analytics and contextual highlights.
- **Neutral Surface Hierarchy**: Anchored by `#f7fbf2` as the pristine canvas base, stepping through progressive container tones (`#ffffff` through `#e0e5db`) to structure depth without artificial drop shadows.
- **Contextual Semantics**: Destructive states and novice triage alerts use `error-container` (`#ffdad6`), intentionally contrasted against the thriving reassurance of `primary-container` (`#a6f5b1`).

## Typography

Typography balances scientific authority with immediate legibility:
- **Headlines (`Roboto Flex`)**: Display and section titles leverage a mechanical, variable grotesk structure with tight tracking (`-0.02em` to `-0.01em`) and confident weights (600–700), giving biological care recommendations weight and urgency.
- **Body & Labels (`Inter`)**: Neutral, neutral-geometric body text provides clinical clarity at all reading distances. A spacious line height (1.6) guarantees readability for diagnostic logs, botanical notes, and weather reports.
- **Labels & Overlines**: Strict 0.875rem and 0.75rem scales keep chips, buttons, and overline indicators crisp and compact across all device densities.

## Layout & Spacing

The layout operates on an 8px base grid rhythm (with a 4px half-step for micro-alignment). 

Content sections utilize a fluid 12-column responsive layout on desktop that transitions into an asymmetric Bento-grid structure for plant metrics and diagnostics:
- **Desktop (1024px+)**: 12 columns, 24px gutters, max-width container capped at 1280px. Bento modules span variable proportions (e.g., 8-col diagnostic viewfinder alongside 4-col environmental sensors).
- **Tablet (768px – 1023px)**: 8 columns, 16px gutters, 24px margins. Two-column card arrangements.
- **Mobile (< 768px)**: 4 columns, 16px gutters, 16px outer margin. All stacked cards collapse to full-width modules.

## Elevation & Depth

In alignment with Material Design 3, spatial hierarchy is articulated primarily through **tonal surface stacking** rather than heavy drop shadows:
- **Surface Elevation Layers**: Content begins at `surface` (`#f7fbf2`) and layers upward using `surface-container-low`, `surface-container`, `surface-container-high`, and `surface-container-highest`. Higher importance equates to deeper chromatic presence.
- **Ambient Shadows**: Shadows are strictly reserved for lifted interactive cards and floating triage drawers. They are diffused, soft, and tinted with deep botanical undertones:
  - *Level 1 (Resting elevated card)*: `0px 1px 3px 1px rgba(16, 31, 16, 0.08), 0px 1px 2px 0px rgba(16, 31, 16, 0.12)`
  - *Level 2 (Hovered / Floating widget)*: `0px 2px 6px 2px rgba(16, 31, 16, 0.08), 0px 1px 2px 0px rgba(16, 31, 16, 0.16)`
  - *Level 3 (Modal / Active sheet)*: `0px 4px 8px 3px rgba(16, 31, 16, 0.10), 0px 1px 3px 0px rgba(16, 31, 16, 0.20)`
- **Hairlines**: When demarcation is needed without elevation, use 1px strokes of `outline-variant` (`#c2c9bd`).

## Shapes

The design system incorporates organic, soft contours inspired by foliage curvature:
- **Pills (Full Radius `9999px`)**: Interactive targets, including Primary Buttons, Tonal Buttons, Filter/Input Chips, and Overline Badges.
- **Large Bento & Surfaces (`28px` / `rounded-xl`)**: Primary content cards, hero comparison frames, and major structural modules.
- **Standard Cards & Menus (`16px` / `rounded-lg`)**: Secondary panels, alert containers, and dialog sheets.
- **Micro Surfaces (`8px`)**: Form inputs, select menus, and tooltips.

## Components

### Buttons
- **Filled Button**: Primary CTA. Pill-shaped (`rounded-full`), `primary` fill (`#1e6b37`), `on-primary` text (`#ffffff`), 48px height, 24px horizontal padding. On hover, apply an 8% white overlay.
- **Tonal Button**: Secondary action. Pill-shaped, `secondary-container` fill (`#d5e8cf`), `on-secondary-container` text (`#101f10`).
- **Outlined Button**: Diagnostic & utility actions. Pill-shaped, transparent background, 1px border using `outline` (`#72796f`), `primary` text.

### Chips
- **Filter & Assistance Chips**: Height 32px, pill-shaped, 12px horizontal padding. Bordered with 1px `outline-variant`. Active/selected state switches fill to `secondary-container` with checkmark icon.
- **Overline / Alert Badge**: Height 24px, pill-shaped, filled with `primary-container` or `error-container` with uppercase `label-sm` text.

### Cards & Bento Modules
- **Standard Card**: Layered on `surface-container-low` with a 16px corner radius and 24px internal padding.
- **Contrast / Triage Card**: Two-tone structural component. Novice failure states utilize `error-container` surfaces with `on-error-container` typography; AI Mentor routines utilize `primary-container` surfaces with `on-primary-container` typography.

### Input Fields
- Outlined style with 8px corner radius. Border is 1px `outline` (`#72796f`), transitioning to 2px `primary` on focus. Floating label adheres to `label-lg`. Background remains transparent or matches `surface-container-lowest`.

### Checkboxes & Radios
- 20px bounding box with 4px corner radius on checkboxes and full pill on radio buttons. In unselected states, 2px border of `outline`. In checked states, filled with `primary` displaying an `on-primary` checkmark icon.

### Additional Suggested Component: Diagnostic Viewfinder
- A camera HUD component bounded by 28px corners, featuring crop-corner guide markers in `primary`, a real-time status chip top-center, and an ambient leaf-vein scanline indicator.