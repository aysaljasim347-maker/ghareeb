import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/follow_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';

// NOTE: Only the NGO's ACTIVE campaigns are shown because campaignsProvider
// fetches status=ACTIVE. Paused/closed campaigns are intentionally excluded.
class NgoProfileScreen extends ConsumerWidget {
  final int ngoId;

  const NgoProfileScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      body: campaignsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            message: 'Could not load NGO profile.',
            onRetry: () => ref.invalidate(campaignsProvider),
          ),
        ),
        data: (all) {
          final ngoCampaigns = all.where((c) => c.ngoId == ngoId).toList();
          final ngoName = ngoCampaigns.isNotEmpty
              ? ngoCampaigns.first.ngoName ?? 'NGO'
              : 'NGO';

          return CustomScrollView(
            slivers: [
              // ── Header ──
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                flexibleSpace: FlexibleSpaceBar(
                  background: _NgoHero(ngoName: ngoName),
                ),
                actions: [
                  Consumer(
                    builder: (context, ref, _) {
                      final isFollowed =
                          ref.watch(followedNgosProvider).contains(ngoId);
                      return IconButton(
                        icon: Icon(isFollowed
                            ? Icons.bookmark
                            : Icons.bookmark_add_outlined),
                        tooltip: isFollowed ? 'Unfollow NGO' : 'Follow NGO',
                        onPressed: () => ref
                            .read(followedNgosProvider.notifier)
                            .toggle(ngoId),
                      );
                    },
                  ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Stats ──
                    _NgoStatsRow(campaigns: ngoCampaigns),
                    const SizedBox(height: 24),

                    // ── Campaigns list ──
                    Text(
                      'Active Campaigns',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),

              if (ngoCampaigns.isEmpty)
                SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No active campaigns',
                    subtitle: 'This NGO has no active campaigns right now.',
                    ctaLabel: 'Browse all',
                    onCta: () => context.go('/donor/campaigns'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _NgoCampaignTile(campaign: ngoCampaigns[i]),
                      childCount: ngoCampaigns.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── NGO hero header ───────────────────────────────────────────────────────────

class _NgoHero extends StatelessWidget {
  final String ngoName;

  const _NgoHero({required this.ngoName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.primary,
            child: Text(
              ngoName.isNotEmpty ? ngoName[0].toUpperCase() : 'N',
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ngoName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _NgoStatsRow extends StatelessWidget {
  final List<CampaignModel> campaigns;

  const _NgoStatsRow({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalRaised = campaigns.fold<double>(0, (s, c) => s + c.raisedPkr);
    final totalSpent = campaigns.fold<double>(0, (s, c) => s + c.spentPkr);
    final fmt = NumberFormat.compact();

    // Derived transparency score for this view
    double utilization = totalRaised > 0 ? totalSpent / totalRaised : 0.0;
    int score = 0;
    if (utilization > 0.6) score += 40;
    if (campaigns.any((c) => c.progressFraction > 0.5)) score += 30;
    if (totalSpent > 0) score += 30;

    return Column(
      children: [
        Row(
          children: [
            _StatBox(
              label: 'Campaigns',
              value: '${campaigns.length}',
              cs: cs,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'Raised',
                value: 'PKR ${fmt.format(totalRaised)}',
                cs: cs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'Spent',
                value: 'PKR ${fmt.format(totalSpent)}',
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              const Text('Transparency Rating',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$score/100',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _StatBox({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Campaign tile ─────────────────────────────────────────────────────────────

class _NgoCampaignTile extends StatelessWidget {
  final CampaignModel campaign;

  const _NgoCampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (campaign.isUrgent)
                    const Icon(Icons.bolt, size: 16, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: campaign.progressFraction,
                backgroundColor: cs.surfaceContainerHighest,
                color: campaign.isUrgent ? Colors.orange : cs.primary,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$pct% funded',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        context.push('/donor/payment/${campaign.id}'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('Donate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
