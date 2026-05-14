# 🏛 Backend Architecture Applied Refactors: DisasterAid V2.1

**Architect:** Principal Backend Architect
**Status:** Implementation of Phase 5A Architecture Audit
**Date:** May 13, 2026

---

## 🔴 Critical Safe Fixes

### 1. Repository Pattern Extraction (Decoupling DB from Logic)
**Problem:** `TasksService` contains both business logic (status transitions, permissions) and raw SQL strings.
**Current Risk:** Extremely difficult to unit test without a database; high friction when changing schema.
**Safe Refactor Step:** Extract all SQL queries into a dedicated `TasksRepository` class. The service now interacts only with the repository.

**New `src/modules/tasks/tasks.repository.ts`:**
```typescript
import { Pool, PoolClient } from 'pg';

export class TasksRepository {
  constructor(private db: Pool | PoolClient) {}

  async findById(id: number) {
    const res = await this.db.query('SELECT * FROM tasks WHERE id = $1', [id]);
    return res.rows[0];
  }

  async updateStatus(id: number, status: string, claimedBy?: number) {
    return this.db.query(
      'UPDATE tasks SET status = $1, claimed_by = $2 WHERE id = $3',
      [status, claimedBy || null, id]
    );
  }
}
```

### 2. Transaction Management Abstraction
**Problem:** Manual transaction blocks (`BEGIN`, `COMMIT`, `ROLLBACK`) are repeated in services, leading to boilerplate and risk of connection leaks.
**Current Risk:** Connection pool exhaustion if `client.release()` is missed in an error branch.
**Safe Refactor Step:** Create a `withTransaction` utility in `src/config/database.ts`.

**Optimized `dbUtils.ts`:**
```typescript
export async function withTransaction<T>(
  pool: Pool,
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
```

---

## 🟠 Structural Improvements

### 1. Dependency Injection for Configuration
**Problem:** Services import the global `env` object directly, making them hard to mock.
**Minimal Safe Change:** Pass the required config object through the constructor.

```typescript
export class TasksService {
  constructor(
    private repo: TasksRepository,
    private config: { jwtSecret: string }
  ) {}
}
```

### 2. Standardized Response DTOs
**Problem:** Database row objects are returned directly to the API, leaking internal snake_case fields.
**Minimal Safe Change:** Implement a `toDTO` mapper function in the Service layer to ensure CamelCase consistency without changing the API contract.

```typescript
const taskToDTO = (row: any) => ({
  id: row.id,
  title: row.title,
  sourceType: row.source_type, // Explicit mapping
  status: row.status,
});
```

---

## ⚠️ Deferred Refactors

### 1. Transition to an ORM (Prisma/Drizzle)
**Why NOT now:** This is a major structural change that would require rewriting the entire data layer and could introduce performance regressions in complex PostGIS queries. Deferred to Phase 6.

### 2. Redis Adapter for Socket.IO
**Why NOT now:** Requires setting up Redis infrastructure. This is an infrastructure/scaling task rather than a code refactor. Deferred until deployment on a multi-node cluster.

---

## ✅ Good Architecture Preserved

*   **Feature-Module Structure:** The project is already well-organized into domain-specific folders (`auth`, `tasks`, `chat`), which we have maintained.
*   **Centralized Error Handling:** The `errorHandler` middleware correctly captures all async errors from the service layer.

---

## 🛠 Suggested Refactor Plan (STEP-BY-STEP)

1.  **Step 1: Database Utilities.** Add `withTransaction` to `database.ts`. (No impact on existing code).
2.  **Step 2: Repository Creation.** Create `tasks.repository.ts` and move queries from `tasks.service.ts` into it.
3.  **Step 3: Service Refactor.** Modify `tasks.service.ts` to accept the repository in its constructor.
4.  **Step 4: Dependency Injection.** Update `tasks.controller.ts` to instantiate the Repository and Service correctly:
    ```typescript
    const repo = new TasksRepository(pool);
    const tasksService = new TasksService(repo, { jwtSecret: env.JWT_SECRET });
    ```
5.  **Step 5: Validation.** Run existing integration tests to ensure no breakage in API responses.
