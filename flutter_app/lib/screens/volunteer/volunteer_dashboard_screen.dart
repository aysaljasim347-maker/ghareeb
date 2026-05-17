import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/providers/volunteer_impact_provider.dart';
import 'package:disasteraid_app/providers/volunteer_reputation_provider.dart';
import 'package:disasteraid_app/core/theme/app_theme.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';

class VolunteerDashboardScreen extends ConsumerWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impactAsync = ref.watch(volunteerImpactProvider);
    final historyAsync = ref.watch(volunteerTasksHistoryProvider);
    final reputation = ref.watch(volunteerReputationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Impact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/volunteer/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(volunteerImpactProvider);
          ref.invalidate(volunteerTasksHistoryProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReputationCard(context, reputation),
              const SizedBox(height: 24),
              
              _buildImpactHeader(context, impactAsync),
              const SizedBox(height: 24),
              
              Text('Impact Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildStatsGrid(context, impactAsync),
              const SizedBox(height: 32),

              Text('Your Badges', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBadgeSection(context, impactAsync),
              const SizedBox(height: 32),

              Text('Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.share, color: AppTheme.primaryColor),
                  title: const Text('Export Impact Summary'),
                  subtitle: const Text('Generate a report of your platform contributions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => impactAsync.whenData((stats) => _exportSummary(context, stats)),
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Tasks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => context.push('/volunteer/activity'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              _buildRecentTasks(context, historyAsync),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReputationCard(BuildContext context, VolunteerReputation rep) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/volunteer/profile'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: rep.trustScore / 100,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: rep.trustScore > 70 ? Colors.green : Colors.blue,
                  ),
                  Text(
                    '${rep.trustScore}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Trust Score', style: theme.textTheme.labelMedium),
                        const SizedBox(width: 4),
                        _getTrendIcon(rep.trend),
                      ],
                    ),
                    Text(
                      rep.rankLabel,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
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

  Widget _getTrendIcon(String trend) {
    if (trend == 'UP') return const Icon(Icons.trending_up, color: Colors.green, size: 16);
    if (trend == 'DOWN') return const Icon(Icons.trending_down, color: Colors.red, size: 16);
    return const Icon(Icons.trending_flat, color: Colors.blue, size: 16);
  }

  void _exportSummary(BuildContext context, VolunteerImpactStats stats) {
    final summary = '''
Volunteer Impact Summary - DisasterAid
--------------------------------------
Lives Impacted: ${stats.peopleHelped}
Tasks Completed: ${stats.totalCompleted}
Success Rate: ${(stats.successRate * 100).toInt()}%
Verified Deliveries: ${stats.verifiedDeliveries}
--------------------------------------
Generated on ${DateFormat('MMM d, yyyy').format(DateTime.now())}
''';

    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impact summary copied to clipboard!')),
    );
  }

  Widget _buildImpactHeader(BuildContext context, AsyncValue<VolunteerImpactStats> async) {
    return async.when(
      loading: () => const _HeaderSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '${stats.peopleHelped}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const Text(
              'LIVES IMPACTED',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, AsyncValue<VolunteerImpactStats> async) {
    return async.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Text('Failed to load stats'),
      data: (stats) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _StatCard(label: 'Completed', value: stats.totalCompleted.toString(), color: AppTheme.successColor, icon: Icons.check_circle),
          _StatCard(label: 'In Progress', value: stats.inProgress.toString(), color: Colors.blue, icon: Icons.pending),
          _StatCard(label: 'Verified', value: stats.verifiedDeliveries.toString(), color: Colors.teal, icon: Icons.verified),
          _StatCard(label: 'Flagged', value: stats.flaggedDeliveries.toString(), color: AppTheme.errorColor, icon: Icons.flag),
        ],
      ),
    );
  }

  Widget _buildBadgeSection(BuildContext context, AsyncValue<VolunteerImpactStats> async) {
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final badges = <Widget>[];
        if (stats.totalCompleted >= 10) {
          badges.add(const _ImpactBadge(icon: Icons.local_fire_department, label: 'Active Helper', color: Colors.orange));
        }
        if (stats.totalCompleted >= 1) {
          badges.add(const _ImpactBadge(icon: Icons.star, label: 'First Relief', color: Colors.amber));
        }

        if (badges.isEmpty) {
          return const Text('Complete your first task to earn badges!', style: TextStyle(color: Colors.grey, fontSize: 13));
        }

        return Wrap(spacing: 12, children: badges);
      },
    );
  }

  Widget _buildRecentTasks(BuildContext context, AsyncValue<List<TaskModel>> async) {
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Error loading activity'),
      data: (tasks) {
        if (tasks.isEmpty) return const Text('No recent activity');
        return Column(
          children: tasks.take(3).map((t) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: Icon(_getCategoryIcon(t.category), size: 18),
            ),
            title: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(t.status.value, style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/volunteer/task/${t.id}'),
          )).toList(),
        );
      },
    );
  }

  IconData _getCategoryIcon(String? cat) {
    switch (cat?.toUpperCase()) {
      case 'FOOD': return Icons.lunch_dining;
      case 'MEDICAL': return Icons.medical_services;
      default: return Icons.assignment;
    }
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
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ImpactBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ImpactBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
