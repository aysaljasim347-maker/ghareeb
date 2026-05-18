import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:disasteraid_app/models/inkind_model.dart';
import 'package:disasteraid_app/providers/inkind_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

class MyInKindDonationsScreen extends ConsumerWidget {
  const MyInKindDonationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myInKindDonationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My InKind Donations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myInKindDonationsProvider),
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
          onRetry: () => ref.invalidate(myInKindDonationsProvider),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volunteer_activism_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("You haven't donated any items yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myInKindDonationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: donations.length,
              itemBuilder: (context, i) => _DonorDonationCard(donation: donations[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DonorDonationCard extends StatelessWidget {
  final InKindDonation donation;
  const _DonorDonationCard({required this.donation});

  Color _statusColor() {
    switch (donation.status) {
      case 'AVAILABLE': return Colors.green;
      case 'ACCEPTED':  return Colors.blue;
      case 'CANCELLED': return Colors.grey;
      default:          return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postedAt = DateTime.tryParse(donation.createdAt);
    final pending = donation.pendingCount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/donor/inkind/${donation.id}/requests'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      donation.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor().withAlpha(100)),
                    ),
                    child: Text(
                      donation.status,
                      style: TextStyle(color: _statusColor(), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      donation.addressText,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.inbox_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${donation.requestCount ?? 0} total request${(donation.requestCount ?? 0) != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pending pending',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (postedAt != null)
                    Text(
                      timeago.format(postedAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
              if (donation.isAvailable) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Tap to review requests', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
