import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/providers/volunteer_impact_provider.dart';
import 'package:reliefnet_app/providers/volunteer_reputation_provider.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

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
            tooltip: 'View profile',
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
              _buildHeroCard(context, reputation, impactAsync),
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

  /// Single hero card merging trust score ring + lives impacted counter.
  Widget _buildHeroCard(
    BuildContext context,
    VolunteerReputation rep,
    AsyncValue<VolunteerImpactStats> impactAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/volunteer/profile'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // Trust score ring
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: rep.trustScore / 100,
                      strokeWidth: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      color: Colors.white,
                    ),
                    Text(
                      '${rep.trustScore}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Rank + trust label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Trust Score',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _getTrendIcon(rep.trend),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rep.rankLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Lives impacted counter
              impactAsync.when(
                loading: () => const SizedBox(width: 56),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stats.peopleHelped}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      'HELPED',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getTrendIcon(String trend) {
    if (trend == 'UP') return const Icon(Icons.trending_up, color: Colors.white70, size: 14);
    if (trend == 'DOWN') return const Icon(Icons.trending_down, color: Colors.white70, size: 14);
    return const Icon(Icons.trending_flat, color: Colors.white70, size: 14);
  }

  void _exportSummary(BuildContext context, VolunteerImpactStats stats) {
    final summary = '''
Volunteer Impact Summary - ReliefNet
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
    final cs = Theme.of(context).colorScheme;
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => Text(
        'Error loading activity',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No recent activity',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          );
        }
        return Column(
          children: tasks.take(3).map((t) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getCategoryIcon(t.category), size: 18, color: cs.primary),
              ),
              title: Text(
                t.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                t.status.value.replaceAll('_', ' '),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
              onTap: () => context.push('/volunteer/task/${t.id}'),
            ),
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
