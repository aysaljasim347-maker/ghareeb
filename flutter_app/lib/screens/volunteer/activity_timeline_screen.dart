import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/providers/volunteer_impact_provider.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';

class ActivityTimelineScreen extends ConsumerWidget {
  const ActivityTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(volunteerTasksHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No activity yet',
              subtitle: 'Tasks you claim and work on will appear here.',
            );
          }

          // Flatten tasks into individual status events for a timeline
          final events = _getSortedEvents(tasks);

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _TimelineItem(
                event: event,
                isLast: index == events.length - 1,
              );
            },
          );
        },
      ),
    );
  }

  List<_TimelineEvent> _getSortedEvents(List<TaskModel> tasks) {
    final events = <_TimelineEvent>[];
    for (final task in tasks) {
      // Event: Claimed
      if (task.claimedAt != null) {
        events.add(_TimelineEvent(
          taskId: task.id,
          taskTitle: task.title,
          type: 'CLAIMED',
          timestamp: DateTime.parse(task.claimedAt!),
          icon: Icons.handshake,
          color: Colors.blue,
        ));
      }
      
      // Event: Completed/Verified (Synthetic if we don't have event timestamps)
      if (task.status == TaskStatus.coordinatorVerified || task.status == TaskStatus.paid) {
         events.add(_TimelineEvent(
          taskId: task.id,
          taskTitle: task.title,
          type: 'VERIFIED',
          timestamp: DateTime.parse(task.updatedAt ?? task.createdAt!),
          icon: Icons.verified,
          color: Colors.green,
        ));
      }

      if (task.status == TaskStatus.flagged) {
         events.add(_TimelineEvent(
          taskId: task.id,
          taskTitle: task.title,
          type: 'FLAGGED',
          timestamp: DateTime.parse(task.updatedAt ?? task.createdAt!),
          icon: Icons.flag,
          color: Colors.red,
        ));
      }
    }
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }
}

class _TimelineEvent {
  final int taskId;
  final String taskTitle;
  final String type;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  _TimelineEvent({
    required this.taskId,
    required this.taskTitle,
    required this.type,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;

  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, color: event.color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM d, HH:mm').format(event.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getEventDescription(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => context.push('/volunteer/task/${event.taskId}'),
                    child: Text(
                      event.taskTitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEventDescription() {
    switch (event.type) {
      case 'CLAIMED': return 'You claimed this task';
      case 'VERIFIED': return 'Task verified & completed';
      case 'FLAGGED': return 'Task was flagged for review';
      default: return 'Status update';
    }
  }
}
