import test from 'node:test';
import assert from 'node:assert/strict';

import { evaluateDueJobsForUser } from '../src/domain/scheduler.ts';
import { evaluateWeatherOverrides } from '../src/domain/weatherOverrides.ts';
import { fetchOpenWeatherForecast } from '../src/providers/openWeatherProvider.ts';
import {
  executeDeleteAccount,
  executeRetireCrop,
  purgeExpiredDiagnosticImages,
  type AccountDeletionAdapter,
  type RetireCropRepository,
} from '../src/functions/lifecycle.ts';
import type {
  CropRecord,
  DurableRequestRecord,
  PlotRecord,
  TaskRecord,
  TriageLogRecord,
} from '../src/types/schema.ts';

test('Phase 4 Scheduler: 15-min UTC dispatcher fires Tanzania EAT windows and prevents duplicates via execution key', () => {
  // 00:05 UTC == 03:05 EAT (Africa/Dar_es_Salaam, UTC+3) -> daily_cadence due
  const at0305Eat = new Date('2026-11-22T00:05:00Z');
  const due1 = evaluateDueJobsForUser({
    timeZone: 'Africa/Dar_es_Salaam',
    now: at0305Eat,
    completedJobKeys: new Set(),
  });
  assert.equal(due1.length, 1);
  assert.equal(due1[0]?.kind, 'daily_cadence');
  assert.equal(due1[0]?.jobKey, 'daily_cadence_2026-11-22_h03');

  // Re-running with completed execution key does not duplicate
  const due2 = evaluateDueJobsForUser({
    timeZone: 'Africa/Dar_es_Salaam',
    now: at0305Eat,
    completedJobKeys: new Set(['daily_cadence_2026-11-22_h03']),
  });
  assert.equal(due2.length, 0);

  // 08:05 UTC == 11:05 EAT -> weather checks for 05:00 (catch-up) and 11:00 are due
  const at1105Eat = new Date('2026-11-22T08:05:00Z');
  const due3 = evaluateDueJobsForUser({
    timeZone: 'Africa/Dar_es_Salaam',
    now: at1105Eat,
    completedJobKeys: new Set(['daily_cadence_2026-11-22_h03']),
  });
  assert.deepEqual(
    due3.map((j) => j.jobKey).sort(),
    ['weather_override_2026-11-22_h05', 'weather_override_2026-11-22_h11'],
  );
});

test('Phase 4 Weather Overrides: Rain defers exposed plots only; sheltered plots & completed tasks stay untouched; heat/frost tasks insert', () => {
  const exposedPlot: PlotRecord = {
    plotId: 'plot_exposed',
    name: 'Backyard Bed',
    plotType: 'raised_bed',
    rainExposure: 'exposed',
    dimensions: null,
    sunlightExposure: 'full_sun',
    createdAt: '2026-11-01T00:00:00Z',
    updatedAt: '2026-11-01T00:00:00Z',
  };
  const shelteredPlot: PlotRecord = {
    ...exposedPlot,
    plotId: 'plot_sheltered',
    name: 'Veranda Pots',
    rainExposure: 'sheltered',
  };

  const tomato: CropRecord = {
    cropId: 'crop_tomato_01',
    cropProfileId: 'tz_tomato',
    commonName: 'Tomato',
    variety: null,
    plantingDate: '2026-10-15',
    plantingMethod: 'transplant',
    currentGrowthStage: 'fruiting',
    lifecycleStatus: 'active',
    healthStatus: 'healthy',
    retiredAt: null,
    createdAt: '2026-10-15T00:00:00Z',
    updatedAt: '2026-11-22T00:00:00Z',
  };

  const exposedWatering: TaskRecord = {
    taskId: 'task_exposed_w',
    cropId: 'crop_tomato_01',
    plotId: 'plot_exposed',
    ruleId: 'tz_rule_water_exposed',
    ruleVersion: '1',
    taskCategory: 'watering',
    title: 'Tomato: Morning watering',
    instructions: 'Water base',
    steps: ['Water'],
    rationale: 'Moisture',
    estimatedDurationMinutes: 3,
    scheduledDate: '2026-11-22',
    timeZone: 'Africa/Dar_es_Salaam',
    dueAt: null,
    scheduleStatus: 'pending',
    weatherOverrideApplied: false,
    weatherOverrideReason: null,
    forecastFetchedAt: null,
    sourceRefs: [],
    diagnosisId: null,
    createdAt: '2026-11-22T00:00:00Z',
    updatedAt: '2026-11-22T00:00:00Z',
  };

  const shelteredWatering: TaskRecord = {
    ...exposedWatering,
    taskId: 'task_sheltered_w',
    plotId: 'plot_sheltered',
  };

  const result = evaluateWeatherOverrides({
    userId: 'uid_tz_1',
    localDate: '2026-11-22',
    timeZone: 'Africa/Dar_es_Salaam',
    nowIso: '2026-11-22T08:00:00Z',
    forecast: {
      rainMm24h: 18.4, // > 12.7 mm
      minTempC: 24.0,
      maxTempC: 36.2, // >= 35.0 C (Dar heat spike)
      fetchedAt: '2026-11-22T08:00:00Z',
    },
    plotsById: new Map([
      ['plot_exposed', exposedPlot],
      ['plot_sheltered', shelteredPlot],
    ]),
    activeCrops: [tomato],
    cropPlotMap: new Map([['crop_tomato_01', 'plot_exposed']]),
    existingTasksForDate: [exposedWatering, shelteredWatering],
    completedTaskIds: new Set(),
  });

  assert.equal(result.forecastStaleOrUnavailable, false);
  assert.equal(result.updatedTasks.length, 1);
  assert.equal(result.updatedTasks[0]?.taskId, 'task_exposed_w');
  assert.equal(result.updatedTasks[0]?.scheduleStatus, 'deferred_weather');
  assert.equal(result.insertedProtectionTasks.length, 1);
  assert.equal(result.insertedProtectionTasks[0]?.taskCategory, 'heat_protection');

  // Outage retains baseline care and flags stale/unavailable
  const outage = evaluateWeatherOverrides({
    userId: 'uid_tz_1',
    localDate: '2026-11-22',
    timeZone: 'Africa/Dar_es_Salaam',
    nowIso: '2026-11-22T08:00:00Z',
    forecast: null,
    plotsById: new Map([['plot_exposed', exposedPlot]]),
    activeCrops: [tomato],
    cropPlotMap: new Map([['crop_tomato_01', 'plot_exposed']]),
    existingTasksForDate: [exposedWatering],
    completedTaskIds: new Set(),
  });
  assert.equal(outage.forecastStaleOrUnavailable, true);
  assert.equal(outage.updatedTasks.length, 0);
});

test('A6: retireCrop cancels future pending tasks while preserving crop record and history', async () => {
  const requests = new Map<string, DurableRequestRecord>();
  let crop: CropRecord = {
    cropId: 'crop_okra_01',
    cropProfileId: 'tz_okra',
    commonName: 'Okra',
    variety: null,
    plantingDate: '2026-09-01',
    plantingMethod: 'direct_seed',
    currentGrowthStage: 'harvest',
    lifecycleStatus: 'active',
    healthStatus: 'healthy',
    retiredAt: null,
    createdAt: '2026-09-01T00:00:00Z',
    updatedAt: '2026-11-20T00:00:00Z',
  };

  const tasks = new Map<string, TaskRecord>([
    [
      'task_future_1',
      {
        taskId: 'task_future_1',
        cropId: 'crop_okra_01',
        plotId: 'plot_0001',
        ruleId: 'tz_rule_water_exposed',
        ruleVersion: '1',
        taskCategory: 'watering',
        title: 'Okra: Watering',
        instructions: 'Water',
        steps: ['Water'],
        rationale: 'Moisture',
        estimatedDurationMinutes: 3,
        scheduledDate: '2026-11-23',
        timeZone: 'Africa/Dar_es_Salaam',
        dueAt: null,
        scheduleStatus: 'pending',
        weatherOverrideApplied: false,
        weatherOverrideReason: null,
        forecastFetchedAt: null,
        sourceRefs: [],
        diagnosisId: null,
        createdAt: '2026-11-20T00:00:00Z',
        updatedAt: '2026-11-20T00:00:00Z',
      },
    ],
  ]);

  const repo: RetireCropRepository = {
    async getRequest(_uid, id) { return requests.get(id) ?? null; },
    async getOwnedCrop(_uid, _pid, cid) { return cid === crop.cropId ? crop : null; },
    async getUserTimeZone() { return 'Africa/Dar_es_Salaam'; },
    async getFuturePendingTasksForCrop(_uid, cid, fromDate) {
      return [...tasks.values()].filter(
        (t) => t.cropId === cid && t.scheduleStatus === 'pending' && t.scheduledDate >= fromDate,
      );
    },
    async commitRetirement({ requestRecord, retiredCrop, cancelledTasks }) {
      requests.set(requestRecord.requestId, requestRecord);
      crop = retiredCrop;
      for (const t of cancelledTasks) tasks.set(t.taskId, t);
    },
  };

  const res = await executeRetireCrop({
    auth: { uid: 'uid_tz_1' },
    requestId: 'req_retire_001',
    plotId: 'plot_0001',
    cropId: 'crop_okra_01',
    repo,
    now: new Date('2026-11-22T06:00:00Z'),
  });

  assert.equal(res.crop.lifecycleStatus, 'retired');
  assert.equal(res.cancelledTaskCount, 1);
  assert.equal(tasks.get('task_future_1')?.scheduleStatus, 'cancelled');
  assert.equal(tasks.size, 1, 'History record is retained, not deleted');
});

test('A10: deleteAccount cascades through Storage, Firestore, and Auth; 30-day image expiry preserves triage text', async () => {
  const deletedSteps: string[] = [];
  const adapter: AccountDeletionAdapter = {
    async deleteUserDiagnosticImages(uid) {
      deletedSteps.push(`storage:${uid}`);
      return { deletedFiles: 3 };
    },
    async deleteUserFirestoreTree(uid) {
      deletedSteps.push(`firestore:${uid}`);
      return { deletedDocuments: 42 };
    },
    async deleteAuthIdentity(uid) {
      deletedSteps.push(`auth:${uid}`);
    },
  };

  const delRes = await executeDeleteAccount({
    auth: { uid: 'uid_tz_del' },
    explicitConfirmation: true,
    adapter,
  });

  assert.equal(delRes.authDeleted, true);
  assert.equal(delRes.deletedFiles, 3);
  assert.equal(delRes.deletedDocuments, 42);
  assert.deepEqual(deletedSteps, ['storage:uid_tz_del', 'firestore:uid_tz_del', 'auth:uid_tz_del']);

  // 30-day image expiry purges JPEG only, keeping textual triageLog intact
  const deletedPaths: string[] = [];
  const sampleExpiredLog: TriageLogRecord = {
    diagnosisId: 'diag_old_01',
    requestId: 'req_old_01',
    cropId: null,
    plotId: null,
    imageStoragePath: 'users/uid_tz_1/diagnostics/diag_old_01.jpg',
    imageExpiresAt: '2026-11-01T00:00:00Z',
    preFlightMetrics: {
      policyVersion: 'image-quality-v1',
      laplacianVariance: 120,
      meanLuminance: 100,
      saturatedFraction: 0.05,
      subjectCheckPassed: true,
    },
    triageCard: {
      whatItIs: 'Lower leaf yellowing',
      immediateAction: 'Prune lower leaves',
      whatNotToWorryAbout: 'Normal aging',
    },
    assessmentStatus: 'supported',
    detectedAnomalyType: 'normal_growth',
    modelConfidence: 0.9,
    sourceRefs: [],
    recoveryTemplateId: null,
    createdAt: '2026-10-02T00:00:00Z',
  };

  const purgeRes = await purgeExpiredDiagnosticImages({
    now: new Date('2026-11-22T00:00:00Z'),
    adapter: {
      async findExpiredTriageLogs() { return [sampleExpiredLog]; },
      async deleteStorageObject(path) { deletedPaths.push(path); },
    },
  });
  assert.equal(purgeRes.purgedCount, 1);
  assert.deepEqual(deletedPaths, ['users/uid_tz_1/diagnostics/diag_old_01.jpg']);
});

test('OpenWeather Provider: Aggregates 24h metric rain/temp and returns null gracefully on outage', async () => {
  const mockOkFetch = (async () => ({
    ok: true,
    async json() {
      return {
        list: [
          { main: { temp_min: 23.4, temp_max: 31.0 }, rain: { '3h': 6.5 } },
          { main: { temp_min: 22.1, temp_max: 35.8 }, rain: { '3h': 8.0 } },
        ],
      };
    },
  })) as unknown as typeof fetch;

  const forecast = await fetchOpenWeatherForecast({
    apiKey: 'test-key',
    latitude: -6.7924,
    longitude: 39.2083,
    now: new Date('2026-11-22T06:00:00Z'),
    fetchImpl: mockOkFetch,
  });

  assert.ok(forecast);
  assert.equal(forecast.rainMm24h, 14.5);
  assert.equal(forecast.minTempC, 22.1);
  assert.equal(forecast.maxTempC, 35.8);

  const mockDownFetch = (async () => ({ ok: false })) as unknown as typeof fetch;
  const outage = await fetchOpenWeatherForecast({
    apiKey: 'test-key',
    latitude: -6.7924,
    longitude: 39.2083,
    fetchImpl: mockDownFetch,
  });
  assert.equal(outage, null);
});
