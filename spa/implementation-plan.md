# Admin SPA — Implementation Plan

## Stack

- **Bundler:** Vite (React template)
- **Framework:** React 18
- **Routing:** react-router-dom v6
- **Styling:** plain CSS with CSS modules (no UI library)
- **HTTP:** fetch API (no axios)
- **State:** React Context for auth/API client, local state per page

No Redux, no Tailwind, no component library. Minimal dependencies.

---

## Project Structure

```
spa/
  index.html
  vite.config.js
  package.json
  public/
  src/
    main.jsx
    App.jsx
    api/
      client.js        # fetch wrapper — injects JWT, base URL, error handling
      auth.js          # POST /admin/login
      users.js         # GET /admin/users/:id, GET /admin/users/search?email=, GET /users/search
      posts.js         # GET /admin/posts/:id, GET /admin/posts/search
      moderation.js    # POST /admin/ban, DELETE /admin/posts/:id, DELETE /admin/comments/:id
      reports.js       # GET /admin/reports
      economy.js       # POST /economy/admin/adjust, GET /economy/admin/violations
      metrics.js       # GET /admin/ops/metrics
    context/
      AuthContext.jsx  # login/logout, JWT storage (localStorage), isAuthenticated, user
    components/
      Layout.jsx       # sidebar + header + main content area
      Layout.module.css
      ProtectedRoute.jsx  # redirects to /login if not authenticated
      Loading.jsx
      Error.jsx
    pages/
      LoginPage/
        LoginPage.jsx
        LoginPage.module.css
      DashboardPage/
        DashboardPage.jsx
        DashboardPage.module.css
      UsersPage/
        UsersPage.jsx          # search + list
        UsersPage.module.css
      UserDetailPage/
        UserDetailPage.jsx     # full info, ban form, adjust balance
        UserDetailPage.module.css
      PostsPage/
        PostsPage.jsx          # search + list
        PostsPage.module.css
      PostDetailPage/
        PostDetailPage.jsx     # full post, delete, view comments
        PostDetailPage.module.css
      ReportsPage/
        ReportsPage.jsx        # report list with filters
        ReportsPage.module.css
      NotFoundPage.jsx
    hooks/
      useApi.js       # generic async hook: { data, loading, error, refetch }
```

---

## Auth Flow

1. `AuthContext` holds `{ user, token, isAuthenticated, login(email, password), logout() }`
2. `login()` calls `POST /api/v1/admin/login` → stores JWT in localStorage
3. `api/client.js` reads JWT from localStorage and attaches `Authorization: Bearer` header
4. On app load, check localStorage for token → set `isAuthenticated = true`
5. `logout()` clears localStorage + resets context

---

## Routing

```jsx
<BrowserRouter>
  <AuthProvider>
    <Routes>
      <Route path="/admin/login" element={<LoginPage />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<Layout />}>
          <Route path="/admin" element={<DashboardPage />} />
          <Route path="/admin/users" element={<UsersPage />} />
          <Route path="/admin/users/:id" element={<UserDetailPage />} />
          <Route path="/admin/posts" element={<PostsPage />} />
          <Route path="/admin/posts/:id" element={<PostDetailPage />} />
          <Route path="/admin/reports" element={<ReportsPage />} />
        </Route>
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  </AuthProvider>
</BrowserRouter>
```

---

## Component Details

### `api/client.js`
```js
const BASE = import.meta.env.VITE_API_URL || '/api/v1';

async function request(method, path, body) {
  const token = localStorage.getItem('admin_token');
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (res.status === 401) {
    localStorage.removeItem('admin_token');
    window.location = '/admin/login';
    return;
  }

  if (res.status === 204) return null;

  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

export const api = {
  get: (path) => request('GET', path),
  post: (path, body) => request('POST', path, body),
  delete: (path) => request('DELETE', path),
};
```

### `hooks/useApi.js`
```js
import { useState, useEffect, useCallback } from 'react';

export function useApi(fn, deps = []) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const execute = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await fn();
      setData(result);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, deps);

  useEffect(() => { execute(); }, [execute]);

  return { data, loading, error, refetch: execute };
}
```

---

## Page-by-Page Breakdown

### LoginPage
- Email + password form
- Calls `POST /admin/login`
- On success: store JWT, redirect to `/admin`
- On error: show "Invalid credentials"

### DashboardPage
- Fetches `GET /admin/ops/metrics`
- Displays key numbers in cards: active users, total posts, reports pending, etc.
- Link shortcuts to Users, Posts, Reports

### UsersPage
- Search bar (by name: uses `GET /api/v1/users/search?query=`)
- Search bar (by email: uses `GET /api/v1/admin/users/search?email=`)
- Results list: username, avatar, status
- Click → navigate to `/admin/users/:id`

### UserDetailPage
- Fetches `GET /api/v1/admin/users/:id`
- Displays all admin fields: email, username, full name, avatar, is_admin, is_shadow_banned, activation_status, restrictions_until, deleted_at
- **Ban section:** form with ban_type dropdown (temporary/permanent), duration input, reason textarea → `POST /admin/ban`
- **Economy section:** adjust balance form (amount, reason) → `POST /economy/admin/adjust`
- **Violations section:** fetches `GET /economy/admin/violations?user_id=` → displays table

### PostsPage
- Search bar (keyword search on captions) → `GET /admin/posts/search?query=`
- Results list: thumbnail, caption snippet, author, created_at
- Click → navigate to `/admin/posts/:id`

### PostDetailPage
- Fetches `GET /api/v1/admin/posts/:id`
- Displays full post: author info, media, caption, metrics
- **Delete button** → confirm → `DELETE /admin/posts/:id`
- **Comments section:** fetches `GET /posts/:id/comments` → threaded display
- Each comment has a **Delete** button → `DELETE /admin/comments/:comment_id`

### ReportsPage
- Fetches `GET /admin/reports?status=pending`
- Filter by status (pending/reviewed), target_type (post/comment)
- Table: target_id, target_type, reason, reporter, status
- Click post ID → navigate to post detail

---

## Tasks (Implementation Order)

### Phase 1 — Project Scaffold
- [ ] Initialize Vite React project in `spa/`
- [ ] Install deps: react-router-dom
- [ ] Create `src/api/client.js`
- [ ] Create `src/context/AuthContext.jsx`
- [ ] Create `src/hooks/useApi.js`
- [ ] Create basic `App.jsx` with routing skeleton
- [ ] Verify the dev server works

### Phase 2 — Auth Guard + Layout
- [ ] Create `LoginPage` — email + password form, login flow
- [ ] Create `ProtectedRoute` — redirects unauthenticated to `/admin/login`
- [ ] Create `Layout` — sidebar navigation (Users, Posts, Reports, Dashboard), header with logout
- [ ] Wire everything in `App.jsx`

### Phase 3 — User Management
- [ ] Create `api/users.js` — `getUserById`, `searchByEmail`
- [ ] Create `api/moderation.js` — `banUser`
- [ ] Create `api/economy.js` — `adjustBalance`, `getViolations`
- [ ] Create `UsersPage` — name search + email search, results list
- [ ] Create `UserDetailPage` — full info display, ban form, balance adjustment form, violations list

### Phase 4 — Post Management
- [ ] Create `api/posts.js` — `getPostById`, `searchPosts`, `deletePost`, `deleteComment`, `getComments`
- [ ] Create `PostsPage` — keyword search, results list
- [ ] Create `PostDetailPage` — post display, delete, threaded comments with delete

### Phase 5 — Reports + Dashboard
- [ ] Create `api/reports.js` — `getReports`
- [ ] Create `api/metrics.js` — `getMetrics`
- [ ] Create `ReportsPage` — filterable report list
- [ ] Create `DashboardPage` — metrics cards + quick links

### Phase 6 — Polish
- [ ] Add Loading/Error states to all pages
- [ ] Add 404 page
- [ ] Responsive sidebar collapse on mobile
- [ ] Confirm dialogs for destructive actions (ban, delete)

---

## Style Guidelines

- Dark sidebar (240px), light content area
- Max content width 1200px, centered
- Consistent 16px/24px spacing scale
- Colors: sidebar #1a1a2e, accent #e94560, success #0f9b0f, danger #cc0000
- Forms: labels above inputs, full-width inputs, consistent padding
- Tables: alternating row backgrounds, header sticky
- No animations beyond hover transitions
- Mobile: sidebar collapses to icons, hamburger toggle

---

## Predefined Admin Credentials

The backend's `EnsureAdmins()` reads from `cfg.Admin.Emails` at startup and promotes those users. The admin SPA will use whatever email+password is configured there. The SPA itself doesn't hardcode credentials — the login form just sends whatever the admin types.

For development, configure in `backend/config.yaml`:
```yaml
admin:
  emails:
    - admin@brightbund.com
```

Then register that user via the normal auth flow first, and it gets promoted to admin on restart.
