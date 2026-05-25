import { Link } from 'react-router-dom';
import styles from './NotFoundPage.module.css';

export default function NotFoundPage() {
  return (
    <div className={styles.container}>
      <div className={styles.title}>404</div>
      <div className={styles.subtitle}>Page not found</div>
      <Link to="/admin" className={styles.link}>
        Go to Dashboard
      </Link>
    </div>
  );
}
