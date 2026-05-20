import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/models/donation_model.dart';
import 'package:reliefnet_app/providers/donation_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';

class ActivityFeedScreen extends ConsumerWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myDonationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
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
              padding: const EdgeInsets.only(top: 8, bottom: 24),
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

    final amount = 'Rs${fmt.format(donation.amountPkr)}';

    String? dateLabel;
    if (donation.createdAt != null) {
      final dt = DateTime.tryParse(donation.createdAt!);
      if (dt != null) {
        dateLabel =
            DateFormat('dd MMM yyyy · hh:mm a').format(dt.toLocal());
      }
    }

    final Color statusColor;
    final String statusText;
    switch (donation.status) {
      case 'CONFIRMED':
        statusColor = Colors.green;
        statusText = 'Confirmed';
        break;
      case 'REJECTED':
        statusColor = cs.error;
        statusText = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Pending';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔥 Top Row (Amount + Status)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amount,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              /// 📌 Campaign Title
              if (donation.campaignTitle != null)
                GestureDetector(
                  onTap: donation.campaignId != null
                      ? () => context.push(
                          '/donor/campaign/${donation.campaignId}')
                      : null,
                  child: Text(
                    donation.campaignTitle!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cs.primary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 6),

              /// 🕒 Date
              if (dateLabel != null)
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}