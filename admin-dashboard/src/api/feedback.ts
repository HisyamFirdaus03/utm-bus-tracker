import { apiClient } from './client';
import type { Feedback, FeedbackStatus } from './types';

export async function listAllFeedback(): Promise<Feedback[]> {
  const { data } = await apiClient.get<Feedback[]>('/api/feedbacks/all/');
  return data;
}

export async function respondToFeedback(
  id: string,
  patch: { admin_response?: string | null; status?: FeedbackStatus },
): Promise<Feedback> {
  const { data } = await apiClient.patch<Feedback>(
    `/api/feedbacks/${id}/respond/`,
    patch,
  );
  return data;
}
