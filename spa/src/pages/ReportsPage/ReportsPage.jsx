import { useState, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { getReports } from '../../api/reports';
import { useApi } from '../../hooks/useApi';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './ReportsPage.module.css';

export default function ReportsPage() {
  const [filters, setFilters] = useState({ status: 'pending', targetType: '', reason: '' });
  const [key, setKey] = useState(0);

  const fetchReports = useCallback(
    () => getReports({
      status: filters.status || undefined,
      targetType: filters.targetType || undefined,
      reason: filters.reason || undefined,
    }),
    [key, filters]
  );

  const reports = useApi(() => fetchReports().catch(() => ({ items: [], total: 0 })), [key, filters]);

  return (
    <div className={styles.page}>
      <div className={styles.filters}>
        <select
          className={styles.select}
          value={filters.status}
          onChange={(e) => setFilters((f) => ({ ...f, status: e.target.value }))}
        >
          <option value="pending">Pending</option>
          <option value="reviewed">Reviewed</option>
          <option value="">All Status</option>
        </select>
        <select
          className={styles.select}
          value={filters.targetType}
          onChange={(e) => setFilters((f) => ({ ...f, targetType: e.target.value }))}
        >
          <option value="">All Types</option>
          <option value="post">Post</option>
          <option value="comment">Comment</option>
        </select>
        <button className={styles.refreshBtn} onClick={() => setKey((k) => k + 1)}>
          Refresh
        </button>
      </div>

      {reports.loading ? (
        <Loading />
      ) : reports.error ? (
        <ErrorMessage message={reports.error} onRetry={() => setKey((k) => k + 1)} />
      ) : (
        <>
          <p className={styles.meta}>{reports.data?.total ?? 0} reports</p>
          <table className={styles.table}>
            <thead>
              <tr>
                <th>Target</th>
                <th>Type</th>
                <th>Reason</th>
                <th>Status</th>
                <th>Reported At</th>
              </tr>
            </thead>
            <tbody>
              {(!reports.data?.items || reports.data.items.length === 0) ? (
                <tr>
                  <td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                    No reports found
                  </td>
                </tr>
              ) : (
                reports.data.items.map((r, i) => (
                  <tr key={r.id || i}>
                    <td>
                      {r.target_type === 'post' ? (
                        <Link to={`/admin/posts/${r.target_id}`} className={styles.link}>
                          {r.target_id?.substring(0, 8)}...
                        </Link>
                      ) : (
                        <span style={{ fontSize: 13 }}>{r.target_id?.substring(0, 8)}...</span>
                      )}
                    </td>
                    <td>{r.target_type}</td>
                    <td>{r.reason}</td>
                    <td>
                      <span
                        className={`${styles.chip} ${
                          r.status === 'reviewed' ? styles.chipReviewed : styles.chipPending
                        }`}
                      >
                        {r.status}
                      </span>
                    </td>
                    <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                      {r.created_at ? new Date(r.created_at).toLocaleDateString() : '-'}
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
