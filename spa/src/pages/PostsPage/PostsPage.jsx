import { useState } from 'react';
import { Link } from 'react-router-dom';
import { searchPosts } from '../../api/posts';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './PostsPage.module.css';

export default function PostsPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState(null);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSearch = async () => {
    if (!query.trim()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await searchPosts(query.trim());
      setResults(data.posts || []);
      setTotal(data.total || data.posts?.length || 0);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={styles.page}>
      <div className={styles.searchRow}>
        <input
          className={styles.searchInput}
          placeholder="Search posts by caption text..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
        />
        <button className={styles.searchBtn} onClick={handleSearch}>
          Search
        </button>
      </div>

      {loading && <Loading />}
      {error && <ErrorMessage message={error} />}

      {results && !loading && !error && (
        <>
          <p className={styles.meta}>{total} posts found</p>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Media</th>
                <th>Caption</th>
                <th>Author</th>
                <th>Likes</th>
                <th>Comments</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {results.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                    No posts found
                  </td>
                </tr>
              ) : (
                results.map((p) => (
                  <tr key={p.post_id || p.id}>
                    <td>
                      {p.media_attachments?.[0]?.thumbnail_url && (
                        <img
                          className={styles.thumb}
                          src={p.media_attachments[0].thumbnail_url}
                          alt=""
                        />
                      )}
                    </td>
                    <td>
                      <Link to={`/admin/posts/${p.post_id || p.id}`} className={styles.postLink}>
                        <span className={styles.caption}>{p.content_text || p.caption || '(no caption)'}</span>
                      </Link>
                    </td>
                    <td>{p.author?.username}</td>
                    <td>{p.metrics?.likes ?? 0}</td>
                    <td>{p.metrics?.comments ?? 0}</td>
                    <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                      {p.created_at ? new Date(p.created_at).toLocaleDateString() : '-'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}
