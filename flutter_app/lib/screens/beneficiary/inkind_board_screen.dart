import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:reliefnet_app/models/inkind_model.dart';
import 'package:reliefnet_app/providers/inkind_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/shimmer_card.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/screens/shared/chat_screen.dart';

class InKindBoardScreen extends ConsumerStatefulWidget {
  const InKindBoardScreen({super.key});

  @override
  ConsumerState<InKindBoardScreen> createState() => _InKindBoardScreenState();
}

class _InKindBoardScreenState extends ConsumerState<InKindBoardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In-Kind Donations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(inKindBoardProvider);
              ref.invalidate(myInKindRequestsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'My Claims'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AvailableBoard(onRefresh: () => ref.invalidate(inKindBoardProvider)),
          _MyClaimsTab(onRefresh: () => ref.invalidate(myInKindRequestsProvider)),
        ],
      ),
    );
  }
}

class _AvailableBoard extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _AvailableBoard({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(inKindBoardProvider);
    return boardAsync.when(
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
        onRetry: onRefresh,
      ),
      data: (donations) {
        if (donations.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No donations available',
            subtitle: 'Check back later — donors post items regularly.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: donations.length,
            itemBuilder: (context, index) =>
                _DonationCard(donation: donations[index]),
          ),
        );
      },
    );
  }
}

class _MyClaimsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _MyClaimsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myInKindRequestsProvider);
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: e.toString(), onRetry: onRefresh),
      data: (requests) {
        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No claims yet',
            subtitle: 'Request an item from the Available tab to see it here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _MyClaimCard(request: requests[index]),
          ),
        );
      },
    );
  }
}

class _MyClaimCard extends ConsumerStatefulWidget {
  final MyInKindRequest request;
  const _MyClaimCard({required this.request});

  @override
  ConsumerState<_MyClaimCard> createState() => _MyClaimCardState();
}

class _MyClaimCardState extends ConsumerState<_MyClaimCard> {
  bool _openingChat = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ACCEPTED': return Icons.check_circle;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.hourglass_top;
    }
  }

  Future<void> _openChat() async {
    final r = widget.request;
    setState(() => _openingChat = true);
    try {
      // If chat room already known, open directly
      if (r.chatRoomId != null) {
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatScreen(
              taskId: 0,
              taskTitle: r.donationTitle,
              inkindRequestId: r.id,
            ),
          ));
        }
        return;
      }
      final notifier = ref.read(inKindNotifierProvider.notifier);
      await notifier.openInKindChat(r.id);
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(
            taskId: 0,
            taskTitle: r.donationTitle,
            inkindRequestId: r.id,
          ),
        ));
        // Refresh so chat_room_id is populated
        ref.invalidate(myInKindRequestsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final theme = Theme.of(context);
    final color = _statusColor(r.status);
    final postedAt = DateTime.tryParse(r.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item photo
          if (r.donationPhotoUrl != null)
            CachedNetworkImage(
              imageUrl: r.donationPhotoUrl!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 140, color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 140, color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 36, color: Colors.grey),
              ),
            )
          else
            Container(
              height: 80, width: double.infinity,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Icon(Icons.volunteer_activism, size: 40, color: theme.colorScheme.primary),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(r.status), size: 13, color: color),
                          const SizedBox(width: 4),
                          Text(r.status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (postedAt != null)
                      Text(timeago.format(postedAt), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(r.donationTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),

                if (r.donationDescription != null) ...[
                  const SizedBox(height: 4),
                  Text(r.donationDescription!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(r.donorName, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(r.donationAddress, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),

                // Donor shared phone if accepted
                if (r.isAccepted && r.donorSharedPhone != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(r.donorSharedPhone!, style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],

                // Chat button for accepted requests
                if (r.isAccepted) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openingChat ? null : _openChat,
                      icon: _openingChat
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.chat_outlined),
                      label: const Text('Chat with Donor'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.31),
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
