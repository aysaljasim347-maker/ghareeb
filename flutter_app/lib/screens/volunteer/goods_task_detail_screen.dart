import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/models/goods_donation_model.dart';
import 'package:reliefnet_app/providers/goods_donation_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';

class GoodsTaskDetailScreen extends ConsumerWidget {
  final int donationId;
  const GoodsTaskDetailScreen({super.key, required this.donationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goodsDonationDetailProvider(donationId));
    final mutation = ref.watch(goodsDonationMutationProvider);

    ref.listen<GoodsDonationMutationState>(goodsDonationMutationProvider,
        (_, next) {
      if (next.status == GoodsDonationMutationStatus.success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task claimed! Head to the pickup address.'),
            backgroundColor: Colors.teal,
          ),
        );
        ref.invalidate(goodsDonationDetailProvider(donationId));
        ref.invalidate(goodsPickupTasksProvider);
        ref.read(goodsDonationMutationProvider.notifier).reset();
      }
      if (next.status == GoodsDonationMutationStatus.error &&
          next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Could not load task details.',
          onRetry: () =>
              ref.invalidate(goodsDonationDetailProvider(donationId)),
        ),
      ),
      data: (d) => _Body(
        donation: d,
        isClaiming: mutation.status == GoodsDonationMutationStatus.loading,
        onClaim: () => ref
            .read(goodsDonationMutationProvider.notifier)
            .claimPickupTask(d.id),
        onMarkDelivered: () => context
            .push('/volunteer/goods-proof/${d.id}'),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final GoodsDonation donation;
  final bool isClaiming;
  final VoidCallback onClaim;
  final VoidCallback onMarkDelivered;

  const _Body({
    required this.donation,
    required this.isClaiming,
    required this.onClaim,
    required this.onMarkDelivered,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClaimedByMe = donation.isAssigned;
    final isPending = donation.isPending;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.teal.shade300, Colors.teal.shade700],
                  ),
                ),
                child: Center(
                  child: Icon(
                    _categoryIcon(donation.category),
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Badges ──
                Row(
                  children: [
                    _Badge(
                      label: donation.category.toUpperCase(),
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      label: donation.status,
                      color: _statusColor(donation.status),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Title ──
                Text(
                  '${donation.itemName} — ${donation.campaignTitle}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),

                // ── Details card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.person_outline,
                          label: 'Donor',
                          value: donation.donorName,
                        ),
                        const Divider(height: 1),
                        _Row(
                          icon: Icons.format_list_numbered,
                          label: 'Quantity',
                          value:
                              '${_qtyLabel(donation.quantity)} ${donation.unit}',
                        ),
                        const Divider(height: 1),
                        _Row(
                          icon: Icons.notes_outlined,
                          label: 'Description',
                          value: donation.description,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Pickup location card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pickup Location',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.teal, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(donation.pickupAddress,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Open in Maps'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Contact card ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contact',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                color: Colors.teal, size: 20),
                            const SizedBox(width: 8),
                            Text(donation.contactNumber,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Call'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Submitted date ──
                Text(
                  'Submitted ${_fmt(donation.submittedAt)}',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ]),
            ),
          ),
        ],
      ),

      // ── Bottom action ──
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: isPending
              ? FilledButton.icon(
                  onPressed: isClaiming ? null : onClaim,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal),
                  icon: isClaiming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isClaiming ? 'Claiming…' : 'Claim Pickup Task',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                )
              : isClaimedByMe
                  ? FilledButton.icon(
                      onPressed: onMarkDelivered,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text(
                        'Mark as Picked Up',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    )
                  : FilledButton(
                      onPressed: null,
                      child: Text(
                        donation.isDelivered
                            ? 'Already Delivered'
                            : 'Task Unavailable',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
        ),
      ),
    );
  }

  String _qtyLabel(double qty) =>
      qty == qty.toInt() ? qty.toInt().toString() : qty.toString();

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt != null
        ? DateFormat('MMM d, yyyy').format(dt.toLocal())
        : iso;
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toUpperCase()) {
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

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'ASSIGNED':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.purple;
      case 'APPROVED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
