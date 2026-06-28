import { apiClient } from './client';

export type Driver = {
  id: string;
  name: string;
  email: string;
  role: 'driver';
  phone_no?: string | null;
  assigned_bus_id?: string | null;
  assigned_bus?: {
    id: string;
    plate_number: string;
    bus_name: string;
  } | null;
};

export async function listDrivers(): Promise<Driver[]> {
  const { data } = await apiClient.get<Driver[]>('/api/auth/drivers/');
  return data;
}

export async function createDriver(payload: {
  name: string;
  email: string;
  password: string;
  phone_no?: string;
}): Promise<Driver> {
  const { data } = await apiClient.post<Driver>('/api/auth/drivers/create/', payload);
  return data;
}

export async function updateDriver(
  uid: string,
  payload: Partial<{ name: string; phone_no: string }>,
): Promise<Driver> {
  const { data } = await apiClient.patch<Driver>(`/api/auth/drivers/${uid}/`, payload);
  return data;
}

export async function deleteDriver(uid: string): Promise<void> {
  await apiClient.delete(`/api/auth/drivers/${uid}/delete/`);
}
