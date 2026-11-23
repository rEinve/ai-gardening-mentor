/**
 * OpenWeather 24-hour Metric Forecast Provider (Tanzania MVP).
 *
 * Uses OpenWeather 5-day / 3-hour forecast API (`units=metric`) and aggregates
 * the next 8 intervals (24 hours) into `rainMm24h`, `minTempC`, and `maxTempC`.
 * Returns `null` on outage/timeout so `evaluateWeatherOverrides` retains baseline care.
 */

import type { WeatherForecast } from '../domain/weatherOverrides.ts';

interface OpenWeatherListItem {
  main?: { temp_min?: number; temp_max?: number };
  rain?: { '3h'?: number };
}

interface OpenWeatherResponse {
  list?: OpenWeatherListItem[];
}

export async function fetchOpenWeatherForecast(params: {
  apiKey: string;
  latitude: number;
  longitude: number;
  now?: Date;
  fetchImpl?: typeof fetch;
}): Promise<WeatherForecast | null> {
  if (!params.apiKey) {
    return null;
  }

  const doFetch = params.fetchImpl ?? fetch;
  const url =
    `https://api.openweathermap.org/data/2.5/forecast` +
    `?lat=${encodeURIComponent(params.latitude)}` +
    `&lon=${encodeURIComponent(params.longitude)}` +
    `&units=metric&cnt=8&appid=${encodeURIComponent(params.apiKey)}`;

  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 6000);
    const response = await doFetch(url, { signal: controller.signal });
    clearTimeout(timer);

    if (!response.ok) {
      return null;
    }

    const data = (await response.json()) as OpenWeatherResponse;
    const intervals = data.list ?? [];
    if (intervals.length === 0) {
      return null;
    }

    let rainMm24h = 0;
    let minTempC = Number.POSITIVE_INFINITY;
    let maxTempC = Number.NEGATIVE_INFINITY;

    for (const item of intervals) {
      rainMm24h += item.rain?.['3h'] ?? 0;
      if (typeof item.main?.temp_min === 'number') {
        minTempC = Math.min(minTempC, item.main.temp_min);
      }
      if (typeof item.main?.temp_max === 'number') {
        maxTempC = Math.max(maxTempC, item.main.temp_max);
      }
    }

    if (!Number.isFinite(minTempC) || !Number.isFinite(maxTempC)) {
      return null;
    }

    return {
      rainMm24h: Number(rainMm24h.toFixed(2)),
      minTempC: Number(minTempC.toFixed(1)),
      maxTempC: Number(maxTempC.toFixed(1)),
      fetchedAt: (params.now ?? new Date()).toISOString(),
    };
  } catch {
    return null;
  }
}
