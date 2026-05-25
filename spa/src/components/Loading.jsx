import styles from './shared.module.css';

export function Loading() {
  return <div className={styles.loading}>Loading...</div>;
}

export function ErrorMessage({ message, onRetry }) {
  return (
    <div className={styles.error}>
      <span className={styles.errorText}>{message}</span>
      {onRetry && (
        <button className={styles.retryBtn} onClick={onRetry}>
          Retry
        </button>
      )}
    </div>
  );
}
