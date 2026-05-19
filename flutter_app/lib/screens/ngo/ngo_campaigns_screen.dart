import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/providers/campaign_provider.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/models/campaign_model.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';

class NgoCampaignsScreen extends ConsumerWidget {
  const NgoCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('My Campaigns')),
      body: campaignsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView(
          message: 'Failed to load campaigns.',
          onRetry: () => ref.invalidate(campaignsProvider),
        ),
        data: (all) {
          final myCampaigns =
              all.where((c) => c.createdBy == user?.id).toList();

          if (myCampaigns.isEmpty) {
            return const EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No campaigns found',
              subtitle: 'Create a campaign in the web portal to see it here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myCampaigns.length,
            itemBuilder: (context, index) {
              final campaign = myCampaigns[index];
              return _CampaignReportTile(campaign: campaign);
            },
          );
        },
      ),
    );
  }
}

class _CampaignReportTile extends StatelessWidget {
  final CampaignModel campaign;
  const _CampaignReportTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final pct = (campaign.progressFraction * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/ngo/campaign-report/${campaign.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  _StatusBadge(status: campaign.status),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: campaign.progressFraction,
                backgroundColor: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rs${NumberFormat('#,###').format(campaign.raisedPkr)} raised of Rs${NumberFormat('#,###').format(campaign.goalPkr)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text('$pct%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/ngo/campaign-report/${campaign.id}'),
                    icon: const Icon(Icons.analytics_outlined, size: 18),
                    label: const Text('View Impact Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'ACTIVE') color = Colors.green;
    if (status == 'PAUSED') color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
