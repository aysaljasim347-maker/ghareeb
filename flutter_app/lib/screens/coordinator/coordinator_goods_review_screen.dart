import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/models/goods_donation_model.dart';
import 'package:reliefnet_app/providers/goods_donation_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';

class CoordinatorGoodsReviewScreen extends ConsumerStatefulWidget {
  final int donationId;
  const CoordinatorGoodsReviewScreen({super.key, required this.donationId});

  @override
  ConsumerState<CoordinatorGoodsReviewScreen> createState() =>
      _CoordinatorGoodsReviewScreenState();
}

class _CoordinatorGoodsReviewScreenState
    extends ConsumerState<CoordinatorGoodsReviewScreen> {
  final _rejectReasonCtrl = TextEditingController();

  @override
  void dispose() {
    _rejectReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _approve(int donationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Delivery'),
        content: const Text(
          'Confirm that this item was collected and delivered. '
          'The quantity will be added to the campaign progress.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref
        .read(goodsDonationMutationProvider.notifier)
        .approveDelivery(donationId);

    final state = ref.read(goodsDonationMutationProvider);
    if (!mounted) return;
    if (state.status == GoodsDonationMutationStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery approved successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
      ref.invalidate(goodsDeliveredReviewProvider);
      ref.read(goodsDonationMutationProvider.notifier).reset();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject(int donationId) async {
    _rejectReasonCtrl.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _RejectDialog(controller: _rejectReasonCtrl),
    );

    if (reason == null || reason.trim().isEmpty || !mounted) return;

    await ref
        .read(goodsDonationMutationProvider.notifier)
        .rejectDelivery(donationId, reason: reason.trim());

    final state = ref.read(goodsDonationMutationProvider);
    if (!mounted) return;
    if (state.status == GoodsDonationMutationStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery rejected.'),
          backgroundColor: Colors.red,
        ),
      );
      context.pop();
      ref.invalidate(goodsDeliveredReviewProvider);
      ref.read(goodsDonationMutationProvider.notifier).reset();
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(goodsDonationDetailProvider(widget.donationId));
    final mutation = ref.watch(goodsDonationMutationProvider);
    final isLoading = mutation.status == GoodsDonationMutationStatus.loading;

    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Review Delivery')),
        body: ErrorView(
          message: 'Could not load donation details.',
          onRetry: () => ref
              .invalidate(goodsDonationDetailProvider(widget.donationId)),
        ),
      ),
      data: (d) => _Body(
        donation: d,
        isLoading: isLoading,
        onApprove: () => _approve(d.id),
        onReject: () => _reject(d.id),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final GoodsDonation donation;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _Body({
    required this.donation,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Delivery')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Donation info ──
                  Text('Donation Details',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _Row(
                              icon: Icons.inventory_outlined,
                              label: 'Item',
                              value: donation.itemName),
                          const Divider(height: 1),
                          _Row(
                              icon: Icons.person_outline,
                              label: 'Donor',
                              value: donation.donorName),
                          const Divider(height: 1),
                          _Row(
                              icon: Icons.format_list_numbered,
                              label: 'Quantity',
                              value:
                                  '${_qtyLabel(donation.quantity)} ${donation.unit}'),
                          const Divider(height: 1),
                          _Row(
                              icon: Icons.campaign_outlined,
                              label: 'Campaign',
                              value: donation.campaignTitle),
                          const Divider(height: 1),
                          _Row(
                              icon: Icons.location_on_outlined,
                              label: 'Pickup',
                              value: donation.pickupAddress),
                          const Divider(height: 1),
                          _Row(
                              icon: Icons.directions_bike_outlined,
                              label: 'Volunteer',
                              value:
                                  donation.volunteerName ?? 'Unknown'),
                          if (donation.deliveredAt != null) ...[
                            const Divider(height: 1),
                            _Row(
                                icon: Icons.schedule_outlined,
                                label: 'Collected',
                                value: _fmt(donation.deliveredAt!)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Proof photo comparison ──
                  Text('Proof Photos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PhotoPanel(
                          label: 'Donor Photo',
                          url: donation.photoUrl,
                          accentColor: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PhotoPanel(
                          label: 'Proof Photo',
                          url: donation.proofPhotoUrl,
                          accentColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Notes from donor ──
                  Text('Item Description',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(donation.description,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 24),

                  // ── Decision guidance ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates_outlined,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Compare both photos and verify the items match '
                            'the description and quantity stated. '
                            'Approve if the items are as described; reject if there is a mismatch.',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action buttons ──
          Container(
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
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onApprove,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green),
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        isLoading ? 'Processing…' : 'Approve',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _qtyLabel(double qty) =>
      qty == qty.toInt() ? qty.toInt().toString() : qty.toString();

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(dt.toLocal())
        : iso;
  }
}

// ── Photo comparison panel ────────────────────────────────────────────────────

class _PhotoPanel extends StatelessWidget {
  final String label;
  final String? url;
  final Color accentColor;

  const _PhotoPanel({
    required this.label,
    required this.url,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: accentColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: url != null
              ? Image.network(
                  url!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 160,
                  width: double.infinity,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          size: 32, color: cs.onSurfaceVariant),
                      const SizedBox(height: 4),
                      Text('No photo',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Reject dialog ─────────────────────────────────────────────────────────────

class _RejectDialog extends StatefulWidget {
  final TextEditingController controller;
  const _RejectDialog({required this.controller});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Delivery'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please provide a reason for rejection so the donor and volunteer can be informed.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'e.g. Items do not match description',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: widget.controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, widget.controller.text),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

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
