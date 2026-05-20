import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/features/tasks/data/tasks_repository.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

// ── Repository Provider ──
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final client = ref.read(apiClientProvider);
  return TasksRepository(client: client);
});

// ── Available Tasks Provider ──
// Returns ALL open tasks, no distance filter.
final availableTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final repo = ref.read(tasksRepositoryProvider);
  return repo.getAvailableTasks();
});

// ── Task Detail Provider ──
final taskDetailProvider =
    FutureProvider.family<TaskModel, int>((ref, taskId) async {
  final repo = ref.read(tasksRepositoryProvider);
  return repo.getTaskById(taskId);
});

// ── Claim Task State ──
enum ClaimStatus { idle, loading, success, error }

class ClaimState {
  final ClaimStatus status;
  final String? error;

  const ClaimState({this.status = ClaimStatus.idle, this.error});
}

class ClaimNotifier extends StateNotifier<ClaimState> {
  final TasksRepository _repository;
  final Ref _ref;
  bool _claiming = false;

  ClaimNotifier({required TasksRepository repository, required Ref ref})
      : _repository = repository,
        _ref = ref,
        super(const ClaimState());

  Future<void> claim(int taskId) async {
    if (_claiming) return;
    _claiming = true;
    state = const ClaimState(status: ClaimStatus.loading);
    try {
      await _repository.claimTask(taskId);
      state = const ClaimState(status: ClaimStatus.success);
      // Refresh the available tasks list
      _ref.invalidate(availableTasksProvider);
    } catch (e) {
      final message = _extractError(e);
      state = ClaimState(status: ClaimStatus.error, error: message);
    } finally {
      _claiming = false;
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map && body['error'] != null) {
        return body['error'] as String;
      }
      if (e.response?.statusCode == 409) {
        return 'This task is already claimed by another volunteer.';
      }
    }
    return 'Failed to claim task. Please try again.';
  }
}

final claimTaskProvider =
    StateNotifierProvider<ClaimNotifier, ClaimState>((ref) {
  final repo = ref.read(tasksRepositoryProvider);
  return ClaimNotifier(repository: repo, ref: ref);
});
