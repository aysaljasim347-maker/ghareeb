import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int taskId;
  final String? taskTitle;

  const ChatScreen({super.key, required this.taskId, this.taskTitle});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  ChatRoom? _room;
  bool _initializingRoom = true;
  String? _chatError;

  @override
  void initState() {
    super.initState();
    _ensureRoom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureRoom() async {
    if (widget.taskId == 0) {
      if (mounted) {
        setState(() {
          _chatError = 'Invalid task ID';
          _initializingRoom = false;
        });
      }
      return;
    }
    try {
      final repo = ref.read(chatRepoProvider);
      final room = await repo.ensureRoom(widget.taskId);
      if (mounted) {
        setState(() {
          _room = room;
          _initializingRoom = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatError = 'Failed to open chat. Please try again.';
          _initializingRoom = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _room == null) return;

    HapticFeedback.lightImpact();
    ref.read(chatProvider(_room!.id).notifier).sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _notifyTyping(String value) {
    if (_room == null) return;
    ref.read(chatProvider(_room!.id).notifier).notifyTyping(value.isNotEmpty);
  }

  void _showParticipants(BuildContext context) {
    if (_room == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chat Participants',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (_room!.creatorName != null)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(_room!.creatorName!),
                  subtitle: const Text('Beneficiary (Creator)'),
                ),
              if (_room!.claimerName != null)
                ListTile(
                  leading: const Icon(Icons.volunteer_activism),
                  title: Text(_room!.claimerName!),
                  subtitle: const Text('Volunteer'),
                ),
              if (_room!.coordinatorName != null)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: Text(_room!.coordinatorName!),
                  subtitle: const Text('Coordinator'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id;

    if (_initializingRoom) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.taskTitle ?? 'Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.taskTitle ?? 'Chat')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 48),
              const SizedBox(height: 16),
              Text(_chatError ?? 'Could not open chat room.'),
              TextButton(
                onPressed: () {
                  setState(() {
                    _initializingRoom = true;
                    _chatError = null;
                  });
                  _ensureRoom();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final chatState = ref.watch(chatProvider(_room!.id));

    // scroll when new messages arrive
    ref.listen<ChatState>(chatProvider(_room!.id), (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_room!.taskTitle,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(
              '${_room!.taskStatus} • ${chatState.isConnected ? 'Online' : 'Connecting...'}',
              style: TextStyle(
                fontSize: 11,
                color: chatState.isConnected
                    ? const Color(0xFF48BB78)
                    : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showParticipants(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Offline Banner ──
          if (!chatState.isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.orange.shade100,
              child: const Text(
                'Waiting for connection...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.deepOrange),
              ),
            ),

          // ── Messages ──
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Say hello!'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
                          final isMe = msg.senderId == currentUserId;

                          final showDateSep = index == 0 ||
                              !_isSameDay(
                                chatState.messages[index - 1].createdAt,
                                msg.createdAt,
                              );

                          return Column(
                            children: [
                              if (showDateSep)
                                _DateSeparator(date: msg.createdAt),
                              _MessageBubble(
                                message: msg,
                                isMe: isMe,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Typing Indicator ──
          if (chatState.isTyping && chatState.typingUserName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${chatState.typingUserName} is typing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // ── Input Bar ──
          _InputBar(
            controller: _textController,
            onSend: _sendMessage,
            onTyping: _notifyTyping,
            onPickImage: () async {
              final xf =
                  await _imagePicker.pickImage(source: ImageSource.gallery);
              if (xf != null && _room != null) {
                // Image message: send path as text for now
                ref
                    .read(chatProvider(_room!.id).notifier)
                    .sendMessage('[Image: ${xf.name}]');
              }
            },

          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Sub-widgets ──

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day
        ? 'Today'
        : DateFormat('d MMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(fontSize: 11, color: cs.primary),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isMe ? cs.onPrimary : cs.primary,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? cs.onPrimary.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(String) onTyping;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onTyping,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      color: cs.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: onPickImage,
            color: cs.onSurfaceVariant,
            tooltip: 'Send image',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onTyping,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: value.text.trim().isNotEmpty
                  ? IconButton(
                      key: const ValueKey('send'),
                      icon: Icon(Icons.send, color: cs.primary),
                      onPressed: onSend,
                    )
                  : const SizedBox(key: ValueKey('empty'), width: 48),
            ),
          ),
        ],
      ),
    );
  }
}
