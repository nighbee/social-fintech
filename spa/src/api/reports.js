import { api } from './client';

export function getReports({ status, targetType, reason, limit = 50, offset = 0 } = {}) {
  const params = new URLSearchParams();
  if (status) params.set('status', status);
  if (targetType) params.set('target_type', targetType);
  if (reason) params.set('reason', reason);
  params.set('limit', limit);
  params.set('offset', offset);
  return api.get(`/admin/reports?${params.toString()}`);
}

export function getMetrics() {
  return api.get('/admin/ops/metrics');
}
