import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/providers/volunteer_reputation_provider.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';

class VolunteerProfileScreen extends ConsumerWidget {
  const VolunteerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final reputation = ref.watch(volunteerReputationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
SliverAppBar(
  expandedHeight: 200,
  pinned: true,
  stretch: true,

  title: const Text('My Profile'),

  flexibleSpace: FlexibleSpaceBar(
    stretchModes: const [StretchMode.blurBackground],

    background: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  user?.name[0].toUpperCase() ?? 'V',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              user?.name ?? 'Volunteer',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            Text(
              reputation.rankLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Trust Score Card ──
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Volunteer Trust Score',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: reputation.trustScore / 100,
                                  strokeWidth: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _getScoreColor(reputation.trustScore),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${reputation.trustScore}',
                                    style:
                                        theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color:
                                          _getScoreColor(reputation.trustScore),
                                    ),
                                  ),
                                  const Text('/ 100',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _getTrendIcon(reputation.trend),
                              const SizedBox(width: 8),
                              Text(
                                _getTrendText(reputation.trend),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Badge Showcase ──
                  Text('Unlocked Badges',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: reputation.badges.length,
                      itemBuilder: (context, index) {
                        final badge = reputation.badges[index];
                        return _BadgeItem(badge: badge);
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Performance Summary ──
                  Text('Performance Summary',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          _PerformanceRow(
                            label: 'Verification Rate',
                            value:
                                '${(reputation.verificationRate * 100).toInt()}%',
                            icon: Icons.verified_user_outlined,
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _PerformanceRow(
                            label: 'Task Completion',
                            value:
                                '${(reputation.completionRate * 100).toInt()}%',
                            icon: Icons.task_alt,
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          _PerformanceRow(
                            label: 'Flag Rate',
                            value:
                                '${((1 - reputation.verificationRate) * 100).toInt()}%',
                            icon: Icons.flag_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  OutlinedButton.icon(
                    onPressed: () => _showSignOutDialog(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score > 80) return Colors.green;
    if (score > 50) return Colors.orange;
    return Colors.red;
  }

  Widget _getTrendIcon(String trend) {
    if (trend == 'UP') {
      return const Icon(Icons.trending_up, color: Colors.green);
    }
    if (trend == 'DOWN') {
      return const Icon(Icons.trending_down, color: Colors.red);
    }
    return const Icon(Icons.trending_flat, color: Colors.blue);
  }

  String _getTrendText(String trend) {
    if (trend == 'UP') return 'Improving trust level';
    if (trend == 'DOWN') return 'Declining trust level';
    return 'Stable reputation';
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will need to sign in again to access the platform.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final VolunteerBadge badge;
  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Opacity(
            opacity: badge.isUnlocked ? 1.0 : 0.3,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: badge.isUnlocked
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              child: Text(badge.icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
              color: badge.isUnlocked ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PerformanceRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
