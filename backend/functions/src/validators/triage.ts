/**
 * Phase 2 Validators:
 * - Canonical `image-quality-v1` thresholds (equality at stated bounds passes)
 * - Private storage ownership & JPEG binary/size/dimension verification
 * - Strict server-side triage output & organic safety boundary validation
 * - `addRecoveryTask` input validation
 */

import type {
  AssessmentStatus,
  DetectedAnomalyType,
  PreFlightMetrics,
  SourceRef,
  TriageCard,
} from '../types/schema.ts';
import { LIMITS, ValidationError } from './garden.ts';

export const IMAGE_QUALITY_V1 = {
  POLICY_VERSION: 'image-quality-v1' as const,
  MIN_LAPLACIAN_VARIANCE: 100,
  MIN_MEAN_LUMINANCE: 40,
  MAX_MEAN_LUMINANCE: 220,
  MAX_SATURATED_FRACTION: 0.15,
  MAX_LONGEST_EDGE_PX: 1024,
  MAX_BYTES: 350_000,
  IMAGE_RETENTION_DAYS: 30,
  DAILY_TRIAGE_QUOTA: 10,
} as const;

const ID_REGEX = /^[a-zA-Z0-9_-]{8,64}$/;

const ANOMALY_TYPES = new Set<DetectedAnomalyType>([
  'pest',
  'fungal_blight',
  'bacterial_blight',
  'watering_symptom',
  'nutrient_deficiency',
  'normal_growth',
]);

// Prohibits synthetic chemical pesticides / commercial neurotoxins / unsafe chemical advice
const UNSAFE_TREATMENT_PATTERNS: readonly RegExp[] = [
  /\borganophosphate/i,
  /\bcarbofuran\b/i,
  /\bchlorpyrifos\b/i,
  /\bimidacloprid\b/i,
  /\bglyphosate\b/i,
  /\bparaquat\b/i,
  /\bmalathion\b/i,
  /\bddt\b/i,
  /\bbleach\b/i,
  /\bgasoline\b/i,
  /\bkerosene\b/i,
  /\bmotor oil\b/i,
  /\bsynthetic pesticide/i,
  /\bchemical poison/i,
];

export interface ImageQualityEvaluation {
  passed: boolean;
  reasons: string[];
}

export function evaluateImageQualityV1(metrics: PreFlightMetrics): ImageQualityEvaluation {
  const reasons: string[] = [];

  if (metrics.policyVersion !== IMAGE_QUALITY_V1.POLICY_VERSION) {
    reasons.push(`Unsupported image policy version: ${String(metrics.policyVersion)}`);
  }
  if (metrics.laplacianVariance < IMAGE_QUALITY_V1.MIN_LAPLACIAN_VARIANCE) {
    reasons.push('Image is too blurry (focus sharper on the affected leaf).');
  }
  if (metrics.meanLuminance < IMAGE_QUALITY_V1.MIN_MEAN_LUMINANCE) {
    reasons.push('Image is too dark (move to brighter natural light).');
  }
  if (metrics.meanLuminance > IMAGE_QUALITY_V1.MAX_MEAN_LUMINANCE) {
    reasons.push('Image is overexposed (shade the leaf from harsh glare).');
  }
  if (metrics.saturatedFraction > IMAGE_QUALITY_V1.MAX_SATURATED_FRACTION) {
    reasons.push('Too many blown-out pixels (reduce direct glare on the leaf).');
  }
  if (!metrics.subjectCheckPassed) {
    reasons.push('No plant leaf or garden soil clearly detected in frame.');
  }

  return { passed: reasons.length === 0, reasons };
}

export interface StoredImageMetadata {
  contentType: string;
  sizeBytes: number;
  widthPx: number;
  heightPx: number;
  hasJpegMagicBytes: boolean;
}

export function validateStoredDiagnosticImage(
  userId: string,
  diagnosisId: string,
  imageStoragePath: string,
  meta: StoredImageMetadata,
): void {
  const expectedPath = `users/${userId}/diagnostics/${diagnosisId}.jpg`;
  if (imageStoragePath !== expectedPath) {
    throw new ValidationError('Storage path must match owned private diagnostic path.');
  }
  if (meta.contentType !== 'image/jpeg' || !meta.hasJpegMagicBytes) {
    throw new ValidationError('Uploaded diagnostic image must be a valid JPEG.');
  }
  if (meta.sizeBytes <= 0 || meta.sizeBytes > IMAGE_QUALITY_V1.MAX_BYTES) {
    throw new ValidationError(`Image size must be between 1 and ${IMAGE_QUALITY_V1.MAX_BYTES} bytes.`);
  }
  const longestEdge = Math.max(meta.widthPx, meta.heightPx);
  if (meta.widthPx <= 0 || meta.heightPx <= 0 || longestEdge > IMAGE_QUALITY_V1.MAX_LONGEST_EDGE_PX) {
    throw new ValidationError(`Image longest edge must not exceed ${IMAGE_QUALITY_V1.MAX_LONGEST_EDGE_PX}px.`);
  }
}

export interface ExecuteTriageInput {
  requestId: string;
  diagnosisId: string;
  imageStoragePath: string;
  cropId: string | null;
  plotId: string | null;
  preFlightMetrics: PreFlightMetrics;
}

export function validateExecuteTriageInput(raw: unknown): ExecuteTriageInput {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new ValidationError('Triage payload must be an object.');
  }
  const obj = raw as Record<string, unknown>;
  const allowed = new Set(['requestId', 'diagnosisId', 'imageStoragePath', 'cropId', 'plotId', 'preFlightMetrics']);
  for (const key of Object.keys(obj)) {
    if (!allowed.has(key)) {
      throw new ValidationError(`Unexpected field "${key}" in executeMultimodalTriage.`);
    }
  }

  if (typeof obj.requestId !== 'string' || !ID_REGEX.test(obj.requestId)) {
    throw new ValidationError('Invalid requestId.');
  }
  if (typeof obj.diagnosisId !== 'string' || !ID_REGEX.test(obj.diagnosisId)) {
    throw new ValidationError('Invalid diagnosisId.');
  }
  if (typeof obj.imageStoragePath !== 'string' || obj.imageStoragePath.length === 0) {
    throw new ValidationError('imageStoragePath is required.');
  }
  if (obj.cropId !== null && (typeof obj.cropId !== 'string' || !ID_REGEX.test(obj.cropId))) {
    throw new ValidationError('cropId must be null or a valid ID.');
  }
  if (obj.plotId !== null && (typeof obj.plotId !== 'string' || !ID_REGEX.test(obj.plotId))) {
    throw new ValidationError('plotId must be null or a valid ID.');
  }

  const m = obj.preFlightMetrics as Record<string, unknown> | undefined;
  if (!m || typeof m !== 'object') {
    throw new ValidationError('preFlightMetrics is required.');
  }

  const metrics: PreFlightMetrics = {
    policyVersion: m.policyVersion as 'image-quality-v1',
    laplacianVariance: Number(m.laplacianVariance),
    meanLuminance: Number(m.meanLuminance),
    saturatedFraction: Number(m.saturatedFraction),
    subjectCheckPassed: Boolean(m.subjectCheckPassed),
  };

  const evalResult = evaluateImageQualityV1(metrics);
  if (!evalResult.passed) {
    throw new ValidationError(`Image failed image-quality-v1: ${evalResult.reasons.join(' ')}`);
  }

  return {
    requestId: obj.requestId,
    diagnosisId: obj.diagnosisId,
    imageStoragePath: obj.imageStoragePath,
    cropId: obj.cropId as string | null,
    plotId: obj.plotId as string | null,
    preFlightMetrics: metrics,
  };
}

export interface CandidateTriageOutput {
  assessmentStatus: AssessmentStatus;
  detectedAnomalyType: DetectedAnomalyType | null;
  triageCard: TriageCard;
  modelConfidence: number | null;
  sourceRefs: SourceRef[];
  recoveryTemplateId: string | null;
}

export function validateModelTriageOutput(
  candidate: CandidateTriageOutput,
  validPassageKeys: ReadonlySet<string>,
  validTemplateIds: ReadonlySet<string>,
): { valid: boolean; reason?: string } {
  const { triageCard, assessmentStatus, detectedAnomalyType, modelConfidence, sourceRefs, recoveryTemplateId } =
    candidate;

  // Bound lengths on all 3 triage fields
  for (const [field, value] of Object.entries(triageCard)) {
    if (typeof value !== 'string' || value.trim().length === 0 || value.length > LIMITS.TRIAGE_FIELD_MAX) {
      return { valid: false, reason: `triageCard.${field} must be 1-${LIMITS.TRIAGE_FIELD_MAX} chars.` };
    }
    for (const pattern of UNSAFE_TREATMENT_PATTERNS) {
      if (pattern.test(value)) {
        return { valid: false, reason: `Unsafe treatment guidance detected in triageCard.${field}.` };
      }
    }
  }

  if (assessmentStatus === 'uncertain') {
    if (detectedAnomalyType !== null) {
      return { valid: false, reason: 'Uncertain assessment must set detectedAnomalyType to null.' };
    }
    if (recoveryTemplateId !== null) {
      return { valid: false, reason: 'Uncertain assessment cannot authorize a recovery template.' };
    }
  } else {
    if (!detectedAnomalyType || !ANOMALY_TYPES.has(detectedAnomalyType)) {
      return { valid: false, reason: 'Supported assessment requires a valid detectedAnomalyType.' };
    }
    if (sourceRefs.length === 0) {
      return { valid: false, reason: 'Supported assessment requires at least one approved sourceRef.' };
    }
  }

  if (modelConfidence !== null && (typeof modelConfidence !== 'number' || modelConfidence < 0 || modelConfidence > 1)) {
    return { valid: false, reason: 'modelConfidence must be null or in [0, 1].' };
  }

  if (sourceRefs.length > LIMITS.CITATIONS_MAX) {
    return { valid: false, reason: `At most ${LIMITS.CITATIONS_MAX} citations allowed.` };
  }
  for (const ref of sourceRefs) {
    const key = `${ref.sourceId}|${ref.revision}|${ref.passageId}`;
    if (!validPassageKeys.has(key)) {
      return { valid: false, reason: `Unresolved citation reference: ${key}` };
    }
  }

  if (recoveryTemplateId !== null && !validTemplateIds.has(recoveryTemplateId)) {
    return { valid: false, reason: `Unreviewed recoveryTemplateId: ${recoveryTemplateId}` };
  }

  return { valid: true };
}

export interface AddRecoveryTaskInput {
  requestId: string;
  diagnosisId: string;
  plotId: string;
  cropId: string;
}

export function validateAddRecoveryTaskInput(raw: unknown): AddRecoveryTaskInput {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new ValidationError('addRecoveryTask payload must be an object.');
  }
  const obj = raw as Record<string, unknown>;
  const allowed = new Set(['requestId', 'diagnosisId', 'plotId', 'cropId']);
  for (const key of Object.keys(obj)) {
    if (!allowed.has(key)) {
      throw new ValidationError(`Unexpected field "${key}" in addRecoveryTask.`);
    }
  }
  for (const field of ['requestId', 'diagnosisId', 'plotId', 'cropId'] as const) {
    if (typeof obj[field] !== 'string' || !ID_REGEX.test(obj[field] as string)) {
      throw new ValidationError(`Invalid ${field}.`);
    }
  }
  return {
    requestId: obj.requestId as string,
    diagnosisId: obj.diagnosisId as string,
    plotId: obj.plotId as string,
    cropId: obj.cropId as string,
  };
}
