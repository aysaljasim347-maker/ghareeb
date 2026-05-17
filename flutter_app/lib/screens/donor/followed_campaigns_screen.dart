import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/follow_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

class FollowedCampaignsScreen extends ConsumerWidget {
  const FollowedCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedIds = ref.watch(followedCampaignsProvider);
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Followed Campaigns')),
      body: campaignsAsync.when(
        loading: () => const ShimmerList(count: 4, itemHeight: 80),
        error: (err, _) => ErrorView(
          message: 'Could not load campaigns.',
          onRetry: () => ref.invalidate(campaignsProvider),
        ),
        data: (allCampaigns) {
          if (followedIds.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'No followed campaigns',
              subtitle:
                  'Tap the bookmark icon on any campaign to follow it and track updates here.',
              ctaLabel: 'Browse Campaigns',
              onCta: () => context.go('/donor/campaigns'),
            );
          }

          final followed = allCampaigns
              .where((c) => followedIds.contains(c.id))
              .toList();

          if (followed.isEmpty) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Followed campaigns ended',
              subtitle:
                  'The campaigns you followed are no longer active.',
              ctaLabel: 'Browse Campaigns',
              onCta: () => context.go('/donor/campaigns'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: followed.length,
              itemBuilder: (context, i) =>
                  _FollowedCampaignCard(campaign: followed[i]),
            ),
          );
        },
      ),
    );
  }
}

class _FollowedCampaignCard extends ConsumerWidget {
  final CampaignModel campaign;

  const _FollowedCampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();
    final fmt = _fmt;

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
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (campaign.isUrgent)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.bolt, size: 16, color: Colors.orange),
                    ),
                  IconButton(
                    icon: const Icon(Icons.bookmark, size: 20),
                    color: cs.primary,
                    tooltip: 'Unfollow',
                    onPressed: () => ref
                        .read(followedCampaignsProvider.notifier)
                        .toggle(campaign.id),
                  ),
                ],
              ),
              if (campaign.ngoName != null) ...[
                const SizedBox(height: 2),
                Text(
                  campaign.ngoName!,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: campaign.progressFraction,
                backgroundColor: cs.surfaceContainerHighest,
                color: campaign.isUrgent ? Colors.orange : cs.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${fmt(campaign.raisedPkr)} / ₹${fmt(campaign.goalPkr)}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '$pct% funded',
                    style: TextStyle(
                      fontSize: 11,
                      color: campaign.isUrgent
                          ? Colors.orange
                          : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () =>
                      context.push('/donor/payment/${campaign.id}'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Donate'),
                ),
              ),
            ],
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
