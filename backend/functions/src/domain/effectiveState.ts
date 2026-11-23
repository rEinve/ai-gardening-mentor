/**
 * Effective task state derivation (docs/schema.md & docs/tech-requirement-document.md).
 *
 * Priority order:
 * 1. completed — if ANY accepted completion event exists for taskId
 * 2. cancelled — from task.scheduleStatus
 * 3. deferred_weather — from task.scheduleStatus
 * 4. pending — default
 *
 * Weather workers NEVER edit completion events, so offline completions always
 * survive weather deferrals and multi-device sync (Acceptance Criterion A5).
 */

import type { EffectiveTaskStatus, TaskCompletionEvent, TaskRecord } from '../types/schema.ts';

export interface DerivedTaskView {
  task: TaskRecord;
  effectiveStatus: EffectiveTaskStatus;
  completionCount: number;
  firstCompletedAt: string | null;
}

export function deriveEffectiveTaskStatus(
  task: TaskRecord,
  completionsForTask: readonly TaskCompletionEvent[],
): DerivedTaskView {
  if (completionsForTask.length > 0) {
    const earliest = completionsForTask.reduce((min, ev) =>
      ev.completedAt < min ? ev.completedAt : min,
    completionsForTask[0]!.completedAt);

    return {
      task,
      effectiveStatus: 'completed',
      completionCount: completionsForTask.length,
      firstCompletedAt: earliest,
    };
  }

  return {
    task,
    effectiveStatus: task.scheduleStatus,
    completionCount: 0,
    firstCompletedAt: null,
  };
}
