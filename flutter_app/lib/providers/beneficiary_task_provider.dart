import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:reliefnet_app/features/auth/presentation/auth_provider.dart';

// ── Repository ──

class BeneficiaryTaskRepository {
  final ApiClient _client;

  BeneficiaryTaskRepository({required ApiClient client}) : _client = client;

  Future<List<TaskModel>> getMyTasks(int userId) async {
    final response = await _client.get(ApiConstants.myTasks);
    final map = response.data as Map<String, dynamic>;
    final list = (map['data'] as List<dynamic>?) ?? [];
    return list.map((t) => TaskModel.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<TaskModel> getTask(int id) async {
    final response = await _client.get('${ApiConstants.tasks}/$id');
    final map = response.data as Map<String, dynamic>;
    // Some endpoints wrap in 'data', others return raw model. 
    // Handle both based on existing repository patterns.
    final data = map['data'] ?? map;
    return TaskModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TaskModel> createTask(Map<String, dynamic> body) async {
    final response = await _client.post(ApiConstants.tasks, data: body);
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TaskModel> updateTask(int id, Map<String, dynamic> body) async {
    final response = await _client.patch('${ApiConstants.tasks}/$id', data: body);
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<dynamic>> getDeliveryDetails(int taskId) async {
    final response = await _client.get('${ApiConstants.deliveries}/task/$taskId');
    final map = response.data as Map<String, dynamic>;
    return (map['data'] as List<dynamic>?) ?? [];
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

final beneficiaryTaskDetailProvider =
    FutureProvider.family<TaskModel, int>((ref, taskId) async {
  final repo = ref.read(beneficiaryTaskRepoProvider);
  return repo.getTask(taskId);
});

final taskDeliveryDetailsProvider =
    FutureProvider.family<List<dynamic>, int>((ref, taskId) async {
  final repo = ref.read(beneficiaryTaskRepoProvider);
  return repo.getDeliveryDetails(taskId);
});

// ── Task Action Notifier (Update/Cancel) ──

class TaskActionNotifier extends StateNotifier<AsyncValue<void>> {
  final BeneficiaryTaskRepository _repo;
  final Ref _ref;

  TaskActionNotifier({required BeneficiaryTaskRepository repo, required Ref ref})
      : _repo = repo,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<void> update(int taskId, Map<String, dynamic> body) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateTask(taskId, body);
      _ref.invalidate(beneficiaryTaskDetailProvider(taskId));
      
      final userId = _ref.read(authProvider).user?.id;
      if (userId != null) _ref.invalidate(myTasksProvider(userId));
    });
  }

  Future<void> cancel(int taskId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateTask(taskId, {'status': 'CANCELLED'});
      _ref.invalidate(beneficiaryTaskDetailProvider(taskId));
      
      final userId = _ref.read(authProvider).user?.id;
      if (userId != null) _ref.invalidate(myTasksProvider(userId));
    });
  }
}

final taskActionProvider =
    StateNotifierProvider<TaskActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.read(beneficiaryTaskRepoProvider);
  return TaskActionNotifier(repo: repo, ref: ref);
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

  @override
  void dispose() {
    state = const CreateTaskState();
    super.dispose();
  }

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
