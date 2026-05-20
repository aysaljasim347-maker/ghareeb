import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/providers/campaign_provider.dart';
import 'package:reliefnet_app/providers/beneficiary_task_provider.dart';
import 'package:reliefnet_app/models/campaign_model.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';

class CampaignReport {
  final CampaignModel campaign;
  final List<TaskModel> tasks;
  final int completedTasks;
  final int pendingTasks;
  final double utilizationPercent;
  final double completionPercent;
  final int transparencyScore;

  CampaignReport({
    required this.campaign,
    required this.tasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.utilizationPercent,
    required this.completionPercent,
    required this.transparencyScore,
  });
}

final campaignReportProvider = 
    FutureProvider.family<CampaignReport, int>((ref, campaignId) async {
  // 1. Get Campaign
  final campaign = await ref.read(campaignDetailProvider(campaignId).future);

  // 2. Get all tasks and filter by campaignId
  // We need to fetch all tasks. Currently, we only have getMyTasks or getAvailableTasks.
  // I'll use getAvailableTasks and maybe we need a way to get all tasks for a campaign.
  // Since we don't have a specialized endpoint, I'll check if getMyTasks (for NGO) 
  // returns them all.
  final user = ref.read(authProvider).user;
  if (user == null) throw Exception('Unauthorized');

  final taskRepo = ref.read(beneficiaryTaskRepoProvider);
  final allMyTasks = await taskRepo.getMyTasks(user.id);
  
  final campaignTasks = allMyTasks.where((t) => t.campaignId == campaignId).toList();

  // 3. Stats
  final completed = campaignTasks.where((t) => 
    t.status == TaskStatus.coordinatorVerified || t.status == TaskStatus.paid
  ).length;
  final pending = campaignTasks.length - completed;

  final utilization = campaign.raisedPkr > 0 ? campaign.spentPkr / campaign.raisedPkr : 0.0;
  final completion = campaignTasks.isNotEmpty ? completed / campaignTasks.length : 0.0;

  // 4. Transparency Score
  int score = 0;
  if (utilization > 0.6) score += 40;
  if (completion > 0.7) score += 30;
  // If there are completed tasks, we assume verified deliveries exist
  if (completed > 0) score += 30;

  return CampaignReport(
    campaign: campaign,
    tasks: campaignTasks,
    completedTasks: completed,
    pendingTasks: pending,
    utilizationPercent: utilization,
    completionPercent: completion,
    transparencyScore: score,
  );
});
