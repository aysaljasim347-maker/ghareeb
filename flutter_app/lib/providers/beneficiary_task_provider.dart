import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';

// ── Repository ──

class BeneficiaryTaskRepository {
  final ApiClient _client;

  BeneficiaryTaskRepository({required ApiClient client}) : _client = client;

  Future<List<TaskModel>> getMyTasks(int userId) async {
    final response = await _client.get(ApiConstants.myTasks);
    final data = response.data as Map<String, dynamic>;
    final tasks = (data['tasks'] as List<dynamic>)
        .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
        .toList();
    return tasks.where((t) => t.createdBy == userId).toList();
  }

  Future<TaskModel> createTask(Map<String, dynamic> body) async {
    final response = await _client.post(ApiConstants.tasks, data: body);
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final beneficiaryTaskRepoProvider = Provider<BeneficiaryTaskRepository>((ref) {
  return BeneficiaryTaskRepository(client: ref.read(apiClientProvider));
});

// ── My Tasks Provider (family by userId) ──

final myTasksProvider =
    FutureProvider.family<List<TaskModel>, int>((ref, userId) async {
  final repo = ref.read(beneficiaryTaskRepoProvider);
  return repo.getMyTasks(userId);
});

// ── Create Task Notifier ──

enum CreateTaskStatus { idle, loading, success, error }

class CreateTaskState {
  final CreateTaskStatus status;
  final String? error;
  final TaskModel? created;

  const CreateTaskState({
    this.status = CreateTaskStatus.idle,
    this.error,
    this.created,
  });

  CreateTaskState copyWith({
    CreateTaskStatus? status,
    String? error,
    TaskModel? created,
  }) {
    return CreateTaskState(
      status: status ?? this.status,
      error: error,
      created: created ?? this.created,
    );
  }
}

class CreateTaskNotifier extends StateNotifier<CreateTaskState> {
  final BeneficiaryTaskRepository _repo;
  final Ref _ref;

  CreateTaskNotifier({required BeneficiaryTaskRepository repo, required Ref ref})
      : _repo = repo,
        _ref = ref,
        super(const CreateTaskState());

  Future<void> submit({
    required int userId,
    required Map<String, dynamic> body,
  }) async {
    state = state.copyWith(status: CreateTaskStatus.loading, error: null);
    try {
      final task = await _repo.createTask(body);
      _ref.invalidate(myTasksProvider(userId));
      state = CreateTaskState(status: CreateTaskStatus.success, created: task);
    } catch (e) {
      state = CreateTaskState(
        status: CreateTaskStatus.error,
        error: _extractError(e),
      );
    }
  }

  void reset() => state = const CreateTaskState();

  String _extractError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('422') || msg.contains('validation')) {
      return 'Please check the form fields and try again.';
    }
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    return 'Failed to submit request. Please try again.';
  }
}

final createTaskProvider =
    StateNotifierProvider<CreateTaskNotifier, CreateTaskState>((ref) {
  final repo = ref.read(beneficiaryTaskRepoProvider);
  return CreateTaskNotifier(repo: repo, ref: ref);
});
