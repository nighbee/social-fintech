# Admin SPA Routes

## Auth & Protection

All admin routes require:

1. `RequireAuth` — validates JWT, checks session is not revoked, user is not shadow-banned/blocked
2. `TouchSession` — updates session `last_used_at`
3. `RequireAdmin` — verifies `user.IsAdmin == true`, returns `403 ADMIN_REQUIRED` otherwise

**Exception:** `POST /api/v1/admin/login` is public (no auth required). Returns JWT for an admin user.

**Base URL:** `/api/v1`

---

## Admin Login (Public)

```
POST /api/v1/admin/login
```

**Body:**
```json
{
  "email": "admin@example.com",
  "password": "adminpassword"
}
```

**Response 200:** `LoginResponse` — access_token, refresh_token, user (with `is_admin: true`)
**Response 401:** `{"error": "invalid_credentials"}` — wrong credentials or user is not an admin

---

## Admin Routes (All Require JWT + Admin)

### Users

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/v1/admin/users/:user_id` | Get full user details (email, ban status, shadow-ban, activation, etc.) |
| `GET` | `/api/v1/admin/users/search?email=` | Search user by exact email |

**`GET /api/v1/admin/users/:user_id` response:**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "username": "johndoe",
  "first_name": "John",
  "last_name": "Doe",
  "date_of_birth": "2000-01-01T00:00:00Z",
  "avatar_url": "...",
  "is_admin": false,
  "is_shadow_banned": false,
  "activation_status": "active",
  "restrictions_until": null,
  "deleted_at": null,
  "last_active_at": "...",
  "created_at": "..."
}
```

### Ban User

```
POST /api/v1/admin/ban
```

**Body:**
```json
{
  "user_id": "uuid",
  "ban_type": "temporary | permanent",
  "duration": "24h",
  "reason": "string"
}
```

**Response:** `204 No Content` — revokes all active sessions for the user.

---

### Posts

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/v1/admin/posts/:post_id` | Get any post by ID (shadow-banned/hidden included) |
| `GET` | `/api/v1/admin/posts/search?query=&limit=&offset=` | Full-text search on post captions |
| `DELETE` | `/api/v1/admin/posts/:post_id` | Admin delete any post |

**`GET /api/v1/admin/posts/:post_id` response:** `PostResponse` — full post with author, media, metrics, viewer interaction state.

**`GET /api/v1/admin/posts/search` response:**
```json
{
  "posts": [ PostResponse, ... ],
  "total": 150
}
```

---

### Comments

| Method | Route | Description |
|---|---|---|
| `DELETE` | `/api/v1/admin/comments/:comment_id` | Admin delete any comment |

---

### Moderation Reports

```
GET /api/v1/admin/reports
```

**Query params:**
| Param | Type | Default | Description |
|---|---|---|---|
| `status` | string | — | `pending` or `reviewed` |
| `target_type` | string | — | `post` or `comment` |
| `reason` | string | — | Filter by reason |
| `limit` | int | 50 | Pagination limit |
| `offset` | int | 0 | Pagination offset |

---

### Economy

| Method | Route | Description |
|---|---|---|
| `POST` | `/api/v1/economy/admin/adjust` | Adjust user balance (silvers/gold) |
| `GET` | `/api/v1/economy/admin/violations?user_id=` | Get violation logs for a user |

**Adjust body:**
```json
{
  "user_id": "uuid",
  "currency": "SILVER_SEAL | GOLD_SEAL",
  "amount": 1000,
  "reason": "string"
}
```

- `amount` is in centinels (1000 = 10.00 silvers)
- `GOLD_SEAL` direct mint is disabled server-side
- Negative amounts deduct from balance

---

### Observability

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/v1/admin/ops/metrics` | JSON metrics snapshot |
| `GET` | `/api/v1/admin/ops/metrics/prometheus` | Prometheus text format |

---

## Lookup Routes (Non-Admin, Used by Admin SPA)

| Method | Route | Auth | Description |
|---|---|---|---|
| `GET` | `/api/v1/users/search?query=` | Public | Search users by name/username |
| `GET` | `/api/v1/profiles/:user_id` | JWT | Public profile (limited fields) |
| `GET` | `/api/v1/posts/:post_id/comments` | JWT | Threaded comments on a post |

---

## SPA Page → API Mapping

| Page | Route | API Calls |
|---|---|---|
| Login | `/admin/login` | `POST /api/v1/admin/login` |
| Dashboard | `/admin` | `GET /api/v1/admin/ops/metrics` |
| Users | `/admin/users` | `GET /api/v1/admin/users/search`, `GET /api/v1/users/search` |
| User Detail | `/admin/users/:id` | `GET /api/v1/admin/users/:id`, `POST /api/v1/admin/ban`, `POST /api/v1/economy/admin/adjust`, `GET /api/v1/economy/admin/violations` |
| Posts | `/admin/posts` | `GET /api/v1/admin/posts/search` |
| Post Detail | `/admin/posts/:id` | `GET /api/v1/admin/posts/:id`, `DELETE /api/v1/admin/posts/:id`, `GET /api/v1/posts/:id/comments`, `DELETE /api/v1/admin/comments/:id` |
| Reports | `/admin/reports` | `GET /api/v1/admin/reports` |
