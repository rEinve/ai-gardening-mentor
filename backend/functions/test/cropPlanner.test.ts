import test from 'node:test';
import assert from 'node:assert/strict';

import {
  calculateCropBatchSchedule,
  generateSuccessionPlan,
} from '../src/domain/cropPlanner.ts';

test('Tomato from seed matches Excel workbook math (28d nursery + 47d field = 75d total)', () => {
  const schedule = calculateCropBatchSchedule(
    {
      batchId: 'batch_tomato_seed',
      cropProfileId: 'tz_tomato',
      startMode: 'seed_nursery',
      anchorDate: '2026-11-01',
      plantCount: 50,
      traysCount: 1,
    },
    '2026-11-15',
  );

  assert.equal(schedule.sowingDate, '2026-11-01');
  assert.equal(schedule.expectedTransplantDate, '2026-11-29'); // +28d
  assert.equal(schedule.daysToTransplant, 14);
  assert.equal(schedule.fieldMaturityDays, 47); // 75 - 28
  assert.equal(schedule.expectedHarvestDate, '2027-01-15'); // Nov 29 + 47d
  assert.equal(schedule.daysToHarvest, 61);
  assert.equal(schedule.estimatedYieldMin, 100);
  assert.equal(schedule.estimatedYieldMax, 175);
  assert.ok(schedule.milestones.some((m) => m.phase === 'nursery'));
  assert.ok(schedule.upcomingPrepAlerts.length > 0);
});

test('Bought seedlings skips nursery and calculates field maturity from transplant date', () => {
  const schedule = calculateCropBatchSchedule(
    {
      batchId: 'batch_pepper_bought',
      cropProfileId: 'tz_pepper',
      startMode: 'bought_seedlings',
      anchorDate: '2026-11-22',
      plantCount: 30,
    },
    '2026-11-22',
  );

  assert.equal(schedule.sowingDate, null);
  assert.equal(schedule.expectedTransplantDate, '2026-11-22');
  assert.equal(schedule.fieldMaturityDays, 40); // Excel Bell Pepper: 68 - 28 = 40d
  assert.equal(schedule.expectedHarvestDate, '2027-01-01');
  assert.equal(schedule.daysToHarvest, 40);
  assert.equal(schedule.milestones.some((m) => m.phase === 'nursery'), false);
  // Day 14 top-dress should already trigger a 14-day prepare-ahead alert on Day 0
  assert.ok(schedule.upcomingPrepAlerts.some((m) => m.phase === 'vegetative'));
});

test('Succession plan spaces batches by interval and cascades manual date overrides', () => {
  const batches = generateSuccessionPlan({
    groupId: 'succ_cuke',
    cropProfileId: 'tz_cucumber',
    startMode: 'bought_seedlings',
    firstAnchorDate: '2026-11-01',
    intervalDays: 21,
    batchCount: 4,
    plantCountPerBatch: 40,
    todayIso: '2026-11-22',
    // Farmer skipped/pushed Batch 3 by 7 extra days (just like in Excel)
    manualOverrides: { 2: '2026-12-20' },
  });

  assert.equal(batches.length, 4);
  assert.equal(batches[0].expectedTransplantDate, '2026-11-01');
  assert.equal(batches[1].expectedTransplantDate, '2026-11-22'); // +21d
  assert.equal(batches[2].expectedTransplantDate, '2026-12-20'); // manual override
  assert.equal(batches[3].expectedTransplantDate, '2027-01-10'); // cascades +21d from Dec 20
});
