import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:disasteraid_app/models/inkind_model.dart';
import 'package:disasteraid_app/providers/inkind_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';

class InKindRequestsScreen extends ConsumerWidget {
  final int donationId;
  const InKindRequestsScreen({super.key, required this.donationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationAsync = ref.watch(inKindDonationProvider(donationId));
    final requestsAsync = ref.watch(inKindRequestsProvider(donationId));

    return Scaffold(
      appBar: AppBar(
        title: donationAsync.maybeWhen(
          data: (d) => Text(d.title, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('Requests'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(inKindRequestsProvider(donationId));
              ref.invalidate(inKindDonationProvider(donationId));
            },
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(inKindRequestsProvider(donationId)),
        ),
        data: (requests) {
          final donation = donationAsync.valueOrNull;

          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No requests yet.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inKindRequestsProvider(donationId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, i) => _RequestCard(
                request: requests[i],
                donationIsAvailable: donation?.isAvailable ?? false,
                donationId: donationId,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final InKindRequest request;
  final bool donationIsAvailable;
  final int donationId;

  const _RequestCard({
    required this.request,
    required this.donationIsAvailable,
    required this.donationId,
  });

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':  return Colors.orange;
      case 'ACCEPTED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default:         return Colors.grey;
    }
  }

  Future<void> _acceptWithPhonePrompt() async {
    final phoneCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Do you want to share your phone number with the beneficiary?'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Your phone number (optional)',
                hintText: 'Leave blank to skip',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(inKindNotifierProvider.notifier);
    try {
      await notifier.acceptRequest(
        widget.request.id,
        donorSharedPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      );
      if (mounted) {
        ref.invalidate(inKindRequestsProvider(widget.donationId));
        ref.invalidate(inKindDonationProvider(widget.donationId));
        ref.invalidate(myInKindDonationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted. All other requests have been rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Request'),
        content: Text('Decline request from ${widget.request.beneficiaryName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(inKindNotifierProvider.notifier).rejectRequest(widget.request.id);
      if (mounted) {
        ref.invalidate(inKindRequestsProvider(widget.donationId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final theme = Theme.of(context);
    final createdAt = DateTime.tryParse(request.createdAt);
    final isLoading = ref.watch(inKindNotifierProvider).isLoading;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    request.beneficiaryName.isNotEmpty ? request.beneficiaryName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.beneficiaryName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (createdAt != null)
                        Text(timeago.format(createdAt), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(request.status).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(request.status).withAlpha(100)),
                  ),
                  child: Text(
                    request.status,
                    style: TextStyle(
                      color: _statusColor(request.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (request.message != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(request.message!, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 10),
            ],

            // Contact details (always visible)
            _ContactRow(icon: Icons.phone, label: 'Phone', value: request.phone),
            if (request.email != null) ...[
              const SizedBox(height: 4),
              _ContactRow(icon: Icons.email_outlined, label: 'Email', value: request.email!),
            ],

            if (request.isAccepted && request.donorSharedPhone != null) ...[
              const SizedBox(height: 4),
              _ContactRow(
                icon: Icons.phone_forwarded_outlined,
                label: 'Your shared phone',
                value: request.donorSharedPhone!,
              ),
            ],

            if (request.isPending && widget.donationIsAvailable) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : _reject,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: isLoading ? null : _acceptWithPhonePrompt,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ],
    );
  }
}
