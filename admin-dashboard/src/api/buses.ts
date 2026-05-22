import { apiClient } from './client';
import type { Bus } from './types';

export async function listBuses(): Promise<Bus[]> {
  const { data } = await apiClient.get<Bus[]>('/api/buses/');
  return data;
}

export async function createBus(payload: Partial<Bus>): Promise<Bus> {
  const { data } = await apiClient.post<Bus>('/api/buses/create/', payload);
  return data;
}

export async function updateBus(id: string, patch: Partial<Bus>): Promise<Bus> {
  const { data } = await apiClient.patch<Bus>(`/api/buses/${id}/update/`, patch);
  return data;
}

export async function deleteBus(id: string): Promise<void> {
  await apiClient.delete(`/api/buses/${id}/delete/`);
}
