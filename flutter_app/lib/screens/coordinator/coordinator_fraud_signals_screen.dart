import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/providers/coordinator_intelligence_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/utils/safe_parser.dart';

class CoordinatorFraudSignalsScreen extends ConsumerWidget {
  const CoordinatorFraudSignalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsAsync = ref.watch(fraudSignalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Anomalies & Signals')),
      body: signalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (signals) {
          final total =
              signals.gpsMismatches.length + signals.highRiskVolunteers.length;

          if (total == 0) {
            return const EmptyState(
              icon: Icons.shield_outlined,
              title: 'No fraud signals detected',
              subtitle: 'Heuristic rules are monitoring field execution truth.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (signals.gpsMismatches.isNotEmpty) ...[
                _buildHeader('GPS Distance Mismatches (>100m)'),
                ...signals.gpsMismatches.map((s) {
                  final distance = SafeParser.toDouble(s['distance_meters']);
                  return _AnomalyTile(
                    title: SafeParser.toStringSafe(s['title'], defaultValue: 'Untitled Task'),
                    subtitle: 'Volunteer: ${s['volunteer_name']}',
                    detail:
                        '${distance.toStringAsFixed(0)} meters mismatch',
                    severity: 'MEDIUM',
                    onEscalate: () => _showEscalateDialog(
                        context, ref, 'deliveries', SafeParser.paramInt(s['delivery_id'])),
                  );
                }),
                const SizedBox(height: 24),
              ],
              if (signals.highRiskVolunteers.isNotEmpty) ...[
                _buildHeader('High Risk Volunteers (>2 flags)'),
                ...signals.highRiskVolunteers.map((v) {
                  final flags = SafeParser.paramInt(v['flag_count']);
                  return _AnomalyTile(
                    title: SafeParser.toStringSafe(v['name'], defaultValue: 'Unknown Volunteer'),
                    subtitle: 'ID: ${v['volunteer_id']}',
                    detail: '$flags repeated failures',
                    severity: 'HIGH',
                    onEscalate: () => _showEscalateDialog(
                        context, ref, 'volunteers', SafeParser.paramInt(v['volunteer_id'])),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
    );
  }

  void _showEscalateDialog(
      BuildContext context, WidgetRef ref, String entity, int id) {
    final reasonController = TextEditingController();
    String severity = 'MEDIUM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Escalate to Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Report this anomaly for higher-level review.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                    labelText: 'Reason for escalation',
                    border: OutlineInputBorder()),
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
                      entity: entity,
                      id: id,
                      reason: reasonController.text.trim(),
                      severity: severity,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Escalation sent to Admin')));
              },
              child: const Text('Escalate'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final String severity;
  final VoidCallback onEscalate;

  const _AnomalyTile({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.severity,
    required this.onEscalate,
  });

  @override
  Widget build(BuildContext context) {
    final color = severity == 'HIGH' ? Colors.red : Colors.orange;
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
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                _SeverityBadge(label: severity, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(detail,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEscalate,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Escalate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SeverityBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
