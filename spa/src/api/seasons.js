import { api } from './client';

export function getSeasons() {
  return api.get('/admin/seasons');
}

export function forceCloseSeason(seasonId) {
  return api.post(`/admin/seasons/${seasonId}/force-close`);
}

export function getUserArchive(userId, limit = 50) {
  return api.get(`/seasons/users/${userId}/archive?limit=${limit}`);
}
