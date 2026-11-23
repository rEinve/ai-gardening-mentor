/**
 * Strict input validators enforcing docs/schema.md bounds and allowlists.
 * Rejects unknown fields, out-of-range lengths, invalid IANA timezones, and future planting dates.
 */

import type {
  GardenExperienceLevel,
  GeographicLocation,
  PlantingMethod,
  PlotDimensions,
  PlotType,
  RainExposure,
  SunlightExposure,
  UnitPreference,
} from '../types/schema.ts';

export const LIMITS = {
  NAME_MAX: 50,
  TITLE_MAX: 60,
  INSTRUCTIONS_MAX: 250,
  CHAT_TEXT_MAX: 2000,
  TRIAGE_FIELD_MAX: 200,
  STEPS_MIN: 1,
  STEPS_MAX: 10,
  CITATIONS_MAX: 10,
  MAX_PLOTS_ONBOARDING: 10,
  MAX_CROPS_PER_PLOT: 25,
} as const;

const PLOT_TYPES = new Set<PlotType>(['in_ground', 'raised_bed', 'container', 'indoor_window']);
const RAIN_EXPOSURES = new Set<RainExposure>(['exposed', 'sheltered', 'indoor']);
const SUNLIGHT_EXPOSURES = new Set<SunlightExposure>(['full_sun', 'partial_shade', 'deep_shade']);
const PLANTING_METHODS = new Set<PlantingMethod>(['direct_seed', 'transplant']);
const UNIT_PREFERENCES = new Set<UnitPreference>(['metric', 'imperial']);
const EXPERIENCE_LEVELS = new Set<GardenExperienceLevel>(['novice', 'beginner', 'intermediate']);

const LOCAL_DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const UUID_OR_ID_REGEX = /^[a-zA-Z0-9_-]{8,64}$/;

export interface InitializeGardenCropInput {
  cropId: string;
  cropProfileId: string;
  variety: string | null;
  plantingDate: string;
  plantingMethod: PlantingMethod;
}

export interface InitializeGardenPlotInput {
  plotId: string;
  name: string;
  plotType: PlotType;
  rainExposure: RainExposure;
  dimensions: PlotDimensions | null;
  sunlightExposure: SunlightExposure;
  crops: InitializeGardenCropInput[];
}

export interface InitializeGardenInput {
  requestId: string;
  displayName: string | null;
  geographicLocation: GeographicLocation;
  timeZone: string;
  unitPreference: UnitPreference;
  gardenExperienceLevel: GardenExperienceLevel;
  plots: InitializeGardenPlotInput[];
}

export class ValidationError extends Error {
  public readonly code = 'INVALID_ARGUMENT';
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export function isValidIanaTimeZone(tz: string): boolean {
  if (typeof tz !== 'string' || tz.length === 0 || tz.length > 64) {
    return false;
  }
  try {
    Intl.DateTimeFormat(undefined, { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

export function isValidLocalDate(dateStr: string): boolean {
  if (!LOCAL_DATE_REGEX.test(dateStr)) {
    return false;
  }
  const [yStr, mStr, dStr] = dateStr.split('-');
  const y = Number(yStr);
  const m = Number(mStr);
  const d = Number(dStr);
  const date = new Date(Date.UTC(y, m - 1, d));
  return (
    date.getUTCFullYear() === y &&
    date.getUTCMonth() === m - 1 &&
    date.getUTCDate() === d
  );
}

export function getTodayLocalDate(timeZone: string, now: Date = new Date()): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(now);
}

function assertAllowedKeys(obj: Record<string, unknown>, allowed: readonly string[], label: string): void {
  const allowedSet = new Set(allowed);
  for (const key of Object.keys(obj)) {
    if (!allowedSet.has(key)) {
      throw new ValidationError(`Unexpected field "${key}" in ${label}.`);
    }
  }
}

export function validateInitializeGardenInput(
  raw: unknown,
  supportedCropProfileIds: ReadonlySet<string>,
  now: Date = new Date(),
): InitializeGardenInput {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new ValidationError('Payload must be a JSON object.');
  }
  const obj = raw as Record<string, unknown>;
  assertAllowedKeys(
    obj,
    ['requestId', 'displayName', 'geographicLocation', 'timeZone', 'unitPreference', 'gardenExperienceLevel', 'plots'],
    'initializeGarden',
  );

  if (typeof obj.requestId !== 'string' || !UUID_OR_ID_REGEX.test(obj.requestId)) {
    throw new ValidationError('requestId must be an 8-64 character alphanumeric/UUID string.');
  }

  if (obj.displayName !== null && (typeof obj.displayName !== 'string' || obj.displayName.length > LIMITS.NAME_MAX)) {
    throw new ValidationError(`displayName must be null or <= ${LIMITS.NAME_MAX} characters.`);
  }

  if (typeof obj.timeZone !== 'string' || !isValidIanaTimeZone(obj.timeZone)) {
    throw new ValidationError('timeZone must be a valid IANA timezone identifier (e.g., Africa/Dar_es_Salaam).');
  }

  if (typeof obj.unitPreference !== 'string' || !UNIT_PREFERENCES.has(obj.unitPreference as UnitPreference)) {
    throw new ValidationError('unitPreference must be "metric" or "imperial".');
  }

  if (
    typeof obj.gardenExperienceLevel !== 'string' ||
    !EXPERIENCE_LEVELS.has(obj.gardenExperienceLevel as GardenExperienceLevel)
  ) {
    throw new ValidationError('gardenExperienceLevel must be novice, beginner, or intermediate.');
  }

  // Validate location
  if (typeof obj.geographicLocation !== 'object' || obj.geographicLocation === null) {
    throw new ValidationError('geographicLocation is required.');
  }
  const loc = obj.geographicLocation as Record<string, unknown>;
  assertAllowedKeys(
    loc,
    ['latitude', 'longitude', 'regionName', 'countryCode', 'postalCode', 'usdaHardinessZone'],
    'geographicLocation',
  );
  if (typeof loc.latitude !== 'number' || loc.latitude < -90 || loc.latitude > 90) {
    throw new ValidationError('latitude must be a number between -90 and 90.');
  }
  if (typeof loc.longitude !== 'number' || loc.longitude < -180 || loc.longitude > 180) {
    throw new ValidationError('longitude must be a number between -180 and 180.');
  }
  if (typeof loc.regionName !== 'string' || loc.regionName.trim().length === 0 || loc.regionName.length > LIMITS.NAME_MAX) {
    throw new ValidationError(`regionName must be 1-${LIMITS.NAME_MAX} characters.`);
  }
  if (typeof loc.countryCode !== 'string' || loc.countryCode.length !== 2) {
    throw new ValidationError('countryCode must be a 2-letter ISO code (e.g., "TZ").');
  }
  if (loc.postalCode !== null && (typeof loc.postalCode !== 'string' || loc.postalCode.length > 20)) {
    throw new ValidationError('postalCode must be null or <= 20 characters.');
  }
  if (loc.usdaHardinessZone !== null && (typeof loc.usdaHardinessZone !== 'string' || loc.usdaHardinessZone.length > 10)) {
    throw new ValidationError('usdaHardinessZone must be null or <= 10 characters.');
  }

  // Validate plots & crops (at least one plot and at least one supported crop required)
  if (!Array.isArray(obj.plots) || obj.plots.length === 0 || obj.plots.length > LIMITS.MAX_PLOTS_ONBOARDING) {
    throw new ValidationError(`plots must contain 1-${LIMITS.MAX_PLOTS_ONBOARDING} plots.`);
  }

  const todayLocal = getTodayLocalDate(obj.timeZone, now);
  let totalCrops = 0;

  const validatedPlots: InitializeGardenPlotInput[] = obj.plots.map((rawPlot, idx) => {
    if (typeof rawPlot !== 'object' || rawPlot === null || Array.isArray(rawPlot)) {
      throw new ValidationError(`plots[${idx}] must be an object.`);
    }
    const p = rawPlot as Record<string, unknown>;
    assertAllowedKeys(
      p,
      ['plotId', 'name', 'plotType', 'rainExposure', 'dimensions', 'sunlightExposure', 'crops'],
      `plots[${idx}]`,
    );

    if (typeof p.plotId !== 'string' || !UUID_OR_ID_REGEX.test(p.plotId)) {
      throw new ValidationError(`plots[${idx}].plotId is invalid.`);
    }
    if (typeof p.name !== 'string' || p.name.trim().length === 0 || p.name.length > LIMITS.NAME_MAX) {
      throw new ValidationError(`plots[${idx}].name must be 1-${LIMITS.NAME_MAX} characters.`);
    }
    if (typeof p.plotType !== 'string' || !PLOT_TYPES.has(p.plotType as PlotType)) {
      throw new ValidationError(`plots[${idx}].plotType is invalid.`);
    }
    if (typeof p.rainExposure !== 'string' || !RAIN_EXPOSURES.has(p.rainExposure as RainExposure)) {
      throw new ValidationError(`plots[${idx}].rainExposure is invalid.`);
    }
    if (typeof p.sunlightExposure !== 'string' || !SUNLIGHT_EXPOSURES.has(p.sunlightExposure as SunlightExposure)) {
      throw new ValidationError(`plots[${idx}].sunlightExposure is invalid.`);
    }
    if (p.dimensions !== null) {
      if (typeof p.dimensions !== 'object' || Array.isArray(p.dimensions)) {
        throw new ValidationError(`plots[${idx}].dimensions must be null or an object.`);
      }
      const dims = p.dimensions as Record<string, unknown>;
      assertAllowedKeys(dims, ['lengthMetres', 'widthMetres'], `plots[${idx}].dimensions`);
      if (typeof dims.lengthMetres !== 'number' || dims.lengthMetres <= 0 || typeof dims.widthMetres !== 'number' || dims.widthMetres <= 0) {
        throw new ValidationError(`plots[${idx}].dimensions lengthMetres and widthMetres must be positive numbers.`);
      }
    }

    if (!Array.isArray(p.crops) || p.crops.length > LIMITS.MAX_CROPS_PER_PLOT) {
      throw new ValidationError(`plots[${idx}].crops must be an array of up to ${LIMITS.MAX_CROPS_PER_PLOT} crops.`);
    }

    const validatedCrops: InitializeGardenCropInput[] = p.crops.map((rawCrop, cIdx) => {
      if (typeof rawCrop !== 'object' || rawCrop === null || Array.isArray(rawCrop)) {
        throw new ValidationError(`plots[${idx}].crops[${cIdx}] must be an object.`);
      }
      const c = rawCrop as Record<string, unknown>;
      assertAllowedKeys(
        c,
        ['cropId', 'cropProfileId', 'variety', 'plantingDate', 'plantingMethod'],
        `plots[${idx}].crops[${cIdx}]`,
      );
      if (typeof c.cropId !== 'string' || !UUID_OR_ID_REGEX.test(c.cropId)) {
        throw new ValidationError(`plots[${idx}].crops[${cIdx}].cropId is invalid.`);
      }
      if (typeof c.cropProfileId !== 'string' || !supportedCropProfileIds.has(c.cropProfileId)) {
        throw new ValidationError(`Unsupported cropProfileId "${String(c.cropProfileId)}" for this region.`);
      }
      if (c.variety !== null && (typeof c.variety !== 'string' || c.variety.length > LIMITS.NAME_MAX)) {
        throw new ValidationError(`plots[${idx}].crops[${cIdx}].variety must be null or <= ${LIMITS.NAME_MAX} chars.`);
      }
      if (typeof c.plantingDate !== 'string' || !isValidLocalDate(c.plantingDate)) {
        throw new ValidationError(`plots[${idx}].crops[${cIdx}].plantingDate must be YYYY-MM-DD.`);
      }
      if (c.plantingDate > todayLocal) {
        throw new ValidationError(`plots[${idx}].crops[${cIdx}].plantingDate cannot be in the future (${todayLocal}).`);
      }
      if (typeof c.plantingMethod !== 'string' || !PLANTING_METHODS.has(c.plantingMethod as PlantingMethod)) {
        throw new ValidationError(`plots[${idx}].crops[${cIdx}].plantingMethod must be direct_seed or transplant.`);
      }
      totalCrops++;
      return {
        cropId: c.cropId,
        cropProfileId: c.cropProfileId,
        variety: c.variety as string | null,
        plantingDate: c.plantingDate,
        plantingMethod: c.plantingMethod as PlantingMethod,
      };
    });

    return {
      plotId: p.plotId,
      name: p.name.trim(),
      plotType: p.plotType as PlotType,
      rainExposure: p.rainExposure as RainExposure,
      dimensions: p.dimensions as PlotDimensions | null,
      sunlightExposure: p.sunlightExposure as SunlightExposure,
      crops: validatedCrops,
    };
  });

  if (totalCrops === 0) {
    throw new ValidationError('At least one supported crop is required during onboarding.');
  }

  return {
    requestId: obj.requestId,
    displayName: obj.displayName as string | null,
    geographicLocation: {
      latitude: loc.latitude as number,
      longitude: loc.longitude as number,
      regionName: (loc.regionName as string).trim(),
      countryCode: (loc.countryCode as string).toUpperCase(),
      postalCode: loc.postalCode as string | null,
      usdaHardinessZone: loc.usdaHardinessZone as string | null,
    },
    timeZone: obj.timeZone,
    unitPreference: obj.unitPreference as UnitPreference,
    gardenExperienceLevel: obj.gardenExperienceLevel as GardenExperienceLevel,
    plots: validatedPlots,
  };
}
