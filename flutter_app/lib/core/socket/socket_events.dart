abstract final class SocketEvent {
  // Server → Client
  static const String newMessage     = 'new_message';
  static const String userTyping     = 'user_typing';
  static const String notification   = 'notification';
  static const String broadcastAlert = 'broadcast_alert';

  // Client → Server
  static const String joinRoom  = 'join_room';
  static const String leaveRoom = 'leave_room';
  static const String sendMsg   = 'send_message';
  static const String typing    = 'typing';
}
