/**
 * Weather Override Engine (Phase 4 — Metric units: mm & °C).
 *
 * Initial candidate thresholds from docs/tech-requirement-document.md:
 * - Rain deferral: rainMm24h > 12.7 mm (exposed plots & pending watering tasks ONLY)
 * - Frost defense: minTempC <= 1.1 °C (e.g., cold highland nights)
 * - Heat protection: maxTempC >= 35.0 °C (e.g., hot coastal/central afternoons)
 * - Weather outage: retains baseline care and flags forecast stale/unavailable
 * - Never modifies append-only taskCompletions.
 */

import type { CropRecord, PlotRecord, TaskRecord } from '../types/schema.ts';
import { buildDeterministicTaskId } from './identity.ts';

export const WEATHER_THRESHOLDS_METRIC = {
  RAIN_DEFERRAL_MM_24H: 12.7,
  FROST_DEFENSE_C: 1.1,
  HEAT_PROTECTION_C: 35.0,
} as const;

export interface WeatherForecast {
  rainMm24h: number;
  minTempC: number;
  maxTempC: number;
  fetchedAt: string; // ISO UTC
}

export interface WeatherOverrideResult {
  updatedTasks: TaskRecord[];
  insertedProtectionTasks: TaskRecord[];
  forecastStaleOrUnavailable: boolean;
}

export function evaluateWeatherOverrides(params: {
  userId: string;
  localDate: string;
  timeZone: string;
  nowIso: string;
  forecast: WeatherForecast | null;
  plotsById: ReadonlyMap<string, PlotRecord>;
  activeCrops: readonly CropRecord[];
  cropPlotMap: ReadonlyMap<string, string>;
  existingTasksForDate: readonly TaskRecord[];
  completedTaskIds: ReadonlySet<string>;
}): WeatherOverrideResult {
  if (!params.forecast) {
    // Weather outage: retain reviewed baseline care without cancelling tasks
    return {
      updatedTasks: [],
      insertedProtectionTasks: [],
      forecastStaleOrUnavailable: true,
    };
  }

  const { rainMm24h, minTempC, maxTempC, fetchedAt } = params.forecast;
  const updatedTasks: TaskRecord[] = [];
  const insertedProtectionTasks: TaskRecord[] = [];

  // 1. Rain deferral: ONLY exposed plots and pending watering tasks (never sheltered/indoor)
  if (rainMm24h > WEATHER_THRESHOLDS_METRIC.RAIN_DEFERRAL_MM_24H) {
    for (const task of params.existingTasksForDate) {
      if (task.taskCategory !== 'watering') continue;
      if (task.scheduleStatus !== 'pending') continue;
      if (params.completedTaskIds.has(task.taskId)) continue;

      const plot = params.plotsById.get(task.plotId);
      if (!plot || plot.rainExposure !== 'exposed') continue;

      updatedTasks.push({
        ...task,
        scheduleStatus: 'deferred_weather',
        weatherOverrideApplied: true,
        weatherOverrideReason: `Rainfall forecast (${rainMm24h.toFixed(1)} mm/24h) exceeds ${WEATHER_THRESHOLDS_METRIC.RAIN_DEFERRAL_MM_24H} mm; exposed watering paused to protect roots.`,
        forecastFetchedAt: fetchedAt,
        updatedAt: params.nowIso,
      });
    }
  }

  // 2. Thermal defense (Frost <= 1.1 °C or Heat >= 35.0 °C) for active non-indoor crops
  const needsFrost = minTempC <= WEATHER_THRESHOLDS_METRIC.FROST_DEFENSE_C;
  const needsHeat = maxTempC >= WEATHER_THRESHOLDS_METRIC.HEAT_PROTECTION_C;

  if (needsFrost || needsHeat) {
    for (const crop of params.activeCrops) {
      if (crop.lifecycleStatus === 'retired') continue;
      const plotId = params.cropPlotMap.get(crop.cropId);
      if (!plotId) continue;
      const plot = params.plotsById.get(plotId);
      if (!plot || plot.rainExposure === 'indoor') continue;

      if (needsFrost) {
        const taskId = buildDeterministicTaskId({
          userId: params.userId,
          cropId: crop.cropId,
          ruleId: 'weather_frost_defense',
          localDate: params.localDate,
          occurrenceSlot: 1,
        });
        if (!params.completedTaskIds.has(taskId)) {
          insertedProtectionTasks.push({
            taskId,
            cropId: crop.cropId,
            plotId,
            ruleId: 'weather_frost_defense',
            ruleVersion: '1',
            taskCategory: 'frost_defense',
            title: `${crop.commonName}: Protect from cold night (${minTempC.toFixed(1)}°C)`.slice(0, 60),
            instructions: 'Cover tender foliage before dusk with breathable cloth or clean buckets.',
            steps: [
              'Drape breathable cover over plants before sunset.',
              'Remove cover in the morning once temperatures rise.',
            ],
            rationale: 'Cold nights at or below 1.1°C can damage tender vegetable leaves.',
            estimatedDurationMinutes: 5,
            scheduledDate: params.localDate,
            timeZone: params.timeZone,
            dueAt: null,
            scheduleStatus: 'pending',
            weatherOverrideApplied: true,
            weatherOverrideReason: `Low temperature alert (${minTempC.toFixed(1)}°C).`,
            forecastFetchedAt: fetchedAt,
            sourceRefs: [],
            diagnosisId: null,
            createdAt: params.nowIso,
            updatedAt: params.nowIso,
          });
        }
      }

      if (needsHeat) {
        const taskId = buildDeterministicTaskId({
          userId: params.userId,
          cropId: crop.cropId,
          ruleId: 'weather_heat_protection',
          localDate: params.localDate,
          occurrenceSlot: 1,
        });
        if (!params.completedTaskIds.has(taskId)) {
          insertedProtectionTasks.push({
            taskId,
            cropId: crop.cropId,
            plotId,
            ruleId: 'weather_heat_protection',
            ruleVersion: '1',
            taskCategory: 'heat_protection',
            title: `${crop.commonName}: Afternoon heat shade (${maxTempC.toFixed(1)}°C)`.slice(0, 60),
            instructions: 'Provide light afternoon shade and check root moisture before midday heat peaks.',
            steps: [
              'Set up temporary shade cloth or palm fronds over midday sun exposure.',
              'Avoid spraying water onto hot leaves at noon; soak roots early morning or evening.',
            ],
            rationale: 'Temperatures at or above 35°C cause severe transpiration wilt and blossom drop.',
            estimatedDurationMinutes: 5,
            scheduledDate: params.localDate,
            timeZone: params.timeZone,
            dueAt: null,
            scheduleStatus: 'pending',
            weatherOverrideApplied: true,
            weatherOverrideReason: `High heat alert (${maxTempC.toFixed(1)}°C).`,
            forecastFetchedAt: fetchedAt,
            sourceRefs: [],
            diagnosisId: null,
            createdAt: params.nowIso,
            updatedAt: params.nowIso,
          });
        }
      }
    }
  }

  return {
    updatedTasks,
    insertedProtectionTasks,
    forecastStaleOrUnavailable: false,
  };
}
