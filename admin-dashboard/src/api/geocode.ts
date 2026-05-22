import axios from 'axios';

import { apiClient } from './client';

export type LatLng = { lat: number; lng: number };

/** Look up a stop's lat/lng by name, biased to UTM Skudai. Goes through the
 *  Django proxy at /api/routes/geocode/ so the Google key stays server-side.
 *
 *  - Returns the matched coords on success.
 *  - Returns null when the geocoder finds no match (HTTP 404).
 *  - Throws Error("…") with the backend's `detail` message for any other
 *    failure (billing not enabled, key restricted, network error, etc.). */
export async function geocodeStopName(name: string): Promise<LatLng | null> {
  try {
    const { data } = await apiClient.get<{ lat: number; lng: number }>(
      '/api/routes/geocode/',
      { params: { q: name } },
    );
    return { lat: data.lat, lng: data.lng };
  } catch (err) {
    if (axios.isAxiosError(err) && err.response?.status === 404) {
      return null;
    }
    const detail =
      axios.isAxiosError(err) &&
      typeof err.response?.data === 'object' &&
      err.response.data !== null &&
      'detail' in err.response.data
        ? String((err.response.data as { detail: unknown }).detail)
        : null;
    throw new Error(detail ?? 'Geocoding request failed');
  }
}
