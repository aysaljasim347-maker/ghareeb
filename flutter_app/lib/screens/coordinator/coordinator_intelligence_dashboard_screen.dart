import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/providers/coordinator_intelligence_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/core/theme/app_theme.dart';
import 'package:disasteraid_app/utils/safe_parser.dart';

class CoordinatorIntelligenceDashboard extends ConsumerWidget {
  const CoordinatorIntelligenceDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intelAsync = ref.watch(coordinatorIntelligenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem, color: Colors.red),
            onPressed: () => _showEmergencyDialog(context, ref),
            tooltip: 'Emergency Escalation',
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            onPressed: () => context.push('/coordinator/signals'),
            tooltip: 'Fraud Signals',
          ),
        ],
      ),
      body: intelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(message: 'Failed to load intelligence', onRetry: () => ref.invalidate(coordinatorIntelligenceProvider)),
        data: (intel) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(coordinatorIntelligenceProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummarySection(context, intel),
                const SizedBox(height: 24),
                _buildStuckTasksList(context, intel.stuckTasks),
                const SizedBox(height: 24),
                _buildVolunteerPerformance(context, intel.topVolunteers),
                const SizedBox(height: 24),
                _buildNgoPerformance(context, intel.ngoPerformance),
                const SizedBox(height: 24),
                _ActionCard(
                  icon: Icons.campaign_outlined,
                  title: 'Broadcast Alert',
                  subtitle: 'Send real-time alerts to volunteers',
                  onTap: () => context.push('/coordinator/broadcast'),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.bolt_outlined,
                  title: 'Live Awareness',
                  subtitle: 'Real-time operational field state',
                  onTap: () => context.push('/coordinator/live'),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.history_edu,
                  title: 'Escalation History',
                  subtitle: 'Review issues sent to Admin',
                  onTap: () => context.push('/coordinator/escalations'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    String severity = 'HIGH';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('🔥 EMERGENCY ESCALATION'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This will alert ALL platform admins immediately. Use only for massive failures or regional disasters.', 
                         style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Situation Report', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: severity,
                items: ['HIGH', 'CRITICAL'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => severity = v!),
                decoration: const InputDecoration(labelText: 'Severity'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                 ref.read(intelligenceActionProvider.notifier).emergencyEscalate(
                   targetEntity: 'operational_scope',
                   targetId: 0,
                   reason: reasonController.text.trim(),
                   severity: severity,
                 );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMERGENCY ALERT BROADCASTED'), backgroundColor: Colors.red));
              },
              child: const Text('BROADCAST EMERGENCY', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, OperationalIntelligence intel) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Verified',
            value: intel.verificationStats['verified'].toString(),
            color: Colors.green,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Flagged',
            value: intel.verificationStats['flagged'].toString(),
            color: Colors.orange,
            icon: Icons.flag_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildStuckTasksList(BuildContext context, List<dynamic> tasks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text('Stuck Tasks (>24h)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (tasks.isNotEmpty)
                  Tag(label: '${tasks.length}', color: Colors.red),
              ],
            ),
            const Divider(height: 24),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No stuck tasks detected.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              ...tasks.take(3).map((t) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t['title'] ?? 'Untitled', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text('Status: ${t['status'] ?? 'Unknown'}', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () => context.push('/coordinator/task/${t['id']}'),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildVolunteerPerformance(BuildContext context, List<dynamic> volunteers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Volunteer Reliability', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...volunteers.take(5).map((v) {
          final totalTasks = SafeParser.paramInt(v['total_tasks']);
          final flags = SafeParser.paramInt(v['flags']);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(SafeParser.toStringSafe(v['name'], defaultValue: 'Unknown'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Total Tasks: $totalTasks'),
              trailing: flags > 0 
                  ? Tag(label: '$flags Flags', color: Colors.orange)
                  : const Tag(label: 'Reliable', color: Colors.green),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNgoPerformance(BuildContext context, List<dynamic> ngos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NGO Execution Speed', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...ngos.take(5).map((n) {
          final totalTasks = SafeParser.paramInt(n['total_tasks']);
          final avgHours = SafeParser.toDouble(n['avg_completion_hours']);
          
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(SafeParser.toStringSafe(n['org_name'], defaultValue: 'Unknown NGO')),
            subtitle: Text('Tasks: $totalTasks'),
            trailing: Text('${avgHours.toStringAsFixed(1)}h avg', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          );
        }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String label;
  final Color color;
  const Tag({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
