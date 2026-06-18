import { api } from './client';

export function adminLogin(email, password) {
  return api.post('/admin/login', { email, password });
}

export function getUserById(userId) {
  return api.get(`/admin/users/${userId}`);
}

export function searchUserByEmail(email) {
  return api.get(`/admin/users/search?email=${encodeURIComponent(email)}`);
}

export function searchUsersByName(query) {
  return api.get(`/users/search?query=${encodeURIComponent(query)}`);
}

export function banUser(userId, banType, duration, reason) {
  return api.post('/admin/ban', {
    user_id: userId,
    ban_type: banType,
    duration: banType === 'temporary' ? duration : undefined,
    reason,
  });
}

export function adjustBalance(userId, amount, reason) {
  return api.post('/economy/admin/adjust', {
    user_id: userId,
    currency: 'SILVER_SEAL',
    amount,
    reason,
  });
}

export function getViolations(userId, page = 1, pageSize = 20) {
  return api.get(
    `/economy/admin/violations?user_id=${userId}&page=${page}&page_size=${pageSize}`
  );
}
