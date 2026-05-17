import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/models/donation_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/donation_provider.dart';
import 'package:disasteraid_app/providers/follow_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/error_view.dart';

class ImpactDashboardScreen extends ConsumerWidget {
  const ImpactDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myDonationsProvider);
    final campaignsAsync = ref.watch(campaignsProvider);
    final followedIds = ref.watch(followedCampaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Impact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined),
            tooltip: 'Followed Campaigns',
            onPressed: () => context.push('/donor/followed'),
          ),
        ],
      ),
      body: donationsAsync.when(
        loading: () => const ShimmerList(count: 4, itemHeight: 80),
        error: (err, _) => ErrorView(
          message: 'Could not load impact data.',
          onRetry: () => ref.invalidate(myDonationsProvider),
        ),
        data: (donations) {
          final summary = DonationSummary.fromDonations(donations);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myDonationsProvider);
              ref.invalidate(campaignsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ImpactSummaryCard(summary: summary),
                const SizedBox(height: 20),

                const _SectionHeader(
                  icon: Icons.volunteer_activism,
                  label: 'Donation Breakdown',
                ),
                const SizedBox(height: 12),
                _DonationBreakdownCard(donations: donations),
                const SizedBox(height: 20),

                _SectionHeader(
                  icon: Icons.bookmark,
                  label: 'Followed Campaigns',
                  trailing: followedIds.isNotEmpty
                      ? TextButton(
                          onPressed: () => context.push('/donor/followed'),
                          child: const Text('See all'),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                campaignsAsync.when(
                  loading: () =>
                      const ShimmerList(count: 2, itemHeight: 72),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (allCampaigns) {
                    if (followedIds.isEmpty) {
                      return _FollowEmptyHint(
                        onBrowse: () => context.go('/donor/campaigns'),
                      );
                    }
                    final followed = allCampaigns
                        .where((c) => followedIds.contains(c.id))
                        .toList();
                    if (followed.isEmpty) {
                      return _FollowEmptyHint(
                        onBrowse: () => context.go('/donor/campaigns'),
                      );
                    }
                    return Column(
                      children: followed
                          .take(3)
                          .map((c) => _FollowedCampaignTile(campaign: c))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),
                const _SectionHeader(
                  icon: Icons.history,
                  label: 'Recent Activity',
                ),
                const SizedBox(height: 12),
                if (donations.isEmpty)
                  const EmptyState(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'No activity yet',
                    subtitle: 'Make your first donation to see activity here.',
                  )
                else
                  Column(
                    children: donations
                        .take(5)
                        .map((d) => _ActivityTile(donation: d))
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Impact summary card ───────────────────────────────────────────────────────

class _ImpactSummaryCard extends StatelessWidget {
  final DonationSummary summary;

  const _ImpactSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Your Giving Impact',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '₹${fmt.format(summary.totalPkr)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'confirmed contributions',
              style: TextStyle(
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _ImpactPill(
                  icon: Icons.volunteer_activism,
                  value: '${summary.count}',
                  label: 'Donations',
                  cs: cs,
                ),
                const SizedBox(width: 12),
                _ImpactPill(
                  icon: Icons.campaign_outlined,
                  value: '${summary.campaignsCount}',
                  label: 'Campaigns',
                  cs: cs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme cs;

  const _ImpactPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.onPrimaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Donation breakdown card ───────────────────────────────────────────────────

class _DonationBreakdownCard extends StatelessWidget {
  final List<DonationModel> donations;

  const _DonationBreakdownCard({required this.donations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    final confirmed =
        donations.where((d) => d.isConfirmed).toList();
    final pending =
        donations.where((d) => d.status == 'PENDING').toList();
    final rejected =
        donations.where((d) => d.status == 'REJECTED').toList();

    final confirmedTotal =
        confirmed.fold<double>(0, (s, d) => s + d.amountPkr);
    final pendingTotal =
        pending.fold<double>(0, (s, d) => s + d.amountPkr);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _BreakdownRow(
              label: 'Confirmed',
              amount: '₹${fmt.format(confirmedTotal)}',
              count: confirmed.length,
              color: Colors.green,
              cs: cs,
            ),
            if (pendingTotal > 0) ...[
              const Divider(height: 16),
              _BreakdownRow(
                label: 'Pending',
                amount: '₹${fmt.format(pendingTotal)}',
                count: pending.length,
                color: Colors.orange,
                cs: cs,
              ),
            ],
            if (rejected.isNotEmpty) ...[
              const Divider(height: 16),
              _BreakdownRow(
                label: 'Rejected',
                amount: '₹${fmt.format(rejected.fold<double>(0, (s, d) => s + d.amountPkr))}',
                count: rejected.length,
                color: cs.error,
                cs: cs,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String amount;
  final int count;
  final Color color;
  final ColorScheme cs;

  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Text(
          '$count donation${count != 1 ? 's' : ''}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Text(amount,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Followed campaign tile ────────────────────────────────────────────────────

class _FollowedCampaignTile extends StatelessWidget {
  final CampaignModel campaign;

  const _FollowedCampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/donor/campaign/${campaign.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (campaign.isUrgent)
                    const Icon(Icons.bolt, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Icon(Icons.bookmark, size: 16, color: cs.primary),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: campaign.progressFraction,
                backgroundColor: cs.surfaceContainerHighest,
                color: campaign.isUrgent ? Colors.orange : cs.primary,
              ),
              const SizedBox(height: 4),
              Text(
                '$pct% funded',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty follow hint ─────────────────────────────────────────────────────────

class _FollowEmptyHint extends StatelessWidget {
  final VoidCallback onBrowse;

  const _FollowEmptyHint({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_add_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Follow campaigns to track them here.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: onBrowse,
            child: const Text('Browse'),
          ),
        ],
      ),
    );
  }
}

// ── Activity tile ─────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final DonationModel donation;

  const _ActivityTile({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    String? dateLabel;
    if (donation.createdAt != null) {
      final dt = DateTime.tryParse(donation.createdAt!);
      if (dt != null) {
        dateLabel = DateFormat('dd MMM yyyy').format(dt.toLocal());
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volunteer_activism,
                    size: 18, color: cs.primary),
              ),
              Container(
                width: 2,
                height: 24,
                color: cs.outlineVariant,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      const TextSpan(text: 'Donated '),
                      TextSpan(
                        text: '₹${fmt.format(donation.amountPkr)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (donation.campaignTitle != null) ...[
                        const TextSpan(text: ' to '),
                        TextSpan(
                          text: donation.campaignTitle,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dateLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
