import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/providers/coordinator_intelligence_provider.dart';

class CoordinatorLiveDashboardScreen extends ConsumerWidget {
  const CoordinatorLiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intelAsync = ref.watch(coordinatorIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Field Awareness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(coordinatorIntelligenceProvider),
          ),
        ],
      ),
      body: intelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (intel) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiveStatsRow(context, intel),
              const SizedBox(height: 32),
              const Text('Active Operations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (intel.stuckTasks.isEmpty)
                const Card(
                    child:
                        ListTile(title: Text('All operations moving smoothly')))
              else
                ...intel.stuckTasks.map((t) => _LiveTaskTile(task: t)),
              const SizedBox(height: 32),
              const Text('Reliability Benchmarks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...intel.topVolunteers.map((v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const CircleAvatar(child: Icon(Icons.person, size: 16)),
                    title: Text(v['name']),
                    subtitle: Text('${v['total_tasks']} tasks performed'),
                    trailing: Text(
                        '${(100 - (v['flags'] * 20)).clamp(0, 100)}% REL',
                        style: TextStyle(
                            color:
                                v['flags'] > 0 ? Colors.orange : Colors.green,
                            fontWeight: FontWeight.bold)),
                  )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatsRow(
      BuildContext context, OperationalIntelligence intel) {
    return Row(
      children: [
        _LiveStatCard(
          label: 'Total Scope',
          value: (intel.verificationStats['verified']! +
                  intel.verificationStats['flagged']!)
              .toString(),
          icon: Icons.assignment_outlined,
          color: Colors.blue,
        ),
        const SizedBox(width: 12),
        _LiveStatCard(
          label: 'Success Rate',
          value: '${_calculateSuccessRate(intel)}%',
          icon: Icons.auto_graph,
          color: Colors.green,
        ),
      ],
    );
  }

  int _calculateSuccessRate(OperationalIntelligence intel) {
    final v = intel.verificationStats['verified']!;
    final f = intel.verificationStats['flagged']!;
    if (v + f == 0) return 100;
    return ((v / (v + f)) * 100).toInt();
  }
}

class _LiveStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _LiveStatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _LiveTaskTile extends StatelessWidget {
  final dynamic task;
  const _LiveTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(task['title'],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: const Text('Alert: IN_PROGRESS for >24h',
            style: TextStyle(color: Colors.red, fontSize: 12)),
        trailing: const Icon(Icons.warning, color: Colors.orange, size: 18),
      ),
    );
  }
}
