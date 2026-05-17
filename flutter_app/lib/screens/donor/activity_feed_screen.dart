import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/models/donation_model.dart';
import 'package:disasteraid_app/providers/donation_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myDonationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Feed')),
      body: donationsAsync.when(
        loading: () => const ShimmerList(count: 6, itemHeight: 72),
        error: (err, _) => ErrorView(
          message: 'Could not load activity.',
          onRetry: () => ref.invalidate(myDonationsProvider),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const EmptyState(
              icon: Icons.feed_outlined,
              title: 'No activity yet',
              subtitle:
                  'Your donation activity will appear here once you contribute to a campaign.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myDonationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: donations.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, i) =>
                  _ActivityItem(donation: donations[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final DonationModel donation;

  const _ActivityItem({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');

    String? dateLabel;
    if (donation.createdAt != null) {
      final dt = DateTime.tryParse(donation.createdAt!);
      if (dt != null) {
        dateLabel =
            DateFormat('dd MMM yyyy · hh:mm a').format(dt.toLocal());
      }
    }

    final Color statusColor;
    final IconData statusIcon;
    switch (donation.status) {
      case 'CONFIRMED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        statusColor = cs.error;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline dot + line ──
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.volunteer_activism,
                    size: 20, color: cs.primary),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Content ──
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                const TextSpan(
                                  text: 'Donated ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text:
                                      '₹${fmt.format(donation.amountPkr)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          donation.status,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    if (donation.campaignTitle != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: donation.campaignId != null
                            ? () => context.push(
                                '/donor/campaign/${donation.campaignId}')
                            : null,
                        child: Text(
                          donation.campaignTitle!,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    if (dateLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        dateLabel,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
