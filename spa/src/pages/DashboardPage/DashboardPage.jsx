import { Link } from 'react-router-dom';
import { getMetrics, getReports } from '../../api/reports';
import { useApi } from '../../hooks/useApi';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './DashboardPage.module.css';

export default function DashboardPage() {
  const metrics = useApi(() => getMetrics().catch(() => null), []);
  const reports = useApi(
    () => getReports({ status: 'pending', limit: 1 }).catch(() => ({ total: 0 })),
    []
  );

  const loading = metrics.loading || reports.loading;

  if (loading) return <Loading />;

  return (
    <>
      <div className={styles.grid}>
        <div className={styles.card}>
          <div className={styles.cardLabel}>Pending Reports</div>
          <div className={styles.cardValue}>{reports.data?.total ?? '-'}</div>
        </div>
        <div className={styles.card}>
          <div className={styles.cardLabel}>Goroutines</div>
          <div className={styles.cardValue}>{metrics.data?.goroutines ?? '-'}</div>
        </div>
        <div className={styles.card}>
          <div className={styles.cardLabel}>Heap Alloc</div>
          <div className={styles.cardValue}>
            {metrics.data?.heap_alloc_mb
              ? `${metrics.data.heap_alloc_mb.toFixed(1)} MB`
              : '-'}
          </div>
        </div>
      </div>

      <div className={styles.quickLinks}>
        <h3 className={styles.quickLinksTitle}>Quick Actions</h3>
        <div className={styles.quickLinksGrid}>
          <Link to="/admin/users" className={styles.quickLinkCard}>
            <span className={styles.quickLinkLabel}>Users</span>
          </Link>
          <Link to="/admin/posts" className={styles.quickLinkCard}>
            <span className={styles.quickLinkLabel}>Posts</span>
          </Link>
          <Link to="/admin/reports" className={styles.quickLinkCard}>
            <span className={styles.quickLinkLabel}>Reports</span>
          </Link>
        </div>
      </div>
    </>
  );
}
