import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reliefnet_app/models/goods_donation_model.dart';
import 'package:reliefnet_app/providers/goods_donation_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';

class GoodsDonationDetailScreen extends ConsumerWidget {
  final int donationId;
  const GoodsDonationDetailScreen({super.key, required this.donationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goodsDonationDetailProvider(donationId));
    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Could not load donation details.',
          onRetry: () =>
              ref.invalidate(goodsDonationDetailProvider(donationId)),
        ),
      ),
      data: (d) => _Body(donation: d),
    );
  }
}

class _Body extends StatelessWidget {
  final GoodsDonation donation;
  const _Body({required this.donation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(donation.itemName),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ── HERO STATUS (NEW UX CORE) ──
          _HeroStatusCard(donation: donation),

          const SizedBox(height: 16),

          // ── QUICK SNAPSHOT ──
          const _SectionTitle('Overview'),
          _SnapshotCard(donation: donation),

          const SizedBox(height: 16),

          // ── TIMELINE (SIMPLIFIED FIRST VIEW) ──
          const _SectionTitle('Progress'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _Timeline(donation: donation),
            ),
          ),

          const SizedBox(height: 16),

          // ── DETAILS (LESS VISUAL NOISE) ──
          const _SectionTitle('Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                _DetailRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Item',
                  value: donation.itemName,
                ),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: donation.category,
                ),
                _DetailRow(
                  icon: Icons.format_list_numbered,
                  label: 'Quantity',
                  value: '${_qtyLabel(donation.quantity)} ${donation.unit}',
                ),
                _DetailRow(
                  icon: Icons.campaign_outlined,
                  label: 'Campaign',
                  value: donation.campaignTitle,
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Pickup',
                  value: donation.pickupAddress,
                ),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: donation.contactNumber,
                ),
                if (donation.volunteerName != null)
                  _DetailRow(
                    icon: Icons.directions_bike_outlined,
                    label: 'Volunteer',
                    value: donation.volunteerName!,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── PROOF PHOTO (ONLY IF EXISTS) ──
          if (donation.proofPhotoUrl != null)
            _PhotoCard(url: donation.proofPhotoUrl!),
        ],
      ),
    );
  }

  String _qtyLabel(double qty) =>
      qty == qty.toInt() ? qty.toInt().toString() : qty.toString();
}

// ── NEW CORE WIDGETS ─────────────────────────────────────────────────────────

class _HeroStatusCard extends StatelessWidget {
  final GoodsDonation donation;

  const _HeroStatusCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final config = _config();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: config.fg.withValues(alpha: 0.15),
            child: Icon(config.icon, color: config.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: config.fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: config.fg.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _Status _config() {
    if (donation.isApproved) {
      return _Status(
        Colors.green.withValues(alpha: 0.12),
        Colors.green.shade700,
        Icons.check_circle,
        'Donation Completed',
        'Your item was successfully received and approved',
      );
    }

    if (donation.isDelivered) {
      return _Status(
        Colors.blue.withValues(alpha: 0.12),
        Colors.blue.shade700,
        Icons.local_shipping,
        'Item Collected',
        'Volunteer has picked up your donation',
      );
    }

    if (donation.isAssigned) {
      return _Status(
        Colors.orange.withValues(alpha: 0.12),
        Colors.orange.shade700,
        Icons.directions_bike,
        'Volunteer Assigned',
        'A volunteer is on the way to collect your item',
      );
    }

    if (donation.isRejected) {
      return _Status(
        Colors.red.withValues(alpha: 0.12),
        Colors.red.shade700,
        Icons.cancel,
        'Donation Rejected',
        donation.rejectionReason ?? 'Not accepted',
      );
    }

    return _Status(
      Colors.grey.withValues(alpha: 0.12),
      Colors.grey.shade700,
      Icons.schedule,
      'Waiting for Pickup',
      'Your donation is in queue for assignment',
    );
  }
}

class _Status {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String title;
  final String subtitle;

  _Status(this.bg, this.fg, this.icon, this.title, this.subtitle);
}

class _SnapshotCard extends StatelessWidget {
  final GoodsDonation donation;

  const _SnapshotCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MiniStat(Icons.inventory_2_outlined, donation.itemName),
            _MiniStat(Icons.category_outlined, donation.category),
            _MiniStat(Icons.confirmation_number_outlined,
                '${donation.quantity} ${donation.unit}'),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStat(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(height: 6),
        SizedBox(
          width: 80,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String url;
  const _PhotoCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(url, height: 200, width: double.infinity, fit: BoxFit.cover),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline ─────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final GoodsDonation donation;
  const _Timeline({required this.donation});

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(donation);
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _TimelineStep(
            step: steps[i],
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  List<_Step> _buildSteps(GoodsDonation d) {
    final steps = <_Step>[];

    steps.add(_Step(
      label: 'Submitted',
      date: d.submittedAt,
      done: true,
      icon: Icons.send_outlined,
    ));

    if (d.isAssigned || d.isDelivered || d.isApproved || d.isRejected) {
      steps.add(_Step(
        label: 'Volunteer Assigned',
        date: null,
        done: true,
        icon: Icons.directions_bike_outlined,
        subtitle: d.volunteerName,
      ));
    } else {
      steps.add(const _Step(
        label: 'Waiting for Volunteer',
        date: null,
        done: false,
        icon: Icons.directions_bike_outlined,
      ));
    }

    if (d.isDelivered || d.isApproved || d.isRejected) {
      steps.add(_Step(
        label: 'Picked Up',
        date: d.deliveredAt,
        done: true,
        icon: Icons.local_shipping_outlined,
      ));
    } else {
      steps.add(const _Step(
        label: 'Pickup',
        date: null,
        done: false,
        icon: Icons.local_shipping_outlined,
      ));
    }

    if (d.isApproved) {
      steps.add(_Step(
        label: 'Approved',
        date: d.approvedAt,
        done: true,
        icon: Icons.check_circle_outline,
        color: Colors.green,
      ));
    } else if (d.isRejected) {
      steps.add(_Step(
        label: 'Rejected',
        date: d.rejectedAt,
        done: true,
        icon: Icons.cancel_outlined,
        color: Colors.red,
      ));
    } else {
      steps.add(const _Step(
        label: 'Coordinator Approval',
        date: null,
        done: false,
        icon: Icons.verified_outlined,
      ));
    }

    return steps;
  }
}

class _Step {
  final String label;
  final String? date;
  final bool done;
  final IconData icon;
  final String? subtitle;
  final Color? color;

  const _Step({
    required this.label,
    required this.date,
    required this.done,
    required this.icon,
    this.subtitle,
    this.color,
  });
}

class _TimelineStep extends StatelessWidget {
  final _Step step;
  final bool isLast;
  const _TimelineStep({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor =
        step.color ?? (step.done ? Colors.teal : cs.onSurfaceVariant);
    final bg = step.done
        ? activeColor.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.4);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left rail ──
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Icon(step.icon,
                      size: 18,
                      color:
                          step.done ? activeColor : cs.onSurfaceVariant),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: step.done
                          ? Colors.teal.withValues(alpha: 0.3)
                          : cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Content ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: step.done ? activeColor : cs.onSurfaceVariant,
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                  if (step.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmt(step.date!),
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(dt.toLocal())
        : iso;
  }
}
