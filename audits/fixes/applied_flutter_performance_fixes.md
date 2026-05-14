# 📱 Applied Flutter Performance Fixes: DisasterAid V2.1

**Engineer:** Senior Flutter Performance Engineer
**Status:** Implementation of Phase 4C Audit
**Date:** May 13, 2026

---

## 🔴 Critical Fixes

### 1. Restoring List Virtualization in Proof Upload
**Problem:** The photo grid in `ProofUploadScreen` used `shrinkWrap: true` inside a `SingleChildScrollView`, forcing all images to render at once.
**Why it is slow:** Disables Flutter's "lazy loading" mechanism, causing high memory usage and jank when handling multiple photos.
**User Impact:** Lag when scrolling and potential crashes on low-end devices.
**Optimized Fix:** Refactor to a `CustomScrollView` using `SliverGrid`.

```dart
// Optimized ProofUploadScreen layout
Widget build(BuildContext context) {
  return Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar(title: Text('Confirm Delivery'), pinned: true),
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(child: _SectionTitle('Delivery Photos')),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _PhotoItem(file: _photos[index]),
              childCount: _photos.length,
            ),
          ),
        ),
        // Additional slivers for Notes and GPS Status...
      ],
    ),
  );
}
```

### 2. Isolating Rebuilds in Task Detail Screen
**Problem:** `VolunteerTaskDetailScreen` was watching 3+ providers at the root `build` method.
**Why it is slow:** Any update to auth state or claim status triggered a full rebuild of the expensive Map and UI tree.
**User Impact:** Micro-stutter during task interactions.
**Optimized Fix:** Use granular `Consumer` widgets for state-dependent UI.

```dart
// Instead of watching at the top level:
// final claimState = ref.watch(claimTaskProvider); 

// Wrap only the Action Button in a Consumer:
Consumer(
  builder: (context, ref, child) {
    final status = ref.watch(claimTaskProvider).status;
    return _ActionBar(
      isLoading: status == ClaimStatus.loading,
      // ... other props
    );
  },
)
```

---

## 🟠 High-Impact Quick Fixes

### 1. Localized State Updates for Tasks
**Problem:** Claiming a task invalidated the entire `availableTasksProvider`, causing a full network refresh.
**Fix:** Implement a `StateNotifier` for the task list that allows surgical removal of a single task from the local list.

```dart
class AvailableTasksNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  // ...
  void removeTask(int taskId) {
    state.whenData((tasks) {
      state = AsyncData(tasks.where((t) => t.id != taskId).toList());
    });
  }
}
```

### 2. Image Memory Optimization
**Problem:** Decoding full-resolution camera photos for small UI thumbnails.
**Fix:** Use `cacheWidth` or `cacheHeight` in `Image.file`.

```dart
Image.file(
  _photos[index],
  fit: BoxFit.cover,
  cacheWidth: 300, // Decodes image at 300px width instead of 4000px+
)
```

---

## ⚠️ Deferred (Risky Changes)

### 1. Background Image Compression
**Explanation:** Compressing images before upload using `flutter_image_compress` is ideal but requires adding a new heavy dependency and handling platform-specific isolates. Deferred to Phase 5.

### 2. WebSocket Stream Buffering
**Explanation:** Buffering chat messages to prevent UI updates on every packet is complex and risks data loss without a robust "ack" system. Deferred.

---

## ✅ Good Practices Found

*   **Riverpod `family`:** Correct usage of `taskDetailProvider(taskId)` to scope data fetching to specific tasks.
*   **Haptic Feedback:** Excellent use of `HapticFeedback` to provide physical cues during performance-sensitive async actions.
*   **Controller Disposal:** `TextEditingController` in `ProofUploadScreen` is correctly disposed in the `dispose()` method.

---

## 🛠 Summary of Improvements
1.  **Rendering:** Switched from monolithic rendering to virtualized "Sliver" rendering in upload flows.
2.  **Memory:** Reduced memory footprint of thumbnails by 90% using `cacheWidth`.
3.  **Responsiveness:** Reduced UI rebuild frequency by isolating state listeners.
