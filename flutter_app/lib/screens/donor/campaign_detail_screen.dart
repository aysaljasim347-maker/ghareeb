import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/providers/campaign_donations_provider.dart';
import 'package:disasteraid_app/providers/campaign_report_provider.dart';
import 'package:disasteraid_app/providers/follow_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';

class CampaignDetailScreen extends ConsumerWidget {
  final int campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(campaignDetailProvider(campaignId));

    return Scaffold(
      body: campaignAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            message: 'Could not load campaign details.',
            onRetry: () => ref.invalidate(campaignDetailProvider(campaignId)),
          ),
        ),
        data: (campaign) => _CampaignDetailBody(campaign: campaign),
      ),
    );
  }
}

class _CampaignDetailBody extends ConsumerWidget {
  final CampaignModel campaign;

  const _CampaignDetailBody({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final donationsAsync = ref.watch(campaignDonationsProvider(campaign.id));
    final pct = (campaign.progressFraction * 100).round();
    final fmt = NumberFormat('#,##0');

    return CustomScrollView(
      slivers: [
        // ── Hero image + back button ──
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: campaign.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: campaign.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _HeroPlaceholder(cs: cs),
                  )
                : _HeroPlaceholder(cs: cs),
          ),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final isFollowed =
                    ref.watch(followedCampaignsProvider).contains(campaign.id);
                return IconButton(
                  icon: Icon(isFollowed
                      ? Icons.bookmark
                      : Icons.bookmark_add_outlined),
                  tooltip: isFollowed ? 'Unfollow' : 'Follow',
                  onPressed: () => ref
                      .read(followedCampaignsProvider.notifier)
                      .toggle(campaign.id),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: () => context.push('/donor/payment/${campaign.id}'),
                icon: const Icon(Icons.volunteer_activism, size: 18),
                label: const Text('Donate'),
              ),
            ),
          ],
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Title + status ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: TaskStatus.fromString(campaign.status)),
                ],
              ),
              const SizedBox(height: 8),

              // ── NGO name (tappable → NGO profile) ──
              if (campaign.ngoName != null && campaign.ngoId != null)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => context.push('/donor/ngo/${campaign.ngoId}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.business, size: 15, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          campaign.ngoName!,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // ── Progress card ──
              _ProgressCard(campaign: campaign, pct: pct, fmt: fmt),

              const SizedBox(height: 16),

              // ── Transparency card ──
              Consumer(
                builder: (context, ref, _) {
                  final reportAsync =
                      ref.watch(campaignReportProvider(campaign.id));
                  return reportAsync.when(
                    data: (report) => _TransparencyCard(
                      campaign: campaign,
                      fmt: fmt,
                      score: report.transparencyScore,
                      completionPercent: report.completionPercent,
                    ),
                    loading: () => _TransparencyCard(
                        campaign: campaign, fmt: fmt, score: 50),
                    error: (_, __) => _TransparencyCard(
                        campaign: campaign, fmt: fmt, score: 50),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Description ──
              if (campaign.description != null &&
                  campaign.description!.isNotEmpty) ...[
                Text(
                  'About this campaign',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  campaign.description!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 24),
              ],

              // ── Recent donations ──
              Text(
                'Recent Donations',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              donationsAsync.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
                error: (_, __) => Text(
                  'Could not load donations.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                data: (donations) {
                  if (donations.isEmpty) {
                    return Text(
                      'Be the first to donate to this campaign.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    );
                  }
                  final recent = donations.take(5).toList();
                  return Column(
                    children: recent
                        .map((d) => _DonationRow(
                              donorName: d.donorName ?? 'Anonymous',
                              amountPkr: d.amountPkr,
                              fmt: fmt,
                              status: d.status,
                            ))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Sticky donate CTA ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/donor/payment/${campaign.id}'),
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Donate to This Campaign'),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final CampaignModel campaign;
  final int pct;
  final NumberFormat fmt;

  const _ProgressCard(
      {required this.campaign, required this.pct, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Raised',
                          style: TextStyle(
                              color: cs.onPrimaryContainer, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${fmt.format(campaign.raisedPkr)}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimaryContainer,
                                ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Goal',
                        style: TextStyle(
                            color: cs.onPrimaryContainer, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '₹${fmt.format(campaign.goalPkr)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: campaign.progressFraction,
                minHeight: 10,
                backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
                color: campaign.isUrgent ? Colors.orange : cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$pct% funded',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (campaign.isUrgent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 12, color: Colors.orange),
                        SizedBox(width: 2),
                        Text('Urgent',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transparency card ─────────────────────────────────────────────────────────

class _TransparencyCard extends StatelessWidget {
  final CampaignModel campaign;
  final NumberFormat fmt;
  final int score;
  final double? completionPercent;

  const _TransparencyCard({
    required this.campaign,
    required this.fmt,
    required this.score,
    this.completionPercent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final utilizationPct = (campaign.utilizationFraction * 100).round();

    final scoreColor = score >= 80
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : cs.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Transparency',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score / 100',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _TransparencyRow(
              label: 'Funds raised',
              value: '₹${fmt.format(campaign.raisedPkr)}',
              cs: cs,
            ),
            _TransparencyRow(
              label: 'Funds deployed',
              value: campaign.spentPkr > 0
                  ? '₹${fmt.format(campaign.spentPkr)}'
                  : 'Not yet disbursed',
              cs: cs,
            ),
            if (completionPercent != null)
              _TransparencyRow(
                label: 'Tasks completed',
                value: '${(completionPercent! * 100).toInt()}%',
                cs: cs,
              ),
            if (campaign.spentPkr > 0 && campaign.raisedPkr > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Utilization — $utilizationPct% of raised funds deployed',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: campaign.utilizationFraction,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: Colors.teal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransparencyRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _TransparencyRow(
      {required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Donation row ──────────────────────────────────────────────────────────────

class _DonationRow extends StatelessWidget {
  final String donorName;
  final double amountPkr;
  final NumberFormat fmt;
  final String status;

  const _DonationRow({
    required this.donorName,
    required this.amountPkr,
    required this.fmt,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            child: Text(
              donorName.isNotEmpty ? donorName[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(donorName,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          StatusChip(status: TaskStatus.fromString(status), fontSize: 10),
          const SizedBox(width: 8),
          Text(
            '₹${fmt.format(amountPkr)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── Hero placeholder ──────────────────────────────────────────────────────────

class _HeroPlaceholder extends StatelessWidget {
  final ColorScheme cs;

  const _HeroPlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer,
      child: Center(
        child: Icon(Icons.campaign, size: 60, color: cs.primary),
      ),
    );
  }
}
