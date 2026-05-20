import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:reliefnet_app/models/inkind_model.dart';
import 'package:reliefnet_app/providers/inkind_provider.dart';
import 'package:reliefnet_app/widgets/empty_state.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/screens/shared/chat_screen.dart';

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
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No requests yet',
              subtitle: 'Requests will appear here when people apply for this donation.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(inKindRequestsProvider(donationId)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
  bool expanded = false;
  bool _openingChat = false;

  Future<void> _openChat() async {
    setState(() => _openingChat = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          taskId: 0,
          inkindRequestId: widget.request.id,
        ),
      ));
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

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.hourglass_top;
      case 'ACCEPTED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help_outline;
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
    final r = widget.request;
    final theme = Theme.of(context);
    final color = _statusColor(r.status);
    final isLoading = ref.watch(inKindNotifierProvider).isLoading;

    final createdAt = DateTime.tryParse(r.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.2,
      child: InkWell(
        onTap: () => setState(() => expanded = !expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      r.beneficiaryName.isNotEmpty
                          ? r.beneficiaryName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.beneficiaryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            timeago.format(createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: r.status,
                    color: color,
                    icon: _statusIcon(r.status),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── MESSAGE (collapsed UX) ──
              if (r.message != null && r.message!.isNotEmpty)
                Text(
                  r.message!,
                  maxLines: expanded ? null : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 10),
              // ── EXPANDABLE CONTACT INFO ──
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    _ContactRow(
                      icon: Icons.phone,
                      value: r.phone,
                    ),
                    if (r.email != null)
                      _ContactRow(
                        icon: Icons.email_outlined,
                        value: r.email!,
                      ),
                    if (r.isAccepted && r.donorSharedPhone != null)
                      _ContactRow(
                        icon: Icons.call,
                        value: r.donorSharedPhone!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // ── ACTIONS ──
              if (r.isPending && widget.donationIsAvailable)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : _acceptWithPhonePrompt,
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              if (r.isAccepted) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openingChat ? null : _openChat,
                    icon: _openingChat
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chat_outlined),
                    label: const Text('Chat with Beneficiary'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


