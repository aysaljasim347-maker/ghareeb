# 🌐 Frontend & System Integration Audit: DisasterAid V2.1

**Auditor:** Senior Full-Stack Architect
**Date:** May 13, 2026
**Scope:** Flutter Mobile App ↔ Node.js Backend ↔ PostgreSQL System

---

## 🔴 Critical System Architecture Issues

### 1. Contract–Implementation Disconnect (Task Discovery)
**Problem:** The `API_CONTRACT.md` specifies that `GET /api/tasks/available` should accept `lat`, `lng`, and `radius` parameters for spatial filtering. However, the backend implementation (`TasksService.getAvailableTasks`) ignores these and returns ALL open tasks from the database.
**Why it is dangerous:**
- **System Collapse:** As the number of tasks in Pakistan grows, the mobile app will attempt to download and render thousands of records on every "Refresh".
- **Bandwidth Waste:** Sending geometry-heavy data to mobile devices over potentially slow 3G/4G networks.
**Impact:** Extreme performance degradation and app crashes at scale.
**System Improvement:** Enforce spatial filtering at the SQL layer using `ST_DWithin` before the data reaches the API response.

### 2. Manual Data Mapping & Naming Inconsistency
**Problem:** The backend uses `snake_case` (DB/Postgres standard) while the Flutter frontend uses `camelCase` (Dart standard). There is no automated bridge (like JSON Serializable or shared DTOs).
**Why it is dangerous:**
- **Fragility:** Every new field requires manual mapping in both the Node.js Service and the Dart Model.
- **Transformation Overhead:** Every request/response involves manual field renaming, increasing CPU cycles on both ends.
**Impact:** High maintenance cost and frequent "broken UI" bugs due to naming mismatches (e.g., `source_type` vs `sourceType`).
**System Improvement:** Adopt a consistent casing strategy or use code generation (like `freezed` in Flutter and `class-transformer` in Node.js) to automate the mapping.

---

## 🟠 Structural System Weaknesses

### 1. Lack of Pagination Strategy
**Description:** None of the core endpoints (Tasks, Donations, Chat) implement keyset or limit/offset pagination.
**Suggested improvement:** Implement a standardized pagination wrapper in the backend that the Flutter frontend can consume for "infinite scroll" lists.

### 2. Duplicate Validation Logic
**Description:** Validation rules (e.g., max photo count, family size limits) are hardcoded in both the Zod schemas (backend) and the Flutter UI logic.
**Suggested improvement:** Centralize validation rules in a shared config or have the frontend fetch "form metadata" from the backend to ensure consistency.

---

## 🟢 Minor System Improvements

### 1. Health Check Granularity
**Description:** The `/api/health` endpoint checks the DB connection but not the Socket.io or External API (FCM) availability.
**Refinement:** Expand health checks to include all downstream dependencies.

### 2. Logging Consistency
**Description:** Backend logs to console; Frontend logs to debugPrint.
**Refinement:** Implement a shared correlation ID in the `AuthInterceptor` to trace a single user action from the Flutter log through to the backend SQL log.

---

## ⚠️ High-Risk System Design Patterns

### 1. Monolithic Socket.IO
**Pattern:** Chat rooms are managed in-memory on a single Node.js process.
**Risk:** When scaling to multiple server instances, users on Server A will never "see" users on Server B in the same chat room.
**Recommendation:** Implement a **Redis Pub/Sub adapter** to sync socket events across the system.

### 2. Geography Data Bloat
**Pattern:** Returning full `GEOGRAPHY` objects to the frontend when only `latitude` and `longitude` are needed for a map marker.
**Risk:** Unnecessary JSON serialization overhead.
**Recommendation:** Always transform spatial data to simple coordinates at the API edge.

---

## ✅ Good System Design Decisions

*   **Zod + Riverpod:** The combination of strict backend validation and reactive state management in the frontend provides a very solid foundation for a "Single Source of Truth."
*   **Interceptor-based Auth:** Using a Dio interceptor for JWT handling is the most robust way to handle session persistence and automatic 401 redirects.
*   **Feature-First Folders:** Both frontend and backend mirror each other's module structure, making it easy for a developer to follow a feature end-to-end.

---

## 🛠 Recommended Architecture Improvements

### 1. Automated Schema Sync (DTOs)
Consider using a tool like `ts-to-zod` or a shared Proto/OpenAPI definition to generate the Dart models. This eliminates the "Manual Mapping" critical issue.

### 2. Aggregator Endpoints for Mobile
Instead of calling `/api/tasks/:id` and then `/api/tasks/:id/events` separately, create a single "Task Dashboard" endpoint that returns the task, its events, and the chat room ID in one payload. This reduces "Chattiness" and improves perceived app speed.

### 3. Backend-Driven UI for Statuses
Move the logic for "What color is this status?" from Flutter to the backend. The API should return the status `label` and its `hex_color`. This allows NGO admins to change status colors/labels without a mobile app update.
