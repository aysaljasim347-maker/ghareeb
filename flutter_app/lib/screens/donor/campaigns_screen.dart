import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

// ── Filter / Sort enums ───────────────────────────────────────────────────────

enum _CampaignFilter {
  all('All'),
  disaster('Disaster'),
  health('Health'),
  education('Education'),
  poverty('Poverty');

  final String label;
  const _CampaignFilter(this.label);
}

enum _SortOption {
  none('Default'),
  mostRaised('Most Raised'),
  nearGoal('Near Goal');

  final String label;
  const _SortOption(this.label);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  _CampaignFilter _filter = _CampaignFilter.all;
  _SortOption _sort = _SortOption.none;

  List<CampaignModel> _applyFilterSort(List<CampaignModel> all) {
    var list = all.toList();

    if (_filter != _CampaignFilter.all) {
      final keyword = _filter.label.toLowerCase();
      list = list.where((c) {
        final searchText =
            '${c.title} ${c.description ?? ''}'.toLowerCase();
        return searchText.contains(keyword);
      }).toList();
    }

    switch (_sort) {
      case _SortOption.mostRaised:
        list.sort((a, b) => b.raisedPkr.compareTo(a.raisedPkr));
        break;
      case _SortOption.nearGoal:
        list.sort(
            (a, b) => b.progressFraction.compareTo(a.progressFraction));
        break;
      case _SortOption.none:
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campaigns'),
        actions: [
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => _SortOption.values
                .map((o) => PopupMenuItem(
                      value: o,
                      child: Text(o.label),
                    ))
                .toList(),
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
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No campaigns found',
              subtitle:
                  'We couldn\'t find any active campaigns. Tap retry to check again.',
              ctaLabel: 'Retry',
              onCta: () => ref.invalidate(campaignsProvider),
            );
          }

          final filtered = _applyFilterSort(campaigns);
          final urgent = campaigns.where((c) => c.isUrgent).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignsProvider),
            child: CustomScrollView(
              slivers: [
                // ── Filter chips ──
                SliverToBoxAdapter(
                  child: _FilterChipRow(
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
                ),

                // ── Urgent section (only when no active filter) ──
                // Intentional: urgent campaigns appear in both the strip and
                // the grid below — "featured + full list" pattern.
                if (_filter == _CampaignFilter.all && urgent.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader(
                      icon: Icons.bolt,
                      label: 'Urgent — Almost Funded',
                      color: Colors.orange,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _UrgentCampaignRow(urgent: urgent),
                  ),
                  const SliverToBoxAdapter(
                    child: _SectionHeader(
                      icon: Icons.campaign,
                      label: 'All Campaigns',
                    ),
                  ),
                ],

                // ── Main grid ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'No ${_filter.label} campaigns',
                      subtitle: 'Try a different category.',
                      ctaLabel: 'Show all',
                      onCta: () =>
                          setState(() => _filter = _CampaignFilter.all),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _CampaignCard(campaign: filtered[index]),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Filter chip row ───────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  final _CampaignFilter selected;
  final ValueChanged<_CampaignFilter> onSelected;

  const _FilterChipRow(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _CampaignFilter.values.map((f) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label),
              selected: selected == f,
              onSelected: (_) => onSelected(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _SectionHeader(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color ?? cs.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Urgent horizontal row ─────────────────────────────────────────────────────

class _UrgentCampaignRow extends StatelessWidget {
  final List<CampaignModel> urgent;

  const _UrgentCampaignRow({required this.urgent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: urgent.length,
        itemBuilder: (context, i) => _UrgentCard(campaign: urgent[i]),
      ),
    );
  }
}

class _UrgentCard extends StatelessWidget {
  final CampaignModel campaign;

  const _UrgentCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();

    return GestureDetector(
      onTap: () => context.push('/donor/campaign/${campaign.id}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.errorContainer,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    campaign.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            LinearProgressIndicator(
              value: campaign.progressFraction,
              backgroundColor: cs.outline.withValues(alpha: 0.2),
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '$pct% funded',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    context.push('/donor/payment/${campaign.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Donate Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Campaign card ─────────────────────────────────────────────────────────────

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/donor/campaign/${campaign.id}'),
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
                        child:
                            Icon(Icons.campaign, size: 40, color: cs.primary),
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
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
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
                      '₹${_fmt(campaign.raisedPkr)} / ₹${_fmt(campaign.goalPkr)}',
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant),
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

  String _fmt(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
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
