import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/providers/volunteer_impact_provider.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

class VolunteerBadge {
  final String id;
  final String label;
  final String description;
  final String icon;
  final bool isUnlocked;

  VolunteerBadge({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });
}

class VolunteerReputation {
  final int trustScore;
  final String rankLabel;
  final String trend; // 'UP', 'DOWN', 'STABLE'
  final List<VolunteerBadge> badges;
  final double verificationRate;
  final double completionRate;

  VolunteerReputation({
    required this.trustScore,
    required this.rankLabel,
    required this.trend,
    required this.badges,
    required this.verificationRate,
    required this.completionRate,
  });

  factory VolunteerReputation.empty() => VolunteerReputation(
        trustScore: 0,
        rankLabel: 'New Volunteer',
        trend: 'STABLE',
        badges: [],
        verificationRate: 0.0,
        completionRate: 0.0,
      );
}

final volunteerReputationProvider = Provider<VolunteerReputation>((ref) {
  final impactAsync = ref.watch(volunteerImpactProvider);
  final historyAsync = ref.watch(volunteerTasksHistoryProvider);

  return impactAsync.maybeWhen(
    data: (stats) {
      final history = historyAsync.value ?? [];

      // 1. Calculate Rates
      final totalDeliveries = stats.totalCompleted + stats.flaggedDeliveries;
      final verificationRate = totalDeliveries > 0
          ? stats.totalCompleted / totalDeliveries
          : 1.0; // Default to perfect if none yet

      final totalTasks = history.length;
      final completionRate =
          totalTasks > 0 ? stats.totalCompleted / totalTasks : 0.0;

      // 2. Consistency Factor (0-30)
      int consistency = 0;
      // Active this week (simulated: if most recent task < 7 days old)
      if (history.isNotEmpty) {
        final lastTask = DateTime.tryParse(history.first.createdAt ?? '');
        if (lastTask != null &&
            DateTime.now().difference(lastTask).inDays < 7) {
          consistency += 15;
        }
      }
      // No flags in last 5 tasks
      final last5 = history.take(5);
      if (last5.isNotEmpty &&
          !last5.any((t) => t.status == TaskStatus.flagged)) {
        consistency += 15;
      }

      // 3. Trust Score Formula
      // 40 * verification + 30 * completion + 30 * consistency
      double score =
          (40 * verificationRate) + (30 * completionRate) + consistency;
      final trustScore = score.clamp(0, 100).toInt();

      // 4. Rank Label
      String rank = 'New Volunteer';
      if (trustScore > 90) {
        rank = 'Top Performer';
      } else if (trustScore > 70) {
        rank = 'Trusted Contributor';
      } else if (totalTasks > 5) {
        rank = 'Regular Contributor';
      }

      // 5. Trend (last 10 tasks)
      String trend = 'STABLE';
      final last10 = history.take(10).toList();
      if (last10.length >= 5) {
        final currentFlags =
            last10.where((t) => t.status == TaskStatus.flagged).length;
        if (currentFlags == 0) {
          trend = 'UP';
        } else if (currentFlags > 1) {
          trend = 'DOWN';
        }
      }

      // 6. Badge System
      final badges = [
        VolunteerBadge(
          id: 'trusted',
          label: 'Trusted Helper',
          description: 'Trust Score above 80',
          icon: '🛡️',
          isUnlocked: trustScore > 80,
        ),
        VolunteerBadge(
          id: 'consistent',
          label: 'Consistent',
          description: 'No flags in recent deliveries',
          icon: '⚡',
          isUnlocked: consistency >= 15,
        ),
        VolunteerBadge(
          id: 'community',
          label: 'Community Hero',
          description: '10+ Verified Deliveries',
          icon: '🎯',
          isUnlocked: stats.totalCompleted >= 10,
        ),
        VolunteerBadge(
          id: 'field',
          label: 'Field Expert',
          description: '5+ Tasks Completed',
          icon: '🗺️',
          isUnlocked: stats.totalCompleted >= 5,
        ),
      ];

      return VolunteerReputation(
        trustScore: trustScore,
        rankLabel: rank,
        trend: trend,
        badges: badges,
        verificationRate: verificationRate,
        completionRate: completionRate,
      );
    },
    orElse: () => VolunteerReputation.empty(),
  );
});
