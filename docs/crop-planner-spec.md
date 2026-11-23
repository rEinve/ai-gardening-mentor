# Proactive Crop Planner & Waterfall Management Specification

Derived from the farmer's operational workbook ([Crop planting log.xlsx](Crop%20planting%20log.xlsx)) and integrated into the AI Gardening Mentor (Tanzania MVP).

## 1. Core Purpose: Proactive Farming (Before Disaster Strikes)

Instead of reacting only when pests or nutrient deficiency appear, the Crop Planner gives every grower a **waterfall project-management timeline** from Day 0 to Harvest:
- Know **exact expected transplant date** (if starting from seed) and **exact expected harvest date** (whether from seed, bought seedlings, or direct seeding).
- See **days remaining** to transplant and to harvest so the grower can check market prices, line up buyers, or decide whether to grow vs. buy for household consumption *before* the crop matures.
- Receive **proactive prepare-ahead alerts** (10–14 days in advance) for upcoming inputs — e.g. DAP at planting, Urea/CAN top-dressing, NPK at flowering, foliar spray, or trellising/staking — with both **Conventional** and **Organic** options and per-plant rates.
- Plan **succession planting** (sequential batches every 21 days or custom interval) for continuous harvest without gaps, with the ability to shift/skip a batch date and cascade subsequent plantings.
- Display **conservative estimated yield ranges** based on plant count or trays so growers avoid overestimating harvests.

---

## 2. Workbook Formulas Ported (`docs/Crop planting log.xlsx`)

| Sheet | Formula / Rule | App Implementation |
| :--- | :--- | :--- |
| `Succ. Planting Plan` | `Batch[n].plantDate = Batch[n-1].plantDate + intervalDays` (editable per batch) | `generateSuccessionPlan()` — supports custom interval (default 21 days) and manual override on any batch with optional cascade. |
| `Exp.Transplanting` | `expectedTransplantDate = sowingDate + nurseryDays` | Computed for `seed_nursery` mode; `daysToTransplant = expectedTransplantDate - today`. |
| `Exp. Harvest` | `fieldMaturityDays = totalMaturityDays - nurseryDays` | For `bought_seedlings`, `expectedHarvestDate = transplantDate + fieldMaturityDays`. For `direct_seed` (`nurseryDays = 0`), `expectedHarvestDate = sowingDate + totalMaturityDays`. |
| `Exp. Harvest` | `remainingDays = expectedHarvestDate - today` | Live countdown badge on every batch card; logs `actualHarvestDate` for predicted-vs-actual variance. |

---

## 3. Three Entry Paths (Matching Real Tanzania Practice)

1. **Bought Seedlings (`bought_seedlings`)**: Many growers buy seedlings from nursery vendors. User enters **Transplant Date** → app skips nursery phase, starts waterfall at Day 0 (Transplant Day), and calculates `expectedHarvestDate = transplantDate + (totalMaturityDays - nurseryDays)`.
2. **Start From Seed (`seed_nursery`)**: User enters **Sowing Date** → app calculates `expectedTransplantDate = sowingDate + nurseryDays`, shows nursery & pre-transplant prep milestones, then flows into transplanting, vegetative, flowering/fruiting, and harvest.
3. **Direct Seeding (`direct_seed`)**: For crops sown directly in soil (e.g. Okra, Maize, Amaranth, Cucumber). `nurseryDays = 0`; `expectedHarvestDate = sowingDate + totalMaturityDays`.

---

## 4. Waterfall Phases & Proactive Input Schedule

Every crop batch generates a chronological waterfall of phases:
1. **Nursery** *(only for `seed_nursery`)*: Tray/seedbed sowing, moisture care, hardening off 5–7 days before transplant.
2. **Pre-Transplant / Bed Prep**: Land prep, spacing, basal organic manure incorporation (7 days before planting/transplant).
3. **Planting / Transplant Day (Day 0)**: Basal phosphorus application (**DAP ~5g/plant** or **1–2 handfuls well-rotted compost/manure per hole**), root-zone watering.
4. **Vegetative Growth (Days 14–21 post-transplant)**: First Nitrogen top-dressing (**Urea or CAN ~5g/plant** in a ring 5–8 cm from stem, OR **liquid manure/compost tea**), weeding, staking/trellising for Tomato & Cucumber.
5. **Flowering & Fruit Set (Days 28–42 post-transplant)**: Balanced/Potassium feed (**NPK 17:17:17 or 20:10:10 ~10g/plant** OR **compost + wood ash side-dress**), preventive **foliar feed (Calcium-Boron)** for blossom-end rot prevention on Tomato/Pepper, lower-leaf airflow pruning.
6. **Harvest Window**: Harvest countdown, market/buyer readiness check (14 days before maturity), and actual harvest date logging.

> **Agronomic Review Notice (`prototype_fixture`)**: All default maturity days, dosage rates, and yield ranges are marked `prototype_fixture` until signed off by a Tanzanian extension agronomist before public pilot launch.

---

## 5. AI Mentor Integration

Active crop batches, days remaining to harvest, and upcoming 14-day input preparation alerts are injected into the **AI Mentor** garden context snapshot so the mentor answers proactively using the farmer's actual planting calendar.
