import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Open', 'Claimed', 'Completed'];

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

  List<TaskModel> _filter(List<TaskModel> tasks, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return tasks.where((t) => t.status == TaskStatus.open).toList();
      case 2:
        return tasks
            .where((t) =>
                t.status == TaskStatus.claimed ||
                t.status == TaskStatus.assigned ||
                t.status == TaskStatus.inProgress)
            .toList();
      case 3:
        return tasks
            .where((t) =>
                t.status == TaskStatus.paid ||
                t.status == TaskStatus.coordinatorVerified ||
                t.status == TaskStatus.submitted)
            .toList();
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id;
    if (userId == null) return const SizedBox.shrink();

    final tasksAsync = ref.watch(myTasksProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
            tooltip: 'Filter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          isScrollable: false,
        ),
      ),
      body: tasksAsync.when(
        loading: () => const ShimmerList(count: 5, itemHeight: 110),
        error: (err, _) => ErrorView(
          message: 'Could not load your requests. Please try again.',
          onRetry: () => ref.invalidate(myTasksProvider(userId)),
        ),
        data: (tasks) => TabBarView(
          controller: _tabController,
          children: List.generate(_tabs.length, (i) {
            final filtered = _filter(tasks, i);
            if (filtered.isEmpty) {
              return EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No requests yet',
                subtitle:
                    'Create your first help request and we\'ll connect you with volunteers.',
                ctaLabel: 'Create Request',
                onCta: () => context.push('/beneficiary/create-task'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(myTasksProvider(userId)),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return _TaskCard(task: filtered[index]);
                },
              ),
            );
          }),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/beneficiary/create-task'),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;

  const _TaskCard({required this.task});

  String _categoryEmoji() {
    switch (task.category?.toUpperCase()) {
      case 'FOOD':
        return '🍞';
      case 'MEDICAL':
        return '💊';
      case 'SHELTER':
        return '🏠';
      default:
        return '📦';
    }
  }

  Color _urgencyDotColor() {
    switch (task.urgency) {
      case TaskUrgency.critical:
        return const Color(0xFFE53E3E);
      case TaskUrgency.high:
        return const Color(0xFFED8936);
      case TaskUrgency.medium:
        return const Color(0xFFECC94B);
      case TaskUrgency.low:
        return const Color(0xFF48BB78);
      default:
        return Colors.grey;
    }
  }

  String _timeAgo() {
    if (task.createdAt == null) return '';
    final dt = DateTime.tryParse(task.createdAt!);
    if (dt == null) return '';
    return timeago.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tasks/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(status: task.status),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _urgencyDotColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(_categoryEmoji(), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              if (task.locationText != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.locationText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
