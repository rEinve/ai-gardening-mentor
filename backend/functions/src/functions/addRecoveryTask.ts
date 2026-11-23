/**
 * Idempotent `addRecoveryTask` service (Phase 2).
 *
 * Creates exactly ONE recovery task from a reviewed task template authorized by
 * a specific owned `triageLogs/{diagnosisId}` record. Returns UnsupportedActionError
 * if the diagnosis is uncertain or has no authorized recovery template.
 */

import type {
  CropRecord,
  DurableRequestRecord,
  TaskRecord,
  TaskTemplate,
  TriageLogRecord,
} from '../types/schema.ts';
import { buildDeterministicTaskId, computeInputHash } from '../domain/identity.ts';
import { getTodayLocalDate } from '../validators/garden.ts';
import { validateAddRecoveryTaskInput } from '../validators/triage.ts';
import { ConflictError } from './initializeGarden.ts';

export class UnsupportedActionError extends Error {
  public readonly code = 'FAILED_PRECONDITION';
  constructor(message: string) {
    super(message);
    this.name = 'UnsupportedActionError';
  }
}

export interface RecoveryTaskRepository {
  getRequest(userId: string, requestId: string): Promise<DurableRequestRecord | null>;
  getTask(userId: string, taskId: string): Promise<TaskRecord | null>;
  getTriageLog(userId: string, diagnosisId: string): Promise<TriageLogRecord | null>;
  getOwnedCrop(userId: string, plotId: string, cropId: string): Promise<CropRecord | null>;
  getUserTimeZone(userId: string): Promise<string>;
  getTaskTemplate(templateId: string): Promise<TaskTemplate | null>;
  commitRecoveryTask(userId: string, req: DurableRequestRecord, task: TaskRecord): Promise<void>;
}

export interface AddRecoveryTaskResult {
  requestId: string;
  task: TaskRecord;
  idempotentReplay: boolean;
}

export async function executeAddRecoveryTask(params: {
  auth: { uid: string };
  rawPayload: unknown;
  repo: RecoveryTaskRepository;
  now?: Date;
}): Promise<AddRecoveryTaskResult> {
  const now = params.now ?? new Date();
  const nowIso = now.toISOString();
  const input = validateAddRecoveryTaskInput(params.rawPayload);

  const inputHash = computeInputHash({
    diagnosisId: input.diagnosisId,
    plotId: input.plotId,
    cropId: input.cropId,
  });

  const existingReq = await params.repo.getRequest(params.auth.uid, input.requestId);
  if (existingReq) {
    if (existingReq.inputHash !== inputHash) {
      throw new ConflictError(`Request ID "${input.requestId}" already used with different recovery inputs.`);
    }
    if (existingReq.state === 'succeeded' && existingReq.resultId) {
      const existingTask = await params.repo.getTask(params.auth.uid, existingReq.resultId);
      if (existingTask) {
        return { requestId: input.requestId, task: existingTask, idempotentReplay: true };
      }
    }
  }

  const diagnosis = await params.repo.getTriageLog(params.auth.uid, input.diagnosisId);
  if (!diagnosis) {
    throw new UnsupportedActionError('Diagnostic result not found for this user.');
  }
  if (diagnosis.assessmentStatus !== 'supported' || !diagnosis.recoveryTemplateId) {
    throw new UnsupportedActionError('No reviewed recovery task template is available for this diagnosis.');
  }

  const crop = await params.repo.getOwnedCrop(params.auth.uid, input.plotId, input.cropId);
  if (!crop || crop.lifecycleStatus === 'retired') {
    throw new UnsupportedActionError('Selected crop does not exist or has been retired.');
  }

  const template = await params.repo.getTaskTemplate(diagnosis.recoveryTemplateId);
  if (!template || template.reviewStatus === 'deprecated') {
    throw new UnsupportedActionError('Authorized recovery task template is unavailable.');
  }

  const timeZone = await params.repo.getUserTimeZone(params.auth.uid);
  const todayLocal = getTodayLocalDate(timeZone, now);
  const taskId = buildDeterministicTaskId({
    userId: params.auth.uid,
    cropId: crop.cropId,
    ruleId: `recovery_${diagnosis.diagnosisId}`,
    localDate: todayLocal,
    occurrenceSlot: 1,
  });

  const task: TaskRecord = {
    taskId,
    cropId: crop.cropId,
    plotId: input.plotId,
    ruleId: `recovery_${diagnosis.diagnosisId}`,
    ruleVersion: template.revision,
    taskCategory: 'recovery',
    title: `${crop.commonName}: ${template.title}`.slice(0, 60),
    instructions: template.instructions,
    steps: [...template.steps],
    rationale: template.rationale,
    estimatedDurationMinutes: template.estimatedDurationMinutes,
    scheduledDate: todayLocal,
    timeZone,
    dueAt: null,
    scheduleStatus: 'pending',
    weatherOverrideApplied: false,
    weatherOverrideReason: null,
    forecastFetchedAt: null,
    sourceRefs: [...template.sourceRefs],
    diagnosisId: diagnosis.diagnosisId,
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  const requestRecord: DurableRequestRecord = {
    requestId: input.requestId,
    kind: 'addRecoveryTask',
    inputHash,
    state: 'succeeded',
    attemptCount: (existingReq?.attemptCount ?? 0) + 1,
    leaseExpiresAt: null,
    resultId: task.taskId,
    errorCode: null,
    retryable: false,
    createdAt: existingReq?.createdAt ?? nowIso,
    updatedAt: nowIso,
  };

  await params.repo.commitRecoveryTask(params.auth.uid, requestRecord, task);

  return { requestId: input.requestId, task, idempotentReplay: false };
}
