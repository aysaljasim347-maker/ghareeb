import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:reliefnet_app/features/tasks/presentation/tasks_provider.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/widgets/error_view.dart';
import 'package:reliefnet_app/widgets/status_chip.dart';

class VolunteerTaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const VolunteerTaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final authUser = ref.watch(authProvider).user;
    final claimState = ref.watch(claimTaskProvider);
    final theme = Theme.of(context);

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
                    // ── Progress + Status + Urgency ──
                    _CompletionProgressBar(status: task.status),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 24),

                    // ── Verification Feedback ──
                    if (task.status == TaskStatus.coordinatorVerified ||
                        task.status == TaskStatus.paid ||
                        task.status == TaskStatus.flagged)
                      _VerificationFeedbackCard(status: task.status),

                    // ── Execution Stepper ──
                    if (!isOpen && task.status != TaskStatus.cancelled) ...[
                      Text('Execution Progress',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _TaskExecutionStepper(status: task.status),
                      const SizedBox(height: 24),
                    ],

                    // ── Instructions Card ──
                    _InstructionsCard(task: task),
                    const SizedBox(height: 24),

                    // ── Checklist (UI-only) ──
                    if (isClaimedByMe && !isOpen && task.status != TaskStatus.cancelled && task.status != TaskStatus.coordinatorVerified && task.status != TaskStatus.paid) ...[
                      _ExecutionChecklist(status: task.status),
                      const SizedBox(height: 24),
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
                    const SizedBox(height: 24),

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
                                userAgentPackageName: 'com.reliefnet.app',
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
            isParticipant: task.createdBy == authUser?.id ||
                task.claimedBy == authUser?.id ||
                task.coordinatorId == authUser?.id,
            isInProgress: isInProgress,
            isLoading: claimState.status == ClaimStatus.loading,
            onClaim: () {
              HapticFeedback.lightImpact();
              ref.read(claimTaskProvider.notifier).claim(taskId);
            },
            onStart: () async {
              try {
                await ref.read(apiClientProvider).post(ApiConstants.startTask(taskId));
                ref.invalidate(taskDetailProvider(taskId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to start task. Please try again.'),
                    backgroundColor: AppTheme.errorColor,
                  ));
                }
              }
            },
            onUnclaim: () async {
              try {
                await ref.read(apiClientProvider).post(ApiConstants.unclaimTask(taskId));
                ref.invalidate(taskDetailProvider(taskId));
                ref.invalidate(availableTasksProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to unclaim task. Please try again.'),
                    backgroundColor: AppTheme.errorColor,
                  ));
                }
              }
            },
            onUploadProof: () => context.push('/volunteer/proof/$taskId'),
            onChat: () => context.push('/chat/$taskId?title=${Uri.encodeComponent(task.title)}'),
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

class _CompletionProgressBar extends StatelessWidget {
  final TaskStatus status;
  const _CompletionProgressBar({required this.status});

  double _getProgress() {
    switch (status) {
      case TaskStatus.open:
        return 0.05;
      case TaskStatus.claimed:
      case TaskStatus.assigned:
        return 0.25;
      case TaskStatus.inProgress:
        return 0.50;
      case TaskStatus.submitted:
        return 0.75;
      case TaskStatus.coordinatorVerified:
      case TaskStatus.paid:
      case TaskStatus.completed:
        return 1.0;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Task Progress',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _TaskExecutionStepper extends StatelessWidget {
  final TaskStatus status;
  const _TaskExecutionStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepItem(
        title: 'Task Accepted',
        isCompleted: _isAtLeast(TaskStatus.claimed),
        isActive: status == TaskStatus.claimed || status == TaskStatus.assigned,
      ),
      _StepItem(
        title: 'In Progress',
        isCompleted: _isAtLeast(TaskStatus.inProgress),
        isActive: status == TaskStatus.inProgress,
      ),
      _StepItem(
        title: 'Submit Proof',
        isCompleted: _isAtLeast(TaskStatus.submitted),
        isActive: status == TaskStatus.submitted,
      ),
      _StepItem(
        title: 'Verification',
        isCompleted: _isAtLeast(TaskStatus.coordinatorVerified),
        isActive: status == TaskStatus.coordinatorVerified || status == TaskStatus.paid,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: step.isCompleted
                        ? AppTheme.successColor
                        : step.isActive
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.isCompleted ? Icons.check : Icons.circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: steps[index + 1].isCompleted
                        ? AppTheme.successColor
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: step.isActive || step.isCompleted
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: step.isActive || step.isCompleted
                        ? Colors.black87
                        : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  bool _isAtLeast(TaskStatus target) {
    final order = [
      TaskStatus.open,
      TaskStatus.claimed,
      TaskStatus.assigned,
      TaskStatus.inProgress,
      TaskStatus.submitted,
      TaskStatus.coordinatorVerified,
      TaskStatus.paid,
      TaskStatus.completed,
    ];
    
    // Handle both claimed and assigned as equivalent for order
    TaskStatus normalizedStatus = status;
    if (status == TaskStatus.assigned) normalizedStatus = TaskStatus.claimed;
    
    TaskStatus normalizedTarget = target;
    if (target == TaskStatus.assigned) normalizedTarget = TaskStatus.claimed;

    final currentIdx = order.indexOf(normalizedStatus);
    final targetIdx = order.indexOf(normalizedTarget);
    
    // If not found in order (e.g. unknown or cancelled), return false unless it's open
    if (currentIdx == -1) return false;
    
    return currentIdx >= targetIdx;
  }
}

class _StepItem {
  final String title;
  final bool isCompleted;
  final bool isActive;
  _StepItem({required this.title, required this.isCompleted, required this.isActive});
}

class _InstructionsCard extends StatelessWidget {
  final TaskModel task;
  const _InstructionsCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final text = task.description ?? 'No specific instructions provided.';
    final keywords = ['photo required', 'gps required', 'urgent', 'priority', 'mandatory'];
    
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Task Instructions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Inter',
                ),
                children: _getHighlightedSpans(text, keywords, context),
              ),
            ),
            if (task.locationText != null) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Location: ${task.locationText}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  List<TextSpan> _getHighlightedSpans(String text, List<String> keywords, BuildContext context) {
    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    
    int currentPos = 0;
    
    // Simple greedy keyword highlighting
    while (currentPos < text.length) {
      int? firstMatchIdx;
      String? matchedKeyword;
      
      for (var keyword in keywords) {
        int idx = lowerText.indexOf(keyword, currentPos);
        if (idx != -1 && (firstMatchIdx == null || idx < firstMatchIdx)) {
          firstMatchIdx = idx;
          matchedKeyword = text.substring(idx, idx + keyword.length);
        }
      }
      
      if (firstMatchIdx != null && matchedKeyword != null) {
        // Add text before match
        if (firstMatchIdx > currentPos) {
          spans.add(TextSpan(text: text.substring(currentPos, firstMatchIdx)));
        }
        
        // Add matched keyword with highlight
        spans.add(TextSpan(
          text: matchedKeyword,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          ),
        ));
        
        currentPos = firstMatchIdx + matchedKeyword.length;
      } else {
        // No more matches
        spans.add(TextSpan(text: text.substring(currentPos)));
        break;
      }
    }
    
    return spans;
  }
}

class _ExecutionChecklist extends StatefulWidget {
  final TaskStatus status;
  const _ExecutionChecklist({required this.status});

  @override
  State<_ExecutionChecklist> createState() => _ExecutionChecklistState();
}

class _ExecutionChecklistState extends State<_ExecutionChecklist> {
  final List<bool> _checked = [false, false, false, false];
  final List<String> _items = [
    'Reach destination location',
    'Verify beneficiary identity',
    'Deliver required aid items',
    'Capture photographic proof'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Execution Checklist',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...List.generate(_items.length, (index) {
          return CheckboxListTile(
            value: _checked[index],
            onChanged: (val) => setState(() => _checked[index] = val ?? false),
            title: Text(_items[index], style: const TextStyle(fontSize: 14)),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryColor,
          );
        }),
      ],
    );
  }
}

class _VerificationFeedbackCard extends StatelessWidget {
  final TaskStatus status;
  const _VerificationFeedbackCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isVerified = status == TaskStatus.coordinatorVerified || status == TaskStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? Colors.green.shade200 : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified : Icons.report_problem,
                color: isVerified ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isVerified ? 'Delivery Verified!' : 'Attention Required',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isVerified ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isVerified 
              ? 'Great job! Your delivery has been confirmed by the coordinator. This impact has been added to your profile.'
              : 'There was an issue with your delivery proof. Please check the coordinator notes below and update your submission if necessary.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isVerified ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          if (isVerified) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '+10 Trust Points Earned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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
  final bool isParticipant;
  final bool isInProgress;
  final bool isLoading;
  final VoidCallback onClaim;
  final VoidCallback onStart;
  final VoidCallback onUnclaim;
  final VoidCallback onUploadProof;
  final VoidCallback onChat;

  const _ActionBar({
    required this.task,
    required this.isOpen,
    required this.isClaimed,
    required this.isClaimedByMe,
    required this.isParticipant,
    required this.isInProgress,
    required this.isLoading,
    required this.onClaim,
    required this.onStart,
    required this.onUnclaim,
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
          if (isParticipant && !isOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open Coordination Chat'),
                ),
              ),
            ),
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
                      onPressed: onStart,
                      child: const Text('Start Task'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onUnclaim,
                  child: const Text('Unclaim'),
                ),
              ],
            ),
          if (isInProgress && isClaimedByMe)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onUploadProof,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Proof of Completion'),
              ),
            ),
        ],
      ),
    );
  }
}
