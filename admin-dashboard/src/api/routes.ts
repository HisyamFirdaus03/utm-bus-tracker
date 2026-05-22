import { apiClient } from './client';
import type { BusRoute, BusStop } from './types';

export async function listRoutes(): Promise<BusRoute[]> {
  const { data } = await apiClient.get<BusRoute[]>('/api/routes/');
  return data;
}

export async function createRoute(payload: Partial<BusRoute> & {
  stop_ids: string[];
}): Promise<BusRoute> {
  const { data } = await apiClient.post<BusRoute>('/api/routes/create/', payload);
  return data;
}

export async function updateRoute(id: string, patch: Partial<BusRoute> & {
  stop_ids?: string[];
}): Promise<BusRoute> {
  const { data } = await apiClient.patch<BusRoute>(`/api/routes/${id}/update/`, patch);
  return data;
}

export async function deleteRoute(id: string): Promise<void> {
  await apiClient.delete(`/api/routes/${id}/delete/`);
}

export async function listStops(): Promise<BusStop[]> {
  const { data } = await apiClient.get<BusStop[]>('/api/routes/stops/');
  return data;
}
