import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:disasteraid_app/core/theme/app_theme.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/features/tasks/presentation/tasks_provider.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/status_chip.dart';

class VolunteerTaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const VolunteerTaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final authUser = ref.watch(authProvider).user;
    final claimState = ref.watch(claimTaskProvider);

    ref.listen<ClaimState>(claimTaskProvider, (_, next) {
      if (next.status == ClaimStatus.success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task claimed! Head to the location.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        ref.invalidate(taskDetailProvider(taskId));
      }
      if (next.status == ClaimStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    });

    return taskAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: 'Could not load task details.',
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
      ),
      data: (task) {
        final isClaimedByMe = task.claimedBy == authUser?.id;
        final isInProgress = task.status == TaskStatus.inProgress;
        final isOpen = task.status == TaskStatus.open;
        final isClaimed = task.status == TaskStatus.claimed ||
            task.status == TaskStatus.assigned;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ── SliverAppBar ──
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black38,
                    child:
                        Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    task.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: _TaskHeroImage(task: task),
                ),
              ),

              // ── Content ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Status + Urgency ──
                    Row(
                      children: [
                        StatusChip(status: task.status),
                        const SizedBox(width: 8),
                        _UrgencyDot(urgency: task.urgency),
                        Text(
                          ' ${task.urgency.value.toLowerCase()} urgency',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Description ──
                    if (task.description != null) ...[
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Details Card ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: Icons.category_outlined,
                              label: 'Category',
                              value: task.category ?? 'General',
                            ),
                            const Divider(height: 1),
                            _DetailRow(
                              icon: Icons.people_outlined,
                              label: 'Family size',
                              value: '${task.familySize} people',
                            ),
                            const Divider(height: 1),
                            _DetailRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Budget',
                              value: 'PKR ${task.budgetPkr.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Location Map ──
                    if (task.latitude != null && task.longitude != null) ...[
                      Text('Location',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 180,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter:
                                  LatLng(task.latitude!, task.longitude!),
                              initialZoom: 13,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.disasteraid.app',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point:
                                        LatLng(task.latitude!, task.longitude!),
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _launchMaps(task.latitude!, task.longitude!),
                          icon: const Icon(Icons.navigation, size: 18),
                          label: Text(task.locationText ?? 'Navigate'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Beneficiary ──
                    if (task.createdByName != null &&
                        (isClaimed || isInProgress)) ...[
                      Text('Beneficiary',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              task.createdByName![0].toUpperCase(),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(task.createdByName!),
                          subtitle: const Text('Awaiting assistance'),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // ── Sticky Bottom Bar ──
          bottomSheet: _ActionBar(
            task: task,
            isOpen: isOpen,
            isClaimed: isClaimed,
            isClaimedByMe: isClaimedByMe,
            isInProgress: isInProgress,
            isLoading: claimState.status == ClaimStatus.loading,
            onClaim: () {
              HapticFeedback.lightImpact();
              ref.read(claimTaskProvider.notifier).claim(taskId);
            },
            onUploadProof: () => context.push('/volunteer/proof/$taskId'),
            onChat: () => context.push('/chat/$taskId'),
          ),
        );
      },
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Sub-widgets ──

class _TaskHeroImage extends StatelessWidget {
  final TaskModel task;
  const _TaskHeroImage({required this.task});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primary.withValues(alpha: 0.7),
            cs.primary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _categoryIcon(task.category),
          size: 72,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  IconData _categoryIcon(String? category) {
    switch (category?.toUpperCase()) {
      case 'FOOD':
        return Icons.lunch_dining;
      case 'MEDICAL':
        return Icons.medical_services;
      case 'SHELTER':
        return Icons.home;
      default:
        return Icons.volunteer_activism;
    }
  }
}

class _UrgencyDot extends StatelessWidget {
  final TaskUrgency urgency;
  const _UrgencyDot({required this.urgency});

  Color get _color {
    switch (urgency) {
      case TaskUrgency.critical:
        return AppTheme.urgencyCritical;
      case TaskUrgency.high:
        return AppTheme.urgencyHigh;
      case TaskUrgency.medium:
        return AppTheme.urgencyMedium;
      default:
        return AppTheme.urgencyLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
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

class _ActionBar extends StatelessWidget {
  final TaskModel task;
  final bool isOpen;
  final bool isClaimed;
  final bool isClaimedByMe;
  final bool isInProgress;
  final bool isLoading;
  final VoidCallback onClaim;
  final VoidCallback onUploadProof;
  final VoidCallback onChat;

  const _ActionBar({
    required this.task,
    required this.isOpen,
    required this.isClaimed,
    required this.isClaimedByMe,
    required this.isInProgress,
    required this.isLoading,
    required this.onClaim,
    required this.onUploadProof,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOpen)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onClaim,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.handshake),
                label: Text(isLoading ? 'Claiming...' : 'Claim This Task'),
              ),
            ),
          if (isClaimed && isClaimedByMe)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Start Task'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {},
                  child: const Text('Unclaim'),
                ),
              ],
            ),
          if (isInProgress && isClaimedByMe)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: onUploadProof,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Proof'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
