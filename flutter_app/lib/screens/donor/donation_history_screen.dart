import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:disasteraid_app/models/donation_model.dart';
import 'package:disasteraid_app/providers/donation_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

enum _DonationFilter {
  all('All'),
  confirmed('Confirmed'),
  pending('Pending'),
  failed('Failed');

  final String label;
  const _DonationFilter(this.label);
}

class DonationHistoryScreen extends ConsumerStatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  ConsumerState<DonationHistoryScreen> createState() =>
      _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends ConsumerState<DonationHistoryScreen> {
  _DonationFilter _filter = _DonationFilter.all;

  List<DonationModel> _applyFilter(List<DonationModel> donations) {
    if (_filter == _DonationFilter.all) return donations;
    return donations.where((d) {
      final status = d.status.toUpperCase();
      switch (_filter) {
        case _DonationFilter.confirmed:
          return status == 'CONFIRMED';
        case _DonationFilter.pending:
          return status == 'PENDING';
        case _DonationFilter.failed:
          return status == 'REJECTED' || status == 'FAILED';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
          final filtered = _applyFilter(donations);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myDonationsProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _ImpactStrip(summary: summary),
                const SizedBox(height: 12),
                _FilterRow(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No ${_filter.label.toLowerCase()} donations.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ...filtered.map((d) => _DonationTimelineTile(donation: d)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImpactStrip extends StatelessWidget {
  final DonationSummary summary;

  const _ImpactStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _MiniStat(
            label: 'Total',
            value: 'Rs ${fmt.format(summary.totalPkr)}',
            color: cs.primary,
          ),
          const SizedBox(width: 12),
          _MiniStat(
            label: 'Donations',
            value: '${summary.count}',
            color: Colors.orange,
          ),
          const SizedBox(width: 12),
          _MiniStat(
            label: 'Campaigns',
            value: '${summary.campaignsCount}',
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      constraints: BoxConstraints(minWidth: width > 400 ? 100 : 80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: width > 400 ? 16 : 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final _DonationFilter selected;
  final ValueChanged<_DonationFilter> onSelected;

  const _FilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _DonationFilter.values.map((f) {
          final isSelected = selected == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f.label),
              selected: isSelected,
              onSelected: (_) => onSelected(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DonationTimelineTile extends StatelessWidget {
  final DonationModel donation;

  const _DonationTimelineTile({required this.donation});

  String _formattedDate() {
    if (donation.createdAt == null) return '';
    final dt = DateTime.tryParse(donation.createdAt!);
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = TaskStatus.fromString(donation.status);

    final Color statusColor;
    switch (status) {
      case TaskStatus.coordinatorVerified:
      case TaskStatus.paid:
        statusColor = Colors.green;
        break;
      case TaskStatus.flagged:
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Timeline Visual ──
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // ── Card ──
            Expanded(
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showReceiptSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                donation.campaignTitle ?? 'Donation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip(status: status, fontSize: 10),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rs ${NumberFormat('#,##0').format(donation.amountPkr)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formattedDate(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _showReceiptSheet(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('View Receipt',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
    final status = TaskStatus.fromString(donation.status);

    final Color statusColor;
    final IconData statusIcon;
    switch (status) {
      case TaskStatus.coordinatorVerified:
      case TaskStatus.paid:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TaskStatus.flagged:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ──
              Icon(statusIcon, size: 64, color: statusColor),
              const SizedBox(height: 12),
              Text(
                'Donation Receipt',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // ── Main Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      donation.campaignTitle ?? 'General Donation',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rs ${NumberFormat('#,##0').format(donation.amountPkr)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StatusChip(status: status, fontSize: 11),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Details ──
              _DetailRow(
                label: 'Date & Time',
                value: donation.createdAt != null
                    ? DateFormat('dd MMM yyyy, hh:mm a')
                        .format(DateTime.parse(donation.createdAt!).toLocal())
                    : 'N/A',
              ),
              _DetailRow(
                label: 'Reference No.',
                value: donation.referenceNumber ?? 'Pending',
              ),
              _DetailRow(
                label: 'Payment Method',
                value: donation.paymentMethod,
              ),

              const SizedBox(height: 32),

              // ── Actions ──
              if (donation.receiptUrl != null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(donation.receiptUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Open Official Receipt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
