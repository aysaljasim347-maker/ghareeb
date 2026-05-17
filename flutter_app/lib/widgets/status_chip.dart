import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final TaskStatus status;
  final double fontSize;

  const StatusChip({super.key, required this.status, this.fontSize = 11});

  Color get _color {
    switch (status) {
      case TaskStatus.open:
        return const Color(0xFFED8936);
      case TaskStatus.assigned:
      case TaskStatus.claimed:
        return const Color(0xFF3182CE);
      case TaskStatus.inProgress:
        return const Color(0xFF805AD5);
      case TaskStatus.submitted:
        return const Color(0xFF00B5D8);
      case TaskStatus.coordinatorVerified:
      case TaskStatus.paid:
        return const Color(0xFF38A169);
      case TaskStatus.flagged:
        return const Color(0xFFE53E3E);
      case TaskStatus.cancelled:
        return const Color(0xFF718096);
      case TaskStatus.pending:
        return const Color(0xFFED8936);
      case TaskStatus.completed:
        return const Color(0xFF38A169);
      case TaskStatus.failed:
      case TaskStatus.refunded:
        return const Color(0xFFE53E3E);
      case TaskStatus.active:
        return const Color(0xFF38A169);
      case TaskStatus.draft:
        return const Color(0xFF718096);
      case TaskStatus.confirmed:
      case TaskStatus.approved:
        return const Color(0xFF38A169);
      case TaskStatus.rejected:
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFF718096);
    }
  }

  String get _label {
    switch (status) {
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.coordinatorVerified:
        return 'Verified';
      case TaskStatus.pending:
        return 'Pending';
      default:
        return status.value
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty
                ? w
                : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
