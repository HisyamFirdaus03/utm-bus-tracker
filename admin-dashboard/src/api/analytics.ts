import { apiClient } from './client';

export type Overview = {
  buses_total: number;
  buses_active: number;
  routes_total: number;
  routes_active: number;
  feedback_total: number;
  feedback_new: number;
  feedback_in_progress: number;
  feedback_resolved: number;
  riders_last_24h: number;
};

export type DailyPoint = { date: string; riders: number };
export type FeedbackPoint = { date: string; count: number };
export type HourPoint = { hour: number; avg_riders: number };
export type StopPoint = { stop_id: string; stop_name: string; riders: number };

export async function getOverview(): Promise<Overview> {
  const { data } = await apiClient.get<Overview>('/api/analytics/overview/');
  return data;
}

export async function getRidershipDaily(days = 30): Promise<DailyPoint[]> {
  const { data } = await apiClient.get<DailyPoint[]>(
    `/api/analytics/ridership/daily/?days=${days}`,
  );
  return data;
}

export async function getRidershipHourly(): Promise<HourPoint[]> {
  const { data } = await apiClient.get<HourPoint[]>('/api/analytics/ridership/hourly/');
  return data;
}

export async function getDemandByStop(limit = 10): Promise<StopPoint[]> {
  const { data } = await apiClient.get<StopPoint[]>(
    `/api/analytics/demand/by-stop/?limit=${limit}`,
  );
  return data;
}

export async function getFeedbackDaily(days = 30): Promise<FeedbackPoint[]> {
  const { data } = await apiClient.get<FeedbackPoint[]>(
    `/api/analytics/feedback/daily/?days=${days}`,
  );
  return data;
}

export async function downloadReport(days = 30): Promise<void> {
  const { data } = await apiClient.get<Blob>(`/api/analytics/report/?days=${days}`, {
    responseType: 'blob',
  });
  const url = URL.createObjectURL(data);
  const a = document.createElement('a');
  a.href = url;
  const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '');
  a.download = `utm-bustracker-report-${stamp}.pdf`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
