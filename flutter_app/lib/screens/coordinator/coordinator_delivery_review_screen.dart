import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/features/tasks/presentation/tasks_provider.dart';
import 'package:disasteraid_app/providers/beneficiary_task_provider.dart';
import 'package:disasteraid_app/providers/delivery_review_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';

class CoordinatorDeliveryReviewScreen extends ConsumerStatefulWidget {
  final int taskId;
  const CoordinatorDeliveryReviewScreen({super.key, required this.taskId});

  @override
  ConsumerState<CoordinatorDeliveryReviewScreen> createState() => _CoordinatorDeliveryReviewScreenState();
}

class _CoordinatorDeliveryReviewScreenState extends ConsumerState<CoordinatorDeliveryReviewScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleReview(int deliveryId, String outcome) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${outcome.substring(0, 1) + outcome.substring(1).toLowerCase()} Delivery'),
        content: Text('Are you sure you want to $outcome this delivery submission?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(outcome, style: TextStyle(color: _getOutcomeColor(outcome))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(deliveryReviewProvider.notifier).reviewDelivery(
            deliveryId: deliveryId,
            taskId: widget.taskId,
            outcome: outcome,
            notes: _notesController.text.trim(),
          );

      if (mounted && ref.read(deliveryReviewProvider).status == ReviewStatus.success) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery $outcome successful')),
        );
      }
    }
  }

  Color _getOutcomeColor(String outcome) {
    if (outcome == 'VERIFY') return Colors.green;
    if (outcome == 'FLAG') return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final deliveryAsync = ref.watch(taskDeliveryDetailsProvider(widget.taskId));
    final reviewState = ref.watch(deliveryReviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Submission')),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(message: 'Task not found', onRetry: () => ref.invalidate(taskDetailProvider(widget.taskId))),
        data: (task) => deliveryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const Center(child: Text('Failed to load delivery proof')),
          data: (deliveries) {
            if (deliveries.isEmpty) return const Center(child: Text('No delivery submitted yet'));
            final delivery = deliveries.first;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Task Information'),
                  Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('NGO: ${task.ngoName ?? 'Platform'}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Volunteer', value: task.claimedByName ?? 'Unknown'),
                  _DetailRow(label: 'Submitted', value: DateFormat('MMM D, HH:mm').format(DateTime.parse(delivery['submitted_at']))),
                  
                  const Divider(height: 32),
                  
                  _SectionHeader(title: 'Delivery Proof'),
                  if (delivery['photo_urls'] != null)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (delivery['photo_urls'] as List).length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(delivery['photo_urls'][i], fit: BoxFit.cover, width: 200),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (delivery['notes'] != null) ...[
                    const Text('Volunteer Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(delivery['notes'], style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 16),
                  ],

                  const Divider(height: 32),

                  _SectionHeader(title: 'Operational Review'),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Review Notes / Feedback',
                      hintText: 'Required if flagging or rejecting',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  if (reviewState.status == ReviewStatus.loading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _handleReview(delivery['id'], 'VERIFY'),
                            icon: const Icon(Icons.verified),
                            label: const Text('Approve Delivery'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                                onPressed: () => _handleReview(delivery['id'], 'FLAG'),
                                icon: const Icon(Icons.flag),
                                label: const Text('Flag Submission'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () => _handleReview(delivery['id'], 'REJECT'),
                                icon: const Icon(Icons.cancel),
                                label: const Text('Reject Proof'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  if (reviewState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(reviewState.error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.1
      )),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
