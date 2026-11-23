import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gardening_mentor/data/offline_garden_store.dart';
import 'package:ai_gardening_mentor/models/crop_planner_models.dart';

void main() {
  test('Tomato from seed matches Excel workbook math (28d nursery + 47d field)', () {
    const plan = CropBatchPlan(
      batchId: 'b1',
      cropProfileId: 'tz_tomato',
      startMode: BatchStartMode.seedNursery,
      anchorDate: '2026-11-01',
      plantCount: 50,
    );

    final schedule = computeBatchSchedule(plan, '2026-11-15');
    expect(schedule.sowingDate, '2026-11-01');
    expect(schedule.expectedTransplantDate, '2026-11-29');
    expect(schedule.daysToTransplant, 14);
    expect(schedule.fieldMaturityDays, 47);
    expect(schedule.expectedHarvestDate, '2027-01-15');
    expect(schedule.daysToHarvest, 61);
    expect(schedule.estimatedYieldMin, 100.0);
    expect(schedule.estimatedYieldMax, 175.0);
    expect(schedule.milestones.any((m) => m.phase == WaterfallPhase.nursery), isTrue);
    expect(schedule.upcomingPrepAlerts, isNotEmpty);
  });

  test('Bought seedlings skips nursery and triggers Day 14 prep alert on Day 0', () {
    const plan = CropBatchPlan(
      batchId: 'b2',
      cropProfileId: 'tz_pepper',
      startMode: BatchStartMode.boughtSeedlings,
      anchorDate: '2026-11-22',
      plantCount: 30,
    );

    final schedule = computeBatchSchedule(plan, '2026-11-22');
    expect(schedule.sowingDate, isNull);
    expect(schedule.expectedTransplantDate, '2026-11-22');
    expect(schedule.fieldMaturityDays, 40);
    expect(schedule.expectedHarvestDate, '2027-01-01');
    expect(schedule.milestones.any((m) => m.phase == WaterfallPhase.nursery), isFalse);
    expect(schedule.upcomingPrepAlerts.any((m) => m.phase == WaterfallPhase.vegetative), isTrue);
  });

  test('OfflineGardenStore succession planting and date cascade works', () {
    final store = OfflineGardenStore();
    store.addSuccessionPlan(
      cropProfileId: 'tz_cucumber',
      startMode: BatchStartMode.boughtSeedlings,
      firstAnchorDate: '2026-11-01',
      intervalDays: 21,
      batchCount: 3,
      plantCountPerBatch: 25,
    );

    final initial = store.computedBatchSchedules;
    expect(initial.length, 3);
    expect(initial[0].plan.anchorDate, '2026-11-01');
    expect(initial[1].plan.anchorDate, '2026-11-22');
    expect(initial[2].plan.anchorDate, '2026-12-13');

    // Shift Batch #2 forward by 7 days and cascade Batch #3
    store.rescheduleBatch(
      initial[1].plan.batchId,
      '2026-11-29',
      cascadeSuccession: true,
    );

    final updated = store.computedBatchSchedules;
    expect(updated[0].plan.anchorDate, '2026-11-01');
    expect(updated[1].plan.anchorDate, '2026-11-29');
    expect(updated[2].plan.anchorDate, '2026-12-20');
  });
}
