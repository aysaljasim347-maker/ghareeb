import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reliefnet_app/models/campaign_model.dart';
import 'package:reliefnet_app/providers/campaign_provider.dart';
import 'package:reliefnet_app/providers/follow_provider.dart';
import 'package:reliefnet_app/widgets/error_view.dart';

class NgoProfileScreen extends ConsumerWidget {
  final int ngoId;

  const NgoProfileScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      body: campaignsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            message: 'Could not load NGO profile.',
            onRetry: () => ref.invalidate(campaignsProvider),
          ),
        ),
        data: (all) {
          final ngoCampaigns = all.where((c) => c.ngoId == ngoId).toList();
          final ngoName = ngoCampaigns.isNotEmpty
              ? ngoCampaigns.first.ngoName ?? 'NGO'
              : 'NGO Profile';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                flexibleSpace: FlexibleSpaceBar(
                  background: _NgoHeroEnhanced(
                    ngoId: ngoId,
                    ngoName: ngoName,
                  ),
                ),
                leading: const BackButton(color: Colors.white),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _NgoImpactStrip(campaigns: ngoCampaigns),
                    const _SectionTitle("Active Campaigns"),
                  ]),
                ),
              ),

              if (ngoCampaigns.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 64,
                              color: Colors.grey.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          const Text(
                            "No active campaigns right now",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Follow this NGO to get notified when new campaigns start.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/donor/campaigns'),
                            child: const Text("Explore campaigns"),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _NgoCampaignTile(campaign: ngoCampaigns[i]),
                      childCount: ngoCampaigns.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _NgoHeroEnhanced extends ConsumerWidget {
  final int ngoId;
  final String ngoName;

  const _NgoHeroEnhanced({
    required this.ngoId,
    required this.ngoName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isFollowed = ref.watch(followedNgosProvider).contains(ngoId);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              ngoName.isNotEmpty ? ngoName[0].toUpperCase() : "N",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            ngoName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Active humanitarian campaigns",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: () => ref
                .read(followedNgosProvider.notifier)
                .toggle(ngoId),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: cs.primary,
            ),
            icon: Icon(isFollowed ? Icons.check : Icons.add),
            label: Text(isFollowed ? "Following" : "Follow NGO"),
          ),
        ],
      ),
    );
  }
}

class _NgoImpactStrip extends StatelessWidget {
  final List<CampaignModel> campaigns;

  const _NgoImpactStrip({required this.campaigns});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final raised = campaigns.fold<double>(0, (s, c) => s + c.raisedPkr);
    final count = campaigns.length;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _MiniImpact(
            icon: Icons.campaign_outlined,
            value: "$count",
            label: "Campaigns",
          ),
          const SizedBox(width: 12),
          _MiniImpact(
            icon: Icons.volunteer_activism_outlined,
            value: "PKR ${(raised / 1000).toStringAsFixed(1)}K",
            label: "Total Raised",
          ),
        ],
      ),
    );
  }
}

class _MiniImpact extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniImpact({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          )
        ],
      ),
    );
  }
}

class _NgoCampaignTile extends StatelessWidget {
  final CampaignModel campaign;

  const _NgoCampaignTile({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (campaign.progressFraction * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/donor/campaign/${campaign.id}'),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (campaign.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "URGENT",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: campaign.progressFraction,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    "$pct% funded",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () =>
                        context.push('/donor/payment/${campaign.id}'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Donate", style: TextStyle(fontSize: 12)),
                  ),
                ],
              )
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
      ),
    );
  }
}
