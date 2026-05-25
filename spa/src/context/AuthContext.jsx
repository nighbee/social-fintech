import { createContext, useContext, useState, useCallback } from 'react';
import { adminLogin } from '../api/users';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => localStorage.getItem('admin_token'));
  const [user, setUser] = useState(() => {
    const stored = localStorage.getItem('admin_user');
    return stored ? JSON.parse(stored) : null;
  });
  const [loginError, setLoginError] = useState(null);
  const [loggingIn, setLoggingIn] = useState(false);

  const login = useCallback(async (email, password) => {
    setLoggingIn(true);
    setLoginError(null);
    try {
      const resp = await adminLogin(email, password);
      if (!resp.user?.is_admin) {
        throw new Error('Not an admin account');
      }
      localStorage.setItem('admin_token', resp.access_token);
      localStorage.setItem('admin_user', JSON.stringify(resp.user));
      setToken(resp.access_token);
      setUser(resp.user);
      return true;
    } catch (e) {
      setLoginError(e.message);
      return false;
    } finally {
      setLoggingIn(false);
    }
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    setToken(null);
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated: !!token,
        user,
        login,
        logout,
        loginError,
        loggingIn,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
