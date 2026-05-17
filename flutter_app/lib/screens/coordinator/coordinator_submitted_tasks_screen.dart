import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/screens/coordinator/coordinator_tasks_screen.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

class CoordinatorSubmittedTasksScreen extends ConsumerWidget {
  const CoordinatorSubmittedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(coordinatorTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(coordinatorTasksProvider),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const ShimmerList(count: 5, itemHeight: 120),
        error: (err, _) => ErrorView(
          message: 'Could not load submissions.',
          onRetry: () => ref.invalidate(coordinatorTasksProvider),
        ),
        data: (tasks) {
          final submitted = tasks.where((t) => t.status == TaskStatus.submitted).toList();

          if (submitted.isEmpty) {
            return const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Clean slate!',
              subtitle: 'All delivery submissions have been reviewed.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(coordinatorTasksProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: submitted.length,
              itemBuilder: (context, index) {
                final task = submitted[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Volunteer: ${task.claimedByName ?? 'Unknown'}', 
                                 style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        StatusChip(status: task.status),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/coordinator/review/${task.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
