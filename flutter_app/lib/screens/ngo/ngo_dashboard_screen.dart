import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/providers/ngo_impact_provider.dart';

class NgoDashboardScreen extends ConsumerWidget {
  const NgoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impactAsync = ref.watch(ngoImpactProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('NGO Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impact Overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            impactAsync.when(
              data: (impact) => _ImpactCard(impact: impact),
              loading: () => const _LoadingCard(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.campaign_outlined,
              title: 'My Campaigns',
              subtitle: 'Manage and view reports for your campaigns',
              onTap: () => context.push('/ngo/campaigns'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.analytics_outlined,
              title: 'Detailed Impact Dashboard',
              subtitle: 'View full analytics and transparency metrics',
              onTap: () => context.push('/ngo/impact'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Request Withdrawal',
              subtitle: 'Withdraw funds from your NGO wallet',
              onTap: () => context.push('/ngo/withdrawals'),
            ),
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(Icons.business_center_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'More operational tools coming soon',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final NgoImpactMetrics impact;
  const _ImpactCard({required this.impact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: 'Raised', value: 'PKR ${(impact.totalRaised / 1000).toStringAsFixed(1)}k'),
            _StatItem(label: 'Helped', value: impact.peopleHelped.toString()),
            _StatItem(label: 'Transparency', value: '${impact.transparencyScore}%'),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
