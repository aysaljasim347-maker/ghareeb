import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reliefnet_app/models/campaign_model.dart';
import 'package:reliefnet_app/providers/campaign_provider.dart';
import 'package:reliefnet_app/providers/follow_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';

enum _WatchlistFilter {
  all('All'),
  urgent('Urgent'),
  nearGoal('Near Goal');

  final String label;
  const _WatchlistFilter(this.label);
}

class FollowedCampaignsScreen extends ConsumerStatefulWidget {
  const FollowedCampaignsScreen({super.key});

  @override
  ConsumerState<FollowedCampaignsScreen> createState() =>
      _FollowedCampaignsScreenState();
}

class _FollowedCampaignsScreenState
    extends ConsumerState<FollowedCampaignsScreen> {
  _WatchlistFilter _filter = _WatchlistFilter.all;

  @override
  Widget build(BuildContext context) {
    final followedIds = ref.watch(followedCampaignsProvider);
    final campaignsAsync = ref.watch(campaignsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Impact Watchlist'),
            Text(
              'Track campaigns you care about',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
      body: campaignsAsync.when(
        loading: () => const ShimmerList(count: 4, itemHeight: 80),
        error: (err, _) => ErrorView(
          message: 'Could not load campaigns.',
          onRetry: () => ref.invalidate(campaignsProvider),
        ),
        data: (allCampaigns) {
          final followed =
              allCampaigns.where((c) => followedIds.contains(c.id)).toList();

          if (followedIds.isEmpty || followed.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'No followed campaigns',
              subtitle:
                  'Tap the bookmark icon on any campaign to follow it and track updates here.',
              ctaLabel: 'Browse Campaigns',
              onCta: () => context.go('/donor/campaigns'),
            );
          }

          final urgentCount = followed.where((c) => c.isUrgent).length;
          final nearGoalCount =
              followed.where((c) => c.progressFraction >= 0.8).length;

          // Apply Filter
          List<CampaignModel> filtered = followed;
          if (_filter == _WatchlistFilter.urgent) {
            filtered = followed.where((c) => c.isUrgent).toList();
          } else if (_filter == _WatchlistFilter.nearGoal) {
            filtered = followed.where((c) => c.progressFraction >= 0.8).toList();
          }

          // Grouping
          final urgentGroup = filtered.where((c) => c.isUrgent).toList();
          final nearGoalGroup = filtered
              .where((c) => !c.isUrgent && c.progressFraction >= 0.8)
              .toList();
          final othersGroup = filtered
              .where((c) => !c.isUrgent && c.progressFraction < 0.8)
              .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignsProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── Quick Insight Bar ──
                _QuickInsightBar(
                  total: followed.length,
                  urgent: urgentCount,
                  nearGoal: nearGoalCount,
                ),
                const SizedBox(height: 16),

                // ── Filter Chips ──
                _FilterChips(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),

                // ── Groups ──
                if (urgentGroup.isNotEmpty) ...[
                  const _SectionHeader(
                      label: '🔥 Urgent Campaigns', color: Colors.orange),
                  ...urgentGroup
                      .map((c) => _FollowedCampaignCard(campaign: c)),
                ],
                if (nearGoalGroup.isNotEmpty) ...[
                  const _SectionHeader(
                      label: '🎯 Near Goal', color: Colors.teal),
                  ...nearGoalGroup
                      .map((c) => _FollowedCampaignCard(campaign: c)),
                ],
                if (othersGroup.isNotEmpty) ...[
                  const _SectionHeader(label: '📌 Others'),
                  ...othersGroup
                      .map((c) => _FollowedCampaignCard(campaign: c)),
                ],

                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No ${_filter.label.toLowerCase()} campaigns.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickInsightBar extends StatelessWidget {
  final int total;
  final int urgent;
  final int nearGoal;

  const _QuickInsightBar({
    required this.total,
    required this.urgent,
    required this.nearGoal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _InsightChip(label: 'Following', value: '$total', cs: cs),
          const SizedBox(width: 10),
          _InsightChip(
            label: 'Urgent',
            value: '$urgent',
            cs: cs,
            color: Colors.orange,
          ),
          const SizedBox(width: 10),
          _InsightChip(
            label: 'Near Goal',
            value: '$nearGoal',
            cs: cs,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final Color? color;

  const _InsightChip({
    required this.label,
    required this.value,
    required this.cs,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: activeColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: activeColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _WatchlistFilter selected;
  final ValueChanged<_WatchlistFilter> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _WatchlistFilter.values.map((f) {
          final isSelected = selected == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f.label),
              selected: isSelected,
              onSelected: (_) => onSelected(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color? color;

  const _SectionHeader({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _FollowedCampaignCard extends ConsumerWidget {
  final CampaignModel campaign;

  const _FollowedCampaignCard({required this.campaign});

  String _getProgressLabel(double progress) {
    if (progress >= 1.0) return 'Goal achieved 🎉';
    if (progress >= 0.8) return 'Almost funded 🔥';
    if (progress >= 0.5) return 'Halfway there';
    if (progress >= 0.2) return 'Picking up pace';
    return 'Just started';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();
    final fmt = _fmt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key('followed_${campaign.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          ref
              .read(followedCampaignsProvider.notifier)
              .toggle(campaign.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${campaign.title}'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => ref
                    .read(followedCampaignsProvider.notifier)
                    .toggle(campaign.id),
              ),
            ),
          );
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: cs.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.bookmark_remove, color: Colors.white),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/donor/campaign/${campaign.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          campaign.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (campaign.isUrgent)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child:
                              Icon(Icons.bolt, size: 20, color: Colors.orange),
                        ),
                    ],
                  ),
                  if (campaign.ngoName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      campaign.ngoName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Expressive Progress Bar ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getProgressLabel(campaign.progressFraction),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: campaign.progressFraction >= 0.8
                              ? Colors.orange
                              : cs.primary,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: campaign.progressFraction,
                      minHeight: 10,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: campaign.isUrgent ? Colors.orange : cs.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs ${fmt(campaign.raisedPkr)} raised of Rs ${fmt(campaign.goalPkr)}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              context.push('/donor/campaign/${campaign.id}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('View Updates'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              context.push('/donor/payment/${campaign.id}'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Donate Now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
