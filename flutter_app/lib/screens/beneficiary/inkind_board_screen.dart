import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:disasteraid_app/models/inkind_model.dart';
import 'package:disasteraid_app/providers/inkind_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

class InKindBoardScreen extends ConsumerWidget {
  const InKindBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(inKindBoardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Donations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inKindBoardProvider),
          ),
        ],
      ),
      body: boardAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerCard(),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inKindBoardProvider),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No donations available right now',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inKindBoardProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: donations.length,
              itemBuilder: (context, index) =>
                  _DonationCard(donation: donations[index]),
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
    final postedAt = DateTime.tryParse(donation.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/beneficiary/inkind/${donation.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (donation.photoUrl != null)
              CachedNetworkImage(
                imageUrl: donation.photoUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                color: theme.colorScheme.primaryContainer.withAlpha(80),
                child: Icon(
                  Icons.volunteer_activism,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donation.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (donation.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      donation.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        donation.donorName,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      const Spacer(),
                      if (postedAt != null)
                        Text(
                          timeago.format(postedAt),
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
