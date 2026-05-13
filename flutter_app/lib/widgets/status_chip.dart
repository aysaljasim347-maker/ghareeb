import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusChip({super.key, required this.status, this.fontSize = 11});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return const Color(0xFFED8936);
      case 'ASSIGNED':
      case 'CLAIMED':
        return const Color(0xFF3182CE);
      case 'IN_PROGRESS':
        return const Color(0xFF805AD5);
      case 'SUBMITTED':
        return const Color(0xFF00B5D8);
      case 'COORDINATOR_VERIFIED':
      case 'PAID':
        return const Color(0xFF38A169);
      case 'FLAGGED':
        return const Color(0xFFE53E3E);
      case 'CANCELLED':
        return const Color(0xFF718096);
      case 'PENDING':
        return const Color(0xFFED8936);
      case 'COMPLETED':
        return const Color(0xFF38A169);
      case 'FAILED':
      case 'REFUNDED':
        return const Color(0xFFE53E3E);
      case 'ACTIVE':
        return const Color(0xFF38A169);
      case 'DRAFT':
        return const Color(0xFF718096);
      default:
        return const Color(0xFF718096);
    }
  }

  String get _label {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COORDINATOR_VERIFIED':
        return 'Verified';
      case 'PENDING_APPROVAL':
        return 'Pending';
      default:
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
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
