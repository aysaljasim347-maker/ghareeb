import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:disasteraid_app/core/api/api_client.dart';
import 'package:disasteraid_app/core/api/api_constants.dart';
import 'package:disasteraid_app/core/storage/secure_storage.dart';
import 'package:disasteraid_app/config/env.dart';

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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      roomId: json['room_id'] as int,
      senderId: json['sender_id'] as int,
      senderName: (json['sender_name'] as String?) ?? 'User',
      text: json['text'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ChatRoom {
  final int id;
  final int taskId;
  final String taskTitle;
  final String taskStatus;
  final String? creatorName;
  final String? claimerName;
  final String? coordinatorName;
  final int messageCount;
  final String? createdAt;

  const ChatRoom({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    this.taskStatus = 'OPEN',
    this.creatorName,
    this.claimerName,
    this.coordinatorName,
    this.messageCount = 0,
    this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      taskTitle: (json['task_title'] as String?) ?? 'Task',
      taskStatus: (json['task_status'] as String?) ?? 'OPEN',
      creatorName: json['creator_name'] as String?,
      claimerName: json['claimer_name'] as String?,
      coordinatorName: json['coordinator_name'] as String?,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }
}

// ── REST helpers ──

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
    final list = (data as Map<String, dynamic>)['data'] as List? ?? [];
    return list
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<ChatRoom> ensureRoom(int taskId) async {
    final response = await _client.get(ApiConstants.roomByTaskId(taskId));
    final data = response.data as Map<String, dynamic>;
    return ChatRoom.fromJson(data['room'] as Map<String, dynamic>? ?? data);
  }

  Future<List<ChatRoom>> getMyRooms() async {
    final response = await _client.get(ApiConstants.chatRooms);
    final data = response.data;
    if (data is List) {
      return data
          .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    final list = (data as Map<String, dynamic>)['data'] as List? ?? [];
    return list
        .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}

final chatRepoProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(client: ref.read(apiClientProvider));
});

// ── Chat State ──

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
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isTyping: isTyping ?? this.isTyping,
      typingUserName: typingUserName,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repo;
  final SecureStorageService _storage;
  final int _roomId;
  io.Socket? _socket;
  Timer? _typingTimer;

  ChatNotifier({
    required ChatRepository repo,
    required SecureStorageService storage,
    required int roomId,
  })  : _repo = repo,
        _storage = storage,
        _roomId = roomId,
        super(const ChatState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _repo.getMessages(_roomId);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
    await _connectSocket();
  }

  Future<void> _connectSocket() async {
    final token = await _storage.getToken();
    if (token == null) return;

    final baseUrl = Env.apiUrl.replaceAll('/api', '');
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      state = state.copyWith(isConnected: true);
      _socket!.emit('join_room', _roomId);
    });

    _socket!.onDisconnect((_) {
      state = state.copyWith(isConnected: false);
    });

    _socket!.on('new_message', (data) {
      final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(messages: [...state.messages, msg]);
    });

    _socket!.on('user_typing', (data) {
      final isTyping = (data as Map)['isTyping'] as bool? ?? false;
      state = state.copyWith(
        isTyping: isTyping,
        typingUserName: isTyping ? 'User' : null,
      );
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty || _socket == null) return;
    _socket!.emit('send_message', {'roomId': _roomId, 'text': text.trim()});
  }

  void notifyTyping(bool isTyping) {
    _socket?.emit('typing', {'roomId': _roomId, 'isTyping': isTyping});
    if (isTyping) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _socket?.emit('typing', {'roomId': _roomId, 'isTyping': false});
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _socket?.emit('leave_room', _roomId);
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, int>((ref, roomId) {
  final repo = ref.read(chatRepoProvider);
  final storage = ref.read(secureStorageProvider);
  return ChatNotifier(repo: repo, storage: storage, roomId: roomId);
});

final myRoomsProvider = FutureProvider<List<ChatRoom>>((ref) async {
  final repo = ref.read(chatRepoProvider);
  return repo.getMyRooms();
});
