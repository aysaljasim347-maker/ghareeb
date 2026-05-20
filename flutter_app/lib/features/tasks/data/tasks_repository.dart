import 'package:reliefnet_app/core/api/api_client.dart';
import 'package:reliefnet_app/core/api/api_constants.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

/// Tasks API data layer.
class TasksRepository {
  final ApiClient _client;

  TasksRepository({required ApiClient client}) : _client = client;

  /// Get ALL available (OPEN) tasks. No distance filter per requirements.
  Future<List<TaskModel>> getAvailableTasks() async {
    final response = await _client.get(ApiConstants.availableTasks);
    final data = response.data as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>?) ?? [];
    return list.map((t) => TaskModel.fromJson(t as Map<String, dynamic>)).toList();
  }

  /// Get task details by ID.
  Future<TaskModel> getTaskById(int id) async {
    final response = await _client.get(ApiConstants.taskById(id));
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Claim a task (volunteer).
  Future<TaskModel> claimTask(int taskId) async {
    final response = await _client.post(ApiConstants.claimTask(taskId));
    final data = response.data as Map<String, dynamic>;
    return TaskModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Create a new task.
  Future<TaskModel> createTask(Map<String, dynamic> taskData) async {
    final response = await _client.post(ApiConstants.tasks, data: taskData);
    return TaskModel.fromJson(response.data as Map<String, dynamic>);
  }
}
