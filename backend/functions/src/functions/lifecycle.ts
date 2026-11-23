/**
 * Phase 4 Lifecycle Operations:
 * - `retireCrop`: sets lifecycleStatus = 'retired' and cancels future pending tasks
 *   without removing history or completed work (Acceptance Criterion A6).
 * - `deleteAccount`: idempotent cascade across all Firestore subcollections,
 *   private Storage objects, and Auth identity (Acceptance Criterion A10).
 * - `purgeExpiredDiagnosticImages`: deletes raw JPEGs past 30-day `imageExpiresAt`
 *   while preserving textual `triageLogs` and citations.
 */

import type {
  CropRecord,
  DurableRequestRecord,
  TaskRecord,
  TriageLogRecord,
} from '../types/schema.ts';
import { computeInputHash } from '../domain/identity.ts';
import { getTodayLocalDate, ValidationError } from '../validators/garden.ts';
import { ConflictError } from './initializeGarden.ts';
import { ForbiddenResourceError } from './processMentorChat.ts';

const ID_REGEX = /^[a-zA-Z0-9_-]{8,64}$/;

export interface RetireCropRepository {
  getRequest(userId: string, requestId: string): Promise<DurableRequestRecord | null>;
  getOwnedCrop(userId: string, plotId: string, cropId: string): Promise<CropRecord | null>;
  getUserTimeZone(userId: string): Promise<string>;
  getFuturePendingTasksForCrop(userId: string, cropId: string, fromLocalDate: string): Promise<TaskRecord[]>;
  commitRetirement(params: {
    userId: string;
    requestRecord: DurableRequestRecord;
    plotId: string;
    retiredCrop: CropRecord;
    cancelledTasks: TaskRecord[];
  }): Promise<void>;
}

export async function executeRetireCrop(params: {
  auth: { uid: string };
  requestId: string;
  plotId: string;
  cropId: string;
  repo: RetireCropRepository;
  now?: Date;
}): Promise<{ crop: CropRecord; cancelledTaskCount: number; idempotentReplay: boolean }> {
  if (!ID_REGEX.test(params.requestId) || !ID_REGEX.test(params.plotId) || !ID_REGEX.test(params.cropId)) {
    throw new ValidationError('Invalid requestId, plotId, or cropId.');
  }

  const now = params.now ?? new Date();
  const nowIso = now.toISOString();
  const inputHash = computeInputHash({ plotId: params.plotId, cropId: params.cropId });

  const existingReq = await params.repo.getRequest(params.auth.uid, params.requestId);
  if (existingReq) {
    if (existingReq.inputHash !== inputHash) {
      throw new ConflictError(`Request ID "${params.requestId}" already used for a different crop.`);
    }
    if (existingReq.state === 'succeeded') {
      const crop = await params.repo.getOwnedCrop(params.auth.uid, params.plotId, params.cropId);
      if (crop) {
        return { crop, cancelledTaskCount: 0, idempotentReplay: true };
      }
    }
  }

  const crop = await params.repo.getOwnedCrop(params.auth.uid, params.plotId, params.cropId);
  if (!crop) {
    throw new ForbiddenResourceError('Crop not found for authenticated user.');
  }

  const timeZone = await params.repo.getUserTimeZone(params.auth.uid);
  const todayLocal = getTodayLocalDate(timeZone, now);
  const futurePending = await params.repo.getFuturePendingTasksForCrop(params.auth.uid, crop.cropId, todayLocal);

  const retiredCrop: CropRecord = {
    ...crop,
    lifecycleStatus: 'retired',
    retiredAt: crop.retiredAt ?? nowIso,
    updatedAt: nowIso,
  };

  const cancelledTasks: TaskRecord[] = futurePending.map((t) => ({
    ...t,
    scheduleStatus: 'cancelled',
    updatedAt: nowIso,
  }));

  const requestRecord: DurableRequestRecord = {
    requestId: params.requestId,
    kind: 'retireCrop',
    inputHash,
    state: 'succeeded',
    attemptCount: (existingReq?.attemptCount ?? 0) + 1,
    leaseExpiresAt: null,
    resultId: crop.cropId,
    errorCode: null,
    retryable: false,
    createdAt: existingReq?.createdAt ?? nowIso,
    updatedAt: nowIso,
  };

  await params.repo.commitRetirement({
    userId: params.auth.uid,
    requestRecord,
    plotId: params.plotId,
    retiredCrop,
    cancelledTasks,
  });

  return {
    crop: retiredCrop,
    cancelledTaskCount: cancelledTasks.length,
    idempotentReplay: false,
  };
}

export interface AccountDeletionAdapter {
  deleteUserFirestoreTree(userId: string): Promise<{ deletedDocuments: number }>;
  deleteUserDiagnosticImages(userId: string): Promise<{ deletedFiles: number }>;
  deleteAuthIdentity(userId: string): Promise<void>;
}

export async function executeDeleteAccount(params: {
  auth: { uid: string };
  explicitConfirmation: boolean;
  adapter: AccountDeletionAdapter;
}): Promise<{ deletedUserId: string; deletedDocuments: number; deletedFiles: number; authDeleted: boolean }> {
  if (!params.explicitConfirmation) {
    throw new ValidationError('Explicit user confirmation is required for account deletion.');
  }

  // Cascade order: Storage images -> Firestore nested tree -> Auth identity
  const { deletedFiles } = await params.adapter.deleteUserDiagnosticImages(params.auth.uid);
  const { deletedDocuments } = await params.adapter.deleteUserFirestoreTree(params.auth.uid);
  await params.adapter.deleteAuthIdentity(params.auth.uid);

  return {
    deletedUserId: params.auth.uid,
    deletedDocuments,
    deletedFiles,
    authDeleted: true,
  };
}

export interface ImageExpiryAdapter {
  findExpiredTriageLogs(nowIso: string): Promise<TriageLogRecord[]>;
  deleteStorageObject(imageStoragePath: string): Promise<void>;
}

/**
 * Deletes raw diagnostic JPEGs past their 30-day `imageExpiresAt` timestamp.
 * Textual `triageLogs` and source citations remain untouched until account deletion.
 */
export async function purgeExpiredDiagnosticImages(params: {
  adapter: ImageExpiryAdapter;
  now?: Date;
}): Promise<{ purgedCount: number }> {
  const nowIso = (params.now ?? new Date()).toISOString();
  const expired = await params.adapter.findExpiredTriageLogs(nowIso);
  for (const log of expired) {
    await params.adapter.deleteStorageObject(log.imageStoragePath);
  }
  return { purgedCount: expired.length };
}
