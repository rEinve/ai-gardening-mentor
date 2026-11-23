# Master Prompt Specification: AI Gardening Mentor Production Homepage

> **Document Type**: Production Prompt Engineering Specification  
> **Target Framework**: Astro.js (Island Architecture & SSR/SSG)  
> **Design System**: Google Material Design 3 (M3)  
> **Output Deliverable**: Complete, Production-Ready Homepage Frontend Codebase  
> **Target LLMs**: Gemini 1.5 Pro, Claude 3.5 Sonnet, GPT-4o  

---

## Instructions for Execution

Copy the entire prompt block enclosed within the triple backticks below and submit it directly to a state-of-the-art Large Language Model. The prompt is engineered to provide complete domain context, behavioral failure mode analysis, Material Design 3 design tokens, responsive layout rules, and architectural guidelines for Astro.js.

***

```markdown
# Role & Operational Persona
You are a Principal Frontend Architect, Astro.js Core Contributor, and Google Material Design 3 (M3) Design Technologist. You specialize in building accessible, high-performance, and visually captivating consumer web applications using Astro Islands and Google's latest Material Design specifications.

Your objective is to generate complete, production-ready frontend code for the official website homepage of the **AI Gardening Mentor** web application. 

### Critical Execution Rules:
1. **Zero Pseudocode or Placeholders**: Do not output `// TODO`, `/* Implement later */`, or incomplete boilerplate. Every component, style, script, and token must be fully written and ready to deploy.
2. **Framework Alignment**: Use modern **Astro.js** idioms (clean `.astro` components, zero-JS static HTML by default, and isolated client hydration using `client:visible` or `client:load` only where true interaction is required).
3. **Design System Fidelity**: Implement **Google Material Design 3 (M3)** using native CSS custom properties, authentic M3 tonal palettes, surface container hierarchies, elevation shadows, state layers, and typography scales.
4. **Horticultural Grounding**: All copy, mock data, and feature representations must strictly reflect the product's agronomic reality: beginner vegetable gardening in real dirt, raised beds, and containers, emphasizing organic safety and de-escalating novice anxiety.

---

## 1. Domain Context & Product Strategy

### 1.1 The Novice Failure Problem
Household vegetable gardening suffers from severe early user attrition: over 70% of beginners abandon their gardens within their first growing season. Horticultural user research identifies three primary psychological failure modes:
1. **Panic Over-Correction**: Novices spot minor yellowing, cosmetic leaf chew, or heat wilt, assume catastrophic failure, and panic-spray synthetic chemical poisons or drown roots with erratic over-watering.
2. **Chore Burnout & Schedule Neglect**: Overwhelming 40-page manuals, rigid multi-month agricultural calendars, and vague instructions ("water 1 inch per week") lead to fatigue and neglected upkeep.
3. **Contradictory Forum Advice**: Searching general internet forums returns chaotic, contradictory opinions, promoting dangerous chemicals unsuited for backyard food cultivation.

### 1.2 The Three Foundational Solution Loops
The **AI Gardening Mentor** replaces anxiety with structured, calm automation through three core loops:
1. **The Core Loop (Camera Diagnostic & Panic Triage)**:
   - *Workflow*: A user photographs plant distress. An edge pre-flight check validates lighting and leaf focus before transmitting to cloud multimodal AI.
   - *Calm Action Plan*: Rather than returning frightening pathological jargon, the app generates a structured 3-step triage card:
     - **What It Is**: Clear, plain-language identification of observable symptoms (e.g., natural lower leaf senescence, early powdery mildew, or heat transpiration wilt).
     - **Immediate Action**: Exactly one organic, non-toxic physical remedy that takes under 5 minutes (e.g., bottom pruning, neem spray, morning deep hydration).
     - **What NOT to Worry About**: Explicit reassurance that halts destructive panic-spraying and debunks worst-case fears.
2. **The Retention Loop (7-Day Bite-Sized Care Cadence)**:
   - *Workflow*: Decomposes ongoing garden maintenance into daily 5-to-10-minute micro-habits.
   - *Offline-First Resilience*: Full local caching enables gardeners to view instructions and check off chores outdoor in garden plots without cellular reception.
   - *Automated Weather Overrides*: Cloud functions intercept real-time weather forecasts to dynamically alter chore schedules:
     - *Precipitation Overrides*: If rainfall exceeds 0.50 inches, watering tasks are automatically deferred with an explanatory badge to prevent root rot.
     - *Thermal Defense*: Approaching freezes (≤34°F) or heat spikes (≥95°F) trigger immediate emergency chores (e.g., deploying row covers or morning shading).
3. **The Trust Loop (Grounded Mentor Chat)**:
   - *Workflow*: A dirt-side conversational interface backed by Firebase Vertex AI.
   - *Organic Safety Boundary*: Strict prompt filters reject synthetic organophosphates or commercial poisons, recommending only safe biological/physical solutions.
   - *Garden Digital Twin Injection*: The system automatically injects the user's microclimate (USDA Hardiness Zone), active crops, biological growth stages, and plot dimensions directly into context, eliminating repetitive setup explanations.

### 1.3 Market Positioning & Competitive Edge
- **Vs. Traditional 2D/Calendar Planners (GrowVeg, Seedtime, Planter)**: Competitors focus on static spacing grids and complex planting calendars. AI Gardening Mentor focuses on active daily execution, physical reassurance, and real-time triage.
- **Vs. Smart Hydroponic Towers (Gardyn, Click & Grow)**: Competitors require $500–$900 proprietary indoor plastic towers, recurring seed-pod subscriptions, and intensive indoor maintenance. AI Gardening Mentor works with real backyard soil, containers, and raised beds at zero hardware cost.

---

## 2. Design System: Google Material Design 3 (M3)

The website must be styled according to Google Material Design 3 guidelines, using an organic, botanical tonal palette derived from agricultural greens and earth tones.

### 2.1 M3 Dynamic Color Tokens (CSS Custom Properties)
Define the following token variables in `src/styles/m3-tokens.css` with comprehensive Light and Dark mode definitions:

```css
:root {
  /* Primary Tonal Palette (Botanical Emerald) */
  --md-sys-color-primary: #1e6b37;
  --md-sys-color-on-primary: #ffffff;
  --md-sys-color-primary-container: #a6f5b1;
  --md-sys-color-on-primary-container: #00210a;

  /* Secondary Tonal Palette (Sage / Foliage) */
  --md-sys-color-secondary: #526350;
  --md-sys-color-on-secondary: #ffffff;
  --md-sys-color-secondary-container: #d5e8cf;
  --md-sys-color-on-secondary-container: #101f10;

  /* Tertiary Tonal Palette (Warm Terracotta / Sunlight) */
  --md-sys-color-tertiary: #386568;
  --md-sys-color-on-tertiary: #ffffff;
  --md-sys-color-tertiary-container: #bcebee;
  --md-sys-color-on-tertiary-container: #002022;

  /* Surface & Container Tonal Hierarchy */
  --md-sys-color-surface: #f7fbf2;
  --md-sys-color-on-surface: #181d18;
  --md-sys-color-surface-variant: #dee5d9;
  --md-sys-color-on-surface-variant: #424940;
  --md-sys-color-surface-container-lowest: #ffffff;
  --md-sys-color-surface-container-low: #f1f5ec;
  --md-sys-color-surface-container: #ebf0e6;
  --md-sys-color-surface-container-high: #e6eae1;
  --md-sys-color-surface-container-highest: #e0e5db;
  --md-sys-color-outline: #72796f;
  --md-sys-color-outline-variant: #c2c9bd;

  /* Error & Panic Triage */
  --md-sys-color-error: #ba1a1a;
  --md-sys-color-on-error: #ffffff;
  --md-sys-color-error-container: #ffdad6;
  --md-sys-color-on-error-container: #410002;

  /* Elevation Shadows */
  --md-sys-elevation-level1: 0px 1px 3px 1px rgba(0, 0, 0, 0.15), 0px 1px 2px 0px rgba(0, 0, 0, 0.30);
  --md-sys-elevation-level2: 0px 2px 6px 2px rgba(0, 0, 0, 0.15), 0px 1px 2px 0px rgba(0, 0, 0, 0.30);
  --md-sys-elevation-level3: 0px 4px 8px 3px rgba(0, 0, 0, 0.15), 0px 1px 3px 0px rgba(0, 0, 0, 0.30);

  /* Shape Scale */
  --md-sys-shape-corner-extra-small: 4px;
  --md-sys-shape-corner-small: 8px;
  --md-sys-shape-corner-medium: 12px;
  --md-sys-shape-corner-large: 16px;
  --md-sys-shape-corner-extra-large: 28px;
  --md-sys-shape-corner-full: 9999px;

  /* State Layer Opacities */
  --md-sys-state-hover: 0.08;
  --md-sys-state-focus: 0.12;
  --md-sys-state-pressed: 0.12;
}

[data-theme="dark"] {
  --md-sys-color-primary: #8bd897;
  --md-sys-color-on-primary: #003915;
  --md-sys-color-primary-container: #005322;
  --md-sys-color-on-primary-container: #a6f5b1;

  --md-sys-color-secondary: #b9ccb4;
  --md-sys-color-on-secondary: #243424;
  --md-sys-color-secondary-container: #3a4b39;
  --md-sys-color-on-secondary-container: #d5e8cf;

  --md-sys-color-tertiary: #a0cfd2;
  --md-sys-color-on-tertiary: #003639;
  --md-sys-color-tertiary-container: #1e4d50;
  --md-sys-color-on-tertiary-container: #bcebee;

  --md-sys-color-surface: #101510;
  --md-sys-color-on-surface: #e0e5db;
  --md-sys-color-surface-variant: #424940;
  --md-sys-color-on-surface-variant: #c2c9bd;
  --md-sys-color-surface-container-lowest: #0b0f0b;
  --md-sys-color-surface-container-low: #181d18;
  --md-sys-color-surface-container: #1c211c;
  --md-sys-color-surface-container-high: #272c26;
  --md-sys-color-surface-container-highest: #323731;
  --md-sys-color-outline: #8c9388;
  --md-sys-color-outline-variant: #424940;

  --md-sys-color-error: #ffb4ab;
  --md-sys-color-on-error: #690005;
  --md-sys-color-error-container: #93000a;
  --md-sys-color-on-error-container: #ffdad6;
}
```

### 2.2 Typography Scale (M3 Type Guidelines)
Utilize modern system font stacks or Google Fonts (Roboto Flex / Inter):
- **Display Large / Headline Large**: `font-size: clamp(2.5rem, 5vw, 3.75rem); line-height: 1.15; font-weight: 700; letter-spacing: -0.02em;`
- **Headline Medium**: `font-size: 2rem; line-height: 1.25; font-weight: 600; letter-spacing: -0.01em;`
- **Title Large / Medium**: `font-size: 1.25rem - 1.5rem; line-height: 1.35; font-weight: 600;`
- **Body Large / Medium**: `font-size: 1rem - 1.125rem; line-height: 1.6; font-weight: 400; color: var(--md-sys-color-on-surface-variant);`
- **Label Large (Buttons & Chips)**: `font-size: 0.875rem; line-height: 1.25; font-weight: 500; letter-spacing: 0.1px;`

### 2.3 Component Archetypes
- **Top App Bar**: Sticky navigation with dynamic surface coloration on scroll and light/dark theme toggle.
- **Buttons**:
  - *Filled Button*: High-emphasis CTA (`background: var(--md-sys-color-primary); color: var(--md-sys-color-on-primary); border-radius: var(--md-sys-shape-corner-full);`).
  - *Tonal Button*: Medium-emphasis secondary action (`background: var(--md-sys-color-secondary-container); color: var(--md-sys-color-on-secondary-container);`).
  - *Outlined Button*: Clean bordered action (`border: 1px solid var(--md-sys-color-outline);`).
- **Cards**:
  - *Elevated Card*: Used for interactive demonstrations with `box-shadow: var(--md-sys-elevation-level1);` and rounded 16px corners.
  - *Surface Container Cards*: Layered structural groupings without heavy borders.
- **M3 Chips**: Rounded pill elements used for tags (`USDA Zone 7b`, `Roma Tomato`, `Offline-Ready`).

---

## 3. Project File Tree & Component Architecture

Generate the complete files according to this production Astro project structure:

```text
src/
├── styles/
│   └── m3-tokens.css              # Complete M3 CSS custom properties and resets
├── layouts/
│   └── BaseLayout.astro           # HTML shell, SEO metadata, theme detection, fonts
├── components/
│   ├── TopAppBar.astro            # Sticky M3 App Bar with theme toggle & mobile drawer
│   ├── HeroSection.astro          # Headline, primary CTAs, trust badges & interactive preview
│   ├── PanicTriageDemo.astro      # Client island: Interactive plant issue scanner & 3-Step Plan
│   ├── ProblemContrast.astro      # Side-by-side contrast: Novice Spiral vs. Mentor Routine
│   ├── CoreLoopsBento.astro       # Bento grid detailing Camera Triage, 7-Day Care & Mentor Chat
│   ├── WeatherOverrideSim.astro   # Client island: Interactive rain & frost override simulator
│   ├── GroundedChatPreview.astro  # Interactive preview of plot context injection
│   ├── ComparisonTable.astro      # Comparative matrix vs. spreadsheets and hydroponic hardware
│   ├── TrustOrganicGuarantee.astro# University Extension organic standard & safety boundaries
│   ├── CallToAction.astro         # High-conversion download card with app store badges
│   └── Footer.astro               # M3 structured footer with legal and documentation links
└── pages/
    └── index.astro                # Composed landing page importing all components
```

---

## 4. Detailed Component & Section Specifications

### 4.1 `TopAppBar.astro`
- Fixed top navigation with smooth scroll-elevation transitions.
- Left: Botanical seedling SVG logo paired with "AI Gardening Mentor".
- Center/Right Navigation links: "Camera Triage", "7-Day Cadence", "Organic Mentor", "Compare".
- Right Actions: Theme Toggle Switch (persists `data-theme` in `localStorage`) and an M3 Filled Button: "Download App".

### 4.2 `HeroSection.astro`
- **Overline Chip**: `🌱 Built for Real Garden Beds & Dirt • University Extension Science`.
- **Headline**: "Stop Guessing. Stop Panicking. Grow Vegetables with Confidence."
- **Body**: "The first intelligent gardening mentor built specifically to eliminate novice anxiety. Get instant 3-step calm triage from a quick photo, follow 5-minute daily micro-habits that adapt to the weather, and chat with an organic mentor that already knows your plot."
- **CTAs**: Filled Button "Start Growing Free" and Outlined Button with camera icon: "Test Live Triage".
- **Visual Artifact**: An interactive mock card displaying an active plant triage scenario (Tomato Heat Wilt vs. Blight).

### 4.3 `PanicTriageDemo.astro` (Interactive Astro Island)
- Interactive tab or button selector offering 3 typical novice scenarios:
  1. *Scenario A: Yellowing Lower Leaves on Roma Tomato*
  2. *Scenario B: White Powdery Spots on Squash Leaf*
  3. *Scenario C: Mid-Day Drooping on Bell Pepper*
- Selecting a scenario instantly renders the authentic **3-Step Calm Action Plan**:
  - **What It Is**: Diagnoses the exact condition in simple terms (e.g., natural leaf senescence, powdery mildew, heat transpiration wilt).
  - **Immediate Action**: A single organic step taking ≤ 5 minutes (e.g., clip lower 2 inches with clean shears; spray baking soda & organic soap solution; deep morning root soak).
  - **What NOT to Worry About**: Clear, anxiety-reducing reassurance (e.g., "This is NOT early blight. Your fruit cluster is completely safe. Do NOT apply copper fungicide.").

### 4.4 `ProblemContrast.astro`
A high-impact side-by-side comparative layout:
- **Left (The Novice Spiral)**: Red-tinted surface container card.
  - ❌ Panic-spraying harsh chemicals over harmless leaf imperfections.
  - ❌ Abandoning the garden due to 40-page spreadsheets and chore fatigue.
  - ❌ Sifting through conflicting forum arguments while plants wilt.
- **Right (The AI Gardening Mentor Routine)**: Green-tinted primary container card.
  - ✅ Rapid visual triage that halts panic and restores confidence in 3 seconds.
  - ✅ 5-minute micro-habits that fit seamlessly into busy daily routines.
  - ✅ Authoritative advice grounded 100% in peer-reviewed organic agricultural science.

### 4.5 `CoreLoopsBento.astro`
A modern M3 Bento Grid illustrating the three foundational loops:
1. **Loop 1: Camera Diagnostic & Panic Triage (Span 2 Cols)**
   - Highlights on-device leaf/soil focus validation and multimodal cloud evaluation.
2. **Loop 2: 7-Day Bite-Sized Care Cadence (Span 1 Col)**
   - Highlights offline-first task completion and daily habit formation in under 10 minutes.
3. **Loop 3: Grounded Mentor Chat (Span 3 Cols)**
   - Highlights automated plot digital twin context injection (USDA Hardiness Zone, crop age, and bed dimensions).

### 4.6 `WeatherOverrideSim.astro` (Interactive Astro Island)
An interactive simulation widget showcasing dynamic task adjustments:
- State toggles: `☀️ Sunny & Normal`, `🌧️ Heavy Rain (>0.50")`, `❄️ Freeze Warning (32°F)`.
- Live Task Card updates dynamically:
  - *Sunny*: Shows daily watering task (5 min).
  - *Rain*: Automatically tags task as `DEFERRED (WEATHER)` with note: *0.75" rainfall detected. Soil saturation verified. Watering paused to protect root health.*
  - *Freeze*: Injects an urgent 5-minute task: *Insert frost cloth or buckets over tender crops before 6:00 PM.*

### 4.7 `ComparisonTable.astro`
A structured comparison table highlighting key advantages over both software planners and hardware hydroponics:

| Feature / Dimension | AI Gardening Mentor | 2D Planners & Spreadsheets (GrowVeg / Planter) | Smart Hydroponic Towers (Gardyn / Click & Grow) |
| :--- | :--- | :--- | :--- |
| **Instant Camera Panic Triage** | **Included (3-Step Calm Action Plan)** | ❌ None (Manual identification) | ❌ Hardware sensors only |
| **Daily Habit Sizing** | **5–10 Minute Micro-Tasks** | ❌ Complex multi-month calendars | ⚠️ Heavy weekly reservoir maintenance |
| **Dynamic Weather Overrides** | **Automatic (Rain & Freeze Interception)** | ❌ Static dates only | ❌ Indoor only (ignores weather) |
| **Outdoor Offline Capability** | **100% Offline-First Local Cache** | ⚠️ Spotty mobile web/app sync | ❌ Requires constant 2.4GHz Wi-Fi |
| **Initial Hardware Investment** | **$0 (Works with existing dirt & pots)** | $25 – $50 / year | $500 – $900 hardware purchase |
| **Organic Horticultural Rigor** | **Strict University Extension Standard** | Generic plant encyclopedias | Proprietary nutrient subscriptions |

### 4.8 `TrustOrganicGuarantee.astro`
- Details the **Horticultural Safety Boundary**: The AI model is strictly prohibited from suggesting synthetic chemical pesticides, commercial neurotoxins, or unverified home concoctions.
- Emphasizes that all guidance aligns with organic University Agricultural Extension research.

### 4.9 `CallToAction.astro` & `Footer.astro`
- Prominent M3 Surface-Container-High card inviting users to start their garden with 5-minute daily micro-habits.
- Includes App Store / Google Play download badges and an email onboarding form.
- Footer with M3 navigation structure, accessibility compliance statement, and legal disclaimers.

---

## 5. Required Code Output Format

Generate each file completely inside its own markdown code block, specifying its file path at the top:
1. `src/styles/m3-tokens.css`
2. `src/layouts/BaseLayout.astro`
3. `src/components/TopAppBar.astro`
4. `src/components/HeroSection.astro`
5. `src/components/PanicTriageDemo.astro`
6. `src/components/ProblemContrast.astro`
7. `src/components/CoreLoopsBento.astro`
8. `src/components/WeatherOverrideSim.astro`
9. `src/components/ComparisonTable.astro`
10. `src/components/TrustOrganicGuarantee.astro`
11. `src/components/CallToAction.astro`
12. `src/components/Footer.astro`
13. `src/pages/index.astro`

Ensure the code executes flawlessly with zero external npm dependencies beyond standard Astro, using native vanilla JavaScript inside component `<script>` tags for interactive islands.
```

***

## Architectural Delivery Blueprint

When submitted to an LLM, this master prompt enforces an end-to-end design and technical delivery matching the following system matrix:

| Architectural Tier | Design / Tech Specification | Behavioral Purpose |
| :--- | :--- | :--- |
| **Component Model** | Astro 4+ Islands (`client:visible`) | Guarantees instant page loads, sub-second LCP, and zero JavaScript bloat for static copy. |
| **Styling Tokens** | Google Material Design 3 CSS Custom Properties | Enforces botanical emerald tonal palettes, dynamic dark mode, and standard M3 elevation and surface scales. |
| **Core Diagnostic** | 3-Step Calm Action Plan UI | Directly solves the primary novice failure mode by turning alarming leaf symptoms into rapid reassurance. |
| **Care Cadence** | Weather Override Simulation Island | Proves the retention value proposition by demonstrating automated chore deferrals for rain and freeze alerts. |
| **Market Differentiation** | High-Density Comparison Matrix | Positions the product clearly against rigid 2D grid plotters and expensive $800+ indoor hydroponic hardware. |
