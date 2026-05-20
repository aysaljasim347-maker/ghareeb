import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/providers/coordinator_intelligence_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';

class CoordinatorEscalationHistoryScreen extends ConsumerWidget {
  const CoordinatorEscalationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(escalationHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Escalation History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (escalations) {
          if (escalations.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No escalations sent',
              subtitle: 'Anomalies you escalate to Admin will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: escalations.length,
            itemBuilder: (context, index) {
              final item = escalations[index];
              final meta = item['metadata'] ?? {};
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Target: ${item['target_entity']} #${item['target_id']}', 
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          _SeverityTag(severity: meta['severity'] ?? 'MEDIUM'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(meta['reason'] ?? 'No reason provided', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, yyyy HH:mm').format(DateTime.parse(item['created_at'])),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SeverityTag extends StatelessWidget {
  final String severity;
  const _SeverityTag({required this.severity});
  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (severity == 'HIGH') color = Colors.red;
    if (severity == 'MEDIUM') color = Colors.orange;
    if (severity == 'LOW') color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(severity, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
