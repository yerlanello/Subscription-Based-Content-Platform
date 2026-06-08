import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../l10n/app_localizations.dart';
import '../models/stream.dart';
import '../services/auth_service.dart';
import '../services/streams_service.dart';

/// LiveKit's chat data-channel topic, matching `@livekit/components-react`
/// `useChat` on the web (DataTopic.CHAT). The payload is JSON of
/// `{ id, timestamp, message }`, UTF-8 encoded.
const _chatTopic = 'lk-chat-topic';

class _ChatLine {
  final String name;
  final String message;
  const _ChatLine(this.name, this.message);
}

/// Realtime stream chat. Mirrors the web `StreamChat`: loads persisted history,
/// publishes/receives live messages over the LiveKit data channel, and persists
/// each sent message so new joiners see it in history.
class StreamChat extends StatefulWidget {
  const StreamChat({super.key, required this.room, required this.streamId});

  final Room room;
  final String streamId;

  @override
  State<StreamChat> createState() => _StreamChatState();
}

class _StreamChatState extends State<StreamChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<StreamMessage> _history = [];
  final List<_ChatLine> _live = [];
  String? _username;
  EventsListener<RoomEvent>? _listener;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadUsername();
    _listener = widget.room.createListener();
    _listener!.on<DataReceivedEvent>(_onData);
  }

  @override
  void dispose() {
    _listener?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await StreamsService.getMessages(widget.streamId);
      if (mounted) {
        setState(() => _history = msgs);
        _scrollToBottom();
      }
    } catch (_) {/* history is best-effort */}
  }

  Future<void> _loadUsername() async {
    final u = await AuthService.getUsername();
    if (mounted) setState(() => _username = u);
  }

  void _onData(DataReceivedEvent event) {
    if (event.topic != _chatTopic) return;
    try {
      final obj = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final message = obj['message'] as String?;
      if (message == null || message.isEmpty) return;
      final name = event.participant?.name.isNotEmpty == true
          ? event.participant!.name
          : (event.participant?.identity ?? L10n.t('anonymous'));
      if (mounted) {
        setState(() => _live.add(_ChatLine(name, message)));
        _scrollToBottom();
      }
    } catch (_) {/* ignore malformed packets */}
  }

  Future<void> _send() async {
    final msg = _controller.text.trim();
    final username = _username;
    if (msg.isEmpty || username == null) return;
    _controller.clear();

    // Optimistically show our own message — LiveKit does not echo data back
    // to the sender.
    setState(() => _live.add(_ChatLine(username, msg)));
    _scrollToBottom();

    // Publish live over the data channel so participants already in the room
    // (web included) see it immediately, in the web's wire format.
    try {
      final payload = utf8.encode(jsonEncode({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': msg,
      }));
      await widget.room.localParticipant
          ?.publishData(payload, reliable: true, topic: _chatTopic);
    } catch (_) {/* ignore — still persisted below */}

    // Persist for new joiners loading history.
    StreamsService.sendMessage(widget.streamId, msg, username).catchError((_) {});
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loggedIn = _username != null;
    final isEmpty = _history.isEmpty && _live.isEmpty;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(L10n.t('chat'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: isEmpty
              ? Center(
                  child: Text(
                    L10n.t('no_messages_yet'),
                    style: TextStyle(
                        color: colorScheme.outline, fontSize: 13),
                  ),
                )
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final m in _history)
                      _MessageLine(name: m.displayName, message: m.message),
                    for (final m in _live)
                      _MessageLine(name: m.name, message: m.message),
                  ],
                ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: loggedIn,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: loggedIn
                        ? L10n.t('write_message')
                        : L10n.t('login_to_chat'),
                    counterText: '',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: loggedIn ? _send : null,
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.name, required this.message});
  final String name;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$name: ',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: colorScheme.primary),
            ),
            TextSpan(
              text: message,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
