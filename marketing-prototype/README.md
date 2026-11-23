# IntelliTheme Starter

The canonical starting point for IntelliWebLab landing pages, prototypes, and reusable page compositions.

IntelliTheme is the consumer template. ThemeUI is the separate design-system repository that builds and supplies the `themeui-lab` package. Keep those repositories separate: update design-system primitives in ThemeUI, and compose pages and consumer styles here.

## Start a new project

```sh
git clone https://github.com/rEinve/intellitheme.git my-project
cd my-project
npm install
npm run dev
```

For local ThemeUI development, link the built ThemeUI package instead:

```sh
# In the separate themeui-lab repository
npm run build:package
npm link

# In this IntelliTheme project
npm install
npm link themeui-lab
npm run dev
```

The committed Git dependency remains the portable fallback for fresh clones. A local `npm link themeui-lab` takes precedence when developing ThemeUI and IntelliTheme together.

## Commands

```sh
npm run dev       # Start the Vite development server
npm run build     # Build the production output in dist/
npm run preview   # Preview the production build
```

## Where to work

- `index.html` is the starter page composition.
- `partials/` contains reusable page sections.
- `src/main.js` contains page interaction setup.
- `src/scss/` contains consumer tokens, themes, and component styles.
- `public/` contains static assets.
- `Design/` contains design references.

## ThemeUI v2

Use the resolved `themeui-lab` package as the source of truth. Keep markup token-bound and use v2 roles such as `--surface`, `--on-surface`, `--tertiary`, and `--outline`. Prefer the package’s sections, containers, grids, stacks, components, and utilities before adding consumer CSS.

The app entrypoint imports `themeui-lab/styles.css` and initializes `initColorScheme()`, `initTabs()`, and `initCarousels()` from the linked or installed package.

New projects should update their page content and branding while preserving the starter’s ThemeUI boundaries. Changes that are genuinely reusable across projects belong in the separate ThemeUI repository.
