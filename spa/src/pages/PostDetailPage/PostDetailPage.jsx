import { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getPostById, deletePost, deleteComment, getComments } from '../../api/posts';
import { useApi } from '../../hooks/useApi';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './PostDetailPage.module.css';

export default function PostDetailPage() {
  const { id } = useParams();
  const postResp = useApi(() => getPostById(id).catch(() => null), [id]);
  const commentsResp = useApi(() => getComments(id).catch(() => null), [id]);

  const [deleteMsg, setDeleteMsg] = useState(null);
  const [deleting, setDeleting] = useState(false);
  const [deleted, setDeleted] = useState(false);

  const handleDeletePost = async () => {
    if (!window.confirm('Delete this post? This cannot be undone.')) return;
    setDeleting(true);
    setDeleteMsg(null);
    try {
      await deletePost(id);
      setDeleted(true);
      setDeleteMsg({ type: 'success', text: 'Post deleted' });
    } catch (e) {
      setDeleteMsg({ type: 'error', text: e.message });
    } finally {
      setDeleting(false);
    }
  };

  const handleDeleteComment = async (commentId) => {
    if (!window.confirm('Delete this comment?')) return;
    try {
      await deleteComment(commentId);
      commentsResp.refetch();
    } catch (e) {
      alert(e.message);
    }
  };

  if (postResp.loading || commentsResp.loading) return <Loading />;
  if (postResp.error || !postResp.data) {
    return <ErrorMessage message={postResp.error || 'Post not found'} />;
  }

  const post = postResp.data;
  const comments = commentsResp.data?.comments || commentsResp.data || [];

  return (
    <div className={styles.page}>
      <Link to="/admin/posts" className={styles.back}>← Back to Posts</Link>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>Post Detail</h2>

        <div className={styles.authorRow}>
          {post.author?.profile_pic_url && (
            <img className={styles.authorAvatar} src={post.author.profile_pic_url} alt="" />
          )}
          <div>
            <div className={styles.authorName}>{post.author?.full_name || post.author?.username}</div>
            <div className={styles.authorUsername}>@{post.author?.username}</div>
          </div>
        </div>

        {post.content_text && (
          <div className={styles.caption}>{post.content_text}</div>
        )}

        {post.media_attachments?.length > 0 && (
          <div className={styles.mediaGrid}>
            {post.media_attachments.map((m, i) => (
              <img
                key={i}
                className={styles.mediaItem}
                src={m.thumbnail_url || m.url || m.image_url}
                alt=""
              />
            ))}
          </div>
        )}

        <div className={styles.metrics}>
          <div className={styles.metric}>
            <span className={styles.metricLabel}>Likes</span>
            <span className={styles.metricValue}>{post.metrics?.likes ?? 0}</span>
          </div>
          <div className={styles.metric}>
            <span className={styles.metricLabel}>Comments</span>
            <span className={styles.metricValue}>{post.metrics?.comments ?? 0}</span>
          </div>
          <div className={styles.metric}>
            <span className={styles.metricLabel}>Silvers</span>
            <span className={styles.metricValue}>{post.metrics?.silvers ?? 0}</span>
          </div>
          <div className={styles.metric}>
            <span className={styles.metricLabel}>Shares</span>
            <span className={styles.metricValue}>{post.metrics?.shares ?? 0}</span>
          </div>
        </div>

        <div className={styles.actions} style={{ marginTop: 16 }}>
          <button
            className={styles.deleteBtn}
            onClick={handleDeletePost}
            disabled={deleting || deleted}
          >
            {deleting ? 'Deleting...' : deleted ? 'Deleted' : 'Delete Post'}
          </button>
          {deleteMsg && (
            <span className={`${styles.msg} ${deleteMsg.type === 'success' ? styles.success : styles.error}`}>
              {deleteMsg.text}
            </span>
          )}
        </div>
      </div>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>Comments ({comments.length})</h2>
        {comments.length === 0 ? (
          <p style={{ fontSize: 14, color: 'var(--text-muted)' }}>No comments</p>
        ) : (
          comments.map((c, i) => (
            <div key={c.id || c.comment_id || i} className={styles.commentItem}>
              <div className={styles.commentAuthor}>
                {c.author?.username || c.username || 'Unknown'}
              </div>
              <div className={styles.commentText}>{c.content_text || c.text}</div>
              <div className={styles.commentMeta}>
                <span>{c.created_at ? new Date(c.created_at).toLocaleDateString() : ''}</span>
                <button
                  className={styles.commentDeleteBtn}
                  onClick={() => handleDeleteComment(c.id || c.comment_id)}
                >
                  Delete
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
