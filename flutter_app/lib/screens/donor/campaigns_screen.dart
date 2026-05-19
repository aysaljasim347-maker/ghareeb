import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/models/goods_campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/goods_campaign_provider.dart';
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

class _CampaignsScreenState extends ConsumerState<CampaignsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _CampaignFilter _filter = _CampaignFilter.all;
  _SortOption _sort = _SortOption.none;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Money'),
            Tab(text: 'Goods (In-Kind)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Money campaigns ──
          _MoneyCampaignsTab(filter: _filter, sort: _sort, onSortChanged: (v) => setState(() => _sort = v), onFilterChanged: (f) => setState(() => _filter = f), applyFilterSort: _applyFilterSort),
          // ── Tab 1: Goods campaigns ──
          const _GoodsCampaignsTab(),
        ],
      ),
    );
  }
}

// ── Money campaigns tab (extracted from original body) ────────────────────────

class _MoneyCampaignsTab extends ConsumerWidget {
  final _CampaignFilter filter;
  final _SortOption sort;
  final ValueChanged<_SortOption> onSortChanged;
  final ValueChanged<_CampaignFilter> onFilterChanged;
  final List<CampaignModel> Function(List<CampaignModel>) applyFilterSort;

  const _MoneyCampaignsTab({
    required this.filter,
    required this.sort,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.applyFilterSort,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);
    return campaignsAsync.when(
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

          final filtered = applyFilterSort(campaigns);
          final urgent = campaigns.where((c) => c.isUrgent).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(campaignsProvider),
            child: CustomScrollView(
              slivers: [
                // ── Filter chips ──
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeader(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: _FilterChipRow(
                        selected: filter,
                        onSelected: onFilterChanged,
                      ),
                    ),
                  ),
                ),

                // ── Urgent section (only when no active filter) ──
                // Intentional: urgent campaigns appear in both the strip and
                // the grid below — "featured + full list" pattern.
                if (filter == _CampaignFilter.all && urgent.isNotEmpty) ...[
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
                    child: Column(
                      children: [
                        SizedBox(height: 12),
                        Divider(),
                        SizedBox(height: 8),
                        _SectionHeader(
                          icon: Icons.campaign,
                          label: 'All Campaigns',
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Main grid ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'No ${filter.label} campaigns',
                      subtitle: 'Try a different category.',
                      ctaLabel: 'Show all',
                      onCta: () => onFilterChanged(_CampaignFilter.all),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        childAspectRatio: MediaQuery.of(context).size.width > 400 ? 0.72 : 0.65,
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
      );
  }
}

// ── Sticky Header Delegate ─────────────────────────────────────────────────────

class _StickyHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeader({required this.child});

  @override
  double get minExtent => 52.0;
  @override
  double get maxExtent => 52.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyHeader oldDelegate) => false;
}

// ── Goods campaigns tab ───────────────────────────────────────────────────────

class _GoodsCampaignsTab extends ConsumerWidget {
  const _GoodsCampaignsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goodsCampaignsProvider);
    return async.when(
      loading: () => const ShimmerList(count: 4, itemHeight: 110),
      error: (e, _) => ErrorView(
        message: 'Could not load goods campaigns.',
        onRetry: () => ref.invalidate(goodsCampaignsProvider),
      ),
      data: (campaigns) {
        if (campaigns.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No goods campaigns',
            subtitle: 'Check back soon for in-kind donation drives.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(goodsCampaignsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _GoodsCampaignCard(campaign: campaigns[i]),
          ),
        );
      },
    );
  }
}

class _GoodsCampaignCard extends StatelessWidget {
  final GoodsCampaign campaign;
  const _GoodsCampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final deadline = DateTime.tryParse(campaign.deadline);
    final daysLeft = deadline?.difference(DateTime.now()).inDays;
    final pct = (campaign.progressFraction * 100).round();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/donor/goods-campaign/${campaign.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 11, color: Colors.teal),
                        SizedBox(width: 4),
                        Text('GOODS',
                            style: TextStyle(
                                color: Colors.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (campaign.ngoName != null)
                    Expanded(
                      child: Text(campaign.ngoName!,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                    ),
                  if (daysLeft != null && daysLeft >= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: daysLeft <= 7
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        daysLeft == 0
                            ? 'Today'
                            : '$daysLeft days left',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: daysLeft <= 7 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                campaign.title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${campaign.itemNeeded} · ${campaign.locationText}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: campaign.progressFraction,
                  minHeight: 6,
                  color: Colors.teal,
                  backgroundColor:
                      cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${campaign.qtyReceived} / ${campaign.targetQty} ${campaign.unit}',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context
                      .push('/donor/goods-campaign/${campaign.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Donate Item'),
                ),
              ),
            ],
          ),
        ),
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
    final width = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: urgent.length,
        itemBuilder: (context, i) => _UrgentCard(
          campaign: urgent[i],
          width: width > 400 ? 240 : width * 0.6,
        ),
      ),
    );
  }
}

class _UrgentCard extends StatelessWidget {
  final CampaignModel campaign;
  final double width;

  const _UrgentCard({required this.campaign, required this.width});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();

    return GestureDetector(
      onTap: () => context.push('/donor/campaign/${campaign.id}'),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.errorContainer,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    campaign.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
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
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              '$pct% funded',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    context.push('/donor/payment/${campaign.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
      elevation: 1,
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
                                fontWeight: FontWeight.w700,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // ── Progress ──
                    Text(
                      'Rs${_fmt(campaign.raisedPkr)} raised',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: campaign.progressFraction,
                        backgroundColor: cs.surfaceContainerHighest,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Goal: Rs${_fmt(campaign.goalPkr)}',
                      style: TextStyle(
                          fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),

                    // ── CTA ──
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            context.push('/donor/payment/${campaign.id}'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Donate Now'),
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
