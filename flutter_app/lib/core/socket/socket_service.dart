import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:disasteraid_app/config/env.dart';
import 'package:disasteraid_app/core/socket/socket_events.dart';
import 'package:disasteraid_app/core/storage/secure_storage.dart';

enum SocketStatus { disconnected, connecting, connected, error }

typedef SocketPayload = Map<String, dynamic>;

/// Single-instance Socket.IO manager for the entire app.
///
/// Lifecycle: created once by [socketServiceProvider], lives until app
/// disposes the ProviderScope. All features (chat, notifications) share
/// this single connection.
class SocketService {
  final SecureStorageService _storage;

  io.Socket? _socket;
  SocketStatus _currentStatus = SocketStatus.disconnected;
  bool _intentionalDisconnect = false;

  // Rooms that should always be joined. Re-joined automatically on reconnect.
  final Set<int> _activeRooms = {};

  // Broadcast streams — zero-buffer, multiple listeners allowed.
  final _statusCtrl        = StreamController<SocketStatus>.broadcast();
  final _messageCtrl       = StreamController<SocketPayload>.broadcast();
  final _typingCtrl        = StreamController<SocketPayload>.broadcast();
  final _notificationCtrl  = StreamController<SocketPayload>.broadcast();

  Stream<SocketStatus>  get statusStream       => _statusCtrl.stream;
  Stream<SocketPayload> get messageStream      => _messageCtrl.stream;
  Stream<SocketPayload> get typingStream       => _typingCtrl.stream;
  Stream<SocketPayload> get notificationStream => _notificationCtrl.stream;

  /// Snapshot of the current connection state for consumers that need it
  /// on first subscribe (avoids missing the initial connected event).
  SocketStatus get currentStatus => _currentStatus;

  SocketService(this._storage);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches the auth token, then opens the WebSocket connection.
  /// Safe to call multiple times — no-ops if already connected.
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _storage.getToken();
    if (token == null) {
      debugPrint('[Socket] No token — aborting connect');
      return;
    }

    _intentionalDisconnect = false;
    _setStatus(SocketStatus.connecting);

    // Dispose any stale socket before creating a new one.
    _socket?.dispose();

    final baseUrl = Env.apiUrl.replaceAll('/api', '');
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token}) // auth BEFORE connect — server sees it in handshake
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _attachHandlers(_socket!);
    _socket!.connect();
  }

  /// Closes the connection cleanly. Called on logout.
  void disconnect() {
    _intentionalDisconnect = true;
    _activeRooms.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setStatus(SocketStatus.disconnected);
  }

  /// Joins a chat room. The room is remembered so it is re-joined after
  /// an automatic reconnect.
  void joinRoom(int roomId) {
    _activeRooms.add(roomId);
    _socket?.emit(SocketEvent.joinRoom, roomId);
  }

  /// Leaves a chat room and stops tracking it for auto-rejoin.
  void leaveRoom(int roomId) {
    _activeRooms.remove(roomId);
    _socket?.emit(SocketEvent.leaveRoom, roomId);
  }

  void sendMessage(int roomId, String text) {
    _socket?.emit(SocketEvent.sendMsg, {'roomId': roomId, 'text': text});
  }

  void sendTyping(int roomId, {required bool isTyping}) {
    _socket?.emit(SocketEvent.typing, {'roomId': roomId, 'isTyping': isTyping});
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _setStatus(SocketStatus s) {
    _currentStatus = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  void _attachHandlers(io.Socket s) {
    s.onConnect((_) {
      debugPrint('[Socket] Connected');
      _setStatus(SocketStatus.connected);
      // Re-join every room that was active before the reconnect.
      for (final roomId in _activeRooms) {
        s.emit(SocketEvent.joinRoom, roomId);
      }
    });

    s.onDisconnect((_) {
      debugPrint('[Socket] Disconnected (intentional=$_intentionalDisconnect)');
      if (!_intentionalDisconnect) {
        _setStatus(SocketStatus.disconnected);
      }
    });

    s.onConnectError((e) {
      debugPrint('[Socket] Connect error: $e');
      _setStatus(SocketStatus.error);
    });

    s.on(SocketEvent.newMessage, (data) {
      if (!_messageCtrl.isClosed && data is Map) {
        _messageCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    s.on(SocketEvent.userTyping, (data) {
      if (!_typingCtrl.isClosed && data is Map) {
        _typingCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    s.on(SocketEvent.notification, (data) {
      if (!_notificationCtrl.isClosed && data is Map) {
        _notificationCtrl.add(Map<String, dynamic>.from(data));
      }
    });

    s.on(SocketEvent.broadcastAlert, (data) {
      if (!_notificationCtrl.isClosed && data is Map) {
        _notificationCtrl.add({
          ...Map<String, dynamic>.from(data),
          'type': 'BROADCAST',
        });
      }
    });
  }

  void dispose() {
    _intentionalDisconnect = true;
    _activeRooms.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _statusCtrl.close();
    _messageCtrl.close();
    _typingCtrl.close();
    _notificationCtrl.close();
  }
}
