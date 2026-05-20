import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';
import 'package:reliefnet_app/providers/campaign_provider.dart';
import 'package:reliefnet_app/providers/beneficiary_task_provider.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

class NgoImpactMetrics {
  final int totalCampaigns;
  final int activeCampaigns;
  final double totalRaised;
  final double totalSpent;
  final double totalGoal;

  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;

  final int peopleHelped; // Verified deliveries count
  final double completionRate;
  final double fundUtilization;
  final int transparencyScore;

  NgoImpactMetrics({
    required this.totalCampaigns,
    required this.activeCampaigns,
    required this.totalRaised,
    required this.totalSpent,
    required this.totalGoal,
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.peopleHelped,
    required this.completionRate,
    required this.fundUtilization,
    required this.transparencyScore,
  });

  factory NgoImpactMetrics.empty() => NgoImpactMetrics(
        totalCampaigns: 0,
        activeCampaigns: 0,
        totalRaised: 0,
        totalSpent: 0,
        totalGoal: 0,
        totalTasks: 0,
        completedTasks: 0,
        inProgressTasks: 0,
        peopleHelped: 0,
        completionRate: 0,
        fundUtilization: 0,
        transparencyScore: 0,
      );
}

final ngoImpactProvider = FutureProvider<NgoImpactMetrics>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return NgoImpactMetrics.empty();

  // 1. Get all campaigns (not just active ones)
  final repo = ref.read(campaignRepoProvider);
  final allCampaigns = await repo.getCampaigns();

  // Filter for this NGO
  final myCampaigns =
      allCampaigns.where((c) => c.createdBy == user.id).toList();

  // 2. Get all tasks created by this NGO
  final taskRepo = ref.read(beneficiaryTaskRepoProvider);
  final myTasks = await taskRepo.getMyTasks(user.id);

  // 3. Aggregate metrics
  final totalCampaigns = myCampaigns.length;
  final activeCampaigns = myCampaigns.where((c) => c.status == 'ACTIVE').length;
  final totalRaised =
      myCampaigns.fold<double>(0, (sum, c) => sum + c.raisedPkr);
  final totalSpent = myCampaigns.fold<double>(0, (sum, c) => sum + c.spentPkr);
  final totalGoal = myCampaigns.fold<double>(0, (sum, c) => sum + c.goalPkr);

  final totalTasks = myTasks.length;
  final completedTasks = myTasks
      .where((t) =>
          t.status == TaskStatus.coordinatorVerified ||
          t.status == TaskStatus.paid)
      .length;
  final inProgressTasks = myTasks
      .where((t) =>
          t.status == TaskStatus.claimed ||
          t.status == TaskStatus.inProgress ||
          t.status == TaskStatus.submitted)
      .length;

  // 4. People Helped (Deliveries)
  int peopleHelped = 0;
  // For each task, check if it has verified deliveries
  // In a real scenario, we might need a more efficient way than looping
  // but following the constraints of using existing endpoints.
  // Actually, 'completedTasks' is a good proxy for 'verified deliveries' per task.
  peopleHelped = completedTasks;

  final completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
  final fundUtilization = totalRaised > 0 ? totalSpent / totalRaised : 0.0;

  // 5. Transparency Score
  int score = 0;
  if (fundUtilization > 0.6) score += 40;
  if (completionRate > 0.7) score += 30;
  if (peopleHelped > 0) score += 30;

  return NgoImpactMetrics(
    totalCampaigns: totalCampaigns,
    activeCampaigns: activeCampaigns,
    totalRaised: totalRaised,
    totalSpent: totalSpent,
    totalGoal: totalGoal,
    totalTasks: totalTasks,
    completedTasks: completedTasks,
    inProgressTasks: inProgressTasks,
    peopleHelped: peopleHelped,
    completionRate: completionRate,
    fundUtilization: fundUtilization,
    transparencyScore: score,
  );
});
