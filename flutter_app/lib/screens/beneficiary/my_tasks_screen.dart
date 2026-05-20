import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';
import 'package:disasteraid_app/providers/notification_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});

  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _BeneficiarySummaryCard extends StatelessWidget {
  final List<TaskModel> tasks;

  const _BeneficiarySummaryCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final active = tasks.where((t) => t.status != TaskStatus.paid && t.status != TaskStatus.coordinatorVerified && t.status != TaskStatus.cancelled).length;
    final completed = tasks.where((t) => t.status == TaskStatus.paid || t.status == TaskStatus.coordinatorVerified).length;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Total', value: total.toString(), color: Theme.of(context).colorScheme.primary),
                _StatItem(label: 'Active', value: active.toString(), color: Colors.blue),
                _StatItem(label: 'Completed', value: completed.toString(), color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['All', 'Active', 'Completed'];

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
      case 1: // Active
        return tasks
            .where((t) =>
                t.status == TaskStatus.open ||
                t.status == TaskStatus.claimed ||
                t.status == TaskStatus.assigned ||
                t.status == TaskStatus.inProgress)
            .toList();
      case 2: // Completed
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
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        actions: [
          IconButton(
            tooltip: notifications.isEmpty
                ? 'Notifications'
                : 'Notifications, ${notifications.length} unread',
            icon: ExcludeSemantics(
              child: Badge(
                isLabelVisible: notifications.isNotEmpty,
                label: Text(notifications.length.toString()),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            onPressed: () => context.push('/beneficiary/notifications'),
          ),
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
        loading: () => const ShimmerList(count: 3, itemHeight: 150),
        error: (err, _) => ErrorView(
          message: 'Could not load your requests. Please try again.',
          onRetry: () => ref.invalidate(myTasksProvider(userId)),
        ),
        data: (tasks) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myTasksProvider(userId)),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _BeneficiarySummaryCard(tasks: tasks),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TabBar(
                        controller: _tabController,
                        tabs: _tabs.map((t) => Tab(text: t)).toList(),
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        onTap: (index) => setState(() {}),
                      ),
                    ),
                  ),
                ),
                _buildTaskList(tasks),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'my_tasks_emergency_fab',
            onPressed: () => context.push('/beneficiary/emergency-request'),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Emergency'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'my_tasks_new_request_fab',
            onPressed: () => context.push('/beneficiary/create-task'),
            icon: const Icon(Icons.add),
            label: const Text('New Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks) {
    final filtered = _filter(tasks, _tabController.index);

    if (filtered.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.assignment_outlined,
          title: 'No requests found',
          subtitle: 'Adjust your filters or create a new request.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _TaskCard(task: filtered[index]),
          childCount: filtered.length,
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
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
        onTap: () => context.push('/beneficiary/task/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(status: task.status),
                  const SizedBox(width: 8),
                  Semantics(
                    label: '${task.urgency?.name ?? "normal"} urgency',
                    child: ExcludeSemantics(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _urgencyDotColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
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
                  Semantics(
                    label: 'Category: ${task.category ?? "General"}',
                    child: ExcludeSemantics(
                      child: Text(_categoryEmoji(), style: const TextStyle(fontSize: 18)),
                    ),
                  ),
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
