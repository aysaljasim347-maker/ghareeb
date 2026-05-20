import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';
import 'package:reliefnet_app/screens/coordinator/coordinator_tasks_screen.dart';
import 'package:reliefnet_app/core/theme/app_theme.dart';

class CoordinatorMapScreen extends ConsumerWidget {
  const CoordinatorMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(coordinatorTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Field Activity Map')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tasks) {
          final center = tasks.isNotEmpty && tasks.first.latitude != null
              ? LatLng(tasks.first.latitude!, tasks.first.longitude!)
              : const LatLng(30.3753, 69.3451); // Pakistan center

          return FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.reliefnet.app',
              ),
              MarkerLayer(
                markers: tasks
                    .where((t) => t.latitude != null && t.longitude != null)
                    .map((t) => Marker(
                          point: LatLng(t.latitude!, t.longitude!),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => context.push('/coordinator/task/${t.id}'),
                            child: Icon(
                              Icons.location_on,
                              color: _getStatusColor(t.status),
                              size: 30,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return Colors.grey;
      case TaskStatus.claimed:
      case TaskStatus.assigned:
        return Colors.blue;
      case TaskStatus.inProgress:
        return Colors.orange;
      case TaskStatus.submitted:
        return Colors.yellow.shade700;
      case TaskStatus.coordinatorVerified:
      case TaskStatus.paid:
        return Colors.green;
      default:
        return AppTheme.primaryColor;
    }
  }
}
