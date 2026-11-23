# IntelliTheme Starter Instructions

## Purpose

- This repository is the canonical starter for IntelliWebLab landing pages, prototypes, and page work.
- Clone this repository for new consumer projects; keep the starter itself reusable.
- `themeui-lab` is a separate repository and the design-system source of truth. Do not copy its source into this repository.

## Package Manager

- Use npm with the committed `package-lock.json`.
- `npm run dev` starts Vite at `http://127.0.0.1:4141`.
- `npm run build` is the required release check.
- `npm run preview` serves the production build.

### Local ThemeUI linking

```sh
# In the separate themeui-lab repository
npm run build:package
npm link

# In this repository
npm link themeui-lab
```

## Structure

- `index.html`: starter page composition.
- `partials/`: reusable HTML fragments.
- `src/main.js`: interaction entrypoint.
- `src/theme.scss` and `src/scss/`: consumer theme and component styles.
- `public/`: static assets.
- `Design/`: design references.

## ThemeUI Contract

- Use the resolved `themeui-lab` package as the source of truth; this starter targets official ThemeUI v2.
- Import `themeui-lab/styles.css` and initialize `initColorScheme`, `initTabs`, and `initCarousels` from the package entrypoint.
- Use unprefixed v2 roles such as `--surface`, `--on-surface`, `--tertiary`, and `--outline`.
- Compose every page section as `section → .container → .grid → responsive span → component`; use ThemeUI primitives and utilities.
- Compose blog articles as `.post-header → figure.post-artwork > picture > img → .post-layout.with-sidebar` with an `aside.takeaways` and `.post-content`.
- Use `var(--space)` (1rem/16px) for all layout gaps, including grids, stacks, cards, carousels, and controls. Keep gaps the same at every breakpoint; do not introduce alternate gap values.
- Use `.learn-more` for blog Read more and Learn more links; the shared component includes the circular arrow.
- Follow the weight rule in `design.md`: H1–H3 use medium (500); reserve bold (700) for `<strong>` and optional emphasis in H4–H6.
- Keep page composition in HTML, reusable presentation in Sass partials, and interactions in JavaScript.
- Do not introduce `--color-*`, `com-col-*`, Tailwind, inline styles, or page-specific grid systems.

## Validation

- Do not use computer-use agents or UI automation tools, including `mcp__cua_repl`, for this repository. Use CLI checks and user-provided screenshots for visual review.
- Inspect compact and wide layouts for visual changes.
- Run `npm run build` before handoff.
- Keep `dist/` and `node_modules/` untracked.

## Commit Attribution

None
