import { useState } from 'react';
import {
  getLeaderboardScopes,
  addUserToLeaderboard,
  removeUserFromLeaderboard,
  adjustLeaderboardScore,
  resetLeaderboard,
} from '../../api/leaderboard';
import { searchUserByEmail } from '../../api/users';
import { Loading, ErrorMessage } from '../../components/Loading';
import styles from './LeaderboardPage.module.css';

export default function LeaderboardPage() {
  const [scopes, setScopes] = useState([]);
  const [scopesLoading, setScopesLoading] = useState(false);
  const [scopesError, setScopesError] = useState(null);

  const [actionResult, setActionResult] = useState(null);

  const [addMode, setAddMode] = useState(false);
  const [removeMode, setRemoveMode] = useState(false);
  const [adjustMode, setAdjustMode] = useState(false);
  const [resetMode, setResetMode] = useState(false);

  const [addForm, setAddForm] = useState({ email: '', scope: 'global', region: '', score: 0 });
  const [removeForm, setRemoveForm] = useState({ email: '', scope: 'global', region: '' });
  const [adjustForm, setAdjustForm] = useState({ email: '', scope: 'global', region: '', amount: 0 });
  const [resetForm, setResetForm] = useState({ scope: 'global', region: '', allWeeks: false });

  const [emailSearchResults, setEmailSearchResults] = useState(null);
  const [emailSearchLoading, setEmailSearchLoading] = useState(false);

  const loadScopes = async () => {
    setScopesLoading(true);
    setScopesError(null);
    try {
      const data = await getLeaderboardScopes();
      setScopes(data.scopes || []);
    } catch (e) {
      setScopesError(e.message);
    } finally {
      setScopesLoading(false);
    }
  };

  const handleEmailSearch = async (email) => {
    if (!email.trim()) return;
    setEmailSearchLoading(true);
    try {
      const user = await searchUserByEmail(email.trim());
      setEmailSearchResults(user ? [user] : []);
    } catch (e) {
      setEmailSearchResults(null);
    } finally {
      setEmailSearchLoading(false);
    }
  };

  const handleAddUser = async () => {
    if (!addForm.email || !emailSearchResults || emailSearchResults.length === 0) return;
    const userId = emailSearchResults[0].id;
    try {
      await addUserToLeaderboard(userId, addForm.scope, addForm.score, addForm.region || undefined);
      setActionResult({ type: 'success', message: `User added to ${addForm.scope} leaderboard` });
      setAddMode(false);
      setAddForm({ email: '', scope: 'global', region: '', score: 0 });
      setEmailSearchResults(null);
      loadScopes();
    } catch (e) {
      setActionResult({ type: 'error', message: e.message });
    }
  };

  const handleRemoveUser = async () => {
    if (!removeForm.email || !emailSearchResults || emailSearchResults.length === 0) return;
    const userId = emailSearchResults[0].id;
    try {
      await removeUserFromLeaderboard(userId, removeForm.scope, removeForm.region || undefined);
      setActionResult({ type: 'success', message: `User removed from ${removeForm.scope} leaderboard` });
      setRemoveMode(false);
      setRemoveForm({ email: '', scope: 'global', region: '' });
      setEmailSearchResults(null);
      loadScopes();
    } catch (e) {
      setActionResult({ type: 'error', message: e.message });
    }
  };

  const handleAdjustScore = async () => {
    if (!adjustForm.email || !emailSearchResults || emailSearchResults.length === 0) return;
    const userId = emailSearchResults[0].id;
    try {
      await adjustLeaderboardScore(userId, adjustForm.scope, adjustForm.amount, adjustForm.region || undefined);
      setActionResult({ type: 'success', message: `Score adjusted by ${adjustForm.amount} in ${adjustForm.scope}` });
      setAdjustMode(false);
      setAdjustForm({ email: '', scope: 'global', region: '', amount: 0 });
      setEmailSearchResults(null);
      loadScopes();
    } catch (e) {
      setActionResult({ type: 'error', message: e.message });
    }
  };

  const handleReset = async () => {
    try {
      const resp = await resetLeaderboard(resetForm.scope, resetForm.region || undefined, resetForm.allWeeks);
      setActionResult({
        type: 'success',
        message: `Reset complete: ${resp.keys_deleted} keys deleted, ${resp.members_dropped} members dropped`,
      });
      setResetMode(false);
      setResetForm({ scope: 'global', region: '', allWeeks: false });
      loadScopes();
    } catch (e) {
      setActionResult({ type: 'error', message: e.message });
    }
  };

  const scopeLabels = { global: 'Global', country: 'Country', city: 'City', district: 'District' };

  return (
    <div className={styles.page}>
      <div className={styles.actions}>
        <button className={styles.primaryBtn} onClick={() => { setAddMode(!addMode); setRemoveMode(false); setAdjustMode(false); setResetMode(false); setEmailSearchResults(null); }}>
          Add User
        </button>
        <button className={styles.primaryBtn} onClick={() => { setRemoveMode(!removeMode); setAddMode(false); setAdjustMode(false); setResetMode(false); setEmailSearchResults(null); }}>
          Remove User
        </button>
        <button className={styles.primaryBtn} onClick={() => { setAdjustMode(!adjustMode); setAddMode(false); setRemoveMode(false); setResetMode(false); setEmailSearchResults(null); }}>
          Adjust Score
        </button>
        <button className={styles.dangerBtn} onClick={() => { setResetMode(!resetMode); setAddMode(false); setRemoveMode(false); setAdjustMode(false); }}>
          Reset
        </button>
        <button className={styles.secondaryBtn} onClick={loadScopes}>
          Refresh Scopes
        </button>
      </div>

      {actionResult && (
        <div className={actionResult.type === 'success' ? styles.successMsg : styles.errorMsg}>
          {actionResult.message}
          <button className={styles.dismissBtn} onClick={() => setActionResult(null)}>×</button>
        </div>
      )}

      {addMode && (
        <div className={styles.formCard}>
          <h3 className={styles.formTitle}>Add User to Leaderboard</h3>
          <div className={styles.formRow}>
            <input
              className={styles.input}
              placeholder="User email..."
              value={addForm.email}
              onChange={(e) => setAddForm({ ...addForm, email: e.target.value })}
            />
            <button className={styles.searchBtn} onClick={() => handleEmailSearch(addForm.email)} disabled={emailSearchLoading}>
              {emailSearchLoading ? 'Searching...' : 'Find User'}
            </button>
          </div>
          {emailSearchResults && emailSearchResults.length > 0 && (
            <div className={styles.foundUser}>
              Found: {emailSearchResults[0].username} ({emailSearchResults[0].email})
            </div>
          )}
          {emailSearchResults && emailSearchResults.length === 0 && (
            <div className={styles.notFound}>User not found</div>
          )}
          <div className={styles.formRow}>
            <select className={styles.select} value={addForm.scope} onChange={(e) => setAddForm({ ...addForm, scope: e.target.value })}>
              <option value="global">Global</option>
              <option value="country">Country</option>
              <option value="city">City</option>
              <option value="district">District</option>
            </select>
            {addForm.scope !== 'global' && (
              <input
                className={styles.input}
                placeholder="H3 region index (optional, all regions if empty)"
                value={addForm.region}
                onChange={(e) => setAddForm({ ...addForm, region: e.target.value })}
              />
            )}
          </div>
          <div className={styles.formRow}>
            <input
              className={styles.input}
              type="number"
              placeholder="Score"
              value={addForm.score}
              onChange={(e) => setAddForm({ ...addForm, score: parseFloat(e.target.value) || 0 })}
            />
          </div>
          <div className={styles.formActions}>
            <button className={styles.submitBtn} onClick={handleAddUser}>Add</button>
            <button className={styles.cancelBtn} onClick={() => { setAddMode(false); setEmailSearchResults(null); }}>Cancel</button>
          </div>
        </div>
      )}

      {removeMode && (
        <div className={styles.formCard}>
          <h3 className={styles.formTitle}>Remove User from Leaderboard</h3>
          <div className={styles.formRow}>
            <input
              className={styles.input}
              placeholder="User email..."
              value={removeForm.email}
              onChange={(e) => setRemoveForm({ ...removeForm, email: e.target.value })}
            />
            <button className={styles.searchBtn} onClick={() => handleEmailSearch(removeForm.email)} disabled={emailSearchLoading}>
              {emailSearchLoading ? 'Searching...' : 'Find User'}
            </button>
          </div>
          {emailSearchResults && emailSearchResults.length > 0 && (
            <div className={styles.foundUser}>
              Found: {emailSearchResults[0].username} ({emailSearchResults[0].email})
            </div>
          )}
          {emailSearchResults && emailSearchResults.length === 0 && (
            <div className={styles.notFound}>User not found</div>
          )}
          <div className={styles.formRow}>
            <select className={styles.select} value={removeForm.scope} onChange={(e) => setRemoveForm({ ...removeForm, scope: e.target.value })}>
              <option value="global">Global</option>
              <option value="country">Country</option>
              <option value="city">City</option>
              <option value="district">District</option>
            </select>
            {removeForm.scope !== 'global' && (
              <input
                className={styles.input}
                placeholder="H3 region index (empty = all regions)"
                value={removeForm.region}
                onChange={(e) => setRemoveForm({ ...removeForm, region: e.target.value })}
              />
            )}
          </div>
          <div className={styles.formActions}>
            <button className={styles.dangerBtn} onClick={handleRemoveUser}>Remove</button>
            <button className={styles.cancelBtn} onClick={() => { setRemoveMode(false); setEmailSearchResults(null); }}>Cancel</button>
          </div>
        </div>
      )}

      {adjustMode && (
        <div className={styles.formCard}>
          <h3 className={styles.formTitle}>Adjust Score</h3>
          <div className={styles.formRow}>
            <input
              className={styles.input}
              placeholder="User email..."
              value={adjustForm.email}
              onChange={(e) => setAdjustForm({ ...adjustForm, email: e.target.value })}
            />
            <button className={styles.searchBtn} onClick={() => handleEmailSearch(adjustForm.email)} disabled={emailSearchLoading}>
              {emailSearchLoading ? 'Searching...' : 'Find User'}
            </button>
          </div>
          {emailSearchResults && emailSearchResults.length > 0 && (
            <div className={styles.foundUser}>
              Found: {emailSearchResults[0].username} ({emailSearchResults[0].email})
            </div>
          )}
          {emailSearchResults && emailSearchResults.length === 0 && (
            <div className={styles.notFound}>User not found</div>
          )}
          <div className={styles.formRow}>
            <select className={styles.select} value={adjustForm.scope} onChange={(e) => setAdjustForm({ ...adjustForm, scope: e.target.value })}>
              <option value="global">Global</option>
              <option value="country">Country</option>
              <option value="city">City</option>
              <option value="district">District</option>
            </select>
            {adjustForm.scope !== 'global' && (
              <input
                className={styles.input}
                placeholder="H3 region index (empty = all regions)"
                value={adjustForm.region}
                onChange={(e) => setAdjustForm({ ...adjustForm, region: e.target.value })}
              />
            )}
          </div>
          <div className={styles.formRow}>
            <input
              className={styles.input}
              type="number"
              placeholder="Adjustment amount (positive/negative)"
              value={adjustForm.amount}
              onChange={(e) => setAdjustForm({ ...adjustForm, amount: parseFloat(e.target.value) || 0 })}
            />
          </div>
          <div className={styles.formActions}>
            <button className={styles.submitBtn} onClick={handleAdjustScore}>Adjust</button>
            <button className={styles.cancelBtn} onClick={() => { setAdjustMode(false); setEmailSearchResults(null); }}>Cancel</button>
          </div>
        </div>
      )}

      {resetMode && (
        <div className={styles.formCard}>
          <h3 className={styles.formTitle}>Reset Leaderboard</h3>
          <p style={{ margin: 0, fontSize: 13, color: 'var(--text-muted)' }}>
            This will permanently delete the sorted set and all member data for the selected scope. This action cannot be undone.
          </p>
          <div className={styles.formRow}>
            <select className={styles.select} value={resetForm.scope} onChange={(e) => setResetForm({ ...resetForm, scope: e.target.value })}>
              <option value="global">Global</option>
              <option value="country">Country</option>
              <option value="city">City</option>
              <option value="district">District</option>
            </select>
            {resetForm.scope !== 'global' && (
              <input
                className={styles.input}
                placeholder="H3 region index (empty = all regions)"
                value={resetForm.region}
                onChange={(e) => setResetForm({ ...resetForm, region: e.target.value })}
              />
            )}
          </div>
          <div className={styles.formRow}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14 }}>
              <input
                type="checkbox"
                checked={resetForm.allWeeks}
                onChange={(e) => setResetForm({ ...resetForm, allWeeks: e.target.checked })}
              />
              Delete all weeks (not just current week)
            </label>
          </div>
          <div className={styles.formActions}>
            <button className={styles.dangerBtn} onClick={handleReset}>Reset Leaderboard</button>
            <button className={styles.cancelBtn} onClick={() => setResetMode(false)}>Cancel</button>
          </div>
        </div>
      )}

      <h3 className={styles.sectionTitle}>Leaderboard Scopes</h3>

      {scopesLoading && <Loading />}
      {scopesError && <ErrorMessage message={scopesError} onRetry={loadScopes} />}

      {!scopesLoading && !scopesError && (
        <table className={styles.table}>
          <thead>
            <tr>
              <th>Scope</th>
              <th>Region</th>
              <th>Members</th>
              <th>Key</th>
            </tr>
          </thead>
          <tbody>
            {scopes.length === 0 ? (
              <tr>
                <td colSpan={4} style={{ textAlign: 'center', color: 'var(--text-muted)' }}>
                  No leaderboard scopes found. Load to see current state.
                </td>
              </tr>
            ) : (
              scopes.map((s, i) => (
                <tr key={s.key + i}>
                  <td>
                    <span className={styles.scopeBadge} data-scope={s.scope}>
                      {scopeLabels[s.scope] || s.scope}
                    </span>
                  </td>
                  <td>{s.region || '-'}</td>
                  <td>{s.card}</td>
                  <td style={{ fontSize: 12, color: 'var(--text-muted)', wordBreak: 'break-all' }}>
                    {s.key}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      )}
    </div>
  );
}
