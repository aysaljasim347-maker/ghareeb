import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/providers/campaign_report_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';

class CampaignReportScreen extends ConsumerWidget {
  final int campaignId;

  const CampaignReportScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(campaignReportProvider(campaignId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign Report')),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: 'Failed to load campaign report.',
          onRetry: () => ref.invalidate(campaignReportProvider(campaignId)),
        ),
        data: (report) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, report),
              const SizedBox(height: 24),
              _buildFinancialCard(context, report),
              const SizedBox(height: 24),
              Text('Task Fulfillment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTaskStats(context, report),
              const SizedBox(height: 24),
              Text('Transparency Rating', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTransparencyCard(context, report.transparencyScore),
              const SizedBox(height: 32),
              _buildTaskList(context, report.tasks),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CampaignReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.campaign.title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              'Launched ${DateFormat('MMM d, yyyy').format(DateTime.parse(report.campaign.createdAt!))}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Spacer(),
            const Tag(label: 'OFFICIAL REPORT', color: Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialCard(BuildContext context, CampaignReport report) {
    final camp = report.campaign;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _FinancialItem(label: 'Raised', value: camp.raisedPkr),
                _FinancialItem(label: 'Spent', value: camp.spentPkr),
                _FinancialItem(
                    label: 'Remaining', value: camp.raisedPkr - camp.spentPkr),
              ],
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: report.utilizationPercent,
              backgroundColor: Colors.grey.shade100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fund Utilization',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('${(report.utilizationPercent * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskStats(BuildContext context, CampaignReport report) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Completed',
            value: report.completedTasks.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'In Progress',
            value: report.pendingTasks.toString(),
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Total',
            value: report.tasks.length.toString(),
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildTransparencyCard(BuildContext context, int score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Platform Transparency Score',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '$score/100',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<TaskModel> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Linked Activities',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...tasks.take(5).map((t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading:
                    const CircleAvatar(child: Icon(Icons.task_alt, size: 16)),
                title: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(t.status.value.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
                trailing: Text('PKR ${t.budgetPkr.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),
      ],
    );
  }
}

class _FinancialItem extends StatelessWidget {
  final String label;
  final double value;

  const _FinancialItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          'PKR ${NumberFormat.compact().format(value)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
