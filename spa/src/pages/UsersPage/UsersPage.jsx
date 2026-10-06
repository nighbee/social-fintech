import { useState } from 'react';
import { Link } from 'react-router-dom';
import { searchUserByEmail, searchUsersByName } from '../../api/users';
import { useApi } from '../../hooks/useApi';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './UsersPage.module.css';

export default function UsersPage() {
  const [nameQuery, setNameQuery] = useState('');
  const [emailQuery, setEmailQuery] = useState('');
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleNameSearch = async () => {
    if (!nameQuery.trim()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await searchUsersByName(nameQuery.trim());
      setResults(Array.isArray(data) ? data : []);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  };

  const handleEmailSearch = async () => {
    if (!emailQuery.trim()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await searchUserByEmail(emailQuery.trim());
      setResults(data ? [data] : []);
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
          placeholder="Search by name or username..."
          value={nameQuery}
          onChange={(e) => setNameQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleNameSearch()}
        />
        <button className={styles.searchBtn} onClick={handleNameSearch}>
          Search Name
        </button>
      </div>
      <div className={styles.searchRow}>
        <input
          className={styles.searchInput}
          placeholder="Search by exact email..."
          value={emailQuery}
          onChange={(e) => setEmailQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleEmailSearch()}
        />
        <button className={styles.searchBtn} onClick={handleEmailSearch}>
          Search Email
        </button>
      </div>

      {loading && <Loading />}
      {error && <ErrorMessage message={error} />}

      {results && !loading && !error && (
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Username</th>
              <th>Name</th>
              <th>Email</th>
              <th>Admin</th>
              <th>Banned</th>
            </tr>
          </thead>
          <tbody>
            {results.length === 0 ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                  No users found
                </td>
              </tr>
            ) : (
              results.map((u) => (
                <tr key={u.id || u.user_id}>
                  <td>
                    <Link to={`/admin/users/${u.id || u.user_id}`} className={styles.userLink}>
                      {u.username}
                    </Link>
                  </td>
                  <td>
                    {u.first_name} {u.last_name}
                  </td>
                  <td style={{ fontSize: 13, color: 'var(--text-muted)' }}>{u.email ?? '-'}</td>
                  <td>{u.is_admin ? 'Yes' : 'No'}</td>
                  <td>{u.is_shadow_banned || u.activation_status === 'blocked' ? 'Yes' : 'No'}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
