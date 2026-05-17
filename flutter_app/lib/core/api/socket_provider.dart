import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:disasteraid_app/config/env.dart';
import 'package:disasteraid_app/core/storage/secure_storage.dart';

/// Centralized Socket.IO provider for global events (notifications, etc).
/// Chat uses its own family provider but could be refactored to share this.
final globalSocketProvider = Provider<io.Socket?>((ref) {
  final storage = ref.read(secureStorageProvider);

  // We use a future internally but return the socket instance.
  // The UI can watch this to see if it's connected.

  final baseUrl = Env.apiUrl.replaceAll('/api', '');
  final socket = io.io(
    baseUrl,
    io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
  );

  // Re-auth on every connection attempt
  socket.onConnect((_) async {
    final token = await storage.getToken();
    if (token != null) {
      socket.auth = {'token': token};
    }
  });

  socket.connect();

  ref.onDispose(() {
    socket.disconnect();
    socket.dispose();
  });

  return socket;
});
