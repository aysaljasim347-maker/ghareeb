import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/features/tasks/data/tasks_repository.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';

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

  ClaimNotifier({required TasksRepository repository, required Ref ref})
      : _repository = repository,
        _ref = ref,
        super(const ClaimState());

  Future<void> claim(int taskId) async {
    state = const ClaimState(status: ClaimStatus.loading);
    try {
      await _repository.claimTask(taskId);
      state = const ClaimState(status: ClaimStatus.success);
      // Refresh the available tasks list
      _ref.invalidate(availableTasksProvider);
    } catch (e) {
      state = ClaimState(
        status: ClaimStatus.error,
        error: e.toString(),
      );
    }
  }
}

final claimTaskProvider =
    StateNotifierProvider<ClaimNotifier, ClaimState>((ref) {
  final repo = ref.read(tasksRepositoryProvider);
  return ClaimNotifier(repository: repo, ref: ref);
});
