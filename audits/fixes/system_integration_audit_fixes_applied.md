# 🌐 System Integration & Contract Alignment: DisasterAid V2.1

**Architect:** Principal Full-Stack Architect
**Status:** Implementation of Phase 5B Integration Audit
**Date:** May 13, 2026

---

## 🔴 Critical Contract Mismatches

### 1. Naming Convention Divergence (Snake vs. Camel)
**Problem:** Backend returns `snake_case` fields (e.g., `source_type`, `budget_pkr`), while Flutter models expect `camelCase` (e.g., `sourceType`, `budgetPkr`).
**Mismatched Model:** `Task` model in Flutter manually checks for both casing styles, leading to fragile parsing.
**Safe Alignment Fix:** Introduce a **Response DTO Mapper** in the Backend Service layer to transform all outgoing responses to `camelCase` before they reach the controller.

**Updated Backend Mapping (`tasks.service.ts`):**
```typescript
const mapTaskToResponse = (task: any) => ({
  id: task.id,
  title: task.title,
  sourceType: task.source_type, // Normalized to camelCase
  budgetPkr: task.budget_pkr,
  itemsNeeded: task.items_needed,
  latitude: task.latitude,
  longitude: task.longitude,
  status: task.status,
  viewCount: task.view_count,
  createdAt: task.created_at,
});
```

### 2. Inconsistent "Task Discovery" Structure
**Problem:** The `getAvailableTasks` endpoint returns `{ tasks, count }`, while `getTaskById` returns a raw task object.
**Safe Alignment Fix:** Standardize all "Success" responses to follow a unified envelope.

**Unified Envelope Pattern:**
```typescript
// All responses now follow: { data, message?, meta? }
res.json({
  data: tasks,
  meta: { count: tasks.length }
});
```

---

## 🟠 Structural Contract Issues

### 1. Leaky Geography Objects
**Description:** Backend sometimes returns raw PostGIS `location` objects (binary) in addition to coordinates.
**Normalization:** Explicitly exclude the `location` field in the DTO mapper and only provide `latitude` and `longitude`.

### 2. Shared Error Format
**Description:** Errors from auth middleware return `{ error: string }`, but validation errors return `{ errors: [] }`.
**Normalization:** Unified error structure:
```json
{
  "status": "error",
  "code": "VALIDATION_FAILED",
  "message": "Invalid input provided",
  "details": [] 
}
```

---

## ⚠️ Deferred Contract Changes

### 1. Breaking `source_type` Enum Values
**Explanation:** Changing "BENEFICIARY_REQUEST" to "request" would break all existing mobile app versions in the field. This requires a API Versioning strategy (`/v2/`) which is deferred.

### 2. Introducing GraphQL
**Explanation:** While GraphQL solves over-fetching, it is a major architectural shift. Deferred.

---

## ✅ Already Well-Aligned Contracts

*   **Authentication Flow:** The JWT Bearer token lifecycle is consistent across Flutter `AuthInterceptor` and Node.js `authenticate` middleware.
*   **Health Checks:** The `/api/health` response is simple, stable, and correctly consumed by the frontend.

---

## 🛠 Recommended Contract Standardization Plan

### 1. Step 1: Backend DTO Layer (Safe Rollout)
Add mappers to all Services. For a "Safe" transition, the mapper will return **both** `snake_case` and `camelCase` fields temporarily to ensure backward compatibility with older Flutter builds.
```typescript
return {
  source_type: task.source_type, // Old
  sourceType: task.source_type,  // New
};
```

### 2. Step 2: Flutter Model Cleanup
Update all `factory fromJson` methods in Flutter to use the new `camelCase` fields exclusively once the backend update is verified.

### 3. Step 3: Global Response Interceptor
Implement a global Express interceptor that wraps all `res.json()` calls into the `{ data, status }` envelope automatically to ensure 100% consistency across all future modules.
