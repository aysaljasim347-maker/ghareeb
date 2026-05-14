# 🚀 Backend Performance Audit: DisasterAid V2.1

**Auditor:** Senior Backend Performance Engineer
**Date:** May 13, 2026
**Scope:** Node.js (Express), TypeScript, PostgreSQL Interaction

---

## 🔴 Critical Bottlenecks

### 1. Database Hit on Every Authenticated Request
**Problem:** The `authenticate` middleware in `auth.ts` queries the `users` and `roles` table for every single request that requires authentication.
**Why it is slow:** If the API handles 1,000 requests/sec, that is 1,000 additional, redundant DB queries just to verify user roles.
**Impact at scale:** Database connection pool exhaustion and significantly increased latency (30-100ms per request).
**Fix:** Embed the user's role and name in the JWT payload or use an in-memory cache (Redis or a simple LRU) for user roles.

```typescript
// Optimized JWT payload
const token = jwt.sign(
  { userId: user.id, role: user.role, name: user.name },
  env.JWT_SECRET
);

// Middleware can then trust the JWT (if verified)
const decoded = jwt.verify(token, env.JWT_SECRET) as AuthUser;
req.user = decoded; // No DB query needed!
```

### 2. Sequential Event Recording (Task Service)
**Problem:** Methods like `createTask`, `claimTask`, and `recordView` perform multiple sequential `await pool.query(...)` calls.
**Why it is slow:** Each `await` waits for the network round-trip to the DB.
**Impact at scale:** Increased response times and holding DB connections longer than necessary.
**Fix:** Use `Promise.all` for independent writes or combine into a single query/transaction block.

```typescript
// Instead of:
await pool.query(INSERT_TASK);
await pool.query(INSERT_EVENT);

// Use:
await Promise.all([
  pool.query(INSERT_TASK),
  pool.query(INSERT_EVENT)
]);
```

---

## 🟠 Medium Performance Issues

### 1. N+1 Problem in `ChatService.getUserRooms`
**Description:** The query uses a subquery `(SELECT COUNT(*) FROM chat_messages ...)` for every room returned. While PostgreSQL optimizes this, it is still less efficient than a `LEFT JOIN` with `GROUP BY`.
**Suggested optimization:** Use a join and aggregation.

```sql
SELECT cr.*, t.title AS task_title, COUNT(cm.id) AS message_count
FROM chat_rooms cr
JOIN tasks t ON t.id = cr.task_id
LEFT JOIN chat_messages cm ON cm.id = cr.id
GROUP BY cr.id, t.title;
```

### 2. Lack of In-Memory Caching for Roles
**Description:** The `AuthService.register` method queries the `roles` table every time to get a role ID.
**Suggested optimization:** Cache roles in memory on startup since they are static.

```typescript
const rolesCache: Record<string, number> = {}; 
// Initialize on startup
```

### 3. Redundant Access Checks in Sockets
**Description:** `join_room` in `chat.gateway.ts` performs a heavy join query to verify access.
**Suggested optimization:** If the user's role is `ADMIN`, bypass the check. For others, consider a lighter check or caching the "participation" status.

---

## 🟢 Minor Optimizations

### 1. `bcrypt` Work Factor
**Description:** `BCRYPT_ROUNDS` is set to 12. This is secure but slow.
**Suggested optimization:** Ensure it's not set higher than 12 in production, and use `bcrypt.compare` as late as possible in the logic.

### 2. Large JSONB Over-fetching
**Description:** Fetching `items_needed` JSONB for every task in a list view is wasteful if only the title and location are needed for the map.
**Suggested optimization:** Define a `TaskSummary` type and only select necessary columns.

---

## ⚠️ High-Risk Patterns

### 1. Non-Atomic View Counting
**Pattern:** `recordView` updates `task_views` and then `tasks.view_count` as two separate top-level queries.
**Risk:** Inconsistent state if the second query fails. Also doubles the write load.
**Recommendation:** Use a single CTE (Common Table Expression) to update both.

### 2. Memory-Heavy Photo URLs
**Pattern:** `deliveries` stores `photo_urls` as `TEXT[]`.
**Risk:** If a delivery has 50 high-res URLs, fetching multiple deliveries will consume significant memory in the Node.js process.
**Recommendation:** Implement strict pagination (limit 10-20) for deliveries.

---

## 🛠 Suggested Fixes (Optimized TypeScript)

### Optimized Authentication Middleware
```typescript
// backend/src/middleware/auth.ts
export async function authenticate(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) throw new Error();

    // Trust verified JWT payload to avoid DB hit
    const decoded = jwt.verify(token, env.JWT_SECRET) as AuthUser;
    
    // Optional: Add a 'version' check if you need to invalidate tokens
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Unauthorized' });
  }
}
```

### Parallel Event Dispatch
```typescript
// backend/src/modules/tasks/tasks.service.ts
async recordView(taskId: number, userId: number) {
  // Fire and forget or run in parallel
  Promise.all([
    pool.query(`INSERT INTO task_views ... ON CONFLICT ...`),
    pool.query(`UPDATE tasks SET view_count = view_count + 1 ...`)
  ]).catch(err => console.error('Failed to record view', err));
}
```

### Batch Role Pre-loading
```typescript
// backend/src/config/roles.ts
let rolesCache: Record<string, number> = {};

export async function preloadRoles() {
  const result = await pool.query('SELECT id, name FROM roles');
  rolesCache = Object.fromEntries(result.rows.map(r => [r.name, r.id]));
}

export const getRoleId = (name: string) => rolesCache[name];
```
