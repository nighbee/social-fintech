import { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getUserById, banUser, adjustBalance, getViolations } from '../../api/users';
import { useApi } from '../../hooks/useApi';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './UserDetailPage.module.css';

export default function UserDetailPage() {
  const { id } = useParams();
  const userResp = useApi(() => getUserById(id).catch((e) => null), [id]);
  const violationsResp = useApi(() => getViolations(id).catch(() => null), [id]);

  const [banType, setBanType] = useState('temporary');
  const [banDuration, setBanDuration] = useState('24h');
  const [banReason, setBanReason] = useState('');
  const [banMsg, setBanMsg] = useState(null);
  const [banSubmitting, setBanSubmitting] = useState(false);

  const [balanceAmount, setBalanceAmount] = useState('');
  const [balanceReason, setBalanceReason] = useState('');
  const [balanceMsg, setBalanceMsg] = useState(null);
  const [balanceSubmitting, setBalanceSubmitting] = useState(false);

  if (userResp.loading) return <Loading />;
  if (userResp.error || !userResp.data) {
    return <ErrorMessage message={userResp.error || 'User not found'} />;
  }

  const user = userResp.data;

  const handleBan = async (e) => {
    e.preventDefault();
    setBanSubmitting(true);
    setBanMsg(null);
    try {
      await banUser(id, banType, banDuration, banReason);
      setBanMsg({ type: 'success', text: 'User banned successfully' });
    } catch (err) {
      setBanMsg({ type: 'error', text: err.message });
    } finally {
      setBanSubmitting(false);
    }
  };

  const handleAdjustBalance = async (e) => {
    e.preventDefault();
    if (!balanceAmount) return;
    setBalanceSubmitting(true);
    setBalanceMsg(null);
    try {
      await adjustBalance(id, parseInt(balanceAmount, 10), balanceReason);
      setBalanceMsg({ type: 'success', text: 'Balance adjusted' });
      setBalanceAmount('');
      setBalanceReason('');
    } catch (err) {
      setBalanceMsg({ type: 'error', text: err.message });
    } finally {
      setBalanceSubmitting(false);
    }
  };

  const statusChip = (val, trueLabel, falseLabel) => {
    if (val) return <span className={`${styles.chip} ${styles.chipRed}`}>{trueLabel}</span>;
    return <span className={`${styles.chip} ${styles.chipGreen}`}>{falseLabel}</span>;
  };

  return (
    <div className={styles.page}>
      <Link to="/admin/users" className={styles.back}>← Back to Users</Link>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>User Info</h2>
        <div className={styles.infoGrid}>
          <span className={styles.infoLabel}>ID</span>
          <span className={styles.infoValue}>{user.id}</span>
          <span className={styles.infoLabel}>Email</span>
          <span className={styles.infoValue}>{user.email}</span>
          <span className={styles.infoLabel}>Username</span>
          <span className={styles.infoValue}>{user.username}</span>
          <span className={styles.infoLabel}>Name</span>
          <span className={styles.infoValue}>{user.first_name} {user.last_name}</span>
          <span className={styles.infoLabel}>Admin</span>
          <span className={styles.infoValue}>{user.is_admin ? 'Yes' : 'No'}</span>
          <span className={styles.infoLabel}>Shadow Banned</span>
          <span className={styles.infoValue}>{statusChip(user.is_shadow_banned, 'Yes', 'No')}</span>
          <span className={styles.infoLabel}>Activation</span>
          <span className={styles.infoValue}>
            <span className={`${styles.chip} ${user.activation_status === 'active' ? styles.chipGreen : styles.chipRed}`}>
              {user.activation_status}
            </span>
          </span>
          {user.restrictions_until && (
            <>
              <span className={styles.infoLabel}>Banned Until</span>
              <span className={styles.infoValue}>{new Date(user.restrictions_until).toLocaleString()}</span>
            </>
          )}
          {user.deleted_at && (
            <>
              <span className={styles.infoLabel}>Deleted At</span>
              <span className={styles.infoValue}>{new Date(user.deleted_at).toLocaleString()}</span>
            </>
          )}
          <span className={styles.infoLabel}>Last Active</span>
          <span className={styles.infoValue}>{new Date(user.last_active_at).toLocaleString()}</span>
          <span className={styles.infoLabel}>Created</span>
          <span className={styles.infoValue}>{new Date(user.created_at).toLocaleString()}</span>
        </div>
      </div>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>Ban User</h2>
        <form className={styles.form} onSubmit={handleBan}>
          <div className={styles.formRow}>
            <div className={styles.field}>
              <span className={styles.label}>Ban Type</span>
              <select className={styles.select} value={banType} onChange={(e) => setBanType(e.target.value)}>
                <option value="temporary">Temporary</option>
                <option value="permanent">Permanent</option>
              </select>
            </div>
            {banType === 'temporary' && (
              <div className={styles.field}>
                <span className={styles.label}>Duration</span>
                <input className={styles.input} value={banDuration} onChange={(e) => setBanDuration(e.target.value)} placeholder="24h, 7d, 30d" />
              </div>
            )}
          </div>
          <div className={styles.field}>
            <span className={styles.label}>Reason</span>
            <input className={styles.input} value={banReason} onChange={(e) => setBanReason(e.target.value)} required />
          </div>
          {banMsg && <div className={`${styles.msg} ${banMsg.type === 'success' ? styles.success : styles.error}`}>{banMsg.text}</div>}
          <div>
            <button className={`${styles.actionBtn} ${styles.banBtn}`} type="submit" disabled={banSubmitting}>
              {banSubmitting ? 'Banning...' : 'Ban User'}
            </button>
          </div>
        </form>
      </div>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>Adjust Balance</h2>
        <form className={styles.form} onSubmit={handleAdjustBalance}>
          <div className={styles.formRow}>
            <div className={styles.field}>
              <span className={styles.label}>Amount (centinels, 100 = 1.00 silver)</span>
              <input className={styles.input} type="number" value={balanceAmount} onChange={(e) => setBalanceAmount(e.target.value)} required />
            </div>
            <div className={styles.field}>
              <span className={styles.label}>Reason</span>
              <input className={styles.input} value={balanceReason} onChange={(e) => setBalanceReason(e.target.value)} required />
            </div>
          </div>
          {balanceMsg && <div className={`${styles.msg} ${balanceMsg.type === 'success' ? styles.success : styles.error}`}>{balanceMsg.text}</div>}
          <div>
            <button className={`${styles.actionBtn} ${styles.balanceBtn}`} type="submit" disabled={balanceSubmitting}>
              {balanceSubmitting ? 'Adjusting...' : 'Adjust Balance'}
            </button>
          </div>
        </form>
      </div>

      <div className={styles.card}>
        <h2 className={styles.cardTitle}>Economy Violations</h2>
        {violationsResp.loading ? (
          <Loading />
        ) : violationsResp.error ? (
          <ErrorMessage message={violationsResp.error} />
        ) : violationsResp.data?.violations?.length > 0 ? (
          <table className={styles.violationsTable}>
            <thead>
              <tr>
                <th>Type</th>
                <th>Description</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {violationsResp.data.violations.map((v, i) => (
                <tr key={i}>
                  <td>{v.type || v.violation_type}</td>
                  <td>{v.description || v.detail}</td>
                  <td>{v.created_at ? new Date(v.created_at).toLocaleString() : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p style={{ fontSize: 14, color: 'var(--text-muted)' }}>No violations found</p>
        )}
      </div>
    </div>
  );
}
