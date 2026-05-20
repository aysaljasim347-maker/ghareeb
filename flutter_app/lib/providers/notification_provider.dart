import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/socket/socket_provider.dart';

class AppNotification {
  final String title;
  final String message;
  final DateTime timestamp;
  final int taskId;
  final String type;

  const AppNotification({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.taskId,
    required this.type,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        title: (json['title'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
        timestamp: DateTime.tryParse(
              (json['timestamp'] as String?) ?? '',
            ) ??
            DateTime.now(),
        taskId: (json['taskId'] as num?)?.toInt() ?? 0,
        type: (json['type'] as String?) ?? 'INFO',
      );
}

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final SocketService _service;
  StreamSubscription<Map<String, dynamic>>? _sub;

  NotificationNotifier(this._service) : super([]) {
    // StreamSubscription — one listener, cleaned up in dispose().
    // No ref.watch(), no socket.on() scattered in constructors.
    _sub = _service.notificationStream.listen(_onPayload);
  }

  void _onPayload(Map<String, dynamic> data) {
    try {
      state = [AppNotification.fromJson(data), ...state];
    } catch (_) {
      // Malformed server payload — discard silently.
    }
  }

  void clear() => state = [];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  // ref.read is correct here — SocketService is a stable Provider, not reactive.
  return NotificationNotifier(ref.read(socketServiceProvider));
});
