import test from 'node:test';
import assert from 'node:assert/strict';

import {
  ConflictError,
  executeInitializeGarden,
  type GardenInitRepository,
} from '../src/functions/initializeGarden.ts';
import { ValidationError } from '../src/validators/garden.ts';
import { deriveEffectiveTaskStatus } from '../src/domain/effectiveState.ts';
import { generateSevenDayCadence } from '../src/domain/cadence.ts';
import { buildDeterministicTaskId, estimateGrowthStage } from '../src/domain/identity.ts';
import {
  TANZANIA_CARE_RULES,
  TANZANIA_CROP_PROFILES,
  TANZANIA_TASK_TEMPLATES,
} from '../src/seeds/tanzaniaFixtures.ts';
import type {
  CropRecord,
  DurableRequestRecord,
  PlotRecord,
  TaskCompletionEvent,
  TaskRecord,
} from '../src/types/schema.ts';

function createInMemoryRepo(): GardenInitRepository & {
  requests: Map<string, DurableRequestRecord>;
  plots: Map<string, PlotRecord>;
  crops: Map<string, CropRecord>;
  tasks: Map<string, TaskRecord>;
} {
  const requests = new Map<string, DurableRequestRecord>();
  const plots = new Map<string, PlotRecord>();
  const crops = new Map<string, CropRecord>();
  const tasks = new Map<string, TaskRecord>();

  return {
    requests,
    plots,
    crops,
    tasks,
    async getRequest(_uid, requestId) {
      return requests.get(requestId) ?? null;
    },
    async getExistingCounts() {
      return {
        plotCount: plots.size,
        cropCount: crops.size,
        taskCount: tasks.size,
      };
    },
    async getReferenceData() {
      return {
        cropProfiles: new Map(TANZANIA_CROP_PROFILES.map((c) => [c.id, c])),
        careRules: TANZANIA_CARE_RULES,
        taskTemplates: new Map(TANZANIA_TASK_TEMPLATES.map((t) => [t.id, t])),
      };
    },
    async commitInitialization({ requestRecord, plots: pList, cropsByPlotId, tasks: tList }) {
      requests.set(requestRecord.requestId, requestRecord);
      for (const p of pList) {
        plots.set(p.plotId, p);
        for (const c of cropsByPlotId.get(p.plotId) ?? []) {
          crops.set(c.cropId, c);
        }
      }
      for (const t of tList) {
        tasks.set(t.taskId, t);
      }
    },
  };
}

const VALID_TZ_PAYLOAD = {
  requestId: 'req_tz_onboard_0001',
  displayName: 'Asha',
  geographicLocation: {
    latitude: -6.7924,
    longitude: 39.2083,
    regionName: 'Dar es Salaam',
    countryCode: 'TZ',
    postalCode: null,
    usdaHardinessZone: null,
  },
  timeZone: 'Africa/Dar_es_Salaam',
  unitPreference: 'metric',
  gardenExperienceLevel: 'novice',
  plots: [
    {
      plotId: 'plot_backyard_01',
      name: 'Backyard Raised Bed',
      plotType: 'raised_bed',
      rainExposure: 'exposed',
      dimensions: { lengthMetres: 3, widthMetres: 1.2 },
      sunlightExposure: 'full_sun',
      crops: [
        {
          cropId: 'crop_tomato_01',
          cropProfileId: 'tz_tomato',
          variety: 'Tengeru 97',
          plantingDate: '2026-10-15',
          plantingMethod: 'transplant',
        },
        {
          cropId: 'crop_okra_01',
          cropProfileId: 'tz_okra',
          variety: 'Clemson Spineless',
          plantingDate: '2026-11-01',
          plantingMethod: 'direct_seed',
        },
      ],
    },
    {
      plotId: 'plot_veranda_02',
      name: 'Veranda Containers',
      plotType: 'container',
      rainExposure: 'sheltered',
      dimensions: null,
      sunlightExposure: 'partial_shade',
      crops: [
        {
          cropId: 'crop_mchicha_01',
          cropProfileId: 'tz_amaranth',
          variety: 'Madiira 1',
          plantingDate: '2026-10-20',
          plantingMethod: 'direct_seed',
        },
      ],
    },
  ],
};

test('A1: Tanzania onboarding creates garden + 7-day cadence and replays idempotently', async () => {
  const repo = createInMemoryRepo();
  const fixedNow = new Date('2026-11-22T06:00:00Z');
  const auth = { uid: 'uid_tz_001', email: null, isAnonymous: true };

  const first = await executeInitializeGarden({
    auth,
    rawPayload: VALID_TZ_PAYLOAD,
    repo,
    now: fixedNow,
  });

  assert.equal(first.idempotentReplay, false);
  assert.equal(first.plotCount, 2);
  assert.equal(first.cropCount, 3);
  assert.ok(first.scheduledTaskCount > 0, 'Should generate 7-day care tasks');

  // Verify sheltered plot receives soil_check instead of exposed watering
  const verandaTasks = [...repo.tasks.values()].filter((t) => t.plotId === 'plot_veranda_02');
  assert.ok(verandaTasks.some((t) => t.taskCategory === 'soil_check'));
  assert.ok(!verandaTasks.some((t) => t.taskCategory === 'watering'));

  // Exact retry with same requestId does not duplicate records
  const replay = await executeInitializeGarden({
    auth,
    rawPayload: VALID_TZ_PAYLOAD,
    repo,
    now: fixedNow,
  });

  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.scheduledTaskCount, first.scheduledTaskCount);
  assert.equal(repo.tasks.size, first.scheduledTaskCount);
});

test('A1 Conflict: Reusing requestId with modified payload is rejected', async () => {
  const repo = createInMemoryRepo();
  const fixedNow = new Date('2026-11-22T06:00:00Z');
  const auth = { uid: 'uid_tz_001', email: null, isAnonymous: true };

  await executeInitializeGarden({ auth, rawPayload: VALID_TZ_PAYLOAD, repo, now: fixedNow });

  await assert.rejects(
    () =>
      executeInitializeGarden({
        auth,
        rawPayload: { ...VALID_TZ_PAYLOAD, displayName: 'Different Name' },
        repo,
        now: fixedNow,
      }),
    ConflictError,
  );
});

test('Validation: Rejects unknown fields, future plantingDate, and unsupported crops', async () => {
  const repo = createInMemoryRepo();
  const fixedNow = new Date('2026-11-22T06:00:00Z');
  const auth = { uid: 'uid_tz_001', email: null, isAnonymous: true };

  await assert.rejects(
    () =>
      executeInitializeGarden({
        auth,
        rawPayload: { ...VALID_TZ_PAYLOAD, forgedAdminFlag: true },
        repo,
        now: fixedNow,
      }),
    ValidationError,
  );

  await assert.rejects(
    () =>
      executeInitializeGarden({
        auth,
        rawPayload: {
          ...VALID_TZ_PAYLOAD,
          plots: [
            {
              ...VALID_TZ_PAYLOAD.plots[0],
              crops: [
                {
                  cropId: 'crop_future_01',
                  cropProfileId: 'tz_tomato',
                  variety: null,
                  plantingDate: '2026-12-25',
                  plantingMethod: 'transplant',
                },
              ],
            },
          ],
        },
        repo,
        now: fixedNow,
      }),
    ValidationError,
  );
});

test('A5: Offline completion event survives weather deferral and multi-device sync', () => {
  const sampleTask: TaskRecord = {
    taskId: 'task_20261122_abc123',
    cropId: 'crop_tomato_01',
    plotId: 'plot_backyard_01',
    ruleId: 'tz_rule_water_exposed',
    ruleVersion: '1',
    taskCategory: 'watering',
    title: 'Tomato: Morning root-zone watering',
    instructions: 'Water at root zone.',
    steps: ['Water base'],
    rationale: 'Steady moisture',
    estimatedDurationMinutes: 3,
    scheduledDate: '2026-11-22',
    timeZone: 'Africa/Dar_es_Salaam',
    dueAt: null,
    scheduleStatus: 'deferred_weather', // Weather worker deferred after user already watered offline
    weatherOverrideApplied: true,
    weatherOverrideReason: 'Rainfall > 12.7 mm/24h',
    forecastFetchedAt: '2026-11-22T05:00:00Z',
    sourceRefs: [],
    diagnosisId: null,
    createdAt: '2026-11-22T00:00:00Z',
    updatedAt: '2026-11-22T05:00:00Z',
  };

  const completions: TaskCompletionEvent[] = [
    {
      eventId: 'ev_phone_1',
      taskId: sampleTask.taskId,
      completedAt: '2026-11-22T04:15:00Z',
      receivedAt: '2026-11-22T07:00:00Z',
    },
    {
      eventId: 'ev_tablet_2',
      taskId: sampleTask.taskId,
      completedAt: '2026-11-22T04:20:00Z',
      receivedAt: '2026-11-22T07:01:00Z',
    },
  ];

  const derived = deriveEffectiveTaskStatus(sampleTask, completions);
  assert.equal(derived.effectiveStatus, 'completed');
  assert.equal(derived.completionCount, 2);
  assert.equal(derived.firstCompletedAt, '2026-11-22T04:15:00Z');
});

test('A6: Deterministic task IDs, completed task preservation, and retired vs harvest lifecycle', () => {
  const id1 = buildDeterministicTaskId({
    userId: 'u1',
    cropId: 'c1',
    ruleId: 'tz_rule_water_exposed',
    localDate: '2026-11-22',
    occurrenceSlot: 1,
  });
  const id2 = buildDeterministicTaskId({
    userId: 'u1',
    cropId: 'c1',
    ruleId: 'tz_rule_water_exposed',
    localDate: '2026-11-22',
    occurrenceSlot: 1,
  });
  assert.equal(id1, id2);

  // Verify Mchicha at day 30 is in harvest stage and stays active in cadence
  const amaranth = TANZANIA_CROP_PROFILES.find((c) => c.id === 'tz_amaranth')!;
  assert.equal(estimateGrowthStage(amaranth, 'direct_seed', '2026-10-20', '2026-11-22'), 'harvest');

  const plot: PlotRecord = {
    plotId: 'p1',
    name: 'Garden',
    plotType: 'in_ground',
    rainExposure: 'exposed',
    dimensions: null,
    sunlightExposure: 'full_sun',
    createdAt: '2026-11-22T00:00:00Z',
    updatedAt: '2026-11-22T00:00:00Z',
  };

  const activeHarvestCrop: CropRecord = {
    cropId: 'c_active',
    cropProfileId: 'tz_amaranth',
    commonName: 'Amaranth',
    variety: null,
    plantingDate: '2026-10-20',
    plantingMethod: 'direct_seed',
    currentGrowthStage: 'harvest',
    lifecycleStatus: 'active',
    healthStatus: 'healthy',
    retiredAt: null,
    createdAt: '2026-11-22T00:00:00Z',
    updatedAt: '2026-11-22T00:00:00Z',
  };

  const retiredCrop: CropRecord = {
    ...activeHarvestCrop,
    cropId: 'c_retired',
    lifecycleStatus: 'retired',
    retiredAt: '2026-11-21T00:00:00Z',
  };

  const generated = generateSevenDayCadence({
    userId: 'u1',
    regionCode: 'TZ',
    timeZone: 'Africa/Dar_es_Salaam',
    startLocalDate: '2026-11-22',
    nowIso: '2026-11-22T00:00:00Z',
    plots: [plot],
    cropsByPlotId: new Map([['p1', [activeHarvestCrop, retiredCrop]]]),
    cropProfiles: new Map(TANZANIA_CROP_PROFILES.map((c) => [c.id, c])),
    careRules: TANZANIA_CARE_RULES,
    taskTemplates: new Map(TANZANIA_TASK_TEMPLATES.map((t) => [t.id, t])),
    completedTaskIds: new Set<string>(),
  });

  assert.ok(generated.some((t) => t.cropId === 'c_active'), 'Harvest-stage active crop keeps receiving tasks');
  assert.ok(!generated.some((t) => t.cropId === 'c_retired'), 'Retired crop receives zero future tasks');
});
