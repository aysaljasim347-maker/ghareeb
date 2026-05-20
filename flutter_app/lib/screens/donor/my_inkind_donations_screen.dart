import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:reliefnet_app/models/inkind_model.dart';
import 'package:reliefnet_app/providers/inkind_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';

class MyInKindDonationsScreen extends ConsumerWidget {
  const MyInKindDonationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myInKindDonationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(myInKindDonationsProvider),
          ),
        ],
      ),
      body: donationsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerCard(),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(myInKindDonationsProvider),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No in-kind donations yet',
              subtitle: 'Post items you want to give away to people in need.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(myInKindDonationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: donations.length,
              itemBuilder: (context, i) =>
                  _DonationCard(donation: donations[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  final InKindDonation donation;
  const _DonationCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final postedAt = DateTime.tryParse(donation.createdAt);
    final timeLabel =
        postedAt != null ? timeago.format(postedAt) : '';

    final pending = donation.pendingCount ?? 0;

    final color = _statusColor(donation.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context
              .push('/donor/inkind/${donation.id}/requests'),
          child: Row(
            children: [
              // ── LEFT STATUS BAR ──
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
                              donation.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          _StatusPill(
                            text: donation.status,
                            color: color,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ── ADDRESS ──
                      Text(
                        donation.addressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── METRICS ROW ──
                      Row(
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${donation.requestCount ?? 0} requests',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(width: 10),

                          if (pending > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange
                                    .withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$pending pending',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ),

                          const Spacer(),

                          Icon(Icons.schedule,
                              size: 12,
                              color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── CTA HINT (only for active items) ──
                      if (donation.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.touch_app_outlined,
                                  size: 14,
                                  color: cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Tap to review requests',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE':
        return Colors.green;
      case 'ACCEPTED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

