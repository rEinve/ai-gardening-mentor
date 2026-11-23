/**
 * Deterministic 7-day rolling care cadence generator.
 * - Upserts deterministic task IDs for 7 local dates starting at startLocalDate.
 * - Skips retired crops; keeps harvest-stage active crops scheduled.
 * - Skips tasks that already have accepted completion events (never regenerates completed work).
 * - Filters rules by region, growth stage, planting method, and plot rainExposure.
 */

import type {
  CareRule,
  CropProfile,
  CropRecord,
  PlotRecord,
  TaskRecord,
  TaskTemplate,
} from '../types/schema.ts';
import {
  addDaysToLocalDate,
  buildDeterministicTaskId,
  daysBetweenLocalDates,
  estimateGrowthStage,
} from './identity.ts';

export interface CadenceContext {
  userId: string;
  regionCode: string; // e.g., "TZ"
  timeZone: string; // e.g., "Africa/Dar_es_Salaam"
  startLocalDate: string; // YYYY-MM-DD
  horizonDays?: number; // default 7
  nowIso: string;
  plots: readonly PlotRecord[];
  cropsByPlotId: ReadonlyMap<string, readonly CropRecord[]>;
  cropProfiles: ReadonlyMap<string, CropProfile>;
  careRules: readonly CareRule[];
  taskTemplates: ReadonlyMap<string, TaskTemplate>;
  completedTaskIds: ReadonlySet<string>;
}

export function generateSevenDayCadence(ctx: CadenceContext): TaskRecord[] {
  const horizon = ctx.horizonDays ?? 7;
  const generated: TaskRecord[] = [];
  const seenIds = new Set<string>();

  for (const plot of ctx.plots) {
    const crops = ctx.cropsByPlotId.get(plot.plotId) ?? [];
    for (const crop of crops) {
      // Explicit retirement stops future scheduling; harvest stage stays active.
      if (crop.lifecycleStatus === 'retired') {
        continue;
      }

      const profile = ctx.cropProfiles.get(crop.cropProfileId);
      if (!profile || !profile.supportedRegions.includes(ctx.regionCode)) {
        continue;
      }

      for (let dayOffset = 0; dayOffset < horizon; dayOffset++) {
        const scheduledDate = addDaysToLocalDate(ctx.startLocalDate, dayOffset);
        const daysSincePlanting = Math.max(0, daysBetweenLocalDates(crop.plantingDate, scheduledDate));
        const stageForDate = estimateGrowthStage(profile, crop.plantingMethod, crop.plantingDate, scheduledDate);

        for (const rule of ctx.careRules) {
          if (rule.reviewStatus === 'deprecated') continue;
          if (rule.region !== ctx.regionCode) continue;
          if (!rule.cropProfileIds.includes(crop.cropProfileId)) continue;
          if (!rule.applicableStages.includes(stageForDate)) continue;
          if (!rule.applicableMethods.includes(crop.plantingMethod)) continue;
          if (!rule.allowedRainExposures.includes(plot.rainExposure)) continue;

          // Cadence modulo check based on days since planting
          if (daysSincePlanting % rule.cadenceIntervalDays !== 0) continue;

          const template = ctx.taskTemplates.get(rule.templateId);
          if (!template || template.reviewStatus === 'deprecated') continue;

          const taskId = buildDeterministicTaskId({
            userId: ctx.userId,
            cropId: crop.cropId,
            ruleId: rule.id,
            localDate: scheduledDate,
            occurrenceSlot: rule.occurrenceSlot,
          });

          // Never regenerate completed tasks or duplicate within a single run
          if (ctx.completedTaskIds.has(taskId) || seenIds.has(taskId)) {
            continue;
          }
          seenIds.add(taskId);

          generated.push({
            taskId,
            cropId: crop.cropId,
            plotId: plot.plotId,
            ruleId: rule.id,
            ruleVersion: rule.revision,
            taskCategory: template.category,
            title: `${crop.commonName}: ${template.title}`.slice(0, 60),
            instructions: template.instructions,
            steps: [...template.steps],
            rationale: template.rationale,
            estimatedDurationMinutes: template.estimatedDurationMinutes,
            scheduledDate,
            timeZone: ctx.timeZone,
            dueAt: null,
            scheduleStatus: 'pending',
            weatherOverrideApplied: false,
            weatherOverrideReason: null,
            forecastFetchedAt: null,
            sourceRefs: [...template.sourceRefs],
            diagnosisId: null,
            createdAt: ctx.nowIso,
            updatedAt: ctx.nowIso,
          });
        }
      }
    }
  }

  return generated;
}
