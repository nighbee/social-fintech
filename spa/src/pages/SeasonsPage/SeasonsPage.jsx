import { useState } from 'react';
import { getSeasons, forceCloseSeason, getUserArchive } from '../../api/seasons';
import { searchUserByEmail } from '../../api/users';
import { useApi } from '../../hooks/useApi';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './SeasonsPage.module.css';

export default function SeasonsPage() {
  const seasonsState = useApi(() => getSeasons().catch(() => ({ seasons: [] })), []);

  const [archiveUserId, setArchiveUserId] = useState(null);
  const [archiveUserEmail, setArchiveUserEmail] = useState('');
  const [archiveData, setArchiveData] = useState(null);
  const [archiveLoading, setArchiveLoading] = useState(false);
  const [archiveError, setArchiveError] = useState(null);

  const [confirmClose, setConfirmClose] = useState(null);
  const [actionResult, setActionResult] = useState(null);

  const handleLookupArchive = async () => {
    if (!archiveUserEmail.trim()) return;
    setArchiveLoading(true);
    setArchiveError(null);
    setArchiveData(null);
    try {
      const user = await searchUserByEmail(archiveUserEmail.trim());
      if (!user || !user.id) {
        setArchiveError('User not found');
        return;
      }
      setArchiveUserId(user.id);
      const data = await getUserArchive(user.id, 50);
      setArchiveData(data);
    } catch (e) {
      setArchiveError(e.message);
    } finally {
      setArchiveLoading(false);
    }
  };

  const handleForceClose = async (seasonId, label) => {
    try {
      const resp = await forceCloseSeason(seasonId);
      setActionResult({
        type: 'success',
        message: `Season ${label} closed. ${resp.archived_users} users archived.`,
      });
      setConfirmClose(null);
      seasonsState.refetch();
    } catch (e) {
      setActionResult({ type: 'error', message: e.message });
      setConfirmClose(null);
    }
  };

  const formatDate = (iso) => {
    const d = new Date(iso);
    return d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
  };

  const halfLabel = (half) => (half === 1 ? 'H1 (Jan-Jun)' : 'H2 (Jul-Dec)');

  const seasons = seasonsState.data?.seasons || [];
  const loading = seasonsState.loading;

  if (loading) return <Loading />;

  return (
    <div className={styles.page}>
      {actionResult && (
        <div className={actionResult.type === 'success' ? styles.successMsg : styles.errorMsg}>
          {actionResult.message}
          <button className={styles.dismissBtn} onClick={() => setActionResult(null)}>×</button>
        </div>
      )}

      <div className={styles.section}>
        <h3 className={styles.sectionTitle}>User Archive Lookup</h3>
        <div className={styles.searchRow}>
          <input
            className={styles.input}
            placeholder="User email..."
            value={archiveUserEmail}
            onChange={(e) => setArchiveUserEmail(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleLookupArchive()}
          />
          <button className={styles.searchBtn} onClick={handleLookupArchive} disabled={archiveLoading}>
            {archiveLoading ? 'Loading...' : 'View Archive'}
          </button>
        </div>

        {archiveError && <ErrorMessage message={archiveError} />}

        {archiveData && archiveUserId && (
          <div className={styles.archiveSection}>
            <h4 className={styles.archiveTitle}>
              Archive for {archiveUserEmail} ({archiveData.items?.length || 0} seasons)
            </h4>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>Season</th>
                  <th>Period</th>
                  <th>Gold Seals</th>
                  <th>Pos.</th>
                  <th>Scope</th>
                  <th>Region</th>
                  <th>Rank</th>
                </tr>
              </thead>
              <tbody>
                {(!archiveData.items || archiveData.items.length === 0) ? (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                      No archive entries
                    </td>
                  </tr>
                ) : (
                  archiveData.items.map((item, i) => {
                    let rankName = '';
                    let rankLevel = '';
                    try {
                      const snap = typeof item.snapshot_payload === 'string'
                        ? JSON.parse(item.snapshot_payload)
                        : item.snapshot_payload;
                      if (snap) {
                        rankName = snap.rank_name || '';
                        rankLevel = snap.rank_level || '';
                      }
                    } catch (_) {}

                    return (
                      <tr key={item.season_id + i}>
                        <td>
                          <span className={styles.badge}>
                            {item.season_year}-H{item.season_half}
                          </span>
                        </td>
                        <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                          {formatDate(item.starts_at)} → {formatDate(item.ends_at)}
                        </td>
                        <td>{item.seal_count}</td>
                        <td>{item.final_position ?? '-'}</td>
                        <td><span className={styles.scopeBadge}>{item.scope || '-'}</span></td>
                        <td style={{ fontSize: 13, color: 'var(--text-muted)', maxWidth: 140, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {item.region || '-'}
                        </td>
                        <td>
                          {rankName && (
                            <span className={styles.rankBadge}>
                              {rankName} {rankLevel && `Lv.${rankLevel}`}
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {seasonsState.error && <ErrorMessage message={seasonsState.error} onRetry={seasonsState.refetch} />}

      <div className={styles.section}>
        <h3 className={styles.sectionTitle}>All Seasons</h3>
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Season</th>
              <th>Period</th>
              <th>Status</th>
              <th>Participants</th>
              <th>Closed At</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {seasons.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                  No seasons found
                </td>
              </tr>
            ) : (
              seasons.map((s) => {
                const label = `${s.season.season_year}-H${s.season.season_half}`;
                return (
                  <tr key={s.season.id}>
                    <td>
                      <span className={styles.badge}>{label}</span>
                    </td>
                    <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                      {formatDate(s.season.starts_at)} → {formatDate(s.season.ends_at)}
                    </td>
                    <td>
                      <span className={s.is_closed ? styles.closedBadge : styles.openBadge}>
                        {s.is_closed ? 'Closed' : 'Open'}
                      </span>
                    </td>
                    <td>{s.participants}</td>
                    <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>
                      {s.season.closed_at ? formatDate(s.season.closed_at) : '-'}
                    </td>
                    <td>
                      {!s.is_closed && (
                        confirmClose === s.season.id ? (
                          <div className={styles.confirmRow}>
                            <button className={styles.dangerBtn} onClick={() => handleForceClose(s.season.id, label)}>
                              Confirm Close
                            </button>
                            <button className={styles.cancelBtn} onClick={() => setConfirmClose(null)}>
                              Cancel
                            </button>
                          </div>
                        ) : (
                          <button
                            className={styles.warnBtn}
                            onClick={() => setConfirmClose(s.season.id)}
                          >
                            Force Close
                          </button>
                        )
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
