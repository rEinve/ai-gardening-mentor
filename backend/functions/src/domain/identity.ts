/**
 * Deterministic identity helpers & growth-stage estimation.
 * Per docs/tech-requirement-document.md:
 * - Task ID derives from userId, cropId, ruleId, localDate, and occurrenceSlot
 *   (ruleVersion is stored as metadata, never part of task identity).
 * - Request IDs bind to a canonical SHA-256 inputHash to detect conflicting reuse.
 */

import { createHash } from 'node:crypto';
import type { CropProfile, GrowthStage, PlantingMethod } from '../types/schema.ts';

export function buildDeterministicTaskId(params: {
  userId: string;
  cropId: string;
  ruleId: string;
  localDate: string;
  occurrenceSlot: number;
}): string {
  const raw = `${params.userId}|${params.cropId}|${params.ruleId}|${params.localDate}|${params.occurrenceSlot}`;
  const digest = createHash('sha256').update(raw).digest('hex').slice(0, 24);
  return `task_${params.localDate.replace(/-/g, '')}_${digest}`;
}

function canonicalize(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }
  if (value !== null && typeof value === 'object') {
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(value as Record<string, unknown>).sort()) {
      sorted[key] = canonicalize((value as Record<string, unknown>)[key]);
    }
    return sorted;
  }
  return value;
}

export function computeInputHash(payload: unknown): string {
  const serialized = JSON.stringify(canonicalize(payload));
  return createHash('sha256').update(serialized).digest('hex');
}

export function daysBetweenLocalDates(startDate: string, endDate: string): number {
  const start = Date.parse(`${startDate}T00:00:00Z`);
  const end = Date.parse(`${endDate}T00:00:00Z`);
  return Math.floor((end - start) / 86_400_000);
}

export function addDaysToLocalDate(localDate: string, days: number): string {
  const ms = Date.parse(`${localDate}T00:00:00Z`) + days * 86_400_000;
  return new Date(ms).toISOString().slice(0, 10);
}

/**
 * Estimates growth stage from cropProfile, plantingMethod, and elapsed days.
 * Per TRD: calendar age is an estimate, not an observation.
 */
export function estimateGrowthStage(
  profile: CropProfile,
  plantingMethod: PlantingMethod,
  plantingDate: string,
  asOfLocalDate: string,
): GrowthStage {
  const elapsedDays = Math.max(0, daysBetweenLocalDates(plantingDate, asOfLocalDate));
  const thresholds = profile.stageEstimatesByMethod[plantingMethod];
  if (!thresholds || thresholds.length === 0) {
    return 'vegetative';
  }
  const sorted = [...thresholds].sort((a, b) => a.minDaysFromPlanting - b.minDaysFromPlanting);
  let stage: GrowthStage = sorted[0]!.stage;
  for (const item of sorted) {
    if (elapsedDays >= item.minDaysFromPlanting) {
      stage = item.stage;
    }
  }
  return stage;
}
