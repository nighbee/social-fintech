import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import styles from './Layout.module.css';

const navItems = [
  { to: '/admin', label: 'Dashboard' },
  { to: '/admin/users', label: 'Users' },
  { to: '/admin/posts', label: 'Posts' },
  { to: '/admin/reports', label: 'Reports' },
  { to: '/admin/leaderboard', label: 'Leaderboard' },
  { to: '/admin/seasons', label: 'Seasons' },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();

  const pageTitle = navItems.find((item) => item.to === location.pathname)?.label
    || (location.pathname.startsWith('/admin/users/') ? 'User Detail' : '')
    || (location.pathname.startsWith('/admin/posts/') ? 'Post Detail' : '')
    || 'Admin';

  return (
    <div className={styles.layout}>
      <aside className={styles.sidebar}>
        <div className={styles.logo}>Brightbund Admin</div>
        <nav className={styles.nav}>
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/admin'}
              className={({ isActive }) =>
                `${styles.navLink} ${isActive ? styles.navLinkActive : ''}`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className={styles.logoutArea}>
          <button className={styles.logoutBtn} onClick={logout}>
            Logout
          </button>
        </div>
      </aside>
      <div className={styles.main}>
        <header className={styles.header}>
          <h1 className={styles.headerTitle}>{pageTitle}</h1>
          <span className={styles.userInfo}>{user?.email}</span>
        </header>
        <div className={styles.content}>
          <Outlet />
        </div>
      </div>
    </div>
  );
}
