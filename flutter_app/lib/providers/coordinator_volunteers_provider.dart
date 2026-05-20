import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/api/api_client.dart';

class VolunteerInScope {
  final int id;
  final String name;
  final String email;
  final String status;
  final double rating;
  final int activeTasks;
  final int completedTasks;
  final String? lastActivity;

  VolunteerInScope({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.rating,
    required this.activeTasks,
    required this.completedTasks,
    this.lastActivity,
  });

  factory VolunteerInScope.fromJson(Map<String, dynamic> json) {
    return VolunteerInScope(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      status: json['status'] as String,
      rating: double.tryParse(json['rating']?.toString() ?? '5.0') ?? 5.0,
      activeTasks: int.tryParse(json['active_tasks']?.toString() ?? '0') ?? 0,
      completedTasks: int.tryParse(json['completed_tasks']?.toString() ?? '0') ?? 0,
      lastActivity: json['last_activity'] as String?,
    );
  }
}

final coordinatorVolunteersProvider = FutureProvider<List<VolunteerInScope>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/coordinator/volunteers');
  final data = response.data as Map<String, dynamic>;
  final list = (data['data'] as List<dynamic>?) ?? [];
  return list.map((v) => VolunteerInScope.fromJson(v as Map<String, dynamic>)).toList();
});
