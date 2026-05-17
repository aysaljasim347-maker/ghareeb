import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/features/tasks/presentation/tasks_provider.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';
import 'package:disasteraid_app/providers/coordinator_intelligence_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';
import 'package:disasteraid_app/widgets/task_status_timeline.dart';

class CoordinatorTaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const CoordinatorTaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(taskDetailProvider(taskId)),
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: 'Could not load task details.',
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (task) => _CoordinatorTaskView(task: task),
      ),
    );
  }
}

class _CoordinatorTaskView extends ConsumerWidget {
  final TaskModel task;
  const _CoordinatorTaskView({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryAsync = ref.watch(taskDeliveryDetailsProvider(task.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NGO: ${task.ngoName ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(status: task.status),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Field Progress',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TaskStatusTimeline(currentStatus: task.status),

          const Divider(),
          const SizedBox(height: 16),

          // Volunteer Info
          if (task.claimedByName != null) ...[
            _SectionHeader(title: 'Assigned Volunteer'),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person),
                ),
                title: Text(task.claimedByName!),
                subtitle: const Text('Field Agent'),
                trailing: IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => context.push(
                      '/chat/${task.id}?title=${Uri.encodeComponent(task.title)}'),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Divider(),
          ],

          // Delivery Proof (Read-Only)
          deliveryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (deliveries) {
              if (deliveries.isEmpty) return const SizedBox.shrink();
              final latest = deliveries.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Delivery Proof (Preview)'),
                  const SizedBox(height: 8),
                  if (latest['proof_image_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        latest['proof_image_url'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  if (latest['notes'] != null) ...[
                    const SizedBox(height: 12),
                    const Text('Volunteer Notes:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey)),
                    Text(latest['notes']),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Submitted: ${DateFormat('MMM D, HH:mm').format(DateTime.parse(latest['submitted_at']))}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              );
            },
          ),

          // Operational Details
          _SectionHeader(title: 'Operational Context'),
          const SizedBox(height: 8),
          if (task.campaignTitle != null)
            _DetailRow(label: 'Campaign', value: task.campaignTitle!),
          if (task.beneficiaryName != null)
            _DetailRow(label: 'Beneficiary', value: task.beneficiaryName!),
          _DetailRow(label: 'Urgency', value: task.urgency.value),
          _DetailRow(label: 'Category', value: task.category ?? 'Relief'),

          const SizedBox(height: 24),
          const Divider(),

          // Location
          _SectionHeader(title: 'Field Location'),
          const SizedBox(height: 8),
          if (task.locationText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(task.locationText!),
            ),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  if (task.latitude != null && task.longitude != null)
                    Text(
                      '${task.latitude?.toStringAsFixed(4)}, ${task.longitude?.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.grey),
                    )
                  else
                    const Text('Location coordinates unavailable',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Escalation Section ──
          if (task.status == TaskStatus.flagged)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Under Admin Review',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        Text(
                            'This task has been escalated for high-level fraud investigation.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.red.shade800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (task.status != TaskStatus.paid &&
              task.status != TaskStatus.coordinatorVerified)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showEscalateDialog(context, ref, task),
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Escalate to Admin'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showEscalateDialog(
      BuildContext context, WidgetRef ref, TaskModel task) {
    final reasonController = TextEditingController();
    String severity = 'MEDIUM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Admin Escalation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Provide reason for escalating this task to the central administration.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                    labelText: 'Reason', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: severity,
                items: ['LOW', 'MEDIUM', 'HIGH']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => severity = v!),
                decoration: const InputDecoration(labelText: 'Severity'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(intelligenceActionProvider.notifier).escalate(
                      entity: 'tasks',
                      id: task.id,
                      reason: reasonController.text.trim(),
                      severity: severity,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Escalation sent')));
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          Text(value),
        ],
      ),
    );
  }
}
