import { api } from './client';

export function getPostById(postId) {
  return api.get(`/admin/posts/${postId}`);
}

export function searchPosts(query, limit = 50, offset = 0) {
  return api.get(
    `/admin/posts/search?query=${encodeURIComponent(query)}&limit=${limit}&offset=${offset}`
  );
}

export function deletePost(postId) {
  return api.delete(`/admin/posts/${postId}`);
}

export function deleteComment(commentId) {
  return api.delete(`/admin/comments/${commentId}`);
}

export function getComments(postId) {
  return api.get(`/posts/${postId}/comments`);
}
