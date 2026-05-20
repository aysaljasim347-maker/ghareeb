import 'package:flutter/material.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

class TaskStatusTimeline extends StatelessWidget {
  final TaskStatus currentStatus;

  const TaskStatusTimeline({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StatusStep(
        status: TaskStatus.open,
        label: 'Open',
        color: Colors.grey,
      ),
      _StatusStep(
        status: TaskStatus.claimed,
        label: 'Claimed',
        color: Colors.blue,
      ),
      _StatusStep(
        status: TaskStatus.inProgress,
        label: 'Working',
        color: Colors.orange,
      ),
      _StatusStep(
        status: TaskStatus.submitted,
        label: 'Submitted',
        color: Colors.purple,
      ),
      _StatusStep(
        status: TaskStatus.coordinatorVerified,
        label: 'Verified',
        color: Colors.green,
      ),
    ];

    // Find the index of the current status to determine completion
    int currentIndex = steps.indexWhere((s) => s.status == currentStatus);
    
    // Fallback logic for statuses not explicitly in the timeline (like PAID)
    if (currentStatus == TaskStatus.paid) {
      currentIndex = steps.length - 1;
    } else if (currentIndex == -1 && currentStatus != TaskStatus.open) {
      // If we are in assigned, treat it as claimed for timeline purposes
      if (currentStatus == TaskStatus.assigned) {
        currentIndex = 1;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Row(
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          final isCompleted = index <= currentIndex;
          final isLast = index == steps.length - 1;

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    // Line before circle
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index == 0
                            ? Colors.transparent
                            : (isCompleted ? step.color : Colors.grey.shade300),
                      ),
                    ),
                    // Circle
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted ? step.color : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? step.color : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    // Line after circle
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isLast
                            ? Colors.transparent
                            : (index < currentIndex
                                ? steps[index + 1].color
                                : Colors.grey.shade300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? step.color : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StatusStep {
  final TaskStatus status;
  final String label;
  final Color color;

  _StatusStep({
    required this.status,
    required this.label,
    required this.color,
  });
}
