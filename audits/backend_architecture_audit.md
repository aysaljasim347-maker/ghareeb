# 🏛 Backend Architecture Audit: DisasterAid V2.1

**Auditor:** Senior Software Architect
**Date:** May 13, 2026
**Scope:** Node.js (Express, TypeScript) System Design

---

## 🔴 Critical Architecture Issues

### 1. Tight Coupling of Business Logic and Data Access
**Problem:** The Service layer (`src/modules/*/services.ts`) is performing both business logic orchestration and raw SQL execution. There is no separate Repository layer.
**Why it is dangerous:**
- **Testability:** Unit testing business logic requires a live database or complex mocking of the `pg` pool.
- **Maintainability:** Changing the schema or switching to an ORM/Query Builder would require rewriting every service.
- **Portability:** Tightly coupled to PostgreSQL raw SQL syntax.
**Impact:** High technical debt; difficulty in implementing complex data patterns like soft deletes or audit logs consistently.
**Suggested improvement:** Introduce a **Repository Layer** for data access. Services should only call repository methods.

### 2. Lack of Transaction Abstraction
**Problem:** Transaction logic (`BEGIN`, `COMMIT`, `ROLLBACK`) is manually managed inside service methods (e.g., `DeliveriesService.verifyDelivery`).
**Why it is dangerous:**
- **Error Prone:** Forgetting a `ROLLBACK` in a catch block or a `client.release()` in a finally block leads to connection leaks.
- **Leaky Abstraction:** Business services must handle low-level DB connection management (`pool.connect()`).
**Impact:** High risk of "Connection Pool Exhaustion" and data inconsistency during failures.
**Suggested improvement:** Use a decorator pattern or a wrapper function for transactions that handles connection lifecycle automatically.

---

## 🟠 Structural Weaknesses

### 1. Feature-Module "God Services"
**Description:** As modules like `Tasks` or `Users` grow, the single `Service` class becomes a "God Object" containing dozens of unrelated methods.
**Suggested improvement:** Break large services into smaller, focused use-cases (e.g., `TaskDiscoveryService`, `TaskClaimService`).

### 2. Missing DTO (Data Transfer Object) Layer
**Description:** Database rows are often passed directly to controllers and then to the client.
**Suggested improvement:** Explicitly map DB models to API DTOs to prevent internal schema leak and enable easier field renaming.

---

## 🟢 Minor Improvements

### 1. Consistent Dependency Injection
**Description:** Currently using singleton exports.
**Refinement:** Use constructor-based dependency injection to make services more testable and allow for easy swapping of repositories.

### 2. Centralized Query Constants
**Description:** Raw SQL strings are embedded in methods.
**Refinement:** Move SQL strings to separate `.sql.ts` files or use a query builder like Knex/Drizzle to improve readability.

---

## ⚠️ High-Risk Design Patterns

### 1. Stateful Socket.IO Gateways
**Pattern:** The `chat.gateway.ts` manages socket connections in-memory.
**Risk:** If the backend scales horizontally (multiple instances), users on different servers won't be able to chat.
**Recommendation:** Implement a **Redis Adapter** for Socket.IO immediately to ensure statelessness across nodes.

### 2. Direct `env` Access in Services
**Pattern:** Services import `env` directly.
**Risk:** Configuration is hard to mock for tests.
**Recommendation:** Pass required config values into service constructors.

---

## ✅ Good Architectural Decisions

*   **Feature-Based Modularity:** Organizing by feature (`auth`, `tasks`, `chat`) instead of by type (`controllers`, `services`) makes the codebase highly navigable and scalable.
*   **Centralized Middleware:** Excellent use of `errorHandler.ts`, `auth.ts`, and `validate.ts` to keep controllers clean.
*   **Zod Schema Validation:** Using Zod for request validation ensures type safety from the network edge to the database.

---

## 🛠 Recommended Improvements (Roadmap)

### Phase 1: Repository Extraction (Immediate)
Extract SQL queries from `TasksService` into `TasksRepository`.
```typescript
// Proposed Repository Pattern
export class TasksRepository {
  constructor(private db: Pool) {}
  async findById(id: number) { ... }
}
```

### Phase 2: Transaction Wrapper (Medium Term)
Implement a utility to handle transaction boilerplate.
```typescript
await runInTransaction(async (client) => {
  await repo.update(client, ...);
});
```

### Phase 3: Domain Events (Long Term)
Instead of calling `pool.query(INSERT_EVENT)` everywhere, emit an event (`EventEmitter`) and have an `EventSubscriber` handle the logging. This decouples core business logic from auditing.
