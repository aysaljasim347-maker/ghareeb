import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:reliefnet_app/models/goods_donation_model.dart';
import 'package:reliefnet_app/providers/goods_donation_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';

class MyGoodsDonationsScreen extends ConsumerWidget {
  const MyGoodsDonationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myGoodsDonationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        centerTitle: false,
      ),
      body: async.when(
        loading: () => const ShimmerList(count: 4, itemHeight: 110),
        error: (e, _) => ErrorView(
          message: 'Could not load your donations.',
          onRetry: () => ref.invalidate(myGoodsDonationsProvider),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No donations yet',
              subtitle: 'Your donated items will appear here once submitted.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(myGoodsDonationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: donations.length,
              itemBuilder: (_, i) =>
                  _DonationCard(donation: donations[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  final GoodsDonation donation;
  const _DonationCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(donation.submittedAt);

    final dateLabel = date != null
        ? DateFormat('MMM d, yyyy').format(date.toLocal())
        : donation.submittedAt;

    final (color, bg) = _statusColors(donation.displayStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context
              .push('/donor/goods-donation/${donation.id}'),
          child: Row(
            children: [
              // ── LEFT ACCENT ──
              Container(
                width: 6,
                height: 110,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── TOP ROW ──
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              donation.itemName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusPill(
                            text: donation.displayStatus,
                            color: color,
                            bg: bg,
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // ── SECONDARY INFO ──
                      Text(
                        '${_qtyLabel(donation.quantity)} ${donation.unit} • ${donation.campaignTitle}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // ── META ROW ──
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(width: 10),

                          if (donation.volunteerName != null) ...[
                            Icon(Icons.person,
                                size: 12, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                donation.volunteerName!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),
              const Icon(Icons.chevron_right),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _qtyLabel(double qty) =>
      qty == qty.toInt() ? qty.toInt().toString() : qty.toString();

  (Color, Color) _statusColors(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return (Colors.orange, Colors.orange.withValues(alpha: 0.12));
      case 'ASSIGNED':
        return (Colors.blue, Colors.blue.withValues(alpha: 0.12));
      case 'DELIVERED':
        return (Colors.purple, Colors.purple.withValues(alpha: 0.12));
      case 'APPROVED':
        return (Colors.green, Colors.green.withValues(alpha: 0.12));
      case 'REJECTED':
        return (Colors.red, Colors.red.withValues(alpha: 0.12));
      default:
        return (Colors.grey, Colors.grey.withValues(alpha: 0.12));
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _StatusPill({
    required this.text,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
