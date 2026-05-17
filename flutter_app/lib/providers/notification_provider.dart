import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/socket_provider.dart';

class AppNotification {
  final String title;
  final String message;
  final DateTime timestamp;
  final int taskId;
  final String type;

  AppNotification({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.taskId,
    required this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      title: json['title'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      taskId: json['taskId'] as int,
      type: json['type'] as String,
    );
  }
}

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final Ref _ref;

  NotificationNotifier(this._ref) : super([]) {
    _init();
  }

  void _init() {
    final socket = _ref.watch(globalSocketProvider);
    if (socket == null) return;

    socket.on('notification', (data) {
      try {
        final notification = AppNotification.fromJson(data as Map<String, dynamic>);
        state = [notification, ...state];
      } catch (e) {
        // Silently ignore
      }
    });

    socket.on('broadcast_alert', (data) {
      try {
        final notification = AppNotification(
          title: data['title'] ?? 'Operational Alert',
          message: data['message'] ?? '',
          timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
          taskId: data['taskId'] ?? 0,
          type: 'BROADCAST',
        );
        state = [notification, ...state];
      } catch (e) {
        // Silently ignore
      }
    });
  }

  void clear() {
    state = [];
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier(ref);
});
