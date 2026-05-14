# 🌍 PostGIS & PostgreSQL Performance Audit: DisasterAid V2.1

**Auditor:** Senior Database Performance Engineer
**Date:** May 13, 2026
**Scope:** PostgreSQL 16 + PostGIS 3 Schema & Node.js Data Access Layer

---

## 🔴 Critical Bottlenecks

### 1. Lack of Spatial Filtering and Pagination
**Problem:** The `tasksService.getAvailableTasks()` query fetches *every single* record where `status = 'OPEN'`.
**Why it is slow:** As the platform grows, the number of open tasks will reach thousands. Fetching all of them (including large `items_needed` JSONB fields) without `LIMIT`, `OFFSET`, or spatial bounds (`ST_DWithin`) will cause massive memory consumption in the backend and network lag.
**Impact at scale:** Application timeouts, high DB CPU usage, and frontend crashes.
**Fix:** Implement geospatial radius filtering and keyset pagination.

```sql
-- Example of optimized spatial query
SELECT t.id, t.title, t.location
FROM tasks t
WHERE t.status = 'OPEN'
  AND ST_DWithin(t.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
ORDER BY t.created_at DESC
LIMIT 20;
```

### 2. Missing GIST Indexes on Geospatial Columns
**Problem:** Only `tasks.location` has a GIST index. `ngo_profiles.location`, `volunteer_profiles.location`, `campaigns.location`, and `deliveries.gps_location` are unindexed.
**Why it is slow:** Any future spatial query (e.g., "Find NGOs near this disaster") will result in a **Full Table Scan**.
**Impact at scale:** Exponential increase in query time for proximity-based features.
**Fix:**
```sql
CREATE INDEX idx_ngo_location ON ngo_profiles USING GIST(location);
CREATE INDEX idx_volunteer_location ON volunteer_profiles USING GIST(location);
CREATE INDEX idx_campaign_location ON campaigns USING GIST(location);
CREATE INDEX idx_deliveries_location ON deliveries USING GIST(gps_location);
```

---

## 🟠 Medium Performance Issues

### 1. Unindexed Foreign Keys
**Problem:** Multiple tables lack indexes on foreign keys used in frequent joins.
**Description:**
- `tasks.campaign_id` (Joined in `CampaignsService.getAll`)
- `donations.campaign_id` (Joined in `DonationsService.getDonationsByCampaign`)
- `chat_messages.room_id` (Crucial for message history)
**Suggested optimization:** Add B-Tree indexes to all frequently joined FKs.

```sql
CREATE INDEX idx_tasks_campaign_id ON tasks(campaign_id);
CREATE INDEX idx_donations_campaign_id ON donations(campaign_id);
CREATE INDEX idx_chat_messages_room_id ON chat_messages(room_id);
```

### 2. Sorting by Expression in `getAvailableTasks`
**Description:** The query uses `ORDER BY CASE t.urgency ...`. PostgreSQL cannot use a standard index on `urgency` for this custom sort order.
**Suggested optimization:** Use an expression index or refactor urgency to a numeric scale (1-4) to allow direct indexed sorting.

```sql
CREATE INDEX idx_tasks_urgency_sort ON tasks (
  (CASE urgency
    WHEN 'CRITICAL' THEN 1
    WHEN 'HIGH' THEN 2
    WHEN 'MEDIUM' THEN 3
    WHEN 'LOW' THEN 4
  END),
  created_at DESC
) WHERE status = 'OPEN';
```

---

## 🟢 Minor Optimizations

### 1. `SELECT *` Over-fetching
**Description:** Most service methods use `SELECT *`. The `tasks` table contains `items_needed` (JSONB) and `description` (TEXT), which can be large.
**Suggested optimization:** Only select required columns in list views.

### 2. `task_views` Indexing
**Description:** The PK is `(task_id, user_id)`. If we ever need to query "Tasks seen by this user", it will be slow.
**Suggested optimization:** Add an index on `(user_id, task_id)`.

---

## ⚠️ High-Risk Patterns

### 1. Task Claiming Race Condition (Mitigated but Heavy)
**Pattern:** `SELECT ... FOR UPDATE` on `tasks` during claiming.
**Risk:** While safe, it locks the row. If the transaction takes too long (e.g., due to slow nested updates), it will queue other volunteers.
**Recommendation:** Keep the `claimTask` transaction as lean as possible. Move the `volunteer_profiles` update *after* the task update but still within the same transaction to minimize lock duration on the `tasks` row.

### 2. Sequential Scans on `ledger_entries`
**Pattern:** `ledger_entries` will grow extremely fast. It lacks indexes on `from_user_id` and `to_user_id`.
**Risk:** Auditing a user's transaction history will become impossible at scale.
**Fix:** Add indexes on user references immediately.

---

## 🛠 Suggested Fixes (Complete SQL Script)

```sql
-- 1. Geospatial Indexes
CREATE INDEX IF NOT EXISTS idx_ngo_location ON ngo_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_volunteer_location ON volunteer_profiles USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_campaign_location ON campaigns USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_deliveries_location ON deliveries USING GIST(gps_location);

-- 2. Foreign Key Indexes
CREATE INDEX IF NOT EXISTS idx_tasks_campaign_id ON tasks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_tasks_beneficiary_id ON tasks(beneficiary_id);
CREATE INDEX IF NOT EXISTS idx_tasks_coordinator_id ON tasks(coordinator_id);
CREATE INDEX IF NOT EXISTS idx_donations_donor_id ON donations(donor_id);
CREATE INDEX IF NOT EXISTS idx_donations_campaign_id ON donations(campaign_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_task_id ON chat_rooms(task_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_ledger_from_user ON ledger_entries(from_user_id);
CREATE INDEX IF NOT EXISTS idx_ledger_to_user ON ledger_entries(to_user_id);

-- 3. Optimized Partial Index for Task Discovery
-- Combines status filter with urgency/time sorting
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
```
