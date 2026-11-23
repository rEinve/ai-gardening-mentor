/**
 * Idempotent `initializeGarden` service (Phase 1 — Acceptance Criterion A1).
 *
 * - Derives `userId` strictly from Firebase Auth context (never from client payload).
 * - Binds `requestId` to canonical `inputHash`; conflicting reuse throws ConflictError.
 * - Retrying the same `requestId` + `inputHash` returns the existing result without
 *   duplicating plots, crops, or 7-day tasks.
 */

import type {
  CareRule,
  CropProfile,
  CropRecord,
  DurableRequestRecord,
  PlotRecord,
  TaskRecord,
  TaskTemplate,
  UserProfile,
} from '../types/schema.ts';
import { generateSevenDayCadence } from '../domain/cadence.ts';
import { computeInputHash, estimateGrowthStage } from '../domain/identity.ts';
import { getTodayLocalDate, validateInitializeGardenInput } from '../validators/garden.ts';

export class ConflictError extends Error {
  public readonly code = 'ALREADY_EXISTS';
  constructor(message: string) {
    super(message);
    this.name = 'ConflictError';
  }
}

export interface InitializeGardenResult {
  requestId: string;
  userId: string;
  plotCount: number;
  cropCount: number;
  scheduledTaskCount: number;
  idempotentReplay: boolean;
}

export interface GardenInitRepository {
  getRequest(userId: string, requestId: string): Promise<DurableRequestRecord | null>;
  getExistingCounts(userId: string): Promise<{ plotCount: number; cropCount: number; taskCount: number }>;
  getReferenceData(): Promise<{
    cropProfiles: Map<string, CropProfile>;
    careRules: CareRule[];
    taskTemplates: Map<string, TaskTemplate>;
  }>;
  commitInitialization(params: {
    userId: string;
    requestRecord: DurableRequestRecord;
    profile: UserProfile;
    plots: PlotRecord[];
    cropsByPlotId: Map<string, CropRecord[]>;
    tasks: TaskRecord[];
  }): Promise<void>;
}

export async function executeInitializeGarden(params: {
  auth: { uid: string; email: string | null; isAnonymous: boolean };
  rawPayload: unknown;
  repo: GardenInitRepository;
  now?: Date;
}): Promise<InitializeGardenResult> {
  const now = params.now ?? new Date();
  const nowIso = now.toISOString();
  const { cropProfiles, careRules, taskTemplates } = await params.repo.getReferenceData();
  const supportedIds = new Set<string>(cropProfiles.keys());

  const input = validateInitializeGardenInput(params.rawPayload, supportedIds, now);
  const inputHash = computeInputHash({
    displayName: input.displayName,
    geographicLocation: input.geographicLocation,
    timeZone: input.timeZone,
    unitPreference: input.unitPreference,
    gardenExperienceLevel: input.gardenExperienceLevel,
    plots: input.plots,
  });

  // Check idempotency / conflicting requestId reuse
  const existingReq = await params.repo.getRequest(params.auth.uid, input.requestId);
  if (existingReq) {
    if (existingReq.inputHash !== inputHash) {
      throw new ConflictError(
        `Request ID "${input.requestId}" was already used with different input parameters.`,
      );
    }
    if (existingReq.state === 'succeeded') {
      const counts = await params.repo.getExistingCounts(params.auth.uid);
      return {
        requestId: input.requestId,
        userId: params.auth.uid,
        plotCount: counts.plotCount,
        cropCount: counts.cropCount,
        scheduledTaskCount: counts.taskCount,
        idempotentReplay: true,
      };
    }
  }

  const todayLocal = getTodayLocalDate(input.timeZone, now);

  const profile: UserProfile = {
    userId: params.auth.uid,
    displayName: input.displayName,
    email: params.auth.email,
    isAnonymous: params.auth.isAnonymous,
    geographicLocation: input.geographicLocation,
    timeZone: input.timeZone,
    unitPreference: input.unitPreference,
    gardenExperienceLevel: input.gardenExperienceLevel,
    fcmDeviceTokens: [],
    createdAt: nowIso,
    updatedAt: nowIso,
  };

  const plots: PlotRecord[] = [];
  const cropsByPlotId = new Map<string, CropRecord[]>();
  let totalCrops = 0;

  for (const p of input.plots) {
    plots.push({
      plotId: p.plotId,
      name: p.name,
      plotType: p.plotType,
      rainExposure: p.rainExposure,
      dimensions: p.dimensions,
      sunlightExposure: p.sunlightExposure,
      createdAt: nowIso,
      updatedAt: nowIso,
    });

    const cropRecords: CropRecord[] = p.crops.map((c) => {
      const cropProfile = cropProfiles.get(c.cropProfileId)!;
      const estimatedStage = estimateGrowthStage(
        cropProfile,
        c.plantingMethod,
        c.plantingDate,
        todayLocal,
      );
      totalCrops++;
      return {
        cropId: c.cropId,
        cropProfileId: c.cropProfileId,
        commonName: cropProfile.commonName,
        variety: c.variety,
        plantingDate: c.plantingDate,
        plantingMethod: c.plantingMethod,
        currentGrowthStage: estimatedStage,
        lifecycleStatus: 'active',
        healthStatus: 'healthy',
        retiredAt: null,
        createdAt: nowIso,
        updatedAt: nowIso,
      };
    });

    cropsByPlotId.set(p.plotId, cropRecords);
  }

  const tasks = generateSevenDayCadence({
    userId: params.auth.uid,
    regionCode: input.geographicLocation.countryCode,
    timeZone: input.timeZone,
    startLocalDate: todayLocal,
    horizonDays: 7,
    nowIso,
    plots,
    cropsByPlotId,
    cropProfiles,
    careRules,
    taskTemplates,
    completedTaskIds: new Set<string>(),
  });

  const requestRecord: DurableRequestRecord = {
    requestId: input.requestId,
    kind: 'initializeGarden',
    inputHash,
    state: 'succeeded',
    attemptCount: (existingReq?.attemptCount ?? 0) + 1,
    leaseExpiresAt: null,
    resultId: params.auth.uid,
    errorCode: null,
    retryable: false,
    createdAt: existingReq?.createdAt ?? nowIso,
    updatedAt: nowIso,
  };

  await params.repo.commitInitialization({
    userId: params.auth.uid,
    requestRecord,
    profile,
    plots,
    cropsByPlotId,
    tasks,
  });

  return {
    requestId: input.requestId,
    userId: params.auth.uid,
    plotCount: plots.length,
    cropCount: totalCrops,
    scheduledTaskCount: tasks.length,
    idempotentReplay: false,
  };
}
