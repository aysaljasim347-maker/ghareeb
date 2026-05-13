import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
            tooltip: 'Search campaigns',
          ),
        ],
      ),
      body: campaignsAsync.when(
        loading: () => const ShimmerGrid(count: 6, childAspectRatio: 0.78),
        error: (err, _) => ErrorView(
          message: 'Could not load campaigns. Please try again.',
          onRetry: () => ref.invalidate(campaignsProvider),
        ),
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return const EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No active campaigns',
              subtitle:
                  'Check back later — new campaigns are added regularly.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignsProvider),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) =>
                      _CampaignCard(campaign: campaigns[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/donor/payment/${campaign.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            AspectRatio(
              aspectRatio: 16 / 9,
              child: campaign.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: campaign.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: cs.primaryContainer,
                        child: Icon(Icons.campaign,
                            size: 40, color: cs.primary),
                      ),
                      errorWidget: (_, __, ___) => _PlaceholderImage(cs: cs),
                    )
                  : _PlaceholderImage(cs: cs),
            ),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // ── Progress ──
                    LinearProgressIndicator(
                      value: campaign.progressFraction,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_format(campaign.raisedPkr)} / ₹${_format(campaign.goalPkr)}',
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),

                    // ── CTA ──
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
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
          ],
        ),
      ),
    );
  }

  String _format(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _PlaceholderImage extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderImage({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer,
      child: Center(
        child: Icon(Icons.campaign, size: 40, color: cs.primary),
      ),
    );
  }
}
