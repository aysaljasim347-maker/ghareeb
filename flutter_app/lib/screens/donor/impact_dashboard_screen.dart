import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/models/donation_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/donation_provider.dart';
import 'package:disasteraid_app/providers/follow_provider.dart';
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
        title: const Text('Impact'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined),
            onPressed: () => context.push('/donor/followed'),
          ),
        ],
      ),
      body: donationsAsync.when(
        loading: () => const ShimmerList(count: 4, itemHeight: 80),
        error: (e, _) => ErrorView(
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
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ImpactHero(summary: summary),
                ),

                SliverToBoxAdapter(
                  child: _QuickStatsRow(summary: summary),
                ),

                const SliverToBoxAdapter(
                  child: _SectionTitle("Campaigns you're supporting"),
                ),

                SliverToBoxAdapter(
                  child: _FollowedCampaignPreview(
                    campaignsAsync: campaignsAsync,
                    followedIds: followedIds,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: _SectionTitle("Donation insights"),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DonationBreakdownCard(donations: donations),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: _SectionTitle("Recent activity"),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        if (i >= donations.length || i >= 5) return null;
                        return _ActivityTile(donation: donations[i]);
                      },
                      childCount: donations.length > 5 ? 5 : donations.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Impact Hero ─────────────────────────────────────────────────────────────

class _ImpactHero extends StatelessWidget {
  final DonationSummary summary;

  const _ImpactHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: EdgeInsets.all(width > 400 ? 24 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "YOUR GIVING IMPACT",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "Rs ${NumberFormat('#,##0').format(summary.totalPkr)}",
              style: TextStyle(
                fontSize: width > 400 ? 36 : 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "across ${summary.campaignsCount} causes supported",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
              fontSize: width > 400 ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Stats ─────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final DonationSummary summary;

  const _QuickStatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _MiniStat("Donations", summary.count.toString(), Icons.favorite),
          const SizedBox(width: 12),
          _MiniStat("Campaigns", summary.campaignsCount.toString(), Icons.campaign),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(width > 400 ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (width > 350) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
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

// ── Followed Campaign Preview ──────────────────────────────────────────────

class _FollowedCampaignPreview extends StatelessWidget {
  final AsyncValue<List<CampaignModel>> campaignsAsync;
  final Set<int> followedIds;

  const _FollowedCampaignPreview({
    required this.campaignsAsync,
    required this.followedIds,
  });

  @override
  Widget build(BuildContext context) {
    return campaignsAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(),
      data: (all) {
        final list = all.where((c) => followedIds.contains(c.id)).toList();

        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "You haven't followed any campaigns yet.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = list[i];
              return Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${(c.progressFraction * 100).round()}% funded",
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                        ),
                        if (c.isUrgent)
                          const Icon(Icons.bolt, size: 14, color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.progressFraction,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Donation Breakdown ──────────────────────────────────────────────────────

class _DonationBreakdownCard extends StatelessWidget {
  final List<DonationModel> donations;

  const _DonationBreakdownCard({required this.donations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    final confirmed = donations.where((d) => d.isConfirmed).toList();
    final pending = donations.where((d) => d.status == 'PENDING').toList();
    final rejected = donations.where((d) => d.status == 'REJECTED' || d.status == 'FAILED').toList();

    final confirmedTotal = confirmed.fold<double>(0, (s, d) => s + d.amountPkr);
    final pendingTotal = pending.fold<double>(0, (s, d) => s + d.amountPkr);
    final rejectedTotal = rejected.fold<double>(0, (s, d) => s + d.amountPkr);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _BreakdownRow(
              label: 'Confirmed',
              amount: 'Rs ${fmt.format(confirmedTotal)}',
              count: confirmed.length,
              color: Colors.green,
            ),
            if (pendingTotal > 0 || pending.isNotEmpty) ...[
              const Divider(height: 24),
              _BreakdownRow(
                label: 'Pending',
                amount: 'Rs ${fmt.format(pendingTotal)}',
                count: pending.length,
                color: Colors.orange,
              ),
            ],
            if (rejectedTotal > 0 || rejected.isNotEmpty) ...[
              const Divider(height: 24),
              _BreakdownRow(
                label: 'Rejected',
                amount: 'Rs ${fmt.format(rejectedTotal)}',
                count: rejected.length,
                color: cs.error,
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

  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('$count donation${count != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
  }
}

// ── Activity Tile ───────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final DonationModel donation;

  const _ActivityTile({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    String dateLabel = 'Recently';
    if (donation.createdAt != null) {
      final dt = DateTime.tryParse(donation.createdAt!);
      if (dt != null) {
        dateLabel = DateFormat('dd MMM').format(dt.toLocal());
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volunteer_activism, size: 16, color: cs.primary),
              ),
              Container(width: 2, height: 20, color: cs.outlineVariant.withValues(alpha: 0.3)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
                    children: [
                      const TextSpan(text: 'Donated '),
                      TextSpan(
                        text: 'Rs ${fmt.format(donation.amountPkr)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (donation.campaignTitle != null) ...[
                        const TextSpan(text: ' to '),
                        TextSpan(
                          text: donation.campaignTitle,
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(dateLabel, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
      ),
    );
  }
}
