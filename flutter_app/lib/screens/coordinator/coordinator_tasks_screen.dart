import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/providers/notification_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

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
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          onTap: (_) => setState(() {}),
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
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
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
                              Text(
                                task.urgency.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _urgencyColor(task.urgency),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NGO: ${task.ngoName ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Volunteer: ${task.claimedByName ?? 'Unassigned'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const Spacer(),
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                task.locationText ?? 'No location',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
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
