/**
 * Proactive Crop Planner & Waterfall Management Engine (Tanzania MVP)
 *
 * Ports the farmer's Excel workbook formulas (`docs/Crop planting log.xlsx`):
 * - `Succ. Planting Plan`: Succession batches spaced by intervalDays with override + cascade.
 * - `Exp.Transplanting`: expectedTransplantDate = sowingDate + nurseryDays; daysToTransplant.
 * - `Exp. Harvest`: fieldMaturityDays = totalMaturityDays - nurseryDays; expectedHarvestDate; remainingDays.
 * - Waterfall Management: Chronological nursery -> bed prep -> transplant -> vegetative -> flowering -> harvest
 *   milestones with 14-day prepare-ahead alerts and both Conventional (DAP/Urea/NPK/Foliar) & Organic options.
 *
 * IMPORTANT: Crop maturity defaults, yield ranges, and fertilizer guidance are marked
 * `reviewStatus: 'prototype_fixture'` until Tanzanian agronomic extension sign-off.
 */

import type { ReviewStatus } from '../types/schema.ts';

export type BatchStartMode = 'seed_nursery' | 'bought_seedlings' | 'direct_seed';
export type InputPreference = 'both' | 'conventional' | 'organic';

export type WaterfallPhase =
  | 'nursery'
  | 'pre_transplant'
  | 'planting_day'
  | 'vegetative'
  | 'flowering_fruiting'
  | 'harvest';

export interface WaterfallMilestoneBlueprint {
  id: string;
  phase: WaterfallPhase;
  /** Offset in days from the field anchor (transplant date, or direct-seed date). Negative = before transplant. */
  dayOffsetFromFieldStart: number;
  /** Only included when startMode === 'seed_nursery' */
  nurseryOnly?: boolean;
  title: string;
  summary: string;
  conventionalInput: string | null;
  organicInput: string | null;
  prepLeadDays: number;
  prepReminder: string | null;
}

export interface CropPlannerProfile {
  profileId: string;
  commonName: string;
  localNameSw: string;
  totalMaturityDays: number;
  nurseryDays: number;
  defaultSuccessionIntervalDays: number;
  defaultStartMode: BatchStartMode;
  yieldUnit: 'kg' | 'bundles';
  conservativeYieldPerPlantMin: number;
  conservativeYieldPerPlantMax: number;
  reviewStatus: ReviewStatus;
  milestones: WaterfallMilestoneBlueprint[];
}

export interface CropBatchInput {
  batchId: string;
  cropProfileId: string;
  startMode: BatchStartMode;
  /** YYYY-MM-DD: sowing date if seed_nursery/direct_seed, or transplant date if bought_seedlings */
  anchorDate: string;
  plantCount: number;
  traysCount?: number | null;
  nurseryDaysOverride?: number | null;
  totalMaturityDaysOverride?: number | null;
  actualHarvestDate?: string | null;
  inputPreference?: InputPreference;
  successionGroupId?: string | null;
  successionIndex?: number | null;
}

export interface ScheduledMilestone {
  id: string;
  phase: WaterfallPhase;
  title: string;
  summary: string;
  scheduledDate: string; // YYYY-MM-DD
  daysFromToday: number;
  isPrepareAheadAlert: boolean;
  conventionalInput: string | null;
  organicInput: string | null;
  prepReminder: string | null;
}

export interface CropBatchSchedule {
  batchId: string;
  cropProfileId: string;
  commonName: string;
  localNameSw: string;
  startMode: BatchStartMode;
  sowingDate: string | null;
  expectedTransplantDate: string | null;
  daysToTransplant: number | null;
  fieldMaturityDays: number;
  totalMaturityDays: number;
  expectedHarvestDate: string;
  daysToHarvest: number;
  actualHarvestDate: string | null;
  harvestVarianceDays: number | null;
  plantCount: number;
  traysCount: number | null;
  estimatedYieldMin: number;
  estimatedYieldMax: number;
  yieldUnit: 'kg' | 'bundles';
  milestones: ScheduledMilestone[];
  upcomingPrepAlerts: ScheduledMilestone[];
  reviewStatus: ReviewStatus;
}

function parseIsoDate(isoDate: string): Date {
  const parts = isoDate.split('-').map(Number);
  const y = parts[0] ?? 1970;
  const m = parts[1] ?? 1;
  const d = parts[2] ?? 1;
  return new Date(Date.UTC(y, m - 1, d));
}

export function addDaysIso(isoDate: string, days: number): string {
  const dt = parseIsoDate(isoDate);
  dt.setUTCDate(dt.getUTCDate() + days);
  const y = String(dt.getUTCFullYear()).padStart(4, '0');
  const m = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const d = String(dt.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function diffDaysIso(targetIso: string, baseIso: string): number {
  const msPerDay = 86_400_000;
  return Math.round((parseIsoDate(targetIso).getTime() - parseIsoDate(baseIso).getTime()) / msPerDay);
}

const FRUITING_SOLANACEAE_MILESTONES: WaterfallMilestoneBlueprint[] = [
  {
    id: 'nursery_sow',
    phase: 'nursery',
    dayOffsetFromFieldStart: -28,
    nurseryOnly: true,
    title: 'Sow seeds in nursery trays',
    summary: 'Fill seedling trays with moist sterile cocopeat/compost mix and sow 1–2 seeds per cell.',
    conventionalInput: 'Starter seedling mix + light misting',
    organicInput: 'Sieved compost + fine sand (2:1) nursery mix',
    prepLeadDays: 7,
    prepReminder: 'Prepare seedling trays, shade net, and clean nursery media.',
  },
  {
    id: 'nursery_harden',
    phase: 'nursery',
    dayOffsetFromFieldStart: -7,
    nurseryOnly: true,
    title: 'Harden off seedlings & prep field beds',
    summary: 'Gradually increase sunlight exposure on trays and dig planting holes in the field bed.',
    conventionalInput: 'Prepare basal DAP (5g/plant) for transplant day',
    organicInput: 'Incorporate 1–2 handfuls well-rotted manure per planting hole',
    prepLeadDays: 7,
    prepReminder: 'Organize basal fertilizer (DAP or well-rotted manure) before transplanting.',
  },
  {
    id: 'transplant_basal',
    phase: 'planting_day',
    dayOffsetFromFieldStart: 0,
    title: 'Transplant & basal phosphorus feed',
    summary: 'Transplant in late afternoon, apply basal feed mixed with soil (never touching bare roots), and water deeply.',
    conventionalInput: 'DAP (18-46-0): ~5g (1 level teaspoon) per plant mixed in hole',
    organicInput: 'Well-rotted compost/manure: 1–2 handfuls per hole + bone meal/rock phosphate',
    prepLeadDays: 10,
    prepReminder: 'Have DAP (5g/plant) or cured compost ready for transplant day.',
  },
  {
    id: 'veg_topdress_1',
    phase: 'vegetative',
    dayOffsetFromFieldStart: 14,
    title: 'Vegetative top-dressing & staking prep',
    summary: 'Apply Nitrogen boost around root zone (5–8 cm from stem) after watering; prepare stakes/trellis.',
    conventionalInput: 'CAN or Urea: ~5g per plant in a ring, then water in',
    organicInput: 'Liquid manure / compost tea drench (500 ml/plant) + mulch ring',
    prepLeadDays: 14,
    prepReminder: 'Source CAN/Urea (or start brewing compost tea) and gather stakes ahead of Day 14.',
  },
  {
    id: 'flowering_npk_foliar',
    phase: 'flowering_fruiting',
    dayOffsetFromFieldStart: 28,
    title: 'Flowering NPK boost & Calcium-Boron foliar',
    summary: 'Support flower retention and fruit set; prune lower yellowed leaves touching soil.',
    conventionalInput: 'NPK 17:17:17 (~10g/plant) + Calcium-Boron foliar spray early morning',
    organicInput: 'Compost side-dress + wood ash (1 tbsp/plant) + kelp/molasses foliar mist',
    prepLeadDays: 14,
    prepReminder: 'Prepare NPK 17:17:17 & Calcium-Boron foliar (or compost + wood ash) for flowering.',
  },
  {
    id: 'harvest_market_check',
    phase: 'harvest',
    dayOffsetFromFieldStart: 40,
    title: 'Pre-harvest market & buyer readiness check',
    summary: 'Check local market prices, confirm buyers or household storage, and stop any restricted sprays.',
    conventionalInput: 'Observe pre-harvest interval (PHI); water consistently to prevent fruit cracking',
    organicInput: 'Consistent root-zone watering + clean harvest crates ready',
    prepLeadDays: 7,
    prepReminder: 'Check market demand and prepare harvest crates/baskets.',
  },
];

const CUCURBIT_MILESTONES: WaterfallMilestoneBlueprint[] = [
  {
    id: 'nursery_sow',
    phase: 'nursery',
    dayOffsetFromFieldStart: -14,
    nurseryOnly: true,
    title: 'Sow cucumber seeds in trays',
    summary: 'Sow 1 seed per cell; keep warm and moist for 10–14 days before gentle transplanting.',
    conventionalInput: 'Clean seedling tray media',
    organicInput: 'Sieved compost + sand nursery mix',
    prepLeadDays: 5,
    prepReminder: 'Prepare seedling trays and trellis poles early.',
  },
  {
    id: 'planting_basal',
    phase: 'planting_day',
    dayOffsetFromFieldStart: 0,
    title: 'Planting / Transplant & basal feed',
    summary: 'Plant without disturbing roots; mix basal phosphorus into soil and water gently.',
    conventionalInput: 'DAP: ~5g per plant mixed with soil below roots',
    organicInput: 'Well-rotted manure/compost: 2 handfuls per planting station',
    prepLeadDays: 10,
    prepReminder: 'Have DAP or cured manure ready for planting day.',
  },
  {
    id: 'veg_trellis_topdress',
    phase: 'vegetative',
    dayOffsetFromFieldStart: 14,
    title: 'Trellis training & Nitrogen top-dress',
    summary: 'Guide vines onto trellis strings and apply first top-dressing for strong vine vigor.',
    conventionalInput: 'CAN or Urea: ~5g per plant, watered in immediately',
    organicInput: 'Compost tea drench (500 ml/plant) + straw mulch',
    prepLeadDays: 12,
    prepReminder: 'Prepare trellis poles/twine and CAN/Urea or compost tea.',
  },
  {
    id: 'flowering_k_boost',
    phase: 'flowering_fruiting',
    dayOffsetFromFieldStart: 25,
    title: 'Flowering NPK & pollination check',
    summary: 'Boost potassium for crisp fruit development; avoid spraying during morning bee activity.',
    conventionalInput: 'NPK 17:17:17 (~10g/plant) + foliar micronutrient spray late afternoon',
    organicInput: 'Compost side-dress + wood ash + clean water misting if aphids appear',
    prepLeadDays: 10,
    prepReminder: 'Organize NPK or potassium-rich organic side-dress before flowering.',
  },
];

const LEAFY_MILESTONES: WaterfallMilestoneBlueprint[] = [
  {
    id: 'planting_basal',
    phase: 'planting_day',
    dayOffsetFromFieldStart: 0,
    title: 'Bed preparation & planting',
    summary: 'Loosen topsoil 15–20 cm deep, incorporate basal nutrients, and plant/sow evenly.',
    conventionalInput: 'DAP or NPK 17:17:17 lightly worked into bed (~3g/plant)',
    organicInput: 'Well-rotted compost/manure (2 kg/m²) mixed into topsoil',
    prepLeadDays: 7,
    prepReminder: 'Prepare fine seedbed and basal compost/fertilizer.',
  },
  {
    id: 'veg_nitrogen',
    phase: 'vegetative',
    dayOffsetFromFieldStart: 12,
    title: 'Leafy Nitrogen top-dressing',
    summary: 'Boost tender green leaf growth; keep soil evenly moist in morning hours.',
    conventionalInput: 'CAN or Urea: ~3–5g per plant (or light band along rows), water in well',
    organicInput: 'Diluted liquid manure tea (1:5 with water) at root zone',
    prepLeadDays: 10,
    prepReminder: 'Prepare CAN/Urea or liquid manure tea for Day 12 leaf boost.',
  },
];

/**
 * Crop planner profiles grounded in `docs/Crop planting log.xlsx` (Succ. Planting Plan,
 * Exp.Transplanting, Exp. Harvest) + Tanzania starter crops.
 */
export const TANZANIA_PLANNER_PROFILES: CropPlannerProfile[] = [
  {
    profileId: 'tz_tomato',
    commonName: 'Tomato',
    localNameSw: 'Nyanya',
    totalMaturityDays: 75, // Excel: 75 days total (28 nursery + 47 field)
    nurseryDays: 28,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'bought_seedlings',
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 2.0,
    conservativeYieldPerPlantMax: 3.5,
    reviewStatus: 'prototype_fixture',
    milestones: FRUITING_SOLANACEAE_MILESTONES,
  },
  {
    profileId: 'tz_cucumber',
    commonName: 'Cucumber',
    localNameSw: 'Tango',
    totalMaturityDays: 57, // Excel: 14 nursery + 43 field
    nurseryDays: 14,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'seed_nursery',
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 1.5,
    conservativeYieldPerPlantMax: 3.0,
    reviewStatus: 'prototype_fixture',
    milestones: CUCURBIT_MILESTONES,
  },
  {
    profileId: 'tz_pepper',
    commonName: 'Bell Pepper / Pilipili',
    localNameSw: 'Pilipili Hoho',
    totalMaturityDays: 68, // Excel: 68 days total (28 nursery + 40 field)
    nurseryDays: 28,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'bought_seedlings',
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 1.0,
    conservativeYieldPerPlantMax: 2.0,
    reviewStatus: 'prototype_fixture',
    milestones: FRUITING_SOLANACEAE_MILESTONES,
  },
  {
    profileId: 'tz_african_eggplant',
    commonName: 'African Eggplant',
    localNameSw: 'Ngogwe / Bilinganya',
    totalMaturityDays: 70, // Excel: 70 days
    nurseryDays: 28,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'bought_seedlings',
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 1.5,
    conservativeYieldPerPlantMax: 2.8,
    reviewStatus: 'prototype_fixture',
    milestones: FRUITING_SOLANACEAE_MILESTONES,
  },
  {
    profileId: 'tz_okra',
    commonName: 'Okra',
    localNameSw: 'Bamia',
    totalMaturityDays: 55, // Excel: 55 days (direct seed)
    nurseryDays: 0,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'direct_seed',
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 0.4,
    conservativeYieldPerPlantMax: 0.8,
    reviewStatus: 'prototype_fixture',
    milestones: CUCURBIT_MILESTONES.filter((m) => !m.nurseryOnly),
  },
  {
    profileId: 'tz_sukuma_wiki',
    commonName: 'Sukuma Wiki / Kale',
    localNameSw: 'Sukumawiki',
    totalMaturityDays: 60, // Excel: Kale/Collard 60 days (21 nursery + 39 field)
    nurseryDays: 21,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'bought_seedlings',
    yieldUnit: 'bundles',
    conservativeYieldPerPlantMin: 2.0,
    conservativeYieldPerPlantMax: 4.0,
    reviewStatus: 'prototype_fixture',
    milestones: LEAFY_MILESTONES,
  },
  {
    profileId: 'tz_amaranth',
    commonName: 'Amaranth',
    localNameSw: 'Mchicha',
    totalMaturityDays: 28, // Fast leafy cycle
    nurseryDays: 0,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'direct_seed',
    yieldUnit: 'bundles',
    conservativeYieldPerPlantMin: 0.25,
    conservativeYieldPerPlantMax: 0.5,
    reviewStatus: 'prototype_fixture',
    milestones: LEAFY_MILESTONES,
  },
  {
    profileId: 'tz_african_nightshade',
    commonName: 'African Nightshade',
    localNameSw: 'Mnavu',
    totalMaturityDays: 42,
    nurseryDays: 14,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: 'direct_seed',
    yieldUnit: 'bundles',
    conservativeYieldPerPlantMin: 1.0,
    conservativeYieldPerPlantMax: 2.0,
    reviewStatus: 'prototype_fixture',
    milestones: LEAFY_MILESTONES,
  },
  {
    profileId: 'tz_squash',
    commonName: 'Squash / Pumpkin',
    localNameSw: 'Boga',
    totalMaturityDays: 85,
    nurseryDays: 0,
    defaultSuccessionIntervalDays: 28,
    defaultStartMode: 'direct_seed',
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 3.0,
    conservativeYieldPerPlantMax: 6.0,
    reviewStatus: 'prototype_fixture',
    milestones: CUCURBIT_MILESTONES.filter((m) => !m.nurseryOnly),
  },
];

export function getPlannerProfile(profileId: string): CropPlannerProfile | undefined {
  return TANZANIA_PLANNER_PROFILES.find((p) => p.profileId === profileId);
}

/**
 * Calculates the full proactive waterfall schedule for a single crop batch.
 * Strictly follows `docs/Crop planting log.xlsx` date math.
 */
export function calculateCropBatchSchedule(
  input: CropBatchInput,
  todayIso: string,
): CropBatchSchedule {
  const profile = getPlannerProfile(input.cropProfileId);
  if (!profile) {
    throw new Error(`Unsupported cropProfileId for planner: ${input.cropProfileId}`);
  }

  const totalMaturityDays = input.totalMaturityDaysOverride ?? profile.totalMaturityDays;
  const effectiveNurseryDays =
    input.startMode === 'direct_seed'
      ? 0
      : (input.nurseryDaysOverride ?? profile.nurseryDays);

  // Field maturity days after transplanting (matches Excel: `='Succ. Planting Plan'!B3 - Exp.Transplanting!B3`)
  const fieldMaturityDays = Math.max(7, totalMaturityDays - effectiveNurseryDays);

  let sowingDate: string | null = null;
  let expectedTransplantDate: string | null = null;
  let fieldAnchorDate: string;

  if (input.startMode === 'seed_nursery') {
    sowingDate = input.anchorDate;
    expectedTransplantDate = addDaysIso(input.anchorDate, effectiveNurseryDays);
    fieldAnchorDate = expectedTransplantDate;
  } else if (input.startMode === 'bought_seedlings') {
    sowingDate = null;
    expectedTransplantDate = input.anchorDate;
    fieldAnchorDate = input.anchorDate;
  } else {
    // direct_seed
    sowingDate = input.anchorDate;
    expectedTransplantDate = null;
    fieldAnchorDate = input.anchorDate;
  }

  const expectedHarvestDate = addDaysIso(fieldAnchorDate, fieldMaturityDays);
  const daysToTransplant =
    input.startMode === 'seed_nursery' && expectedTransplantDate
      ? diffDaysIso(expectedTransplantDate, todayIso)
      : null;
  const daysToHarvest = diffDaysIso(expectedHarvestDate, todayIso);

  const actualHarvestDate = input.actualHarvestDate ?? null;
  const harvestVarianceDays = actualHarvestDate
    ? diffDaysIso(actualHarvestDate, expectedHarvestDate)
    : null;

  const plantCount = Math.max(1, Math.round(input.plantCount));
  const estimatedYieldMin = Number((plantCount * profile.conservativeYieldPerPlantMin).toFixed(1));
  const estimatedYieldMax = Number((plantCount * profile.conservativeYieldPerPlantMax).toFixed(1));

  const milestones: ScheduledMilestone[] = [];
  for (const bp of profile.milestones) {
    if (bp.nurseryOnly && input.startMode !== 'seed_nursery') {
      continue;
    }
    const scheduledDate = addDaysIso(fieldAnchorDate, bp.dayOffsetFromFieldStart);
    const daysFromToday = diffDaysIso(scheduledDate, todayIso);
    const isPrepareAheadAlert = daysFromToday > 0 && daysFromToday <= bp.prepLeadDays;

    milestones.push({
      id: `${input.batchId}_${bp.id}`,
      phase: bp.phase,
      title: bp.title,
      summary: bp.summary,
      scheduledDate,
      daysFromToday,
      isPrepareAheadAlert,
      conventionalInput: bp.conventionalInput,
      organicInput: bp.organicInput,
      prepReminder: bp.prepReminder,
    });
  }

  // Always append the Expected Harvest milestone at the end of the waterfall
  const harvestDaysFromToday = diffDaysIso(expectedHarvestDate, todayIso);
  milestones.push({
    id: `${input.batchId}_expected_harvest`,
    phase: 'harvest',
    title: `Expected Harvest Window (${profile.commonName})`,
    summary: `Conservative est. yield: ${estimatedYieldMin}–${estimatedYieldMax} ${profile.yieldUnit} from ${plantCount} plants. Log actual harvest date to improve future predictions.`,
    scheduledDate: expectedHarvestDate,
    daysFromToday: harvestDaysFromToday,
    isPrepareAheadAlert: harvestDaysFromToday > 0 && harvestDaysFromToday <= 14,
    conventionalInput: null,
    organicInput: null,
    prepReminder: 'Confirm market/buyers or household plan before harvest window opens.',
  });

  milestones.sort((a, b) => a.scheduledDate.localeCompare(b.scheduledDate));
  const upcomingPrepAlerts = milestones.filter((m) => m.isPrepareAheadAlert);

  return {
    batchId: input.batchId,
    cropProfileId: profile.profileId,
    commonName: profile.commonName,
    localNameSw: profile.localNameSw,
    startMode: input.startMode,
    sowingDate,
    expectedTransplantDate,
    daysToTransplant,
    fieldMaturityDays,
    totalMaturityDays,
    expectedHarvestDate,
    daysToHarvest,
    actualHarvestDate,
    harvestVarianceDays,
    plantCount,
    traysCount: input.traysCount ?? null,
    estimatedYieldMin,
    estimatedYieldMax,
    yieldUnit: profile.yieldUnit,
    milestones,
    upcomingPrepAlerts,
    reviewStatus: profile.reviewStatus,
  };
}

/**
 * Generates N sequential succession batches (matches `Succ. Planting Plan` sheet).
 * Supports per-index manual overrides (`manualOverrides[batchIndex] = 'YYYY-MM-DD'`)
 * where subsequent batches automatically cascade from the overridden date.
 */
export function generateSuccessionPlan(params: {
  groupId: string;
  cropProfileId: string;
  startMode: BatchStartMode;
  firstAnchorDate: string;
  intervalDays: number;
  batchCount: number;
  plantCountPerBatch: number;
  traysPerBatch?: number | null;
  todayIso: string;
  manualOverrides?: Record<number, string>;
}): CropBatchSchedule[] {
  const safeCount = Math.max(1, Math.min(12, Math.round(params.batchCount)));
  const safeInterval = Math.max(7, Math.round(params.intervalDays));
  const schedules: CropBatchSchedule[] = [];

  let currentAnchor = params.firstAnchorDate;
  for (let i = 0; i < safeCount; i++) {
    if (i > 0) {
      currentAnchor = addDaysIso(currentAnchor, safeInterval);
    }
    const overrideDate = params.manualOverrides?.[i];
    if (overrideDate) {
      currentAnchor = overrideDate;
    }
    const schedule = calculateCropBatchSchedule(
      {
        batchId: `${params.groupId}_b${i + 1}`,
        cropProfileId: params.cropProfileId,
        startMode: params.startMode,
        anchorDate: currentAnchor,
        plantCount: params.plantCountPerBatch,
        traysCount: params.traysPerBatch ?? null,
        successionGroupId: params.groupId,
        successionIndex: i + 1,
      },
      params.todayIso,
    );
    schedules.push(schedule);
  }
  return schedules;
}
