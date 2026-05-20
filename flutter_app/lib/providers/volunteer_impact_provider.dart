import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/providers/chat_provider.dart';
import 'package:reliefnet_app/features/tasks/presentation/tasks_provider.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

class VolunteerImpactStats {
  final int totalCompleted;
  final int inProgress;
  final int verifiedDeliveries;
  final int flaggedDeliveries;
  final double successRate;
  final int peopleHelped;

  VolunteerImpactStats({
    required this.totalCompleted,
    required this.inProgress,
    required this.verifiedDeliveries,
    required this.flaggedDeliveries,
    required this.successRate,
    required this.peopleHelped,
  });

  factory VolunteerImpactStats.empty() => VolunteerImpactStats(
        totalCompleted: 0,
        inProgress: 0,
        verifiedDeliveries: 0,
        flaggedDeliveries: 0,
        successRate: 0.0,
        peopleHelped: 0,
      );
}

/// Aggregates volunteer impact from existing task and chat data.
/// Since there's no direct "claimed tasks" endpoint, we use Chat Rooms
/// as an index for tasks the volunteer is involved in.
final volunteerImpactProvider = FutureProvider<VolunteerImpactStats>((ref) async {
  final roomsAsync = ref.watch(myRoomsProvider);
  
  return roomsAsync.when(
    data: (rooms) async {
      if (rooms.isEmpty) return VolunteerImpactStats.empty();

      final tasks = <TaskModel>[];
      final repo = ref.read(tasksRepositoryProvider);

      // Fetch each task linked to a chat room
      // This ensures we only count tasks the volunteer actually claimed (rooms are auto-created on claim)
      for (final room in rooms) {
        try {
          if (room.taskId == null) continue;
          final task = await repo.getTaskById(room.taskId!);
          tasks.add(task);
        } catch (_) {
          // Skip if task details can't be fetched
        }
      }

      final completed = tasks.where((t) => 
        t.status == TaskStatus.coordinatorVerified || 
        t.status == TaskStatus.paid || 
        t.status == TaskStatus.completed
      ).length;

      final ongoing = tasks.where((t) => 
        t.status == TaskStatus.claimed || 
        t.status == TaskStatus.assigned || 
        t.status == TaskStatus.inProgress || 
        t.status == TaskStatus.submitted
      ).length;

      final flagged = tasks.where((t) => t.status == TaskStatus.flagged).length;

      final successRate = (completed + flagged) > 0 
          ? completed / (completed + flagged) 
          : 0.0;

      return VolunteerImpactStats(
        totalCompleted: completed,
        inProgress: ongoing,
        verifiedDeliveries: completed, // Assuming 1:1 for now
        flaggedDeliveries: flagged,
        successRate: successRate,
        peopleHelped: completed, // Base impact metric
      );
    },
    loading: () => VolunteerImpactStats.empty(),
    error: (_, __) => VolunteerImpactStats.empty(),
  );
});

final volunteerTasksHistoryProvider = FutureProvider<List<TaskModel>>((ref) async {
  final roomsAsync = ref.watch(myRoomsProvider);
  return roomsAsync.when(
    data: (rooms) async {
      final tasks = <TaskModel>[];
      final repo = ref.read(tasksRepositoryProvider);
      for (final room in rooms) {
        try {
          if (room.taskId == null) continue;
          final task = await repo.getTaskById(room.taskId!);
          tasks.add(task);
        } catch (_) {}
      }
      // Sort by status priority then most recent
      tasks.sort((a, b) => b.id.compareTo(a.id));
      return tasks;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
