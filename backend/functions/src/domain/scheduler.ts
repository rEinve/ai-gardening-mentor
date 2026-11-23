/**
 * 15-minute UTC Scheduling Dispatcher & Execution Keys (Phase 4).
 *
 * Per docs/tech-requirement-document.md:
 * - Local 03:00 -> daily cadence (`daily_cadence`)
 * - Local 05:00, 11:00, 17:00 -> weather checks (`weather_override`)
 * - Deterministic per-user/date/job execution key prevents duplicates across retries & DST.
 */

export type ScheduledJobKind = 'daily_cadence' | 'weather_override';

export interface DueJob {
  kind: ScheduledJobKind;
  localDate: string; // YYYY-MM-DD
  localHour: number; // 3, 5, 11, or 17
  timeZone: string;
  jobKey: string;
}

const WEATHER_CHECK_HOURS = new Set<number>([5, 11, 17]);

export function getLocalDateTimeParts(timeZone: string, now: Date): {
  localDate: string;
  hour: number;
  minute: number;
} {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);

  const map = new Map(parts.map((p) => [p.type, p.value]));
  const year = map.get('year') ?? '1970';
  const month = map.get('month') ?? '01';
  const day = map.get('day') ?? '01';
  const hour = Number(map.get('hour') ?? '0') % 24;
  const minute = Number(map.get('minute') ?? '0');

  return { localDate: `${year}-${month}-${day}`, hour, minute };
}

export function buildJobExecutionKey(kind: ScheduledJobKind, localDate: string, localHour: number): string {
  const paddedHour = String(localHour).padStart(2, '0');
  return `${kind}_${localDate}_h${paddedHour}`;
}

/**
 * Evaluates which scheduled jobs are due for a user at `now` (within a 15-minute window)
 * or missed earlier today if `allowCatchUp` is enabled.
 */
export function evaluateDueJobsForUser(params: {
  timeZone: string;
  now: Date;
  completedJobKeys: ReadonlySet<string>;
  allowCatchUp?: boolean;
}): DueJob[] {
  const { localDate, hour, minute } = getLocalDateTimeParts(params.timeZone, params.now);
  const due: DueJob[] = [];
  const allowCatchUp = params.allowCatchUp ?? true;

  // 1. Daily cadence at local 03:00
  const cadenceKey = buildJobExecutionKey('daily_cadence', localDate, 3);
  const cadenceWindowMatch = hour === 3 && minute < 15;
  const cadenceCatchUp = allowCatchUp && hour >= 3;
  if ((cadenceWindowMatch || cadenceCatchUp) && !params.completedJobKeys.has(cadenceKey)) {
    due.push({
      kind: 'daily_cadence',
      localDate,
      localHour: 3,
      timeZone: params.timeZone,
      jobKey: cadenceKey,
    });
  }

  // 2. Weather overrides at local 05:00, 11:00, 17:00
  for (const targetHour of WEATHER_CHECK_HOURS) {
    const key = buildJobExecutionKey('weather_override', localDate, targetHour);
    const inWindow = hour === targetHour && minute < 15;
    const catchUp = allowCatchUp && hour >= targetHour;
    if ((inWindow || catchUp) && !params.completedJobKeys.has(key)) {
      due.push({
        kind: 'weather_override',
        localDate,
        localHour: targetHour,
        timeZone: params.timeZone,
        jobKey: key,
      });
    }
  }

  return due;
}
