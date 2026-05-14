# 📱 Flutter Frontend Applied Architecture Refactors: DisasterAid V2.1

**Architect:** Senior Flutter Architect
**Status:** Implementation of Phase 5C Architecture Audit
**Date:** May 13, 2026

---

## 🔴 Critical Architecture Fixes

### 1. Presentation-Logic Decoupling (Screen → Provider)
**Problem:** `VolunteerTaskDetailScreen` contains complex branching logic for task statuses (`isOpen`, `isClaimedByMe`, etc.) and directly handles SnackBar displays.
**Risk:** Business logic is trapped in the UI, making it impossible to unit test and leading to "God Widgets" that are hard to maintain.
**Safe Fix:** Move task status logic into a dedicated `TaskDetailState` within the `presentation` folder of the tasks feature.

**Optimized `TaskDetailState`:**
```dart
class TaskDetailViewState {
  final TaskModel task;
  final bool isClaimedByMe;
  final bool canClaim;
  final bool canUploadProof;

  TaskDetailViewState({
    required this.task,
    this.isClaimedByMe = false,
    this.canClaim = false,
    this.canUploadProof = false,
  });
}
```

### 2. Eliminating Monolithic Rebuilds (Granular Consumer)
**Problem:** Root-level `ref.watch` in major screens causes expensive widgets (like `FlutterMap`) to rebuild when unrelated state (like a button's loading status) changes.
**Risk:** High CPU usage and visible UI stuttering on low-end devices.
**Safe Fix:** Use the `Consumer` widget to wrap only the dynamic parts of the UI, keeping the rest of the widget tree static.

**Safe Refactor Pattern:**
```dart
// Static part of the screen
const SliverAppBar(...),
// Dynamic part wrapped in Consumer
Consumer(
  builder: (context, ref, child) {
    final status = ref.watch(claimTaskProvider).status;
    return _ActionButton(isLoading: status == ClaimStatus.loading);
  },
),
```

---

## 🟠 Structural Improvements

### 1. Standardized Repository Pattern
**Problem:** Some providers directly interact with the `ApiClient`.
**Safe Change:** Enforce that all providers must interact with a `Repository` class. This provides a clean boundary for caching and mock data injection.

### 2. CamelCase Model Alignment (from Phase 5B)
**Problem:** Models currently manually check for `snake_case` from the backend.
**Safe Change:** Update the `factory fromJson` to exclusively expect `camelCase`, reflecting the backend's new DTO mappers.

```dart
// Optimized parsing
sourceType: json['sourceType'] as String, // No longer fallback to snake_case
```

---

## ⚠️ Deferred Refactors

### 1. Migrating to a BLoC/Redux Architecture
**Why NOT now:** Riverpod is already deeply integrated. Switching state management patterns would require a full UI rewrite and risks introducing many bugs. Deferred.

### 2. Introducing a Global Service Locator
**Why NOT now:** Riverpod's provider system already handles dependency injection effectively. Adding another layer (like `get_it`) would add unnecessary complexity.

---

## ✅ Good Architecture Already Present

*   **Feature-Based Folder Structure:** The division of `auth`, `tasks`, and `chat` into self-contained feature folders is excellent and facilitates team scaling.
*   **Centralized API Client:** The `api_client.dart` correctly handles interceptors and timeouts in a single place.

---

## 🛠 Step-by-Step Refactor Plan

1.  **Step 1: Domain Logic Extraction.** Move all `status == 'OPEN'` style checks into the `TaskModel` as getters (e.g., `task.isOpen`).
2.  **Step 2: Granular Widget Splitting.** Break down `_ActionBar` and `_TaskCard` into smaller, stateless sub-widgets that accept simple parameters.
3.  **Step 3: Consumer Injection.** Replace top-level `ref.watch` calls with targeted `Consumer` widgets in `TaskDetailScreen` and `TasksScreen`.
4.  **Step 4: Repository Enforcement.** Ensure `chat_provider.dart` and `donation_provider.dart` use their respective repositories instead of direct API calls.
5.  **Step 5: Contract Validation.** Verify that the UI correctly renders using the new `camelCase` DTO fields from the backend.
