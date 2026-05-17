import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:disasteraid_app/models/donation_model.dart';
import 'package:disasteraid_app/providers/donation_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

class DonationHistoryScreen extends ConsumerWidget {
  const DonationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(myDonationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Donations')),
      body: donationsAsync.when(
        loading: () => const ShimmerList(count: 5, itemHeight: 80),
        error: (err, _) => ErrorView(
          message: 'Could not load donation history.',
          onRetry: () => ref.invalidate(myDonationsProvider),
        ),
        data: (donations) {
          if (donations.isEmpty) {
            return const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'No donations yet',
              subtitle:
                  'Your donations will appear here once you contribute to a campaign.',
            );
          }
          final summary = DonationSummary.fromDonations(donations);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myDonationsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCard(summary: summary),
                const SizedBox(height: 16),
                ...donations.map((d) => _DonationTile(donation: d)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DonationSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Donation Portfolio',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              '₹${fmt.format(summary.totalPkr)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'total donated (confirmed)',
              style: TextStyle(
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatPill(
                  icon: Icons.volunteer_activism,
                  value: '${summary.count}',
                  label: 'Donations',
                  cs: cs,
                ),
                const SizedBox(width: 12),
                _StatPill(
                  icon: Icons.campaign_outlined,
                  value: '${summary.campaignsCount}',
                  label: 'Campaigns',
                  cs: cs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme cs;

  const _StatPill(
      {required this.icon,
      required this.value,
      required this.label,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.onPrimaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DonationTile extends StatelessWidget {
  final DonationModel donation;

  const _DonationTile({required this.donation});

  String _formattedDate() {
    if (donation.createdAt == null) return '';
    final dt = DateTime.tryParse(donation.createdAt!);
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showReceiptSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Icon ──
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volunteer_activism,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: donation.campaignId != null
                          ? () => context
                              .push('/donor/campaign/${donation.campaignId}')
                          : null,
                      child: Text(
                        donation.campaignTitle ?? 'Donation',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: donation.campaignId != null
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          decoration: donation.campaignId != null
                              ? TextDecoration.underline
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formattedDate(),
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              // ── Amount + Status ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${NumberFormat('#,##0').format(donation.amountPkr)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  StatusChip(
                      status: TaskStatus.fromString(donation.status),
                      fontSize: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReceiptSheet(donation: donation),
    );
  }
}

class _ReceiptSheet extends StatelessWidget {
  final DonationModel donation;

  const _ReceiptSheet({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Receipt',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _ReceiptRow('Campaign', donation.campaignTitle ?? 'N/A'),
            _ReceiptRow('Amount',
                '₹${NumberFormat('#,##0').format(donation.amountPkr)}'),
            _ReceiptRow('Status', donation.status),
            if (donation.createdAt != null)
              _ReceiptRow(
                'Date',
                DateFormat('dd MMM yyyy, hh:mm a')
                    .format(DateTime.parse(donation.createdAt!).toLocal()),
              ),
            if (donation.referenceNumber != null)
              _ReceiptRow('Reference', donation.referenceNumber!),
            if (donation.receiptUrl != null) ...[
              _ReceiptRow('Receipt', donation.receiptUrl!),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(donation.receiptUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Could not open receipt URL.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open Receipt'),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
