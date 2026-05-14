# 📱 Flutter Performance Audit: DisasterAid V2.1

**Auditor:** Senior Flutter Performance Engineer
**Date:** May 13, 2026
**Scope:** Flutter Mobile App (Screens, Providers, Widgets)

---

## 🔴 Critical Performance Issues

### 1. Disadvantageous List Rendering (Disabling Virtualization)
**Problem:** In `ProofUploadScreen`, a `GridView.builder` is used with `shrinkWrap: true` and `NeverScrollableScrollPhysics()` inside a `SingleChildScrollView`.
**Why it is slow:** `shrinkWrap: true` forces the GridView to calculate its full height and render **all** items at once, even those not visible on screen. This destroys the benefit of `ListView/GridView.builder` (virtualization).
**User impact:** UI jank and memory spikes when the user adds multiple photos (up to 8).
**Fix:** Use a `CustomScrollView` with `SliverGrid`.

```dart
// Optimized ProofUploadScreen
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: _SectionTitle('Delivery Photos *')),
    SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _PhotoCard(file: _photos[index]),
        childCount: _photos.length,
      ),
    ),
    // Use other slivers for Notes and GPS
  ],
)
```

### 2. Excessive Screen Rebuilds (Task Detail)
**Problem:** `VolunteerTaskDetailScreen` (a `ConsumerWidget`) watches multiple providers (`taskDetailProvider`, `authProvider`, `claimTaskProvider`) at the root of the `build` method.
**Why it is slow:** If the user's auth state or the claim state changes (e.g., during a progress update), the **entire screen** including the expensive `FlutterMap` and all UI elements rebuild.
**User impact:** Visible stutter when claiming a task or during network updates.
**Fix:** Use granular `Consumer` widgets or `ref.listen` to isolate rebuilds.

```dart
// Optimized rebuild pattern
return Scaffold(
  body: CustomScrollView(
    slivers: [
       // Static parts...
       SliverToBoxAdapter(
         child: Consumer(
           builder: (context, ref, child) {
             final task = ref.watch(taskDetailProvider(id)).value;
             return task != null ? StatusChip(status: task.status) : child!;
           },
           child: const SizedBox.shrink(),
         ),
       ),
    ],
  ),
);
```

### 3. Missing Chat Pagination
**Problem:** `ChatNotifier` fetches all messages at once via `_repo.getMessages(_roomId)`.
**Why it is slow:** As a chat room grows (e.g., in complex relief efforts), the app will attempt to load and render hundreds or thousands of messages on entry.
**User impact:** Significant "loading" delay and high memory usage.
**Fix:** Implement lazy loading/pagination in the repository and UI.

---

## 🟠 Medium Performance Issues

### 1. Global List Invalidation
**Description:** In `TasksProvider`, successful task claiming triggers `_ref.invalidate(availableTasksProvider)`.
**Why it is slow:** This forces a complete network refresh and re-rendering of the entire task list.
**Suggested optimization:** Update the local state in the `availableTasksProvider` to remove the claimed task without a full refresh.

### 2. Image Memory Management
**Description:** `Image.file` is used for captured photos in `ProofUploadScreen`.
**Suggested optimization:** Use `cacheWidth` or `cacheHeight` to limit memory consumption of high-res photos.
```dart
Image.file(
  _photos[index],
  fit: BoxFit.cover,
  cacheWidth: 300, // Limits decoded image size in memory
)
```

---

## 🟢 Minor Optimizations

### 1. Missing `const` Constructors
**Description:** Many sub-widgets in `task_detail_screen.dart` lack `const` constructors where data is static.
**Suggested optimization:** Add `const` to internal UI elements to allow the compiler to optimize the widget tree.

### 2. Shimmer Overhead
**Description:** `ShimmerList` creates multiple `Shimmer.fromColors` animations.
**Suggested optimization:** Wrap the entire `ListView` in one `Shimmer` widget for better animation performance.

---

## ⚠️ High-Risk Patterns

### 1. Heavy Map in ScrollView
**Pattern:** `FlutterMap` inside a `SliverList`.
**Risk:** Maps are extremely heavy to initialize. If the user scrolls the map in and out of view frequently, it can cause frame drops.
**Recommendation:** Use a static map image (Google/OSM Static Maps API) for the detail view, and only open the interactive map on tap or in a separate view.

### 2. Large Data Sets in `FutureProvider.family`
**Pattern:** `myTasksProvider` filters tasks in memory after fetching.
**Risk:** If the API returns 1000 tasks and we filter for 5 in Dart, it's a waste of bandwidth and CPU.
**Recommendation:** Move all filtering logic to the PostgreSQL/PostGIS backend.

---

## 🛠 Suggested Fixes (Performance-Optimized Code)

### Granular Rebuild with `Consumer`
```dart
// Isolate the map to prevent rebuilds when other state changes
class _MapSection extends ConsumerWidget {
  final double lat;
  final double lng;
  const _MapSection({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FlutterMap(
      options: MapOptions(initialCenter: LatLng(lat, lng)),
      children: [
        TileLayer(urlTemplate: '...'),
        MarkerLayer(markers: [...]),
      ],
    );
  }
}
```

### Optimized Shimmer Wrapper
```dart
class OptimizedShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const ShimmerPlaceholder(),
      ),
    );
  }
}
```
