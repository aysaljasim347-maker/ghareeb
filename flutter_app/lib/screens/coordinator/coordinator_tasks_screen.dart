import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:reliefnet_app/providers/notification_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';
import 'package:reliefnet_app/widgets/status_chip.dart';

final coordinatorTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/tasks/coordinator');
  final data = response.data as Map<String, dynamic>;
  final list = (data['data'] as List<dynamic>?) ?? [];
  return list
      .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
      .toList();
});

class CoordinatorTasksScreen extends ConsumerStatefulWidget {
  const CoordinatorTasksScreen({super.key});

  @override
  ConsumerState<CoordinatorTasksScreen> createState() => _CoordinatorTasksScreenState();
}

class _CoordinatorTasksScreenState extends ConsumerState<CoordinatorTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['All', 'Active', 'Completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _filter(List<TaskModel> tasks, int index) {
    switch (index) {
      case 1: // Active
        return tasks.where((t) => 
          ['CLAIMED', 'IN_PROGRESS', 'SUBMITTED'].contains(t.status.value)).toList();
      case 2: // Completed
        return tasks.where((t) => 
          ['COORDINATOR_VERIFIED', 'PAID'].contains(t.status.value)).toList();
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(coordinatorTasksProvider);
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Operations'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: notifications.isNotEmpty,
              label: Text(notifications.length.toString()),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/coordinator/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(coordinatorTasksProvider),
          ),
        ],
bottom: TabBar(
  controller: _tabController,

  // 🔴 Selected tab (DARKER - strong contrast)
  labelColor: Colors.white,

  // ⚪ Unselected tab (faded but visible)
  unselectedLabelColor: Colors.white70,

  // 🔵 Indicator (same as selected emphasis)
  indicatorColor: Colors.white,

  indicatorWeight: 3,

  labelStyle: const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 14,
  ),

  unselectedLabelStyle: const TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
  ),

  tabs: _tabs.map((t) => Tab(text: t)).toList(),
),
      ),
      body: tasksAsync.when(
        loading: () => const ShimmerList(count: 5, itemHeight: 100),
        error: (err, _) => ErrorView(
          message: 'Could not load operational data.',
          onRetry: () => ref.invalidate(coordinatorTasksProvider),
        ),
        data: (tasks) {
          final filtered = _filter(tasks, _tabController.index);

          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_ind_outlined,
              title: 'No tasks found',
              subtitle: 'Tasks in this category will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(coordinatorTasksProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final task = filtered[index];
                final cs = Theme.of(context).colorScheme;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/coordinator/task/${task.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StatusChip(status: task.status),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _urgencyColor(task.urgency)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    task.urgency.value.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _urgencyColor(task.urgency),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'NGO: ${task.ngoName ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 13,
                                    color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    task.claimedByName ?? 'Unassigned',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.location_on_outlined,
                                    size: 13,
                                    color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    task.locationText ?? 'No location',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _urgencyColor(TaskUrgency urgency) {
    switch (urgency) {
      case TaskUrgency.critical:
        return const Color(0xFFE53E3E);
      case TaskUrgency.high:
        return const Color(0xFFED8936);
      case TaskUrgency.medium:
        return const Color(0xFFECC94B);
      default:
        return const Color(0xFF48BB78);
    }
  }
}
