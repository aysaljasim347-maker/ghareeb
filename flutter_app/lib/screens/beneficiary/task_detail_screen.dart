import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';
import 'package:disasteraid_app/providers/feedback_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';
import 'package:disasteraid_app/widgets/task_status_timeline.dart';

class BeneficiaryTaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const BeneficiaryTaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(beneficiaryTaskDetailProvider(taskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(beneficiaryTaskDetailProvider(taskId)),
          ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Syncing request details...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (err, _) => ErrorView(
          message: 'Could not load request details. Check your connection.',
          onRetry: () => ref.invalidate(beneficiaryTaskDetailProvider(taskId)),
        ),
        data: (task) => _TaskDetailView(task: task),
      ),
    );
  }
}

class _TaskDetailView extends ConsumerWidget {
  final TaskModel task;

  const _TaskDetailView({required this.task});

  String _timeAgo() {
    if (task.createdAt == null) return '';
    final dt = DateTime.tryParse(task.createdAt!);
    if (dt == null) return '';
    return timeago.format(dt);
  }

  bool _canChat() {
    return task.status != TaskStatus.open &&
        task.status != TaskStatus.cancelled &&
        task.status != TaskStatus.unknown;
  }

  void _handleCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
            'Are you sure you want to cancel this request? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep it')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(taskActionProvider.notifier).cancel(task.id);
            },
            child:
                const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

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
                      'Requested ${_timeAgo()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(status: task.status),
            ],
          ),

          if (task.status == TaskStatus.open) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/beneficiary/task/${task.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Request'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _handleCancel(context, ref),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/beneficiary/task/${task.id}/edit'),
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Update Location'),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),

          // Status Timeline
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Progress Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TaskStatusTimeline(currentStatus: task.status),

          const Divider(),
          const SizedBox(height: 16),

          // Volunteer Info
          if (task.claimedByName != null) ...[
            const _SectionHeader(title: 'Assigned Volunteer'),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.person),
                ),
                title: Text(task.claimedByName!),
                subtitle: const Text('Working on your request'),
                trailing: _canChat()
                    ? IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () => context.push(
                            '/chat/${task.id}?title=${Uri.encodeComponent(task.title)}'),
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
            if (_canChat())
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                        '/chat/${task.id}?title=${Uri.encodeComponent(task.title)}'),
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat with Volunteer'),
                  ),
                ),
              ),
            const Divider(),
          ],

          // Request Details
          const _SectionHeader(title: 'Request Details'),
          const SizedBox(height: 8),
          if (task.category != null)
            _DetailRow(label: 'Category', value: task.category!),
          if (task.description != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(task.description!),
          ],

          if (task.itemsNeeded.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Items Needed',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...task.itemsNeeded.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record,
                          size: 8, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('${item.item} (${item.quantity})'),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 24),
          const Divider(),

          // Delivery Proof
          deliveryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (deliveries) {
              if (deliveries.isEmpty) return const SizedBox.shrink();
              final latest = deliveries.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Execution Proof'),
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

          // Feedback Section
          deliveryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (deliveries) {
              if (deliveries.isEmpty) return const SizedBox.shrink();
              final delivery = deliveries.first;
              return _FeedbackSection(task: task, delivery: delivery);
            },
          ),

          // Location
          const _SectionHeader(title: 'Delivery Location'),
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
        ],
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

class _FeedbackSection extends ConsumerStatefulWidget {
  final TaskModel task;
  final dynamic delivery;

  const _FeedbackSection({required this.task, required this.delivery});

  @override
  ConsumerState<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends ConsumerState<_FeedbackSection> {
  int _rating = 5;
  String _status = 'RECEIVED';
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_status == 'NOT_RECEIVED' && _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide details for non-receipt')),
      );
      return;
    }

    ref.read(beneficiaryFeedbackProvider.notifier).submit(
          deliveryId: widget.delivery['id'],
          taskId: widget.task.id,
          status: _status,
          rating: _status == 'NOT_RECEIVED' ? null : _rating,
          comment: _commentController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final feedbackState = ref.watch(beneficiaryFeedbackProvider);
    final hasFeedback = widget.delivery['confirmation_status'] != null;

    if (hasFeedback) {
      final status = widget.delivery['confirmation_status'];
      final rating = widget.delivery['beneficiary_rating'];
      final comment = widget.delivery['beneficiary_comment'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Your Confirmation'),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'RECEIVED'
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color:
                            status == 'RECEIVED' ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: $status',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (rating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < rating ? Icons.star : Icons.star_border,
                                size: 16,
                                color: Colors.amber,
                              )),
                    ),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Your Comment: "$comment"',
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ),
          const Divider(),
        ],
      );
    }

    // Only show if task is submitted/verified/paid
    if (!['SUBMITTED', 'COORDINATOR_VERIFIED', 'PAID']
        .contains(widget.task.status.value)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Confirm Aid Receipt'),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Have you received the requested items?'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Yes, Received'),
                      selected: _status == 'RECEIVED',
                      onSelected: (val) => setState(() => _status = 'RECEIVED'),
                    ),
                    ChoiceChip(
                      label: const Text('Partially'),
                      selected: _status == 'PARTIAL',
                      onSelected: (val) => setState(() => _status = 'PARTIAL'),
                    ),
                    ChoiceChip(
                      label: const Text('No'),
                      selected: _status == 'NOT_RECEIVED',
                      onSelected: (val) =>
                          setState(() => _status = 'NOT_RECEIVED'),
                    ),
                  ],
                ),
                if (_status != 'NOT_RECEIVED') ...[
                  const SizedBox(height: 16),
                  const Text('Rate the volunteer:'),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                        5,
                        (i) => IconButton(
                              icon: Icon(
                                i < _rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () => setState(() => _rating = i + 1),
                            )),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: _status == 'NOT_RECEIVED'
                        ? 'Please describe the issue'
                        : 'Optional comments',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: feedbackState.isLoading ? null : _submit,
                    child: feedbackState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Confirmation'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
