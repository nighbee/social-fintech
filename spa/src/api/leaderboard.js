import { api } from './client';

export function getLeaderboardScopes() {
  return api.get('/admin/leaderboard/scopes');
}

export function addUserToLeaderboard(userId, scope, score, region) {
  return api.post('/admin/leaderboard/add-user', { user_id: userId, scope, score, region });
}

export function removeUserFromLeaderboard(userId, scope, region) {
  return api.post('/admin/leaderboard/remove-user', { user_id: userId, scope, region });
}

export function adjustLeaderboardScore(userId, scope, amount, region) {
  return api.post('/admin/leaderboard/adjust-score', { user_id: userId, scope, amount, region });
}
