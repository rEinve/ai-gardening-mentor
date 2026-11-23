// Proactive Crop Planner & Waterfall Management Models (Tanzania MVP).
// Ported from docs/Crop planting log.xlsx (Succ. Planting Plan, Exp.Transplanting, Exp. Harvest)
// and aligned with backend/functions/src/domain/cropPlanner.ts.

enum BatchStartMode {
  boughtSeedlings,
  seedNursery,
  directSeed,
}

enum InputPreference {
  both,
  conventional,
  organic,
}

enum WaterfallPhase {
  nursery,
  preTransplant,
  plantingDay,
  vegetative,
  floweringFruiting,
  harvest,
}

class WaterfallMilestoneBlueprint {
  const WaterfallMilestoneBlueprint({
    required this.id,
    required this.phase,
    required this.dayOffsetFromFieldStart,
    required this.title,
    required this.summary,
    this.nurseryOnly = false,
    this.conventionalInput,
    this.organicInput,
    this.prepLeadDays = 10,
    this.prepReminder,
  });

  final String id;
  final WaterfallPhase phase;
  final int dayOffsetFromFieldStart;
  final bool nurseryOnly;
  final String title;
  final String summary;
  final String? conventionalInput;
  final String? organicInput;
  final int prepLeadDays;
  final String? prepReminder;
}

class CropPlannerProfile {
  const CropPlannerProfile({
    required this.profileId,
    required this.commonName,
    required this.localNameSw,
    required this.totalMaturityDays,
    required this.nurseryDays,
    required this.defaultSuccessionIntervalDays,
    required this.defaultStartMode,
    required this.yieldUnit,
    required this.conservativeYieldPerPlantMin,
    required this.conservativeYieldPerPlantMax,
    required this.milestones,
  });

  final String profileId;
  final String commonName;
  final String localNameSw;
  final int totalMaturityDays;
  final int nurseryDays;
  final int defaultSuccessionIntervalDays;
  final BatchStartMode defaultStartMode;
  final String yieldUnit; // 'kg' or 'bundles'
  final double conservativeYieldPerPlantMin;
  final double conservativeYieldPerPlantMax;
  final List<WaterfallMilestoneBlueprint> milestones;
}

class ScheduledMilestone {
  const ScheduledMilestone({
    required this.id,
    required this.batchId,
    required this.cropLabel,
    required this.phase,
    required this.title,
    required this.summary,
    required this.scheduledDate,
    required this.daysFromToday,
    required this.isPrepareAheadAlert,
    this.conventionalInput,
    this.organicInput,
    this.prepReminder,
  });

  final String id;
  final String batchId;
  final String cropLabel;
  final WaterfallPhase phase;
  final String title;
  final String summary;
  final String scheduledDate; // YYYY-MM-DD
  final int daysFromToday;
  final bool isPrepareAheadAlert;
  final String? conventionalInput;
  final String? organicInput;
  final String? prepReminder;
}

class CropBatchPlan {
  const CropBatchPlan({
    required this.batchId,
    required this.cropProfileId,
    required this.startMode,
    required this.anchorDate,
    required this.plantCount,
    this.traysCount,
    this.nurseryDaysOverride,
    this.totalMaturityDaysOverride,
    this.actualHarvestDate,
    this.successionGroupId,
    this.successionIndex,
    this.completedMilestoneIds = const {},
  });

  final String batchId;
  final String cropProfileId;
  final BatchStartMode startMode;
  final String anchorDate; // YYYY-MM-DD
  final int plantCount;
  final int? traysCount;
  final int? nurseryDaysOverride;
  final int? totalMaturityDaysOverride;
  final String? actualHarvestDate;
  final String? successionGroupId;
  final int? successionIndex;
  final Set<String> completedMilestoneIds;

  CropBatchPlan copyWith({
    String? anchorDate,
    int? plantCount,
    int? traysCount,
    String? actualHarvestDate,
    Set<String>? completedMilestoneIds,
  }) {
    return CropBatchPlan(
      batchId: batchId,
      cropProfileId: cropProfileId,
      startMode: startMode,
      anchorDate: anchorDate ?? this.anchorDate,
      plantCount: plantCount ?? this.plantCount,
      traysCount: traysCount ?? this.traysCount,
      nurseryDaysOverride: nurseryDaysOverride,
      totalMaturityDaysOverride: totalMaturityDaysOverride,
      actualHarvestDate: actualHarvestDate ?? this.actualHarvestDate,
      successionGroupId: successionGroupId,
      successionIndex: successionIndex,
      completedMilestoneIds: completedMilestoneIds ?? this.completedMilestoneIds,
    );
  }
}

class ComputedBatchSchedule {
  const ComputedBatchSchedule({
    required this.plan,
    required this.profile,
    required this.sowingDate,
    required this.expectedTransplantDate,
    required this.daysToTransplant,
    required this.fieldMaturityDays,
    required this.totalMaturityDays,
    required this.expectedHarvestDate,
    required this.daysToHarvest,
    required this.harvestVarianceDays,
    required this.estimatedYieldMin,
    required this.estimatedYieldMax,
    required this.milestones,
    required this.upcomingPrepAlerts,
  });

  final CropBatchPlan plan;
  final CropPlannerProfile profile;
  final String? sowingDate;
  final String? expectedTransplantDate;
  final int? daysToTransplant;
  final int fieldMaturityDays;
  final int totalMaturityDays;
  final String expectedHarvestDate;
  final int daysToHarvest;
  final int? harvestVarianceDays;
  final double estimatedYieldMin;
  final double estimatedYieldMax;
  final List<ScheduledMilestone> milestones;
  final List<ScheduledMilestone> upcomingPrepAlerts;

  String get batchDisplayLabel {
    final idx = plan.successionIndex;
    if (idx != null) {
      return '${profile.commonName} (${profile.localNameSw}) — Batch #$idx';
    }
    return '${profile.commonName} (${profile.localNameSw})';
  }
}

String formatIsoDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseIsoDate(String iso) {
  final parts = iso.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

String addDaysIso(String iso, int days) {
  final dt = parseIsoDate(iso).add(Duration(days: days));
  return formatIsoDate(dt);
}

int diffDaysIso(String targetIso, String baseIso) {
  return parseIsoDate(targetIso).difference(parseIsoDate(baseIso)).inDays;
}

String startModeLabel(BatchStartMode mode) => switch (mode) {
      BatchStartMode.boughtSeedlings => 'Bought Seedlings',
      BatchStartMode.seedNursery => 'From Seed (Nursery)',
      BatchStartMode.directSeed => 'Direct Seeding',
    };

String phaseLabel(WaterfallPhase phase) => switch (phase) {
      WaterfallPhase.nursery => 'Nursery',
      WaterfallPhase.preTransplant => 'Pre-Transplant',
      WaterfallPhase.plantingDay => 'Planting Day',
      WaterfallPhase.vegetative => 'Vegetative',
      WaterfallPhase.floweringFruiting => 'Flowering & Fruit',
      WaterfallPhase.harvest => 'Harvest',
    };

const List<WaterfallMilestoneBlueprint> _kSolanaceaeMilestones = [
  WaterfallMilestoneBlueprint(
    id: 'nursery_sow',
    phase: WaterfallPhase.nursery,
    dayOffsetFromFieldStart: -28,
    nurseryOnly: true,
    title: 'Sow seeds in nursery trays',
    summary: 'Fill seedling trays with moist sterile mix and sow 1–2 seeds per cell. Keep shaded and evenly moist.',
    conventionalInput: 'Starter seedling mix + gentle morning misting',
    prepLeadDays: 7,
    prepReminder: 'Prepare seedling trays, shade net, and clean nursery media.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'nursery_harden',
    phase: WaterfallPhase.preTransplant,
    dayOffsetFromFieldStart: -7,
    nurseryOnly: true,
    title: 'Harden off seedlings & prepare field beds',
    summary: 'Increase sun exposure gradually over 5–7 days; dig planting holes and mix well-rotted manure into the soil.',
    conventionalInput: 'Prepare basal DAP (5g/plant) + well-rotted manure for transplant day',
    prepLeadDays: 7,
    prepReminder: 'Buy basal DAP (5g/plant) and finish digging beds before transplanting.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'transplant_basal',
    phase: WaterfallPhase.plantingDay,
    dayOffsetFromFieldStart: 0,
    title: 'Transplant & basal phosphorus feed',
    summary: 'Transplant in late afternoon; mix basal DAP into the hole covered with a thin layer of soil (never touching bare roots), then water deeply.',
    conventionalInput: 'DAP (18-46-0): ~5g (1 level tsp) per plant mixed into planting hole',
    prepLeadDays: 10,
    prepReminder: 'Have DAP (5g/plant) ready for transplant day.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'veg_topdress',
    phase: WaterfallPhase.vegetative,
    dayOffsetFromFieldStart: 14,
    title: 'Vegetative top-dressing & staking',
    summary: 'Apply Nitrogen in a ring 5–8 cm from the stem after watering to drive strong stem & leaf growth; set up stakes and twine.',
    conventionalInput: 'CAN or Urea: ~5g per plant in a ring, then water in well',
    prepLeadDays: 14,
    prepReminder: 'Prepare CAN or Urea (~5g/plant) and gather stakes/twine ahead of Day 14.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'flowering_boost',
    phase: WaterfallPhase.floweringFruiting,
    dayOffsetFromFieldStart: 28,
    title: 'Flowering NPK boost & Calcium-Boron foliar',
    summary: 'Apply balanced NPK to support flower retention; spray Calcium-Boron early morning to prevent flower drop and blossom-end rot; prune lower yellowed leaves touching soil.',
    conventionalInput: 'NPK 17:17:17 (~10g/plant) + Calcium-Boron foliar spray early morning',
    prepLeadDays: 14,
    prepReminder: 'Get NPK 17:17:17 and Calcium-Boron foliar spray ready before flowering starts.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'fruiting_care',
    phase: WaterfallPhase.floweringFruiting,
    dayOffsetFromFieldStart: 38,
    title: 'Fruiting stage care & steady watering',
    summary: 'Keep soil moisture even (avoid dry-then-flood cycles that crack fruits), tie heavy fruit branches to stakes, and scout undersides of leaves for pests/blight.',
    conventionalInput: 'Potash-rich foliar or light NPK top-up if plants look pale; observe pre-harvest spray intervals (PHI)',
    prepLeadDays: 10,
    prepReminder: 'Check twine/stakes for heavy fruit clusters and confirm spray pre-harvest intervals.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'market_check',
    phase: WaterfallPhase.harvest,
    dayOffsetFromFieldStart: 42,
    title: 'Pre-harvest market & buyer readiness',
    summary: 'Check local market prices, contact buyers before fruits ripen, and prepare clean crates/baskets for picking.',
    conventionalInput: 'Stop any restricted sprays per label PHI; harvest in cool morning hours',
    prepLeadDays: 7,
    prepReminder: 'Check local market prices and line up buyers before harvest opens.',
  ),
];

const List<WaterfallMilestoneBlueprint> _kCucurbitMilestones = [
  WaterfallMilestoneBlueprint(
    id: 'nursery_sow',
    phase: WaterfallPhase.nursery,
    dayOffsetFromFieldStart: -14,
    nurseryOnly: true,
    title: 'Sow seeds in nursery trays',
    summary: 'Sow 1 seed per cell; keep warm and moist for 10–14 days before gentle transplanting.',
    conventionalInput: 'Clean seedling tray media',
    prepLeadDays: 5,
    prepReminder: 'Prepare seedling trays and trellis poles early.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'planting_basal',
    phase: WaterfallPhase.plantingDay,
    dayOffsetFromFieldStart: 0,
    title: 'Planting / Transplant & basal feed',
    summary: 'Plant without disturbing roots; mix basal DAP into soil below roots and water gently.',
    conventionalInput: 'DAP: ~5g per plant mixed with soil below roots',
    prepLeadDays: 10,
    prepReminder: 'Have DAP (~5g/plant) ready for planting day.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'veg_trellis',
    phase: WaterfallPhase.vegetative,
    dayOffsetFromFieldStart: 14,
    title: 'Trellis training & Nitrogen top-dress',
    summary: 'Guide vines onto trellis strings and apply first top-dressing for strong vine vigor.',
    conventionalInput: 'CAN or Urea: ~5g per plant, watered in immediately',
    prepLeadDays: 12,
    prepReminder: 'Prepare trellis poles/twine and CAN or Urea ahead of Day 14.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'flowering_k',
    phase: WaterfallPhase.floweringFruiting,
    dayOffsetFromFieldStart: 25,
    title: 'Flowering & Fruiting NPK boost',
    summary: 'Boost potassium for crisp, straight fruits; avoid spraying during morning bee pollination hours.',
    conventionalInput: 'NPK 17:17:17 (~10g/plant) + micronutrient foliar late afternoon',
    prepLeadDays: 10,
    prepReminder: 'Get NPK 17:17:17 ready before flowering starts.',
  ),
];

const List<WaterfallMilestoneBlueprint> _kLeafyMilestones = [
  WaterfallMilestoneBlueprint(
    id: 'planting_basal',
    phase: WaterfallPhase.plantingDay,
    dayOffsetFromFieldStart: 0,
    title: 'Bed preparation & planting',
    summary: 'Loosen topsoil 15–20 cm deep, incorporate basal fertilizer or cured manure, and plant evenly.',
    conventionalInput: 'DAP or NPK 17:17:17 lightly worked into bed (~3g/plant)',
    prepLeadDays: 7,
    prepReminder: 'Prepare fine seedbed and basal DAP/NPK.',
  ),
  WaterfallMilestoneBlueprint(
    id: 'veg_nitrogen',
    phase: WaterfallPhase.vegetative,
    dayOffsetFromFieldStart: 12,
    title: 'Leafy Nitrogen top-dressing',
    summary: 'Boost tender green leaf growth; water evenly in the morning so leaves stay crisp.',
    conventionalInput: 'CAN or Urea: ~3–5g per plant (or light band along rows), water in well',
    prepLeadDays: 10,
    prepReminder: 'Prepare CAN or Urea for Day 12 leaf boost.',
  ),
];

/// Planner profiles calibrated to `docs/Crop planting log.xlsx` + Tanzania starter crops.
/// Marked `prototype_fixture` until Tanzanian agronomic sign-off.
const List<CropPlannerProfile> kTanzaniaPlannerProfiles = [
  CropPlannerProfile(
    profileId: 'tz_tomato',
    commonName: 'Tomato',
    localNameSw: 'Nyanya',
    totalMaturityDays: 75,
    nurseryDays: 28,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.boughtSeedlings,
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 2.0,
    conservativeYieldPerPlantMax: 3.5,
    milestones: _kSolanaceaeMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_cucumber',
    commonName: 'Cucumber',
    localNameSw: 'Tango',
    totalMaturityDays: 57,
    nurseryDays: 14,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.seedNursery,
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 1.5,
    conservativeYieldPerPlantMax: 3.0,
    milestones: _kCucurbitMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_pepper',
    commonName: 'Bell Pepper / Pilipili',
    localNameSw: 'Pilipili Hoho',
    totalMaturityDays: 68,
    nurseryDays: 28,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.boughtSeedlings,
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 1.0,
    conservativeYieldPerPlantMax: 2.0,
    milestones: _kSolanaceaeMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_african_eggplant',
    commonName: 'African Eggplant',
    localNameSw: 'Ngogwe / Bilinganya',
    totalMaturityDays: 70,
    nurseryDays: 28,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.boughtSeedlings,
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 1.5,
    conservativeYieldPerPlantMax: 2.8,
    milestones: _kSolanaceaeMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_okra',
    commonName: 'Okra',
    localNameSw: 'Bamia',
    totalMaturityDays: 55,
    nurseryDays: 0,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.directSeed,
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 0.4,
    conservativeYieldPerPlantMax: 0.8,
    milestones: _kCucurbitMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_sukuma_wiki',
    commonName: 'Sukuma Wiki / Kale',
    localNameSw: 'Sukumawiki',
    totalMaturityDays: 60,
    nurseryDays: 21,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.boughtSeedlings,
    yieldUnit: 'bundles',
    conservativeYieldPerPlantMin: 2.0,
    conservativeYieldPerPlantMax: 4.0,
    milestones: _kLeafyMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_amaranth',
    commonName: 'Amaranth',
    localNameSw: 'Mchicha',
    totalMaturityDays: 28,
    nurseryDays: 0,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.directSeed,
    yieldUnit: 'bundles',
    conservativeYieldPerPlantMin: 0.25,
    conservativeYieldPerPlantMax: 0.5,
    milestones: _kLeafyMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_african_nightshade',
    commonName: 'African Nightshade',
    localNameSw: 'Mnavu',
    totalMaturityDays: 42,
    nurseryDays: 14,
    defaultSuccessionIntervalDays: 21,
    defaultStartMode: BatchStartMode.directSeed,
    yieldUnit: 'bundles',
    conservativeYieldPerPlantMin: 1.0,
    conservativeYieldPerPlantMax: 2.0,
    milestones: _kLeafyMilestones,
  ),
  CropPlannerProfile(
    profileId: 'tz_squash',
    commonName: 'Squash / Pumpkin',
    localNameSw: 'Boga',
    totalMaturityDays: 85,
    nurseryDays: 0,
    defaultSuccessionIntervalDays: 28,
    defaultStartMode: BatchStartMode.directSeed,
    yieldUnit: 'kg',
    conservativeYieldPerPlantMin: 3.0,
    conservativeYieldPerPlantMax: 6.0,
    milestones: _kCucurbitMilestones,
  ),
];

CropPlannerProfile findPlannerProfile(String profileId) {
  return kTanzaniaPlannerProfiles.firstWhere(
    (p) => p.profileId == profileId,
    orElse: () => kTanzaniaPlannerProfiles.first,
  );
}

ComputedBatchSchedule computeBatchSchedule(CropBatchPlan plan, String todayIso) {
  final profile = findPlannerProfile(plan.cropProfileId);
  final totalMaturityDays = plan.totalMaturityDaysOverride ?? profile.totalMaturityDays;
  final effectiveNurseryDays = plan.startMode == BatchStartMode.directSeed
      ? 0
      : (plan.nurseryDaysOverride ?? profile.nurseryDays);

  final fieldMaturityDays = (totalMaturityDays - effectiveNurseryDays).clamp(7, 365);

  String? sowingDate;
  String? expectedTransplantDate;
  late String fieldAnchorDate;

  switch (plan.startMode) {
    case BatchStartMode.seedNursery:
      sowingDate = plan.anchorDate;
      expectedTransplantDate = addDaysIso(plan.anchorDate, effectiveNurseryDays);
      fieldAnchorDate = expectedTransplantDate;
    case BatchStartMode.boughtSeedlings:
      sowingDate = null;
      expectedTransplantDate = plan.anchorDate;
      fieldAnchorDate = plan.anchorDate;
    case BatchStartMode.directSeed:
      sowingDate = plan.anchorDate;
      expectedTransplantDate = null;
      fieldAnchorDate = plan.anchorDate;
  }

  final expectedHarvestDate = addDaysIso(fieldAnchorDate, fieldMaturityDays);
  final daysToTransplant = (plan.startMode == BatchStartMode.seedNursery && expectedTransplantDate != null)
      ? diffDaysIso(expectedTransplantDate, todayIso)
      : null;
  final daysToHarvest = diffDaysIso(expectedHarvestDate, todayIso);
  final harvestVarianceDays = plan.actualHarvestDate != null
      ? diffDaysIso(plan.actualHarvestDate!, expectedHarvestDate)
      : null;

  final safePlants = plan.plantCount < 1 ? 1 : plan.plantCount;
  final yieldMin = double.parse((safePlants * profile.conservativeYieldPerPlantMin).toStringAsFixed(1));
  final yieldMax = double.parse((safePlants * profile.conservativeYieldPerPlantMax).toStringAsFixed(1));

  final cropLabel = plan.successionIndex != null
      ? '${profile.commonName} #${plan.successionIndex}'
      : profile.commonName;

  final milestones = <ScheduledMilestone>[];
  for (final bp in profile.milestones) {
    if (bp.nurseryOnly && plan.startMode != BatchStartMode.seedNursery) {
      continue;
    }
    final scheduledDate = addDaysIso(fieldAnchorDate, bp.dayOffsetFromFieldStart);
    final daysFromToday = diffDaysIso(scheduledDate, todayIso);
    final isPrep = daysFromToday > 0 && daysFromToday <= bp.prepLeadDays;

    milestones.add(
      ScheduledMilestone(
        id: '${plan.batchId}_${bp.id}',
        batchId: plan.batchId,
        cropLabel: cropLabel,
        phase: bp.phase,
        title: bp.title,
        summary: bp.summary,
        scheduledDate: scheduledDate,
        daysFromToday: daysFromToday,
        isPrepareAheadAlert: isPrep,
        conventionalInput: bp.conventionalInput,
        organicInput: bp.organicInput,
        prepReminder: bp.prepReminder,
      ),
    );
  }

  final harvestDaysFromToday = diffDaysIso(expectedHarvestDate, todayIso);
  milestones.add(
    ScheduledMilestone(
      id: '${plan.batchId}_expected_harvest',
      batchId: plan.batchId,
      cropLabel: cropLabel,
      phase: WaterfallPhase.harvest,
      title: 'Expected Harvest Window (${profile.commonName})',
      summary:
          'Expected maturity date reached for $safePlants plants. Pick in cool morning hours and log your actual harvest date to improve future schedules.',
      scheduledDate: expectedHarvestDate,
      daysFromToday: harvestDaysFromToday,
      isPrepareAheadAlert: harvestDaysFromToday > 0 && harvestDaysFromToday <= 14,
      prepReminder: 'Confirm market buyers or household plan before harvest window opens.',
    ),
  );

  milestones.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  final alerts = milestones
      .where((m) => m.isPrepareAheadAlert && !plan.completedMilestoneIds.contains(m.id))
      .toList();

  return ComputedBatchSchedule(
    plan: plan,
    profile: profile,
    sowingDate: sowingDate,
    expectedTransplantDate: expectedTransplantDate,
    daysToTransplant: daysToTransplant,
    fieldMaturityDays: fieldMaturityDays,
    totalMaturityDays: totalMaturityDays,
    expectedHarvestDate: expectedHarvestDate,
    daysToHarvest: daysToHarvest,
    harvestVarianceDays: harvestVarianceDays,
    estimatedYieldMin: yieldMin,
    estimatedYieldMax: yieldMax,
    milestones: milestones,
    upcomingPrepAlerts: alerts,
  );
}
