import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';
import 'package:disasteraid_app/core/socket/socket_provider.dart';
import 'package:disasteraid_app/core/socket/socket_service.dart';

// ── Domain models ──────────────────────────────────────────────────────────────

class ChatMessage {
  final int id;
  final int roomId;
  final int senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        roomId: json['room_id'] as int,
        senderId: json['sender_id'] as int,
        senderName: (json['sender_name'] as String?) ?? 'User',
        text: json['text'] as String,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}

class ChatRoom {
  final int id;
  final int? taskId;
  final int? inkindRequestId;
  final String taskTitle;
  final String taskStatus;
  final String? creatorName;
  final String? claimerName;
  final String? coordinatorName;
  final int messageCount;
  final String? createdAt;

  const ChatRoom({
    required this.id,
    this.taskId,
    this.inkindRequestId,
    required this.taskTitle,
    this.taskStatus = 'OPEN',
    this.creatorName,
    this.claimerName,
    this.coordinatorName,
    this.messageCount = 0,
    this.createdAt,
  });

  bool get isInKindRoom => inkindRequestId != null;

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: (json['id'] as num).toInt(),
        taskId: json['task_id'] != null ? (json['task_id'] as num).toInt() : null,
        inkindRequestId: json['inkind_request_id'] != null
            ? (json['inkind_request_id'] as num).toInt()
            : null,
        taskTitle: (json['task_title'] as String?) ?? 'Item Donation',
        taskStatus: (json['task_status'] as String?) ?? 'OPEN',
        creatorName: json['creator_name'] as String?,
        claimerName: json['claimer_name'] as String?,
        coordinatorName: json['coordinator_name'] as String?,
        messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] as String?,
      );
}

// ── Repository ─────────────────────────────────────────────────────────────────

class ChatRepository {
  final ApiClient _client;

  ChatRepository({required ApiClient client}) : _client = client;

  Future<List<ChatMessage>> getMessages(int roomId) async {
    final response = await _client.get(ApiConstants.roomMessages(roomId));
    final data = response.data;
    if (data is List) {
      return data
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    final list =
        (data as Map<String, dynamic>)['data'] as List? ?? [];
    return list
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<ChatRoom> ensureRoom(int taskId) async {
    final response =
        await _client.get(ApiConstants.roomByTaskId(taskId));
    final data = response.data as Map<String, dynamic>;
    return ChatRoom.fromJson(
        data['room'] as Map<String, dynamic>? ?? data);
  }

  Future<ChatRoom> ensureInKindRoom(int requestId) async {
    final response =
        await _client.get(ApiConstants.inKindChatRoom(requestId));
    final data = response.data as Map<String, dynamic>;
    return ChatRoom.fromJson(
        data['room'] as Map<String, dynamic>? ?? data);
  }

  Future<List<ChatRoom>> getMyRooms() async {
    final response = await _client.get(ApiConstants.chatRooms);
    final data = response.data;
    if (data is List) {
      return data
          .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    final list =
        (data as Map<String, dynamic>)['data'] as List? ?? [];
    return list
        .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}

final chatRepoProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(client: ref.read(apiClientProvider));
});

// ── State ──────────────────────────────────────────────────────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isConnected;
  final bool isTyping;
  final String? typingUserName;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isConnected = false,
    this.isTyping = false,
    this.typingUserName,
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isConnected,
    bool? isTyping,
    String? typingUserName,
    bool? isLoading,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isConnected: isConnected ?? this.isConnected,
        isTyping: isTyping ?? this.isTyping,
        // Nullable field: passing null intentionally clears the name.
        typingUserName: typingUserName,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repo;
  final SocketService _socket; // injected — NOT created here
  final int _roomId;

  StreamSubscription<SocketPayload>? _msgSub;
  StreamSubscription<SocketPayload>? _typingSub;
  StreamSubscription<SocketStatus>? _statusSub;
  Timer? _typingTimer;

  ChatNotifier({
    required ChatRepository repo,
    required SocketService socket,
    required int roomId,
  })  : _repo = repo,
        _socket = socket,
        _roomId = roomId,
        super(const ChatState()) {
    _init();
  }

  Future<void> _init() async {
    // Reflect current socket status immediately — don't wait for a stream event.
    final alreadyConnected = _socket.currentStatus == SocketStatus.connected;
    state = state.copyWith(isConnected: alreadyConnected, isLoading: true);

    // Load message history via REST before subscribing to real-time stream.
    try {
      final messages = await _repo.getMessages(_roomId);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }

    // Subscribe to new messages for THIS room only.
    _msgSub = _socket.messageStream
        .where((data) => (data['room_id'] as num?)?.toInt() == _roomId)
        .listen((data) {
      try {
        final msg = ChatMessage.fromJson(data);
        state = state.copyWith(messages: [...state.messages, msg]);
      } catch (e) {
        debugPrint('[Chat] Failed to parse incoming message: $e\nPayload: $data');
      }
    });

    // Subscribe to typing indicators for THIS room only.
    _typingSub = _socket.typingStream
        .where((data) => (data['roomId'] as num?)?.toInt() == _roomId)
        .listen((data) {
      final isTyping = data['isTyping'] as bool? ?? false;
      state = state.copyWith(
        isTyping: isTyping,
        typingUserName: isTyping
            ? (data['userName'] as String?) ?? 'User'
            : null,
      );
    });

    // Track connection status. On reconnect, re-join the room automatically.
    _statusSub = _socket.statusStream.listen((status) {
      final connected = status == SocketStatus.connected;
      state = state.copyWith(isConnected: connected);
      if (connected) {
        _socket.joinRoom(_roomId);
      }
    });

    // Join the room. If already connected this emits immediately;
    // if not, SocketService._attachHandlers onConnect re-joins all active rooms.
    _socket.joinRoom(_roomId);
  }

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _socket.sendMessage(_roomId, trimmed);
  }

  void notifyTyping(bool isTyping) {
    _socket.sendTyping(_roomId, isTyping: isTyping);
    if (isTyping) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _socket.sendTyping(_roomId, isTyping: false);
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgSub?.cancel();
    _typingSub?.cancel();
    _statusSub?.cancel();
    // Leave the room but do NOT disconnect the shared socket.
    _socket.leaveRoom(_roomId);
    super.dispose();
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, int>((ref, roomId) {
  return ChatNotifier(
    repo: ref.read(chatRepoProvider),
    socket: ref.read(socketServiceProvider),
    roomId: roomId,
  );
});

final myRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  return ref.read(chatRepoProvider).getMyRooms();
});
