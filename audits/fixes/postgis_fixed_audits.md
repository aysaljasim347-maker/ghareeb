# 🛠 PostGIS & PostgreSQL Performance Fixes: DisasterAid V2.1

**Engineer:** Senior PostGIS Performance Engineer
**Status:** Implementation of Phase 4A Audit
**Date:** May 13, 2026

---

## 🔴 Critical Fixes

### 1. Missing Spatial Indexes (GIST)
**Problem:** Multiple tables containing geospatial data lack GIST indexes, causing full table scans for proximity queries.
**Why it is slow:** PostGIS cannot use bounding box optimizations without a GIST index.
**Optimized SQL (Index Creation):**
```sql
-- Apply GIST indexes to all geospatial columns
CREATE INDEX IF NOT EXISTS idx_ngo_location ON ngo_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_volunteer_location ON volunteer_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_campaign_location ON campaigns USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_deliveries_location ON deliveries USING GIST(gps_location);
```

### 2. Slow Join Operations (Foreign Key Indexes)
**Problem:** Missing indexes on foreign keys used in core services (`Tasks`, `Donations`, `Chat`).
**Why it is slow:** Joins like `tasks LEFT JOIN campaigns` or filtering `donations` by `campaign_id` result in sequential scans of the child tables.
**Fix (Index Creation):**
```sql
CREATE INDEX IF NOT EXISTS idx_tasks_campaign_id ON tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_donations_campaign_id ON donations(campaign_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_ledger_from_user ON ledger_entries(from_user_id);
CREATE INDEX IF NOT EXISTS idx_ledger_to_user ON ledger_entries(to_user_id);
```

---

## 🟠 High-Impact Quick Fixes

### 1. Task Discovery Optimization
**Problem:** The `getAvailableTasks` query sorts by a complex `CASE` expression for urgency and filters by status.
**Fix:** Create a partial, ordered index to make discovery near-instant.
```sql
CREATE INDEX IF NOT EXISTS idx_tasks_discovery_optimized ON tasks (
  (CASE urgency
    WHEN 'CRITICAL' THEN 1
    WHEN 'HIGH' THEN 2
    WHEN 'MEDIUM' THEN 3
    WHEN 'LOW' THEN 4
  END),
  created_at DESC
) WHERE status = 'OPEN';
```

### 2. User Activity Tracking
**Problem:** `task_views` is primarily indexed on `(task_id, user_id)`. Querying "all tasks seen by a user" is inefficient.
**Fix:** Add a reverse-order index.
```sql
CREATE INDEX IF NOT EXISTS idx_task_views_user_task ON task_views(user_id, task_id);
```

---

## ⚠️ Deferred (Risky Changes)

### 1. Materialized Views for NGO Leaderboards
**Explanation:** While a materialized view would speed up NGO rankings, it introduces complexity around refresh intervals and data staleness. This is deferred until traffic volume justifies the cache invalidation logic.

### 2. Partitioning `ledger_entries`
**Explanation:** Table partitioning is a high-impact change but requires significant schema migration. Deferred until the ledger exceeds 10 million rows.

---

## ✅ Good Practices Found

*   **Existing GIST Index:** `tasks.location` was already correctly indexed with GIST.
*   **Partial Status Index:** `idx_tasks_status` correctly filters for 'OPEN' and 'ASSIGNED' states.
*   **Modern PostgreSQL:** Use of `GEOGRAPHY` type over `GEOMETRY` for simpler distance calculations (meters) was a good architectural choice.

---

## 🛠 Final Migration Script

```sql
BEGIN;

-- 1. Geospatial GIST Indexes
CREATE INDEX IF NOT EXISTS idx_ngo_location ON ngo_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_volunteer_location ON volunteer_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_campaign_location ON campaigns USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_deliveries_location ON deliveries USING GIST(gps_location);

-- 2. Foreign Key B-Tree Indexes
CREATE INDEX IF NOT EXISTS idx_tasks_campaign_id ON tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_donations_campaign_id ON donations(campaign_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_task_id ON chat_rooms(task_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_ledger_from_user ON ledger_entries(from_user_id);
CREATE INDEX IF NOT EXISTS idx_ledger_to_user ON ledger_entries(to_user_id);

-- 3. Optimized Discovery Index (Expression + Partial)
CREATE INDEX IF NOT EXISTS idx_tasks_discovery_optimized ON tasks (
  (CASE urgency
    WHEN 'CRITICAL' THEN 1
    WHEN 'HIGH' THEN 2
    WHEN 'MEDIUM' THEN 3
    WHEN 'LOW' THEN 4
  END),
  created_at DESC
) WHERE status = 'OPEN';

-- 4. Covered Index for User Views
CREATE INDEX IF NOT EXISTS idx_task_views_user_task ON task_views(user_id, task_id);

COMMIT;
```
