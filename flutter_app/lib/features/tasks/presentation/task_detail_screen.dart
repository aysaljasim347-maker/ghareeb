import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reliefnet_app/features/tasks/presentation/tasks_provider.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';

class TaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final authState = ref.watch(authProvider);
    final claimState = ref.watch(claimTaskProvider);

    // Listen for claim result
    ref.listen<ClaimState>(claimTaskProvider, (prev, next) {
      if (next.status == ClaimStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task claimed successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        ref.invalidate(taskDetailProvider(taskId));
      }
      if (next.status == ClaimStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (task) {
          final userId = authState.user?.id;
          final isParticipant = task.createdBy == userId ||
              task.claimedBy == userId ||
              task.coordinatorId == userId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Urgency + Status Row ──
                Row(
                  children: [
                    _UrgencyBadge(urgency: task.urgency),
                    const SizedBox(width: 8),
                    _StatusBadge(status: task.status),
                    if (isParticipant) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => context
                            .push('/chat/${task.id}?title=${task.title}'),
                        icon: const Icon(Icons.chat_bubble),
                        tooltip: 'Open Chat',
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'PKR ${task.budgetPkr.toStringAsFixed(0)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Title ──
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                // ── Description ──
                if (task.description != null) ...[
                  Text(
                    task.description!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Details Card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.category,
                          label: 'Category',
                          value: task.category ?? 'General',
                        ),
                        const Divider(),
                        _DetailRow(
                          icon: Icons.family_restroom,
                          label: 'Family Size',
                          value: '${task.familySize}',
                        ),
                        const Divider(),
                        _DetailRow(
                          icon: Icons.location_on,
                          label: 'Location',
                          value: task.locationText ?? 'Coordinates set',
                        ),
                        const Divider(),
                        _DetailRow(
                          icon: Icons.source,
                          label: 'Source',
                          value: task.sourceType.replaceAll('_', ' '),
                        ),
                        const Divider(),
                        _DetailRow(
                          icon: Icons.person,
                          label: 'Created By',
                          value: task.createdByName ?? 'Unknown',
                        ),
                        if (task.claimedByName != null) ...[
                          const Divider(),
                          _DetailRow(
                            icon: Icons.handshake,
                            label: 'Claimed By',
                            value: task.claimedByName!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Items Needed ──
                if (task.itemsNeeded.isNotEmpty) ...[
                  Text(
                    'Items Needed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: task.itemsNeeded
                        .map((item) => Chip(
                              label: Text('${item.item} (${item.quantity})'),
                              backgroundColor:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Chat Button (for participants) ──
                if (isParticipant && !task.isOpen)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => context
                            .push('/chat/${task.id}?title=${task.title}'),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Open Coordination Chat'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ),

                // ── Claim Button (Volunteers only, OPEN tasks only) ──

                if (task.isOpen && authState.user?.isVolunteer == true)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: claimState.status == ClaimStatus.loading
                          ? null
                          : () => ref
                              .read(claimTaskProvider.notifier)
                              .claim(taskId),
                      icon: claimState.status == ClaimStatus.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.volunteer_activism),
                      label: Text(
                        claimState.status == ClaimStatus.loading
                            ? 'Claiming...'
                            : 'Claim This Task',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final TaskUrgency urgency;
  const _UrgencyBadge({required this.urgency});

  Color get _color {
    switch (urgency) {
      case TaskUrgency.critical:
        return AppTheme.urgencyCritical;
      case TaskUrgency.high:
        return AppTheme.urgencyHigh;
      case TaskUrgency.medium:
        return AppTheme.urgencyMedium;
      case TaskUrgency.low:
        return AppTheme.urgencyLow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color),
      ),
      child: Text(
        urgency.value,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _color),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.value.replaceAll('_', ' '),
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
