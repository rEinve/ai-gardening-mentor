/**
 * Durable Multimodal Triage Worker (`executeMultimodalTriage`) — Phase 2
 *
 * Enforces:
 * - Auth ownership & private JPEG validation (image-quality-v1 + server binary/size check)
 * - Server-authoritative quota: 10 triages/user/day
 * - Idempotent `requestId` + `inputHash` binding with lease/retry protection
 * - Strict output validation (organic safety filter, citation resolution, uncertain fallback)
 * - 30-day image expiry metadata (`imageExpiresAt`)
 */

import type { DurableRequestRecord, TriageLogRecord } from '../types/schema.ts';
import { computeInputHash } from '../domain/identity.ts';
import { ConflictError } from './initializeGarden.ts';
import {
  IMAGE_QUALITY_V1,
  validateExecuteTriageInput,
  validateModelTriageOutput,
  validateStoredDiagnosticImage,
  type CandidateTriageOutput,
  type StoredImageMetadata,
} from '../validators/triage.ts';

export class QuotaExceededError extends Error {
  public readonly code = 'RESOURCE_EXHAUSTED';
  public readonly dailyLimit = IMAGE_QUALITY_V1.DAILY_TRIAGE_QUOTA;
  constructor(message: string) {
    super(message);
    this.name = 'QuotaExceededError';
  }
}

export class InvalidModelOutputError extends Error {
  public readonly code = 'FAILED_PRECONDITION';
  public readonly retryable = true;
  constructor(message: string) {
    super(message);
    this.name = 'InvalidModelOutputError';
  }
}

export interface MultimodalTriageProvider {
  analyzeImage(params: {
    imageStoragePath: string;
    cropId: string | null;
    plotId: string | null;
  }): Promise<CandidateTriageOutput>;
}

export interface TriageRepository {
  getRequest(userId: string, requestId: string): Promise<DurableRequestRecord | null>;
  getTriageLog(userId: string, diagnosisId: string): Promise<TriageLogRecord | null>;
  countDailyTriages(userId: string, utcDatePrefix: string): Promise<number>;
  getStoredImageMetadata(imageStoragePath: string): Promise<StoredImageMetadata | null>;
  getValidPassageKeys(): Promise<Set<string>>;
  getValidTemplateIds(): Promise<Set<string>>;
  saveRequest(userId: string, req: DurableRequestRecord): Promise<void>;
  commitTriageResult(userId: string, req: DurableRequestRecord, log: TriageLogRecord): Promise<void>;
}

export interface ExecuteTriageResult {
  requestId: string;
  diagnosisId: string;
  triageLog: TriageLogRecord;
  idempotentReplay: boolean;
}

const LEASE_DURATION_MS = 30_000;
const MAX_ATTEMPTS = 3;

export async function executeMultimodalTriage(params: {
  auth: { uid: string };
  rawPayload: unknown;
  repo: TriageRepository;
  provider: MultimodalTriageProvider;
  now?: Date;
}): Promise<ExecuteTriageResult> {
  const now = params.now ?? new Date();
  const nowIso = now.toISOString();
  const input = validateExecuteTriageInput(params.rawPayload);

  const inputHash = computeInputHash({
    diagnosisId: input.diagnosisId,
    imageStoragePath: input.imageStoragePath,
    cropId: input.cropId,
    plotId: input.plotId,
  });

  // 1. Check durable request state for idempotency / conflicting reuse / active lease
  const existingReq = await params.repo.getRequest(params.auth.uid, input.requestId);
  if (existingReq) {
    if (existingReq.inputHash !== inputHash) {
      throw new ConflictError(`Request ID "${input.requestId}" already used with different triage inputs.`);
    }
    if (existingReq.state === 'succeeded' && existingReq.resultId) {
      const existingLog = await params.repo.getTriageLog(params.auth.uid, existingReq.resultId);
      if (existingLog) {
        return {
          requestId: input.requestId,
          diagnosisId: existingLog.diagnosisId,
          triageLog: existingLog,
          idempotentReplay: true,
        };
      }
    }
    if (existingReq.attemptCount >= MAX_ATTEMPTS && existingReq.state === 'failed') {
      throw new InvalidModelOutputError('Maximum triage retry attempts exceeded for this request.');
    }
  }

  // 2. Server-authoritative daily quota check (only for fresh logical requests)
  if (!existingReq) {
    const utcDay = nowIso.slice(0, 10);
    const usedToday = await params.repo.countDailyTriages(params.auth.uid, utcDay);
    if (usedToday >= IMAGE_QUALITY_V1.DAILY_TRIAGE_QUOTA) {
      throw new QuotaExceededError(
        `Daily triage limit reached (${IMAGE_QUALITY_V1.DAILY_TRIAGE_QUOTA}/day). Resets at 00:00 UTC.`,
      );
    }
  }

  // 3. Server-side Storage ownership, format, dimension, and size check
  const imageMeta = await params.repo.getStoredImageMetadata(input.imageStoragePath);
  if (!imageMeta) {
    throw new InvalidModelOutputError('Diagnostic image not found in private storage.');
  }
  validateStoredDiagnosticImage(params.auth.uid, input.diagnosisId, input.imageStoragePath, imageMeta);

  // 4. Acquire processing lease
  const attemptCount = (existingReq?.attemptCount ?? 0) + 1;
  const leaseExpiresAt = new Date(now.getTime() + LEASE_DURATION_MS).toISOString();
  const processingReq: DurableRequestRecord = {
    requestId: input.requestId,
    kind: 'executeMultimodalTriage',
    inputHash,
    state: 'processing',
    attemptCount,
    leaseExpiresAt,
    resultId: null,
    errorCode: null,
    retryable: true,
    createdAt: existingReq?.createdAt ?? nowIso,
    updatedAt: nowIso,
  };
  await params.repo.saveRequest(params.auth.uid, processingReq);

  // 5. Call multimodal provider and validate candidate output before finalizing
  try {
    const candidate = await params.provider.analyzeImage({
      imageStoragePath: input.imageStoragePath,
      cropId: input.cropId,
      plotId: input.plotId,
    });

    const [validPassages, validTemplates] = await Promise.all([
      params.repo.getValidPassageKeys(),
      params.repo.getValidTemplateIds(),
    ]);

    const check = validateModelTriageOutput(candidate, validPassages, validTemplates);
    if (!check.valid) {
      const failedReq: DurableRequestRecord = {
        ...processingReq,
        state: 'failed',
        leaseExpiresAt: null,
        errorCode: 'INVALID_MODEL_OUTPUT',
        retryable: attemptCount < MAX_ATTEMPTS,
        updatedAt: new Date().toISOString(),
      };
      await params.repo.saveRequest(params.auth.uid, failedReq);
      throw new InvalidModelOutputError(`Model output rejected: ${check.reason}`);
    }

    const expiresAt = new Date(
      now.getTime() + IMAGE_QUALITY_V1.IMAGE_RETENTION_DAYS * 86_400_000,
    ).toISOString();

    const triageLog: TriageLogRecord = {
      diagnosisId: input.diagnosisId,
      requestId: input.requestId,
      cropId: input.cropId,
      plotId: input.plotId,
      imageStoragePath: input.imageStoragePath,
      imageExpiresAt: expiresAt,
      preFlightMetrics: input.preFlightMetrics,
      triageCard: candidate.triageCard,
      assessmentStatus: candidate.assessmentStatus,
      detectedAnomalyType: candidate.detectedAnomalyType,
      modelConfidence: candidate.modelConfidence,
      sourceRefs: [...candidate.sourceRefs],
      recoveryTemplateId: candidate.recoveryTemplateId,
      createdAt: nowIso,
    };

    const succeededReq: DurableRequestRecord = {
      ...processingReq,
      state: 'succeeded',
      leaseExpiresAt: null,
      resultId: triageLog.diagnosisId,
      errorCode: null,
      retryable: false,
      updatedAt: nowIso,
    };

    await params.repo.commitTriageResult(params.auth.uid, succeededReq, triageLog);

    return {
      requestId: input.requestId,
      diagnosisId: triageLog.diagnosisId,
      triageLog,
      idempotentReplay: false,
    };
  } catch (err) {
    if (err instanceof InvalidModelOutputError) {
      throw err;
    }
    const failedReq: DurableRequestRecord = {
      ...processingReq,
      state: 'failed',
      leaseExpiresAt: null,
      errorCode: 'PROVIDER_ERROR',
      retryable: attemptCount < MAX_ATTEMPTS,
      updatedAt: new Date().toISOString(),
    };
    await params.repo.saveRequest(params.auth.uid, failedReq);
    throw err;
  }
}
