// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:reliefnet_app/models/campaign_model.dart';
// import 'package:reliefnet_app/models/goods_campaign_model.dart';
// import 'package:reliefnet_app/providers/campaign_provider.dart';
// import 'package:reliefnet_app/providers/goods_campaign_provider.dart';
// import 'package:reliefnet_app/widgets/empty_state.dart';
// import 'package:reliefnet_app/widgets/error_view.dart';
// import 'package:reliefnet_app/widgets/shimmer_card.dart';

// // ── Filter / Sort enums ───────────────────────────────────────────────────────

// enum _CampaignFilter {
//   all('All'),
//   disaster('Disaster'),
//   health('Health'),
//   education('Education'),
//   poverty('Poverty');

//   final String label;
//   const _CampaignFilter(this.label);
// }

// enum _SortOption {
//   none('Default'),
//   mostRaised('Most Raised'),
//   nearGoal('Near Goal');

//   final String label;
//   const _SortOption(this.label);
// }

// // ── Screen ────────────────────────────────────────────────────────────────────

// class CampaignsScreen extends ConsumerStatefulWidget {
//   const CampaignsScreen({super.key});

//   @override
//   ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
// }

// class _CampaignsScreenState extends ConsumerState<CampaignsScreen>
//     with SingleTickerProviderStateMixin {
//   late final TabController _tabController;
//   _CampaignFilter _filter = _CampaignFilter.all;
//   _SortOption _sort = _SortOption.none;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   List<CampaignModel> _applyFilterSort(List<CampaignModel> all) {
//     var list = all.toList();

//     if (_filter != _CampaignFilter.all) {
//       final keyword = _filter.label.toLowerCase();
//       list = list.where((c) {
//         final searchText =
//             '${c.title} ${c.description ?? ''}'.toLowerCase();
//         return searchText.contains(keyword);
//       }).toList();
//     }

//     switch (_sort) {
//       case _SortOption.mostRaised:
//         list.sort((a, b) => b.raisedPkr.compareTo(a.raisedPkr));
//         break;
//       case _SortOption.nearGoal:
//         list.sort(
//             (a, b) => b.progressFraction.compareTo(a.progressFraction));
//         break;
//       case _SortOption.none:
//         break;
//     }

//     return list;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Campaigns',
//           style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
//         ),
//         actions: [
//           PopupMenuButton<_SortOption>(
//             icon: const Icon(Icons.sort_rounded),
//             tooltip: 'Sort campaigns',
//             initialValue: _sort,
//             onSelected: (v) => setState(() => _sort = v),
//             itemBuilder: (_) => _SortOption.values
//                 .map((o) => PopupMenuItem(
//                       value: o,
//                       child: Row(
//                         children: [
//                           Icon(
//                             _sort == o
//                                 ? Icons.radio_button_checked
//                                 : Icons.radio_button_off,
//                             size: 16,
//                             color: _sort == o ? cs.primary : cs.onSurfaceVariant,
//                           ),
//                           const SizedBox(width: 8),
//                           Text(o.label),
//                         ],
//                       ),
//                     ))
//                 .toList(),
//           ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           labelStyle: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//           unselectedLabelStyle: const TextStyle(
//             fontWeight: FontWeight.w400,
//             fontSize: 14,
//           ),
//           tabs: const [
//             Tab(text: 'Money'),
//             Tab(text: 'Goods (In-Kind)'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           // ── Tab 0: Money campaigns ──
//           _MoneyCampaignsTab(
//             filter: _filter,
//             sort: _sort,
//             onSortChanged: (v) => setState(() => _sort = v),
//             onFilterChanged: (f) => setState(() => _filter = f),
//             applyFilterSort: _applyFilterSort,
//           ),
//           // ── Tab 1: Goods campaigns ──
//           const _GoodsCampaignsTab(),
//         ],
//       ),
//     );
//   }
// }

// // ── Money campaigns tab ───────────────────────────────────────────────────────

// class _MoneyCampaignsTab extends ConsumerWidget {
//   final _CampaignFilter filter;
//   final _SortOption sort;
//   final ValueChanged<_SortOption> onSortChanged;
//   final ValueChanged<_CampaignFilter> onFilterChanged;
//   final List<CampaignModel> Function(List<CampaignModel>) applyFilterSort;

//   const _MoneyCampaignsTab({
//     required this.filter,
//     required this.sort,
//     required this.onSortChanged,
//     required this.onFilterChanged,
//     required this.applyFilterSort,
//   });

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final campaignsAsync = ref.watch(campaignsProvider);
//     return campaignsAsync.when(
//       loading: () => const ShimmerGrid(count: 6, childAspectRatio: 0.78),
//       error: (err, _) => ErrorView(
//         message: 'Could not load campaigns. Please try again.',
//         onRetry: () => ref.invalidate(campaignsProvider),
//       ),
//       data: (campaigns) {
//         if (campaigns.isEmpty) {
//           return EmptyState(
//             icon: Icons.campaign_outlined,
//             title: 'No campaigns found',
//             subtitle:
//                 'We couldn\'t find any active campaigns. Tap retry to check again.',
//             ctaLabel: 'Retry',
//             onCta: () => ref.invalidate(campaignsProvider),
//           );
//         }

//         final filtered = applyFilterSort(campaigns);
//         final urgent = campaigns.where((c) => c.isUrgent).toList();

//         return RefreshIndicator(
//           onRefresh: () async => ref.invalidate(campaignsProvider),
//           child: CustomScrollView(
//             slivers: [
//               // ── Filter chips ──
//               SliverPersistentHeader(
//                 pinned: true,
//                 delegate: _StickyHeader(
//                   child: Container(
//                     color: Theme.of(context).scaffoldBackgroundColor,
//                     child: _FilterChipRow(
//                       selected: filter,
//                       onSelected: onFilterChanged,
//                     ),
//                   ),
//                 ),
//               ),

//               // ── Urgent section (only when no active filter) ──
//               if (filter == _CampaignFilter.all && urgent.isNotEmpty) ...[
//                 const SliverToBoxAdapter(
//                   child: _SectionHeader(
//                     icon: Icons.bolt_rounded,
//                     label: 'Urgent — Almost Funded',
//                     color: Colors.orange,
//                   ),
//                 ),
//                 SliverToBoxAdapter(
//                   child: _UrgentCampaignRow(urgent: urgent),
//                 ),
//                 const SliverToBoxAdapter(
//                   child: Column(
//                     children: [
//                       SizedBox(height: 12),
//                       Divider(indent: 16, endIndent: 16),
//                       SizedBox(height: 4),
//                       _SectionHeader(
//                         icon: Icons.campaign_rounded,
//                         label: 'All Campaigns',
//                       ),
//                     ],
//                   ),
//                 ),
//               ],

//               // ── Main grid ──
//               if (filtered.isEmpty)
//                 SliverFillRemaining(
//                   child: EmptyState(
//                     icon: Icons.search_off_rounded,
//                     title: 'No ${filter.label} campaigns',
//                     subtitle: 'Try a different category.',
//                     ctaLabel: 'Show all',
//                     onCta: () => onFilterChanged(_CampaignFilter.all),
//                   ),
//                 )
//               else
//                 SliverPadding(
//                   padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
//                   sliver: SliverGrid(
//   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//     crossAxisCount:
//         MediaQuery.of(context).size.width > 900
//             ? 4
//             : MediaQuery.of(context).size.width > 600
//                 ? 3
//                 : 2,

//     // FIXED HEIGHT = no overflow
//     mainAxisExtent: 310,

//     crossAxisSpacing: 12,
//     mainAxisSpacing: 12,
//   ),
//                     delegate: SliverChildBuilderDelegate(
//                       (context, index) =>
//                           _CampaignCard(campaign: filtered[index]),
//                       childCount: filtered.length,
//                     ),
//                   ),
//                 ),

//               // Bottom padding for nav bar
//               const SliverToBoxAdapter(child: SizedBox(height: 16)),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// // ── Sticky Header Delegate ────────────────────────────────────────────────────

// class _StickyHeader extends SliverPersistentHeaderDelegate {
//   final Widget child;
//   _StickyHeader({required this.child});

//   @override
//   double get minExtent => 56.0; // FIX: was 52, clips on large-font devices
//   @override
//   double get maxExtent => 56.0;

//   @override
//   Widget build(
//       BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return child;
//   }

//   @override
//   bool shouldRebuild(_StickyHeader oldDelegate) => false;
// }

// // ── Goods campaigns tab ───────────────────────────────────────────────────────

// class _GoodsCampaignsTab extends ConsumerWidget {
//   const _GoodsCampaignsTab();

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final async = ref.watch(goodsCampaignsProvider);
//     return async.when(
//       loading: () => const ShimmerList(count: 4, itemHeight: 110),
//       error: (e, _) => ErrorView(
//         message: 'Could not load goods campaigns.',
//         onRetry: () => ref.invalidate(goodsCampaignsProvider),
//       ),
//       data: (campaigns) {
//         if (campaigns.isEmpty) {
//           return const EmptyState(
//             icon: Icons.inventory_2_outlined,
//             title: 'No goods campaigns',
//             subtitle: 'Check back soon for in-kind donation drives.',
//           );
//         }
//         return RefreshIndicator(
//           onRefresh: () async => ref.invalidate(goodsCampaignsProvider),
//           child: ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
//             itemCount: campaigns.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) =>
//                 _GoodsCampaignCard(campaign: campaigns[i]),
//           ),
//         );
//       },
//     );
//   }
// }

// // ── Goods campaign card ───────────────────────────────────────────────────────

// class _GoodsCampaignCard extends StatelessWidget {
//   final GoodsCampaign campaign;
//   const _GoodsCampaignCard({required this.campaign});

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final deadline = DateTime.tryParse(campaign.deadline);
//     final daysLeft = deadline?.difference(DateTime.now()).inDays;
//     final pct = (campaign.progressFraction * 100).round();

//     return Card(
//       margin: EdgeInsets.zero,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       elevation: 0,
//       color: cs.surface,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(16),
//         onTap: () => context.push('/donor/goods-campaign/${campaign.id}'),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ── Top row: badge + org + days left ──
//               Row(
//                 children: [
//                   _GoodsBadge(),
//                   const SizedBox(width: 8),
//                   if (campaign.ngoName != null)
//                     Expanded(
//                       child: Text(
//                         campaign.ngoName!,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: cs.onSurfaceVariant,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     )
//                   else
//                     const Spacer(),
//                   if (daysLeft != null && daysLeft >= 0)
//                     _DaysLeftBadge(daysLeft: daysLeft),
//                 ],
//               ),

//               const SizedBox(height: 10),

//               // ── Title ──
//               Text(
//                 campaign.title,
//                 style: Theme.of(context).textTheme.titleSmall?.copyWith(
//                       fontWeight: FontWeight.w700,
//                       fontSize: 15,
//                       height: 1.3,
//                     ),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),

//               const SizedBox(height: 4),

//               Text(
//                 '${campaign.itemNeeded} · ${campaign.locationText}',
//                 style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
//                 overflow: TextOverflow.ellipsis,
//               ),

//               const SizedBox(height: 12),

//               // ── Progress ──
//               Semantics(
//                 label:
//                     '$pct% of goods goal collected: ${campaign.qtyReceived} of ${campaign.targetQty} ${campaign.unit}',
//                 child: ExcludeSemantics(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(6),
//                         child: LinearProgressIndicator(
//                           value: campaign.progressFraction,
//                           minHeight: 7,
//                           color: Colors.teal,
//                           backgroundColor: cs.surfaceContainerHighest,
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             '${campaign.qtyReceived} / ${campaign.targetQty} ${campaign.unit}',
//                             style: TextStyle(
//                                 fontSize: 12,
//                                 color: cs.onSurfaceVariant,
//                                 fontWeight: FontWeight.w500),
//                           ),
//                           Text(
//                             '$pct%',
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.teal.shade700,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 12),

//               // ── CTA ──
//               SizedBox(
//                 width: double.infinity,
//                 height: 42,
//                 child: FilledButton(
//                   onPressed: () =>
//                       context.push('/donor/goods-campaign/${campaign.id}'),
//                   style: FilledButton.styleFrom(
//                     backgroundColor: Colors.teal,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                     textStyle: const TextStyle(
//                         fontSize: 14, fontWeight: FontWeight.w600),
//                   ),
//                   child: const Text('Donate Item'),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Small reusable badge widgets ──────────────────────────────────────────────

// class _GoodsBadge extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.teal.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
//       ),
//       child: const Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.inventory_2_outlined, size: 11, color: Colors.teal),
//           SizedBox(width: 4),
//           Text(
//             'GOODS',
//             style: TextStyle(
//               color: Colors.teal,
//               fontSize: 10,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.4,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _DaysLeftBadge extends StatelessWidget {
//   final int daysLeft;
//   const _DaysLeftBadge({required this.daysLeft});

//   @override
//   Widget build(BuildContext context) {
//     final isUrgent = daysLeft <= 7;
//     final color = isUrgent ? Colors.red : Colors.green;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Text(
//         daysLeft == 0 ? 'Today' : '$daysLeft days left',
//         style: TextStyle(
//           fontSize: 11,
//           fontWeight: FontWeight.w700,
//           color: isUrgent ? Colors.red.shade700 : Colors.green.shade700,
//         ),
//       ),
//     );
//   }
// }

// // ── Filter chip row ───────────────────────────────────────────────────────────

// class _FilterChipRow extends StatelessWidget {
//   final _CampaignFilter selected;
//   final ValueChanged<_CampaignFilter> onSelected;

//   const _FilterChipRow(
//       {required this.selected, required this.onSelected});

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 56,
//       child: ListView(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
//         children: _CampaignFilter.values.map((f) {
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: FilterChip(
//               label: Text(f.label),
//               selected: selected == f,
//               onSelected: (_) => onSelected(f),
//               visualDensity: VisualDensity.compact,
//               labelStyle: TextStyle(
//                 fontSize: 13,
//                 fontWeight:
//                     selected == f ? FontWeight.w600 : FontWeight.w400,
//               ),
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ── Section header ────────────────────────────────────────────────────────────

// class _SectionHeader extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color? color;

//   const _SectionHeader(
//       {required this.icon, required this.label, this.color});

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
//       child: Row(
//         children: [
//           Icon(icon, size: 18, color: color ?? cs.primary),
//           const SizedBox(width: 6),
//           Text(
//             label,
//             style: Theme.of(context).textTheme.titleSmall?.copyWith(
//                   fontWeight: FontWeight.w700,
//                   color: color ?? cs.onSurface,
//                   letterSpacing: 0.1,
//                 ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Urgent horizontal row ─────────────────────────────────────────────────────

// class _UrgentCampaignRow extends StatelessWidget {
//   final List<CampaignModel> urgent;

//   const _UrgentCampaignRow({required this.urgent});

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     // FIX: clamp card width so button text never wraps on small phones
//     final cardWidth = (screenWidth * 0.72).clamp(220.0, 300.0);

//     return SizedBox(
//       height: 190,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//         separatorBuilder: (_, __) => const SizedBox(width: 12),
//         itemCount: urgent.length,
//         itemBuilder: (context, i) => _UrgentCard(
//           campaign: urgent[i],
//           width: cardWidth,
//         ),
//       ),
//     );
//   }
// }

// class _UrgentCard extends StatelessWidget {
//   final CampaignModel campaign;
//   final double width;

//   const _UrgentCard({required this.campaign, required this.width});

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final pct = (campaign.progressFraction * 100).round();

//     return Semantics(
//       label: '${campaign.title}, $pct% funded, urgent campaign',
//       button: true,
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: () => context.push('/donor/campaign/${campaign.id}'),
//           borderRadius: BorderRadius.circular(16),
//           child: Container(
//             width: width,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(16),
//               color: cs.errorContainer,
//               border: Border.all(
//                 color: Colors.orange.withValues(alpha: 0.25),
//               ),
//             ),
//             padding: const EdgeInsets.all(14),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     const ExcludeSemantics(
//                       child: Icon(Icons.bolt_rounded,
//                           size: 16, color: Colors.orange),
//                     ),
//                     const SizedBox(width: 4),
//                     Expanded(
//                       child: Text(
//                         campaign.title,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style:
//                             Theme.of(context).textTheme.titleSmall?.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 13,
//                                   height: 1.3,
//                                 ),
//                       ),
//                     ),
//                   ],
//                 ),

//                 const Spacer(),

//                 // Progress
//                 Semantics(
//                   label: '$pct% funded',
//                   child: ExcludeSemantics(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         LinearProgressIndicator(
//                           value: campaign.progressFraction,
//                           backgroundColor: cs.outline.withValues(alpha: 0.2),
//                           color: Colors.orange,
//                           borderRadius: BorderRadius.circular(4),
//                           minHeight: 5,
//                         ),
//                         const SizedBox(height: 5),
//                         Text(
//                           '$pct% funded',
//                           style:
//                               Theme.of(context).textTheme.labelSmall?.copyWith(
//                                     fontWeight: FontWeight.w600,
//                                     color: Colors.orange.shade800,
//                                   ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 10),

//                 // CTA
//                 SizedBox(
//                   width: double.infinity,
//                   height: 36,
//                   child: FilledButton(
//                     onPressed: () =>
//                         context.push('/donor/payment/${campaign.id}'),
//                     style: FilledButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       padding: EdgeInsets.zero,
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8)),
//                       textStyle: const TextStyle(
//                           fontSize: 13, fontWeight: FontWeight.bold),
//                     ),
//                     child: const Text('Donate Now'),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Campaign card (grid) ──────────────────────────────────────────────────────

// class _CampaignCard extends StatelessWidget {
//   final CampaignModel campaign;

//   const _CampaignCard({required this.campaign});

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;

//     return Card(
//       clipBehavior: Clip.antiAlias,
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(14),
//         side: BorderSide(
//           color: cs.outlineVariant.withValues(alpha: 0.5),
//         ),
//       ),
//       child: InkWell(
//         onTap: () => context.push('/donor/campaign/${campaign.id}'),
//         child: Column(
//           children: [
//             // ───────────────── IMAGE ─────────────────
//             AspectRatio(
//               aspectRatio: 16 / 9,
//               child: campaign.imageUrl != null
//                   ? CachedNetworkImage(
//                       imageUrl: campaign.imageUrl!,
//                       fit: BoxFit.cover,
//                       placeholder: (_, __) =>
//                           _PlaceholderImage(cs: cs),
//                       errorWidget: (_, __, ___) =>
//                           _PlaceholderImage(cs: cs),
//                     )
//                   : _PlaceholderImage(cs: cs),
//             ),

//             // ───────────────── CONTENT ─────────────────
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // FIXED TITLE HEIGHT
//                     SizedBox(
//                       height: 36,
//                       child: Text(
//                         campaign.title,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style:
//                             Theme.of(context).textTheme.bodyMedium?.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 13,
//                                   height: 1.3,
//                                 ),
//                       ),
//                     ),

//                     const SizedBox(height: 8),

//                     // AMOUNT
//                     Text(
//                       'Rs ${_fmt(campaign.raisedPkr)} raised',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style:
//                           Theme.of(context).textTheme.bodySmall?.copyWith(
//                                 fontWeight: FontWeight.w700,
//                                 color: cs.primary,
//                                 fontSize: 12,
//                               ),
//                     ),

//                     const SizedBox(height: 8),

//                     // PROGRESS
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(4),
//                       child: LinearProgressIndicator(
//                         value: campaign.progressFraction,
//                         minHeight: 5,
//                         backgroundColor:
//                             cs.surfaceContainerHighest,
//                       ),
//                     ),

//                     const SizedBox(height: 6),

//                     // GOAL
//                     Text(
//                       'Goal: Rs ${_fmt(campaign.goalPkr)}',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: cs.onSurfaceVariant,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),

//                     // PUSH BUTTON TO BOTTOM
//                     const Spacer(),

//                     // BUTTON
//                     SizedBox(
//                       width: double.infinity,
//                       height: 42,
//                       child: FilledButton(
//                         onPressed: () => context.push(
//                           '/donor/payment/${campaign.id}',
//                         ),
//                         style: FilledButton.styleFrom(
//                           shape: RoundedRectangleBorder(
//                             borderRadius:
//                                 BorderRadius.circular(10),
//                           ),
//                           textStyle: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                         child: const FittedBox(
//                           fit: BoxFit.scaleDown,
//                           child: Text('Donate Now'),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   String _fmt(double value) {
//     if (value >= 100000) {
//       return '${(value / 100000).toStringAsFixed(1)}L';
//     }

//     if (value >= 1000) {
//       return '${(value / 1000).toStringAsFixed(1)}K';
//     }

//     return value.toStringAsFixed(0);
//   }
// }

// // ── Placeholder image ─────────────────────────────────────────────────────────

// class _PlaceholderImage extends StatelessWidget {
//   final ColorScheme cs;

//   const _PlaceholderImage({required this.cs});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: cs.primaryContainer,
//       child: Center(
//         child: Icon(Icons.campaign_rounded, size: 36, color: cs.primary),
//       ),
//     );
//   }
// }
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reliefnet_app/models/campaign_model.dart';
import 'package:reliefnet_app/models/goods_campaign_model.dart';
import 'package:reliefnet_app/providers/campaign_provider.dart';
import 'package:reliefnet_app/providers/goods_campaign_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';

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

// ── Brand color ───────────────────────────────────────────────────────────────
// Single source of truth — change this one line to retheme the whole screen.
const _kPrimary = Color(0xFF1A56DB); // strong blue

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
        final text = '${c.title} ${c.description ?? ''}'.toLowerCase();
        return text.contains(keyword);
      }).toList();
    }
    switch (_sort) {
      case _SortOption.mostRaised:
        list.sort((a, b) => b.raisedPkr.compareTo(a.raisedPkr));
        break;
      case _SortOption.nearGoal:
        list.sort((a, b) => b.progressFraction.compareTo(a.progressFraction));
        break;
      case _SortOption.none:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── AppBar with explicit dark background so tabs are always visible ──
appBar: AppBar(
  elevation: 0,
  title: const Text(
    'Campaigns',
    style: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 20,
    ),
  ),
        actions: [
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort_rounded, color: Colors.white),
            tooltip: 'Sort campaigns',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => _SortOption.values.map((o) {
              return PopupMenuItem(
                value: o,
                child: Row(
                  children: [
                    Icon(
                      _sort == o
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 16,
                      color: _sort == o ? _kPrimary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(o.label),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        // ── TabBar: white text on dark blue — always readable ──
        bottom: TabBar(
          controller: _tabController,
          // Both tabs always visible — indicator slides between them
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Money'),
            Tab(text: 'Goods (In-Kind)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MoneyCampaignsTab(
            filter: _filter,
            sort: _sort,
            onSortChanged: (v) => setState(() => _sort = v),
            onFilterChanged: (f) => setState(() => _filter = f),
            applyFilterSort: _applyFilterSort,
          ),
          const _GoodsCampaignsTab(),
        ],
      ),
    );
  }
}

// ── Money campaigns tab ───────────────────────────────────────────────────────

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
            subtitle: 'We couldn\'t find any active campaigns.',
            ctaLabel: 'Retry',
            onCta: () => ref.invalidate(campaignsProvider),
          );
        }

        final filtered = applyFilterSort(campaigns);
        final urgent = campaigns.where((c) => c.isUrgent).toList();

        return RefreshIndicator(
          color: _kPrimary,
          onRefresh: () async => ref.invalidate(campaignsProvider),
          child: CustomScrollView(
            slivers: [
              // ── Sticky filter chips with its OWN background ──
          SliverPersistentHeader(
  pinned: true,
  delegate: _StickyHeader(
    selected: filter,
    onSelected: onFilterChanged,
  ),
),
              // ── Urgent section ──
              if (filter == _CampaignFilter.all && urgent.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader(
                    icon: Icons.bolt_rounded,
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
                      SizedBox(height: 8),
                      Divider(indent: 16, endIndent: 16, thickness: 0.8),
                      _SectionHeader(
                        icon: Icons.campaign_rounded,
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
                    icon: Icons.search_off_rounded,
                    title: 'No ${filter.label} campaigns',
                    subtitle: 'Try a different category.',
                    ctaLabel: 'Show all',
                    onCta: () => onFilterChanged(_CampaignFilter.all),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 900
                              ? 4
                              : MediaQuery.of(context).size.width > 600
                                  ? 3
                                  : 2,
                      mainAxisExtent: 310,
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

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }
}

// ── Sticky Header Delegate ────────────────────────────────────────────────────

class _StickyHeader extends SliverPersistentHeaderDelegate {
  final _CampaignFilter selected;
  final ValueChanged<_CampaignFilter> onSelected;

  _StickyHeader({required this.selected, required this.onSelected});

  @override
  double get minExtent => 56.0;
  @override
  double get maxExtent => 56.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _FilterChipRow(
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeader oldDelegate) =>
      oldDelegate.selected != selected;
}
// ── Filter chip row ───────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  final _CampaignFilter selected;
  final ValueChanged<_CampaignFilter> onSelected;

  const _FilterChipRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        children: _CampaignFilter.values.map((f) {
          final isSelected = selected == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label),
              selected: isSelected,
              onSelected: (_) => onSelected(f),
              // ── Explicit colors so chips are always visible ──
              backgroundColor: Colors.grey.shade100,
              selectedColor: _kPrimary.withValues(alpha: 0.12),
              checkmarkColor: _kPrimary,
              side: BorderSide(
                color: isSelected ? _kPrimary : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _kPrimary : Colors.grey.shade700,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? _kPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color ?? cs.onSurface,
                  letterSpacing: 0.1,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.72).clamp(220.0, 300.0);
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: urgent.length,
        itemBuilder: (context, i) =>
            _UrgentCard(campaign: urgent[i], width: cardWidth),
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

    return Semantics(
      label: '${campaign.title}, $pct% funded, urgent campaign',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/donor/campaign/${campaign.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: cs.errorContainer,
              border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ExcludeSemantics(
                      child: Icon(Icons.bolt_rounded,
                          size: 16, color: Colors.orange),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        campaign.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.3,
                            ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Semantics(
                  label: '$pct% funded',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: campaign.progressFraction,
                          backgroundColor:
                              cs.outline.withValues(alpha: 0.2),
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 5,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$pct% funded',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton(
                    onPressed: () =>
                        context.push('/donor/payment/${campaign.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Donate Now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Campaign card (grid) ──────────────────────────────────────────────────────

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/donor/campaign/${campaign.id}'),
        child: Column(
          children: [
            // ── Image ──
            AspectRatio(
              aspectRatio: 16 / 9,
              child: campaign.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: campaign.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _PlaceholderImage(cs: cs),
                      errorWidget: (_, __, ___) =>
                          _PlaceholderImage(cs: cs),
                    )
                  : _PlaceholderImage(cs: cs),
            ),

            // ── Content ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 36,
                      child: Text(
                        campaign.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.3,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs ${_fmt(campaign.raisedPkr)} raised',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _kPrimary,
                                fontSize: 12,
                              ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: campaign.progressFraction,
                        minHeight: 5,
                        color: _kPrimary,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Goal: Rs ${_fmt(campaign.goalPkr)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton(
                        onPressed: () =>
                            context.push('/donor/payment/${campaign.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Donate Now'),
                        ),
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
          color: _kPrimary,
          onRefresh: () async => ref.invalidate(goodsCampaignsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _GoodsCampaignCard(campaign: campaigns[i]),
          ),
        );
      },
    );
  }
}

// ── Goods campaign card ───────────────────────────────────────────────────────

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
      margin: EdgeInsets.zero,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('/donor/goods-campaign/${campaign.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GoodsBadge(),
                  const SizedBox(width: 8),
                  if (campaign.ngoName != null)
                    Expanded(
                      child: Text(
                        campaign.ngoName!,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (daysLeft != null && daysLeft >= 0)
                    _DaysLeftBadge(daysLeft: daysLeft),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                campaign.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      height: 1.3,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${campaign.itemNeeded} · ${campaign.locationText}',
                style:
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Semantics(
                label:
                    '$pct% of goods goal: ${campaign.qtyReceived} of ${campaign.targetQty} ${campaign.unit}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: campaign.progressFraction,
                          minHeight: 7,
                          color: Colors.teal,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${campaign.qtyReceived} / ${campaign.targetQty} ${campaign.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: () =>
                      context.push('/donor/goods-campaign/${campaign.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
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

// ── Reusable badge widgets ────────────────────────────────────────────────────

class _GoodsBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 11, color: Colors.teal),
          SizedBox(width: 4),
          Text(
            'GOODS',
            style: TextStyle(
              color: Colors.teal,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysLeftBadge extends StatelessWidget {
  final int daysLeft;
  const _DaysLeftBadge({required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final isUrgent = daysLeft <= 7;
    final color = isUrgent ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        daysLeft == 0 ? 'Today' : '$daysLeft days left',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isUrgent ? Colors.red.shade700 : Colors.green.shade700,
        ),
      ),
    );
  }
}

// ── Placeholder image ─────────────────────────────────────────────────────────

class _PlaceholderImage extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderImage({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer,
      child: Center(
        child: Icon(Icons.campaign_rounded, size: 36, color: cs.primary),
      ),
    );
  }
}