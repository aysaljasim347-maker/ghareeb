import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reliefnet_app/core/socket/socket_service.dart';
import 'package:reliefnet_app/core/storage/secure_storage.dart';

export 'socket_service.dart' show SocketService, SocketStatus;

/// The single [SocketService] instance for the app.
/// Lives for the lifetime of [ProviderScope].
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref.read(secureStorageProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive connection status. UI can watch this to show
/// online/offline banners without coupling to [SocketService] directly.
final socketStatusProvider = StreamProvider<SocketStatus>((ref) {
  return ref.watch(socketServiceProvider).statusStream;
});
