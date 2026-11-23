import test from 'node:test';
import assert from 'node:assert/strict';

import {
  evaluateImageQualityV1,
  IMAGE_QUALITY_V1,
  validateStoredDiagnosticImage,
  type CandidateTriageOutput,
  type StoredImageMetadata,
} from '../src/validators/triage.ts';
import {
  executeMultimodalTriage,
  InvalidModelOutputError,
  QuotaExceededError,
  type MultimodalTriageProvider,
  type TriageRepository,
} from '../src/functions/executeMultimodalTriage.ts';
import {
  executeAddRecoveryTask,
  UnsupportedActionError,
  type RecoveryTaskRepository,
} from '../src/functions/addRecoveryTask.ts';
import { ConflictError } from '../src/functions/initializeGarden.ts';
import { ValidationError } from '../src/validators/garden.ts';
import {
  TANZANIA_KNOWLEDGE_SOURCES,
  TANZANIA_TASK_TEMPLATES,
} from '../src/seeds/tanzaniaFixtures.ts';
import type {
  CropRecord,
  DurableRequestRecord,
  TaskRecord,
  TriageLogRecord,
} from '../src/types/schema.ts';

function buildValidPassageKeys(): Set<string> {
  const keys = new Set<string>();
  for (const src of TANZANIA_KNOWLEDGE_SOURCES) {
    for (const p of src.passages) {
      keys.add(`${src.sourceId}|${src.revision}|${p.passageId}`);
    }
  }
  return keys;
}

function createInMemoryTriageRepo(opts?: { dailyCount?: number; imageMeta?: StoredImageMetadata | null }): TriageRepository & {
  requests: Map<string, DurableRequestRecord>;
  logs: Map<string, TriageLogRecord>;
} {
  const requests = new Map<string, DurableRequestRecord>();
  const logs = new Map<string, TriageLogRecord>();
  const validPassages = buildValidPassageKeys();
  const validTemplates = new Set(TANZANIA_TASK_TEMPLATES.map((t) => t.id));
  const defaultMeta: StoredImageMetadata = {
    contentType: 'image/jpeg',
    sizeBytes: 180_000,
    widthPx: 1024,
    heightPx: 768,
    hasJpegMagicBytes: true,
  };

  return {
    requests,
    logs,
    async getRequest(_uid, requestId) {
      return requests.get(requestId) ?? null;
    },
    async getTriageLog(_uid, diagnosisId) {
      return logs.get(diagnosisId) ?? null;
    },
    async countDailyTriages() {
      return opts?.dailyCount ?? logs.size;
    },
    async getStoredImageMetadata() {
      return opts && 'imageMeta' in opts ? (opts.imageMeta ?? null) : defaultMeta;
    },
    async getValidPassageKeys() {
      return validPassages;
    },
    async getValidTemplateIds() {
      return validTemplates;
    },
    async saveRequest(_uid, req) {
      requests.set(req.requestId, req);
    },
    async commitTriageResult(_uid, req, log) {
      requests.set(req.requestId, req);
      logs.set(log.diagnosisId, log);
    },
  };
}

const VALID_METRICS = {
  policyVersion: 'image-quality-v1' as const,
  laplacianVariance: 100, // Exact lower bound passes
  meanLuminance: 40, // Exact lower bound passes
  saturatedFraction: 0.15, // Exact upper bound passes
  subjectCheckPassed: true,
};

const SUPPORTED_CANDIDATE: CandidateTriageOutput = {
  assessmentStatus: 'supported',
  detectedAnomalyType: 'normal_growth',
  triageCard: {
    whatItIs: 'Natural lower leaf senescence on maturing tomato.',
    immediateAction: 'Snip the bottom two yellowed leaves cleanly at the stem collar.',
    whatNotToWorryAbout: 'Not early blight; upper canopy and fruit clusters remain healthy.',
  },
  modelConfidence: 0.88,
  sourceRefs: [
    {
      sourceId: 'ewskt_growhow_tropical_veg',
      revision: 'v1-fixture',
      passageId: 'solanaceae_lower_airflow',
    },
  ],
  recoveryTemplateId: 'tpl_lower_leaf_airflow',
};

const UNCERTAIN_CANDIDATE: CandidateTriageOutput = {
  assessmentStatus: 'uncertain',
  detectedAnomalyType: null,
  triageCard: {
    whatItIs: 'Symptoms are not clear enough for a reliable identification.',
    immediateAction: 'Retake a close-up photo showing both top and underside of an affected leaf.',
    whatNotToWorryAbout: 'Avoid applying sprays until the cause is clearly identified.',
  },
  modelConfidence: null,
  sourceRefs: [],
  recoveryTemplateId: null,
};

test('A2: image-quality-v1 enforces exact thresholds and server JPEG/ownership boundary', () => {
  assert.equal(evaluateImageQualityV1(VALID_METRICS).passed, true);
  assert.equal(
    evaluateImageQualityV1({ ...VALID_METRICS, meanLuminance: 220 }).passed,
    true,
  );

  // Failures
  assert.equal(evaluateImageQualityV1({ ...VALID_METRICS, laplacianVariance: 99.9 }).passed, false);
  assert.equal(evaluateImageQualityV1({ ...VALID_METRICS, meanLuminance: 39.9 }).passed, false);
  assert.equal(evaluateImageQualityV1({ ...VALID_METRICS, meanLuminance: 220.1 }).passed, false);
  assert.equal(evaluateImageQualityV1({ ...VALID_METRICS, saturatedFraction: 0.151 }).passed, false);
  assert.equal(evaluateImageQualityV1({ ...VALID_METRICS, subjectCheckPassed: false }).passed, false);

  // Server storage boundary rejects wrong owner path or oversized image
  assert.throws(
    () =>
      validateStoredDiagnosticImage('uid_1', 'diag_0001', 'users/uid_other/diagnostics/diag_0001.jpg', {
        contentType: 'image/jpeg',
        sizeBytes: 100_000,
        widthPx: 800,
        heightPx: 600,
        hasJpegMagicBytes: true,
      }),
    ValidationError,
  );

  assert.throws(
    () =>
      validateStoredDiagnosticImage('uid_1', 'diag_0001', 'users/uid_1/diagnostics/diag_0001.jpg', {
        contentType: 'image/jpeg',
        sizeBytes: IMAGE_QUALITY_V1.MAX_BYTES + 1,
        widthPx: 800,
        heightPx: 600,
        hasJpegMagicBytes: true,
      }),
    ValidationError,
  );
});

test('A3: Durable triage replays idempotently, rejects conflicting requestId, and recovers from provider crash', async () => {
  const repo = createInMemoryTriageRepo();
  const payload = {
    requestId: 'req_triage_0001',
    diagnosisId: 'diag_tomato_0001',
    imageStoragePath: 'users/uid_tz_1/diagnostics/diag_tomato_0001.jpg',
    cropId: 'crop_tomato_01',
    plotId: 'plot_0001',
    preFlightMetrics: VALID_METRICS,
  };

  let calls = 0;
  const flakyProvider: MultimodalTriageProvider = {
    async analyzeImage() {
      calls++;
      if (calls === 1) {
        throw new Error('Transient network drop');
      }
      return SUPPORTED_CANDIDATE;
    },
  };

  // First attempt fails transiently and records retryable failed request
  await assert.rejects(() =>
    executeMultimodalTriage({ auth: { uid: 'uid_tz_1' }, rawPayload: payload, repo, provider: flakyProvider }),
  );
  assert.equal(repo.requests.get('req_triage_0001')?.state, 'failed');
  assert.equal(repo.requests.get('req_triage_0001')?.retryable, true);

  // Retry with SAME logical requestId succeeds and commits 1 triage log
  const res = await executeMultimodalTriage({
    auth: { uid: 'uid_tz_1' },
    rawPayload: payload,
    repo,
    provider: flakyProvider,
    now: new Date('2026-11-22T06:00:00Z'),
  });
  assert.equal(res.idempotentReplay, false);
  assert.equal(repo.logs.size, 1);
  assert.equal(res.triageLog.imageExpiresAt, '2026-12-22T06:00:00.000Z'); // +30 days

  // Replay after lost ack returns existing result without calling provider again
  const replay = await executeMultimodalTriage({
    auth: { uid: 'uid_tz_1' },
    rawPayload: payload,
    repo,
    provider: flakyProvider,
  });
  assert.equal(replay.idempotentReplay, true);
  assert.equal(calls, 2);

  // Conflicting reuse of same requestId is rejected
  await assert.rejects(
    () =>
      executeMultimodalTriage({
        auth: { uid: 'uid_tz_1' },
        rawPayload: { ...payload, diagnosisId: 'diag_different_02', imageStoragePath: 'users/uid_tz_1/diagnostics/diag_different_02.jpg' },
        repo,
        provider: flakyProvider,
      }),
    ConflictError,
  );
});

test('A4: Uncertain diagnosis succeeds safely; unsafe chemical guidance or fabricated citations are rejected', async () => {
  const repo = createInMemoryTriageRepo();
  const basePayload = {
    requestId: 'req_uncertain_01',
    diagnosisId: 'diag_uncertain_01',
    imageStoragePath: 'users/uid_tz_1/diagnostics/diag_uncertain_01.jpg',
    cropId: null,
    plotId: null,
    preFlightMetrics: VALID_METRICS,
  };

  const uncertainRes = await executeMultimodalTriage({
    auth: { uid: 'uid_tz_1' },
    rawPayload: basePayload,
    repo,
    provider: { async analyzeImage() { return UNCERTAIN_CANDIDATE; } },
  });
  assert.equal(uncertainRes.triageLog.assessmentStatus, 'uncertain');
  assert.equal(uncertainRes.triageLog.detectedAnomalyType, null);
  assert.equal(uncertainRes.triageLog.recoveryTemplateId, null);

  // Unsafe synthetic pesticide advice is blocked even if JSON shape is valid
  await assert.rejects(
    () =>
      executeMultimodalTriage({
        auth: { uid: 'uid_tz_1' },
        rawPayload: {
          ...basePayload,
          requestId: 'req_unsafe_0001',
          diagnosisId: 'diag_unsafe_0001',
          imageStoragePath: 'users/uid_tz_1/diagnostics/diag_unsafe_0001.jpg',
        },
        repo,
        provider: {
          async analyzeImage() {
            return {
              ...SUPPORTED_CANDIDATE,
              triageCard: {
                ...SUPPORTED_CANDIDATE.triageCard,
                immediateAction: 'Spray diluted chlorpyrifos across the tomato leaves.',
              },
            };
          },
        },
      }),
    InvalidModelOutputError,
  );
});

test('A9 Quota & Recovery Task: 10/day quota enforced and addRecoveryTask is idempotent and blocks uncertain results', async () => {
  const fullQuotaRepo = createInMemoryTriageRepo({ dailyCount: 10 });
  await assert.rejects(
    () =>
      executeMultimodalTriage({
        auth: { uid: 'uid_tz_1' },
        rawPayload: {
          requestId: 'req_quota_00011',
          diagnosisId: 'diag_quota_00011',
          imageStoragePath: 'users/uid_tz_1/diagnostics/diag_quota_00011.jpg',
          cropId: null,
          plotId: null,
          preFlightMetrics: VALID_METRICS,
        },
        repo: fullQuotaRepo,
        provider: { async analyzeImage() { return SUPPORTED_CANDIDATE; } },
      }),
    QuotaExceededError,
  );

  // Recovery task tests
  const requests = new Map<string, DurableRequestRecord>();
  const tasks = new Map<string, TaskRecord>();
  const logs = new Map<string, TriageLogRecord>([
    [
      'diag_supported_1',
      {
        diagnosisId: 'diag_supported_1',
        requestId: 'req_t1',
        cropId: 'crop_tomato_01',
        plotId: 'plot_0001',
        imageStoragePath: 'users/uid_tz_1/diagnostics/diag_supported_1.jpg',
        imageExpiresAt: '2026-12-22T06:00:00Z',
        preFlightMetrics: VALID_METRICS,
        triageCard: SUPPORTED_CANDIDATE.triageCard,
        assessmentStatus: 'supported',
        detectedAnomalyType: 'normal_growth',
        modelConfidence: 0.9,
        sourceRefs: SUPPORTED_CANDIDATE.sourceRefs,
        recoveryTemplateId: 'tpl_lower_leaf_airflow',
        createdAt: '2026-11-22T06:00:00Z',
      },
    ],
    [
      'diag_uncertain_1',
      {
        diagnosisId: 'diag_uncertain_1',
        requestId: 'req_t2',
        cropId: null,
        plotId: null,
        imageStoragePath: 'users/uid_tz_1/diagnostics/diag_uncertain_1.jpg',
        imageExpiresAt: '2026-12-22T06:00:00Z',
        preFlightMetrics: VALID_METRICS,
        triageCard: UNCERTAIN_CANDIDATE.triageCard,
        assessmentStatus: 'uncertain',
        detectedAnomalyType: null,
        modelConfidence: null,
        sourceRefs: [],
        recoveryTemplateId: null,
        createdAt: '2026-11-22T06:00:00Z',
      },
    ],
  ]);

  const activeCrop: CropRecord = {
    cropId: 'crop_tomato_01',
    cropProfileId: 'tz_tomato',
    commonName: 'Tomato',
    variety: 'Tengeru 97',
    plantingDate: '2026-10-15',
    plantingMethod: 'transplant',
    currentGrowthStage: 'fruiting',
    lifecycleStatus: 'active',
    healthStatus: 'healthy',
    retiredAt: null,
    createdAt: '2026-10-15T06:00:00Z',
    updatedAt: '2026-11-22T06:00:00Z',
  };

  const recoveryRepo: RecoveryTaskRepository = {
    async getRequest(_uid, id) { return requests.get(id) ?? null; },
    async getTask(_uid, id) { return tasks.get(id) ?? null; },
    async getTriageLog(_uid, id) { return logs.get(id) ?? null; },
    async getOwnedCrop(_uid, _plotId, cropId) { return cropId === activeCrop.cropId ? activeCrop : null; },
    async getUserTimeZone() { return 'Africa/Dar_es_Salaam'; },
    async getTaskTemplate(id) { return TANZANIA_TASK_TEMPLATES.find((t) => t.id === id) ?? null; },
    async commitRecoveryTask(_uid, req, task) {
      requests.set(req.requestId, req);
      tasks.set(task.taskId, task);
    },
  };

  const recoveryInput = {
    requestId: 'req_recovery_001',
    diagnosisId: 'diag_supported_1',
    plotId: 'plot_0001',
    cropId: 'crop_tomato_01',
  };

  const created = await executeAddRecoveryTask({
    auth: { uid: 'uid_tz_1' },
    rawPayload: recoveryInput,
    repo: recoveryRepo,
    now: new Date('2026-11-22T06:00:00Z'),
  });
  assert.equal(created.idempotentReplay, false);
  assert.equal(created.task.taskCategory, 'recovery');
  assert.equal(created.task.diagnosisId, 'diag_supported_1');

  const replayed = await executeAddRecoveryTask({
    auth: { uid: 'uid_tz_1' },
    rawPayload: recoveryInput,
    repo: recoveryRepo,
    now: new Date('2026-11-22T06:00:00Z'),
  });
  assert.equal(replayed.idempotentReplay, true);
  assert.equal(tasks.size, 1);

  // Uncertain diagnosis cannot create a recovery task
  await assert.rejects(
    () =>
      executeAddRecoveryTask({
        auth: { uid: 'uid_tz_1' },
        rawPayload: { ...recoveryInput, requestId: 'req_recovery_002', diagnosisId: 'diag_uncertain_1' },
        repo: recoveryRepo,
      }),
    UnsupportedActionError,
  );
});
