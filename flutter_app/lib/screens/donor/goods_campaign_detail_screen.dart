import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/models/goods_campaign_model.dart';
import 'package:reliefnet_app/providers/goods_campaign_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';

class GoodsCampaignDetailScreen extends ConsumerWidget {
  final int campaignId;
  const GoodsCampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goodsCampaignDetailProvider(campaignId));
    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Could not load campaign.',
          onRetry: () =>
              ref.invalidate(goodsCampaignDetailProvider(campaignId)),
        ),
      ),
      data: (c) => _Body(campaign: c),
    );
  }
}

class _Body extends StatelessWidget {
  final GoodsCampaign campaign;
  const _Body({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final pct = (campaign.progressFraction * 100).round();
    final deadline = DateTime.tryParse(campaign.deadline);
    final daysLeft = deadline?.difference(DateTime.now()).inDays;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HERO ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  campaign.coverImageUrl != null
                      ? Image.network(campaign.coverImageUrl!,
                          fit: BoxFit.cover)
                      : _HeroPlaceholder(category: campaign.category),

                  // Dark overlay (important UX improvement)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),

                  // Bottom hero content
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            _Badge(text: 'GOODS'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          campaign.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          campaign.ngoName ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // quick progress pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$pct% completed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CONTENT ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── AT A GLANCE ──
                const _SectionTitle('At a glance'),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Item Needed',
                          value: campaign.itemNeeded,
                        ),
                        const Divider(),
                        _InfoRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: campaign.category,
                        ),
                        const Divider(),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: campaign.locationText,
                        ),
                        const Divider(),
                        _InfoRow(
                          icon: Icons.timer_outlined,
                          label: 'Deadline',
                          value: deadline != null
                              ? DateFormat('MMM d, yyyy').format(deadline)
                              : campaign.deadline,
                          trailing: daysLeft != null
                              ? _MiniChip(
                                  text: daysLeft <= 3
                                      ? 'Ending soon'
                                      : '$daysLeft days left',
                                  color:
                                      daysLeft <= 3 ? Colors.red : Colors.green,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── PROGRESS ──
                const _SectionTitle('Progress'),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: campaign.progressFraction,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${campaign.qtyReceived} of ${campaign.targetQty} ${campaign.unit} received',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── STORY ──
                const _SectionTitle('Why this matters'),

                Text(
                  campaign.description,
                  style: const TextStyle(
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),

      // ── FIXED ACTION BAR ──
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: campaign.isActive && !campaign.isExpired
                  ? () => context
                      .push('/donor/goods-campaign/${campaign.id}/donate')
                  : null,
              icon: const Icon(Icons.volunteer_activism),
              label: Text(
                campaign.isExpired ? 'Campaign ended' : 'Donate Items',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.teal,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final String category;
  const _HeroPlaceholder({required this.category});

  IconData get _icon {
    switch (category.toUpperCase()) {
      case 'MEDICINES':
        return Icons.medical_services_outlined;
      case 'CLOTHES':
        return Icons.checkroom_outlined;
      case 'FOOD':
        return Icons.rice_bowl_outlined;
      case 'SHELTER':
        return Icons.home_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.teal.shade300, Colors.teal.shade700],
        ),
      ),
      child: Center(
        child: Icon(_icon, size: 72, color: Colors.white.withValues(alpha: 0.6)),
      ),
    );
  }
}
